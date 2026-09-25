-------------
-- settings — the live settings of a resource, changed from the admin console (w_admin) while the
-- server runs, with a plain explanation behind every value.
--
-- A resource opts in with one manifest line and one shared file:
--
--   fxmanifest.lua   w_settings 'yes'                      (w_admin finds it by this line)
--   shared file, LAST in shared_scripts (after everything that builds its Config):
--     MyLive = w.settings.define({
--       resource = 'my_res', version = 1,
--       access = function(src) return IsPlayerAceAllowed(src, 'my_res.admin') end, accessAce = 'my_res.admin',
--       groups = {
--         { id = 'needs', store = 'own', apply = function(changes, actor) ... end,
--           fields = { w.settings.number({ key = 'needs.rate', min = 0, max = 25, step = 0.1, default = 1,
--                                          read = function() return MyCfg.rate end }) } },
--         { id = 'food', store = 'central', clientVisible = true,
--           rows = function() return { { id = 'apple', label = { ar = 'تفاح', en = 'Apple' } } } end,
--           columns = { w.settings.number({ key = 'hunger', min = -50, max = 100, step = 1,
--             read = function(row) return Config.Food[row].hunger or 0 end,
--             write = function(row, v) Config.Food[row].hunger = v end }) } },
--       },
--     })
--
-- The module then registers three exports INSIDE the resource (server.lua):
--   WSettingsSchema()              -> the schema as plain data, every text in Arabic and English
--   WSettingsValues(group?)        -> { values, defaults, overridden, rows?, orphans }
--   WSettingsApply(changes, actor) -> { ok, applied, rejected }
-- Only data crosses resources, never functions (a function becomes a funcref on the way).
--
-- Storage, chosen per group:
--   'central'  one row per CHANGED key in `w_admin_settings (resource, skey)`, read by the resource
--              itself at boot (w_admin may be stopped), applied on top of the final Config, with the
--              code default it replaced (`base`) so a later change of that default is flagged (drift)
--   'own'      the resource keeps its existing save path (group.apply): its own panel keeps working
--              and sees the same values
--
-- Texts: every label / help / example / unit comes from the resource's own locales/{ar,en}.json
-- under settings.* (see settings.textBase below), so the schema always carries both languages.
--
-- This file: the field constructors, the ONE validator both sides run (w_admin before asking, the
-- resource again before saving), key parsing, and define(), which hands over to server.lua /
-- client.lua of this module.
-------------
local settings = w.createModule("settings")

settings.KEY_PATTERN = "^[%w_%-%.]+$"
settings.ID_PATTERN = "^[%w_%-]+$"
settings.MAX_KEY = 191
settings.MAX_CHANGES = 500
settings.MAX_BYTES = 262144
settings.MAX_TEXT = 2000

local TYPES = { number = true, bool = true, enum = true, text = true, list = true, table = true }
settings.TYPES = TYPES

-------------
-- Field constructors: plain tables with the type set. Any key the schema format knows may be
-- given (min, max, step, integer, unit, options, maxLength, pattern, item, maxItems, advanced,
-- requiresRestart, derived, text, label, help, example, danger, confirm, default, read, write).
-------------
local function ctor(kind)
  return function(def)
    def = type(def) == "table" and def or {}
    def.type = kind
    return def
  end
end
settings.number = ctor("number")
settings.bool = ctor("bool")
settings.enum = ctor("enum")
settings.text = ctor("text")
settings.list = ctor("list")

-------------
-- values
-------------

--- A deep copy of a value (tables are copied, the rest returned as is)
function settings.copy(value)
  if type(value) ~= "table" then return value end
  local out = {}
  for k, v in pairs(value) do out[k] = settings.copy(v) end
  return out
end

--- Two values are the same setting value: numbers within 1e-9 (a JSON round trip), tables deep
function settings.equal(a, b)
  if a == b then return true end
  local ta, tb = type(a), type(b)
  if ta == "number" and tb == "number" then return math.abs(a - b) < 1e-9 end
  if ta ~= "table" or tb ~= "table" then return false end
  for k, v in pairs(a) do
    if not settings.equal(v, b[k]) then return false end
  end
  for k in pairs(b) do
    if a[k] == nil then return false end
  end
  return true
end

local function finite(n)
  return type(n) == "number" and n == n and n ~= math.huge and n ~= -math.huge
end

--- Why `value` cannot be stored in `field`, or nil when it can. Out of range is REJECTED, never
--- clamped: a clamped value is a value the admin did not choose. A text over maxLength is rejected,
--- never cut (a cut could split an Arabic letter).
---@param field table a field definition (or its plain-data copy from the schema)
---@param value any
---@return string|nil reason 'bad_type' | 'out_of_range'
function settings.check(field, value)
  local kind = field and field.type
  if kind == "number" then
    if not finite(value) then return "bad_type" end
    if field.integer and value % 1 ~= 0 then return "bad_type" end
    if field.min and value < field.min - 1e-9 then return "out_of_range" end
    if field.max and value > field.max + 1e-9 then return "out_of_range" end
    local step = tonumber(field.step)
    if step and step > 0 then
      local n = (value - (field.min or 0)) / step
      if math.abs(n - math.floor(n + 0.5)) > 1e-6 then return "out_of_range" end
    end
    return nil
  elseif kind == "bool" then
    if type(value) == "boolean" then return nil end
    return "bad_type"
  elseif kind == "enum" then
    for _, option in ipairs(field.options or {}) do
      if option.value == value then return nil end
    end
    return (type(value) == "string" or type(value) == "number") and "out_of_range" or "bad_type"
  elseif kind == "text" then
    if type(value) ~= "string" or value:find("\0", 1, true) then return "bad_type" end
    local length = utf8.len(value)
    if not length then return "bad_type" end
    if length > (field.maxLength or settings.MAX_TEXT) then return "out_of_range" end
    if field.pattern and value ~= "" and not value:match(field.pattern) then return "out_of_range" end
    return nil
  elseif kind == "list" then
    if type(value) ~= "table" then return "bad_type" end
    local n = #value
    for k in pairs(value) do
      if math.type(k) ~= "integer" or k < 1 or k > n then return "bad_type" end
    end
    if field.maxItems and n > field.maxItems then return "out_of_range" end
    if type(field.item) == "table" then
      for i = 1, n do
        local reason = settings.check(field.item, value[i])
        if reason then return reason end
      end
    end
    return nil
  end
  return "bad_type"
end

--- settings.check plus the field's own rule (field.validate(value) -> reason | nil), which only
--- the resource has (a function does not travel in the schema)
function settings.checkField(field, value)
  local reason = settings.check(field, value)
  if reason then return reason end
  if type(field.validate) == "function" then
    local ok, result = pcall(field.validate, value)
    if not ok then return "bad_type" end
    if result then return tostring(result) end
  end
  return nil
end

-------------
-- the index: which key names which field
-------------

local function noDots(id) return type(id) == "string" and id:match(settings.ID_PATTERN) ~= nil end

--- Builds the lookup of a definition (with functions) or of a schema (plain data from
--- WSettingsSchema): { fields = { [key] = field }, groupOf = { [key] = group },
--- tables = { [groupId] = { group, columns = { [col] = column } } } }.
---@param groups table[] the groups (definition or schema)
---@return table index
function settings.index(groups)
  local index = { fields = {}, groupOf = {}, tables = {}, groups = {} }
  for _, group in ipairs(groups or {}) do
    index.groups[group.id] = group
    local columns = group.columns
    if not columns and type(group.fields) == "table" and group.fields[1] and group.fields[1].type == "table" then
      columns = group.fields[1].columns -- the schema shape: one table field that carries the columns
    end
    if columns then
      local cols = {}
      for _, column in ipairs(columns) do cols[column.key] = column end
      index.tables[group.id] = { group = group, columns = cols }
    else
      for _, field in ipairs(group.fields or {}) do
        index.fields[field.key] = field
        index.groupOf[field.key] = group
      end
    end
  end
  return index
end

--- What a key names: a field ('field', field, group) or a table cell ('cell', column, group, rowId).
--- A cell key is '<group>.<row>.<column>'; rows and columns carry no dots.
---@return string|nil kind
---@return table|nil field or column
---@return table|nil group
---@return string|nil row
function settings.locate(index, key)
  if type(key) ~= "string" or #key > settings.MAX_KEY or not key:match(settings.KEY_PATTERN) then return nil end
  local field = index.fields[key]
  if field then return "field", field, index.groupOf[key] end
  local groupId, rest = key:match("^([^%.]+)%.(.+)$")
  local tbl = groupId and index.tables[groupId]
  if not tbl then return nil end
  local row, col = rest:match("^(.+)%.([^%.]+)$")
  if not row or row:find(".", 1, true) then return nil end
  local column = tbl.columns[col]
  if not column then return nil end
  return "cell", column, tbl.group, row
end

--- The key of a table cell
function settings.cellKey(groupId, row, col)
  return ("%s.%s.%s"):format(groupId, row, col)
end

--- Checks the SHAPE of a batch of changes against an index: size, keys, types, ranges. The
--- resource runs this again with `opts` (current values, rows, locks) before saving; w_admin runs it
--- on the schema before asking. Returns the normalised changes and the rejected ones.
---   changes: a dense array of { key, from, to } or { key, from, reset = true } (at most 500)
---   opts.current(kind, field, group, row, key) -> the value now      (compare-and-set: 'stale')
---   opts.row(group, row) -> false (no such row) | true | lockedText (the row may not change)
---@param index table
---@param changes any
---@param opts? table
---@return table[] list  { key, kind, field, group, row, from, to, reset }
---@return table[] rejected  { key, reason }
function settings.checkChanges(index, changes, opts)
  local list, rejected = {}, {}
  if type(changes) ~= "table" then return list, { { key = "", reason = "bad_type" } } end
  local n = #changes
  if n == 0 then return list, rejected end
  if n > settings.MAX_CHANGES then return list, { { key = "", reason = "too_many" } } end
  for k in pairs(changes) do
    if math.type(k) ~= "integer" or k < 1 or k > n then return list, { { key = "", reason = "bad_type" } } end
  end
  local seen = {}
  opts = opts or {}
  for i = 1, n do
    local change = changes[i]
    local key = type(change) == "table" and change.key or nil
    local function reject(reason) rejected[#rejected + 1] = { key = type(key) == "string" and key or "", reason = reason } end
    if type(change) ~= "table" or type(key) ~= "string" then
      reject("bad_type")
    elseif seen[key] then
      reject("duplicate")
    else
      seen[key] = true
      local kind, field, group, row = settings.locate(index, key)
      local reset = change.reset == true
      if not kind then
        reject("unknown_key")
      elseif field.readOnly == true then
        reject("unknown_key")
      else
        local reason = nil
        if not reset then reason = settings.checkField(field, change.to) end
        if not reason and kind == "cell" and opts.row then
          local state = opts.row(group, row)
          if state == false or state == nil then
            reason = "unknown_key"
          elseif state ~= true and not reset then
            reason = "locked_row"
          end
        end
        if not reason and opts.current then
          local now = opts.current(kind, field, group, row, key)
          if not settings.equal(now, change.from) then reason = "stale" end
        end
        if reason then
          reject(reason)
        else
          local to = nil -- (not `reset and nil or v`: that idiom loses a `false`)
          if not reset then to = settings.copy(change.to) end
          list[#list + 1] = {
            key = key, kind = kind, field = field, group = group, row = row,
            from = change.from, to = to, reset = reset,
          }
        end
      end
    end
  end
  return list, rejected
end

-------------
-- texts (the resource's locales/{ar,en}.json, key 'settings.*')
-------------

local dictionaries = {}

local function dictionary(lang)
  local resource = GetCurrentResourceName()
  local cacheKey = resource .. ":" .. lang
  if dictionaries[cacheKey] == nil then
    local raw = LoadResourceFile(resource, ("locales/%s.json"):format(lang))
    local ok, data = pcall(json.decode, raw or "")
    dictionaries[cacheKey] = ok and type(data) == "table" and data or false
  end
  return dictionaries[cacheKey] or nil
end

local function lookup(data, key)
  if type(data) ~= "table" then return nil end
  if type(data[key]) == "string" then return data[key] end -- a flat dictionary
  local node = data
  for part in key:gmatch("[^%.]+") do
    if type(node) ~= "table" then return nil end
    node = node[part]
  end
  return type(node) == "string" and node or nil
end

--- A text in both languages from the resource's locales ({ ar, en }), or nil when neither has it.
--- A missing language takes the other one.
---@param key string e.g. 'settings.food.hunger.help'
---@return table|nil
function settings.textOf(key)
  local ar, en = lookup(dictionary("ar"), key), lookup(dictionary("en"), key)
  if not ar and not en then return nil end
  return { ar = ar or en, en = en or ar }
end

--- Drops the cached dictionaries (a locale file changed while the resource runs)
function settings.reloadTexts()
  dictionaries = {}
end

--- The text key base of a group / field / column:
---   group            settings.<group>                 (.label .help .confirm)
---   field            settings.<field key>             (.label .help .example .unit .danger .confirm)
---   table column     settings.<group>.<column>        (same sub-keys)
---   option           <field base>.options.<value>     ('' is written 'none')
---   family           settings.<group>.families.<id>
---   read-only col    settings.<group>.readOnly.<key>
---   link             settings.links.<id>              (.label .help)
--- A definition may name another base with `text = 'settings.x.y'`.
function settings.textBase(kind, def, group)
  if type(def) == "table" and type(def.text) == "string" then return def.text end
  if kind == "group" then return "settings." .. def.id end
  if kind == "column" then return ("settings.%s.%s"):format(group.id, def.key) end
  return "settings." .. def.key
end

-------------
-- define
-------------

local function fail(message, ...)
  error(("w.settings.define (%s): " .. message):format(GetCurrentResourceName(), ...), 3)
end

--- Registers the settings of THIS resource (once). Call it from a shared file loaded after
--- everything that builds the Config it edits. Returns a handle:
---   handle.onChange(fn)          fn(changes, actor) after every apply (server) / every push (client)
---   handle.apply(changes, actor) the server-side apply (what WSettingsApply runs; for the resource's
---                                own panel or a console command)
---   handle.values(group?)        what WSettingsValues answers
---   handle.get(key)              the value in effect now
---
--- Group:  { id, store = 'central' | 'own', clientVisible?, level?, confirm?, text?,
---           fields = { field... }                         (a form)
---           or rows = function() -> { { id, label = {ar,en} | key, family?, image?, locked? } },
---              describe = function(id) -> { label?, image? }   (costly labels, asked by the page only)
---              columns = { column... }, families = { { id } }, readOnly = { { key, read(row) } },
---              checkRow = function(row, cells, changed) -> reason | nil  (a table: one row per item)
---           apply = function(changes, actor) -> ok, err   (own groups: the resource's save path)
---           onChange = function(changes, actor) }
--- Field:  w.settings.number / bool / enum / text / list { key, read(), write(v) (central), default
---         (own), min, max, step, integer, options, maxLength, pattern, item, maxItems, advanced,
---         requiresRestart, derived, text }
--- Column: the same with read(row) / write(row, v) and a key without dots.
---@param spec table
---@return table handle
function settings.define(spec)
  if type(spec) ~= "table" or type(spec.groups) ~= "table" then fail("spec.groups is missing") end
  local server = IsDuplicityVersion()
  local def = { resource = GetCurrentResourceName(), spec = spec, groups = {}, hooks = {} }
  local seenGroup, seenKey = {}, {}
  for _, group in ipairs(spec.groups) do
    if not noDots(group.id) then fail("group id '%s' must be letters, digits, _ or -", tostring(group.id)) end
    if seenGroup[group.id] then fail("group '%s' is declared twice", group.id) end
    seenGroup[group.id] = true
    group.store = group.store == "own" and "own" or "central"
    if group.columns then
      group.type = "table"
      if type(group.rows) ~= "function" then fail("table group '%s' needs rows()", group.id) end
      local seenCol = {}
      for _, column in ipairs(group.columns) do
        if not noDots(column.key) or not TYPES[column.type] or column.type == "table" then
          fail("column '%s' of '%s' needs a key without dots and a type", tostring(column.key), group.id)
        end
        if seenCol[column.key] then fail("column '%s' of '%s' is declared twice", column.key, group.id) end
        seenCol[column.key] = true
        if type(column.read) ~= "function" then fail("column '%s' of '%s' needs read(row)", column.key, group.id) end
        if group.store == "central" and type(column.write) ~= "function" then
          fail("column '%s' of '%s' needs write(row, value)", column.key, group.id)
        end
      end
    else
      group.type = "form"
      for _, field in ipairs(group.fields or {}) do
        if type(field.key) ~= "string" or not field.key:match(settings.KEY_PATTERN) or #field.key > settings.MAX_KEY then
          fail("a field of '%s' has no valid key", group.id)
        end
        if not TYPES[field.type] or field.type == "table" then fail("field '%s' has no type", field.key) end
        if seenKey[field.key] then fail("key '%s' is declared twice", field.key) end
        seenKey[field.key] = true
        if type(field.read) ~= "function" then fail("field '%s' needs read()", field.key) end
        if group.store == "central" and type(field.write) ~= "function" then fail("field '%s' needs write(value)", field.key) end
      end
    end
    if group.store == "own" and server and type(group.apply) ~= "function" then
      fail("own group '%s' needs apply(changes, actor)", group.id)
    end
    def.groups[#def.groups + 1] = group
  end
  def.index = settings.index(def.groups)
  if server then return settings._server(def) end
  return settings._client(def)
end

return settings
