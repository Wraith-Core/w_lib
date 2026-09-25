-------------
-- settings (server) — the resource side of the live-settings protocol: boot, apply, push, audit.
--
--   w.settings.define(spec)          (shared.lua) -> settings._server(def): registers in THIS resource
--     exports WSettingsSchema() / WSettingsValues(group?) / WSettingsApply(changes, actor)
--     the callback '<resource>:w_settings:snapshot' (a client that starts asks for the values)
--     the net event '<resource>:w_settings' (pushed to every client, 100 ms after the last change)
--   w.settings.ensureTables()        the three tables (w_admin runs it too; whoever starts first)
--   w.settings.safeMode()            true when `setr w_settings:safe 1`: central values are NOT
--                                    applied at boot (they are listed as orphans), new values refused
--   w.settings.audit(rows)           writes audit rows (w_admin's history reads them)
--
-- Rules inside WSettingsApply (the resource is the authority, w_admin is only the front door):
--   1. only w_admin, w_lib (the console command) or the resource itself may call it
--   2. the actor passes the resource's own admin test (spec.access); the console (src 0) always does
--   3. all or nothing: unknown_key, out_of_range, bad_type, locked_row, stale, duplicate, ...
--   4. compare-and-set: `from` must equal the value in effect, or the change is 'stale' (two admins,
--      or the resource's own panel, edited the same value)
--   5. save first (own groups: group.apply; central: one transaction with the audit rows), then
--      write Config, then the onChange hooks, then the push. A failed save applies nothing.
-------------
local settings = w.createModule("settings")

local RESOURCE = GetCurrentResourceName()
local EVENT = RESOURCE .. ":w_settings"
local SNAPSHOT = RESOURCE .. ":w_settings:snapshot"

local TABLES = {
  [[CREATE TABLE IF NOT EXISTS `w_admin_settings` (
    `resource` VARCHAR(64) NOT NULL,
    `skey` VARCHAR(191) NOT NULL,
    `value` LONGTEXT NOT NULL,
    `base` LONGTEXT NULL,
    `updated_at` INT NOT NULL,
    `updated_by` VARCHAR(64) NULL,
    PRIMARY KEY (`resource`, `skey`)
  ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci]],
  [[CREATE TABLE IF NOT EXISTS `w_admin_settings_audit` (
    `id` BIGINT AUTO_INCREMENT PRIMARY KEY,
    `batch` VARCHAR(36) NOT NULL,
    `resource` VARCHAR(64) NOT NULL,
    `skey` VARCHAR(191) NOT NULL,
    `old_value` LONGTEXT NULL,
    `new_value` LONGTEXT NULL,
    `actor_cid` VARCHAR(64) NULL,
    `actor_name` VARCHAR(96) NULL,
    `actor_src` INT NULL,
    `via` VARCHAR(32) NOT NULL DEFAULT 'w_admin',
    `note` VARCHAR(200) NULL,
    `created_at` INT NOT NULL,
    KEY `resource_skey` (`resource`, `skey`),
    KEY `created_at` (`created_at`)
  ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci]],
  [[CREATE TABLE IF NOT EXISTS `w_admin_settings_presets` (
    `id` INT AUTO_INCREMENT PRIMARY KEY,
    `name` VARCHAR(80) NOT NULL,
    `data` LONGTEXT NOT NULL,
    `created_by` VARCHAR(64) NULL,
    `created_at` INT NOT NULL
  ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci]],
}

local tablesReady = false

--- Creates the three tables when missing. Needs oxmysql's MySQL in this resource.
---@return boolean
function settings.ensureTables()
  if tablesReady then return true end
  if type(MySQL) ~= "table" or not MySQL.query then return false end
  for _, sql in ipairs(TABLES) do
    local ok, err = pcall(MySQL.query.await, sql)
    if not ok then
      w.print.error(("w_settings: could not create the settings tables (%s)"):format(tostring(err)))
      return false
    end
  end
  tablesReady = true
  return true
end

--- `setr w_settings:safe 1` (or `true`): every resource boots with its code defaults and refuses new
--- central values until the convar is cleared and the resource restarted. The stored values stay in
--- the table and are listed as orphans (reason 'safe'), so a bad value can be found and reset.
---@return boolean
function settings.safeMode()
  local v = GetConvar("w_settings:safe", "0")
  return v == "1" or v == "true"
end

local function encode(value)
  if value == nil then return nil end
  local ok, text = pcall(json.encode, value)
  return ok and text or nil
end

local function decode(text)
  if type(text) ~= "string" then return nil end
  local ok, value = pcall(json.decode, text)
  if ok then return value end
  return nil
end

--- Whole numbers as integers (30, not 30.0): Config tables and JSON stay tidy
local function tidy(value)
  if math.type(value) == "float" and value % 1 == 0 and value > -2^53 and value < 2^53 then
    return math.tointeger(value)
  end
  return value
end

local function newBatch()
  local hex = {}
  for i = 1, 32 do hex[i] = ("%x"):format(math.random(0, 15)) end
  local s = table.concat(hex)
  return ("%s-%s-%s-%s-%s"):format(s:sub(1, 8), s:sub(9, 12), s:sub(13, 16), s:sub(17, 20), s:sub(21, 32))
end

--- Writes audit rows { batch, resource, key, old, new (nil = back to the default), actor, via, note }
---@param rows table[]
---@return boolean
function settings.audit(rows)
  if type(rows) ~= "table" or #rows == 0 then return true end
  if not settings.ensureTables() then return false end
  local queries = {}
  for _, r in ipairs(rows) do
    local actor = r.actor or {}
    queries[#queries + 1] = {
      query = "INSERT INTO w_admin_settings_audit (batch, resource, skey, old_value, new_value, actor_cid, actor_name, actor_src, via, note, created_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
      values = { r.batch, r.resource, r.key, encode(r.old), encode(r.new), actor.cid and tostring(actor.cid) or nil,
        actor.name and tostring(actor.name):sub(1, 96) or nil, tonumber(actor.src), tostring(r.via or actor.via or "w_admin"):sub(1, 32),
        r.note and tostring(r.note):sub(1, 200) or nil, r.at or os.time() },
    }
  end
  local ok, done = pcall(MySQL.transaction.await, queries)
  return ok and done ~= false
end

-------------
-- the definition of this resource
-------------

local state -- one per resource VM

local function reasonList(changes, reason)
  local out = {}
  for i, c in ipairs(type(changes) == "table" and changes or {}) do
    out[i] = { key = type(c) == "table" and type(c.key) == "string" and c.key or "", reason = reason }
  end
  if #out == 0 then out[1] = { key = "", reason = reason } end
  return out
end

local function refuse(changes, reason, extra)
  local out = { ok = false, applied = {}, rejected = reasonList(changes, reason) }
  if extra then for k, v in pairs(extra) do out[k] = v end end
  return out
end

local function readLive(kind, field, row)
  if kind == "field" then return field.read() end
  return field.read(row)
end

local function writeLive(kind, field, row, value)
  if kind == "field" then field.write(settings.copy(value)) else field.write(row, settings.copy(value)) end
end

--- The rows of a table group, as the resource declares them now: { [id] = row }
local function rowMap(group)
  local ok, rows = pcall(group.rows)
  local map, list = {}, {}
  if not ok then
    w.print.error(("w_settings: rows() of '%s' failed: %s"):format(group.id, tostring(rows)))
    return map, list
  end
  for _, row in ipairs(type(rows) == "table" and rows or {}) do
    if type(row) == "table" and type(row.id) == "string" and row.id:match(settings.ID_PATTERN) and not map[row.id] then
      map[row.id] = row
      list[#list + 1] = row
    end
  end
  return map, list
end

local function rowsOf(group)
  local cache = state.rowCache[group.id]
  if not cache or GetGameTimer() - cache.at > 2000 then
    local map, list = rowMap(group)
    cache = { map = map, list = list, at = GetGameTimer() }
    state.rowCache[group.id] = cache
  end
  return cache.map, cache.list
end

--- The code default of a key (central: the value before the first override; own: field.default)
local function defaultOf(key, kind, field, group, row)
  if group.store == "own" then
    local d = field.default
    if type(d) == "function" then d = d(row) end
    return settings.copy(d)
  end
  if state.captured[key] then return settings.copy(state.originals[key]) end
  local ok, value = pcall(readLive, kind, field, row)
  if ok then return value end -- (a `false` default must survive: no `ok and value or nil`)
  return nil
end

local function capture(key, kind, field, row)
  if state.captured[key] then return end
  local ok, value = pcall(readLive, kind, field, row)
  if ok then state.originals[key] = settings.copy(value) else state.originals[key] = nil end
  state.captured[key] = true
end

--- The value in effect (for a restart-only value changed since the start: the value the admin
--- chose, which takes effect at the next start)
local function currentOf(kind, field, group, row, key)
  if group.store == "central" and field.requiresRestart and state.pending[key] ~= nil then
    return settings.copy(state.pending[key])
  end
  local ok, value = pcall(readLive, kind, field, row)
  if not ok then return nil end
  return value
end

local function rowStateOf(group, row)
  local map = rowsOf(group)
  local r = map[row]
  if not r then return false end
  if r.locked then return r.locked end
  return true
end

-------------
-- texts and the schema (plain data)
-------------

local EMPTY = { ar = "", en = "" }

local function textAt(base, sub)
  return settings.textOf(base .. "." .. sub)
end

local function localText(value, fallbackKey)
  if type(value) == "table" and (value.ar or value.en) then
    return { ar = value.ar or value.en, en = value.en or value.ar }
  end
  if type(value) == "string" then
    return settings.textOf(value) or { ar = value, en = value }
  end
  return fallbackKey and settings.textOf(fallbackKey) or nil
end

local SCALAR_KEYS = { "min", "max", "step", "integer", "scale", "maxLength", "multiline", "pattern", "maxItems",
  "requiresRestart", "advanced", "readOnly" }

local function fieldData(kind, field, group)
  local base = settings.textBase(kind, field, group)
  local out = {
    key = field.key,
    type = field.type,
    label = localText(field.label) or textAt(base, "label") or { ar = field.key, en = field.key },
    help = localText(field.help) or textAt(base, "help") or EMPTY,
    example = localText(field.example) or textAt(base, "example"),
    unit = localText(field.unit) or textAt(base, "unit"),
    danger = localText(field.danger) or textAt(base, "danger"),
    confirm = localText(field.confirm) or textAt(base, "confirm"),
  }
  for _, k in ipairs(SCALAR_KEYS) do
    if field[k] ~= nil then out[k] = field[k] end
  end
  if type(field.derived) == "table" then out.derived = settings.copy(field.derived) end
  if type(field.options) == "table" then
    out.options = {}
    for i, option in ipairs(field.options) do
      local id = option.value == "" and "none" or tostring(option.value)
      out.options[i] = {
        value = option.value,
        label = localText(option.label) or settings.textOf(base .. ".options." .. id) or { ar = tostring(option.value), en = tostring(option.value) },
        help = localText(option.help),
      }
    end
  end
  if type(field.item) == "table" then out.item = fieldData("field", field.item, group) end
  return out
end

local function buildSchema()
  local spec = state.def.spec
  local out = {
    resource = RESOURCE,
    version = spec.version or 1,
    title = localText(spec.title) or settings.textOf("settings.title") or { ar = RESOURCE, en = RESOURCE },
    description = localText(spec.description) or settings.textOf("settings.description") or EMPTY,
    groups = {},
  }
  if type(spec.links) == "table" then
    out.links = {}
    for i, link in ipairs(spec.links) do
      local base = "settings.links." .. tostring(link.id)
      out.links[i] = {
        id = link.id, command = link.command, level = link.level,
        label = localText(link.label) or textAt(base, "label") or { ar = tostring(link.id), en = tostring(link.id) },
        help = localText(link.help) or textAt(base, "help") or EMPTY,
      }
    end
  end
  for _, group in ipairs(state.def.groups) do
    local base = settings.textBase("group", group)
    local g = {
      id = group.id,
      label = localText(group.label) or textAt(base, "label") or { ar = group.id, en = group.id },
      help = localText(group.help) or textAt(base, "help") or EMPTY,
      confirm = localText(group.confirm) or textAt(base, "confirm"),
      store = group.store,
      clientVisible = group.clientVisible == true,
      type = group.type,
      level = group.level,
      fields = {},
    }
    if group.type == "table" then
      local tbl = { key = group.id, type = "table", label = g.label, help = g.help, columns = {} }
      for i, column in ipairs(group.columns) do tbl.columns[i] = fieldData("column", column, group) end
      if type(group.families) == "table" then
        tbl.families = {}
        for i, family in ipairs(group.families) do
          tbl.families[i] = {
            id = family.id,
            label = localText(family.label) or settings.textOf(("%s.families.%s"):format(base, family.id)) or { ar = family.id, en = family.id },
          }
        end
      end
      if type(group.readOnly) == "table" then
        tbl.readOnly = {}
        for i, ro in ipairs(group.readOnly) do
          tbl.readOnly[i] = {
            key = ro.key,
            label = localText(ro.label) or settings.textOf(("%s.readOnly.%s"):format(base, ro.key)) or { ar = ro.key, en = ro.key },
          }
        end
      end
      g.fields[1] = tbl
    else
      for i, field in ipairs(group.fields or {}) do g.fields[i] = fieldData("field", field, group) end
    end
    out.groups[#out.groups + 1] = g
  end
  return out
end

-------------
-- values (what the page reads)
-------------

local function lastEdits()
  local out = {}
  if not settings.ensureTables() then return out end
  local ok, rows = pcall(MySQL.query.await,
    "SELECT skey, actor_name, created_at FROM w_admin_settings_audit WHERE resource = ? ORDER BY id DESC LIMIT 300", { RESOURCE })
  if not ok or type(rows) ~= "table" then return out end
  for _, r in ipairs(rows) do
    if r.skey and not out[r.skey] then out[r.skey] = { by = r.actor_name or "", at = tonumber(r.created_at) or 0 } end
  end
  return out
end

local function overrideInfo(key, group, value, default, edits)
  if group.store == "central" then
    local o = state.overrides[key]
    if not o then return nil end
    -- the stored row names the editor by citizen id; the audit keeps the name people recognise
    local e = edits()[key]
    local by = (e and e.by ~= "" and e.by) or o.by or ""
    return { by = by, at = o.at or 0, base = settings.copy(o.base) }
  end
  if settings.equal(value, default) then return nil end
  edits = edits()
  local e = edits[key] or {}
  return { by = e.by or "", at = e.at or 0, base = settings.copy(default) }
end

--- The label and picture of a row: rows() may carry them, group.describe(id) -> { label, image }
--- may add them when they are costly (another resource's item catalogue), asked only here.
local function describeRow(group, row)
  local label, image = row.label, row.image
  if type(group.describe) == "function" then
    local ok, v = pcall(group.describe, row.id)
    if ok and type(v) == "table" then
      label = v.label or label
      image = v.image or image
    end
  end
  return localText(label) or { ar = row.id, en = row.id }, image
end

local function values(groupId)
  local def = state.def
  local out = { values = {}, defaults = {}, overridden = {}, orphans = {} }
  local edits
  local function lazyEdits()
    edits = edits or lastEdits()
    return edits
  end
  local wanted = {}
  if groupId ~= nil then
    local g = def.index.groups[groupId]
    if not g then return nil end
    wanted[1] = g
  else
    for _, g in ipairs(def.groups) do
      if g.type ~= "table" then wanted[#wanted + 1] = g end
    end
  end
  for _, group in ipairs(wanted) do
    if group.type == "table" then
      local _, list = rowsOf(group)
      out.rows = {}
      for _, row in ipairs(list) do
        local label, image = describeRow(group, row)
        local r = {
          id = row.id, label = label, image = image, family = row.family,
          locked = row.locked and localText(row.locked) or nil,
          cells = {}, defaults = {}, overridden = {},
        }
        for _, column in ipairs(group.columns) do
          local key = settings.cellKey(group.id, row.id, column.key)
          local value = currentOf("cell", column, group, row.id, key)
          local default = defaultOf(key, "cell", column, group, row.id)
          r.cells[column.key], r.defaults[column.key] = value, default
          local info = overrideInfo(key, group, value, default, lazyEdits)
          if info then
            out.overridden[key] = info
            r.overridden[#r.overridden + 1] = column.key
          end
        end
        if type(group.readOnly) == "table" then
          for _, ro in ipairs(group.readOnly) do
            if type(ro.read) == "function" then
              local ok, v = pcall(ro.read, row.id)
              if ok then r.cells[ro.key] = v end
            end
          end
        end
        out.rows[#out.rows + 1] = r
      end
    else
      for _, field in ipairs(group.fields or {}) do
        local key = field.key
        local value = currentOf("field", field, group, nil, key)
        local default = defaultOf(key, "field", field, group)
        out.values[key], out.defaults[key] = value, default
        local info = overrideInfo(key, group, value, default, lazyEdits)
        if info then out.overridden[key] = info end
      end
    end
  end
  for key in pairs(state.orphans) do
    local prefix = key:match("^([^%.]+)")
    if groupId == nil or prefix == groupId then out.orphans[#out.orphans + 1] = key end
  end
  table.sort(out.orphans)
  return out
end

-------------
-- push to the clients (only the central values of clientVisible groups that are in effect)
-------------

local function snapshot()
  local out = { v = state.version, values = {} }
  for key, o in pairs(state.overrides) do
    if o.visible and o.live then out.values[key] = settings.copy(o.value) end
  end
  return out
end

local function schedulePush()
  if state.pushPending then return end
  state.pushPending = true
  Citizen.SetTimeout(100, function()
    state.pushPending = false
    state.version = state.version + 1
    TriggerClientEvent(EVENT, -1, snapshot())
  end)
end

-------------
-- apply
-------------

local function actorOf(actor)
  actor = type(actor) == "table" and actor or {}
  local src = tonumber(actor.src) or 0
  local name = actor.name
  if name == nil then name = src == 0 and "console" or (GetPlayerName(src) or ("#" .. src)) end
  return {
    src = math.tointeger(src) or 0,
    cid = actor.cid ~= nil and tostring(actor.cid) or nil,
    name = tostring(name):sub(1, 96),
    via = tostring(actor.via or "w_admin"):sub(1, 32),
    note = actor.note ~= nil and tostring(actor.note):sub(1, 200) or nil,
  }
end

local rate = {}

local function limited(actor)
  if actor.src == 0 then return false end
  local now = GetGameTimer()
  local r = rate[actor.src]
  if not r or now - r.at >= 1000 then
    rate[actor.src] = { at = now, n = 1 }
    return false
  end
  r.n = r.n + 1
  return r.n > 2
end

AddEventHandler("playerDropped", function()
  if state then rate[source] = nil end
end)

local function hooksFor(list, actor)
  local byGroup = {}
  for _, c in ipairs(list) do
    local g = c.group.id
    byGroup[g] = byGroup[g] or {}
    byGroup[g][#byGroup[g] + 1] = { key = c.key, row = c.row, column = c.kind == "cell" and c.field.key or nil,
      value = settings.copy(c.value), old = settings.copy(c.old), reset = c.reset }
  end
  for _, group in ipairs(state.def.groups) do
    local changes = byGroup[group.id]
    if changes and type(group.onChange) == "function" then
      local ok, err = pcall(group.onChange, changes, actor)
      if not ok then w.print.error(("w_settings: onChange of '%s' failed: %s"):format(group.id, tostring(err))) end
    end
  end
  local all = {}
  for _, c in ipairs(list) do
    all[#all + 1] = { key = c.key, group = c.group.id, row = c.row, column = c.kind == "cell" and c.field.key or nil,
      value = settings.copy(c.value), old = settings.copy(c.old), reset = c.reset }
  end
  for _, fn in ipairs(state.def.hooks) do
    local ok, err = pcall(fn, all, actor)
    if not ok then w.print.error(("w_settings: onChange hook failed: %s"):format(tostring(err))) end
  end
end

local function apply(changes, actor, invoker)
  if invoker and invoker ~= "" and invoker ~= RESOURCE and invoker ~= "w_admin" and invoker ~= "w_lib" then
    return refuse(changes, "no_access")
  end
  actor = actorOf(actor)
  if not state.booted then return refuse(changes, "not_ready") end
  local spec = state.def.spec
  if actor.src ~= 0 and type(spec.access) == "function" then
    local ok, allowed = pcall(spec.access, actor.src)
    if not ok or not allowed then return refuse(changes, "no_access", { ace = spec.accessAce }) end
  end
  local okSize, encoded = pcall(json.encode, changes)
  if not okSize or type(encoded) ~= "string" then return refuse(changes, "bad_type") end
  if #encoded > settings.MAX_BYTES then return refuse(changes, "too_large") end

  -- resetting a stored value that is not applied (an orphan) only deletes its row
  local orphanResets, rest = {}, {}
  for _, c in ipairs(type(changes) == "table" and changes or {}) do
    if type(c) == "table" and c.reset == true and type(c.key) == "string" and state.orphans[c.key] then
      orphanResets[#orphanResets + 1] = c.key
    else
      rest[#rest + 1] = c
    end
  end

  local list, rejected = settings.checkChanges(state.def.index, rest, { current = currentOf, row = rowStateOf })

  -- a table group may refuse a combination on one row (buff strength without a buff)
  if #rejected == 0 then
    local touched = {}
    for _, c in ipairs(list) do
      if c.kind == "cell" and type(c.group.checkRow) == "function" then
        touched[c.group.id] = touched[c.group.id] or { group = c.group, rows = {} }
        touched[c.group.id].rows[c.row] = true
      end
    end
    for _, t in pairs(touched) do
      for row in pairs(t.rows) do
        local cells, touchedCols = {}, {}
        for _, column in ipairs(t.group.columns) do
          local key = settings.cellKey(t.group.id, row, column.key)
          cells[column.key] = currentOf("cell", column, t.group, row, key)
        end
        for _, c in ipairs(list) do
          if c.kind == "cell" and c.group == t.group and c.row == row then
            if c.reset then
              cells[c.field.key] = defaultOf(c.key, "cell", c.field, c.group, row)
            else
              cells[c.field.key] = c.to
            end
            touchedCols[c.field.key] = true
          end
        end
        local ok, reason = pcall(t.group.checkRow, row, cells, touchedCols)
        if ok and reason then
          for _, c in ipairs(list) do
            if c.group == t.group and c.row == row then rejected[#rejected + 1] = { key = c.key, reason = reason } end
          end
        end
      end
    end
  end

  if #rejected > 0 then return { ok = false, applied = {}, rejected = rejected } end
  if #list == 0 and #orphanResets == 0 then return { ok = true, applied = {}, rejected = {} } end

  if settings.safeMode() then
    local refused = {}
    for _, c in ipairs(list) do
      if c.group.store == "central" and not c.reset then refused[#refused + 1] = { key = c.key, reason = "safe_mode" } end
    end
    if #refused > 0 then return { ok = false, applied = {}, rejected = refused } end
  end
  if limited(actor) then return refuse(changes, "rate_limited") end

  -- what each change becomes
  local now = os.time()
  for _, c in ipairs(list) do
    c.old = currentOf(c.kind, c.field, c.group, c.row, c.key)
    c.default = defaultOf(c.key, c.kind, c.field, c.group, c.row)
    if c.reset then
      c.value = settings.copy(c.default)
    else
      c.value = tidy(c.to)
    end
    -- a central value equal to the code default is not an override: its row goes
    if c.group.store == "central" and settings.equal(c.value, c.default) then c.drop = true end
  end

  local batch = newBatch()
  local auditRows = {}
  for _, c in ipairs(list) do
    local newValue = nil -- NULL: back to the code default
    if not (c.reset or c.drop) then newValue = c.value end
    auditRows[#auditRows + 1] = { batch = batch, resource = RESOURCE, key = c.key, old = c.old,
      new = newValue, actor = actor, via = actor.via, note = actor.note, at = now }
  end
  for _, key in ipairs(orphanResets) do
    auditRows[#auditRows + 1] = { batch = batch, resource = RESOURCE, key = key, old = state.orphans[key].value,
      new = nil, actor = actor, via = actor.via, note = "orphan", at = now }
  end

  -- 1) own groups: the resource's own save path
  local ownDone = {}
  for _, group in ipairs(state.def.groups) do
    if group.store == "own" then
      local mine = {}
      for _, c in ipairs(list) do
        if c.group == group then
          mine[#mine + 1] = { key = c.key, row = c.row, column = c.kind == "cell" and c.field.key or nil,
            value = settings.copy(c.value), old = settings.copy(c.old), reset = c.reset }
        end
      end
      if #mine > 0 then
        local ok, saved, err = pcall(group.apply, mine, actor)
        if not ok or saved == false then
          w.print.error(("w_settings: saving '%s' failed: %s"):format(group.id, tostring(ok and err or saved)))
          -- undo the own groups already saved in this batch
          for _, done in ipairs(ownDone) do
            local undo = {}
            for i, c in ipairs(done.changes) do undo[i] = { key = c.key, row = c.row, column = c.column, value = c.old, old = c.value } end
            pcall(done.group.apply, undo, actor)
          end
          return refuse(changes, "db_error")
        end
        ownDone[#ownDone + 1] = { group = group, changes = mine }
      end
    end
  end

  -- 2) central groups + the audit in one transaction
  local queries = {}
  for _, c in ipairs(list) do
    if c.group.store == "central" then
      if c.reset or c.drop then
        queries[#queries + 1] = { query = "DELETE FROM w_admin_settings WHERE resource = ? AND skey = ?", values = { RESOURCE, c.key } }
      else
        queries[#queries + 1] = {
          query = "INSERT INTO w_admin_settings (resource, skey, value, base, updated_at, updated_by) VALUES (?, ?, ?, ?, ?, ?) ON DUPLICATE KEY UPDATE value = VALUES(value), base = VALUES(base), updated_at = VALUES(updated_at), updated_by = VALUES(updated_by)",
          values = { RESOURCE, c.key, encode(c.value), encode(c.default), now, actor.cid or actor.name },
        }
      end
    end
  end
  for _, key in ipairs(orphanResets) do
    queries[#queries + 1] = { query = "DELETE FROM w_admin_settings WHERE resource = ? AND skey = ?", values = { RESOURCE, key } }
  end
  local stored = settings.ensureTables()
  if stored then
    for _, r in ipairs(auditRows) do
      queries[#queries + 1] = {
        query = "INSERT INTO w_admin_settings_audit (batch, resource, skey, old_value, new_value, actor_cid, actor_name, actor_src, via, note, created_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
        values = { r.batch, r.resource, r.key, encode(r.old), encode(r.new), actor.cid, actor.name, actor.src, actor.via, r.note, r.at },
      }
    end
    local ok, done = pcall(MySQL.transaction.await, queries)
    stored = ok and done ~= false
  end
  if not stored then
    for _, done in ipairs(ownDone) do
      local undo = {}
      for i, c in ipairs(done.changes) do undo[i] = { key = c.key, row = c.row, column = c.column, value = c.old, old = c.value } end
      pcall(done.group.apply, undo, actor)
    end
    w.print.error("w_settings: the database refused the change; nothing was applied")
    return refuse(changes, "db_error")
  end

  -- 3) Config, live (central); own groups were written by their apply
  local push = false
  for _, c in ipairs(list) do
    if c.group.store == "central" then
      capture(c.key, c.kind, c.field, c.row)
      local live = not c.field.requiresRestart
      if c.reset or c.drop then
        state.overrides[c.key] = nil
        if live then writeLive(c.kind, c.field, c.row, state.originals[c.key]) end
      else
        state.overrides[c.key] = { value = settings.copy(c.value), base = settings.copy(c.default), by = actor.name, at = now,
          visible = c.group.clientVisible == true, live = live }
        if live then writeLive(c.kind, c.field, c.row, c.value) end
      end
      if live and c.group.clientVisible then push = true end
      if not live then state.pending[c.key] = settings.copy(c.value) end
    end
  end
  for _, key in ipairs(orphanResets) do state.orphans[key] = nil end
  state.rowCache = {}

  -- 4) hooks, then 5) the push
  hooksFor(list, actor)
  if push then schedulePush() end

  local applied = {}
  for _, c in ipairs(list) do applied[#applied + 1] = { key = c.key, value = settings.copy(c.value), old = settings.copy(c.old), reset = c.reset or c.drop or nil } end
  for _, key in ipairs(orphanResets) do applied[#applied + 1] = { key = key, value = nil, reset = true } end
  return { ok = true, applied = applied, rejected = {}, batch = batch }
end

-------------
-- boot: read the stored values and apply them on top of the final Config
-------------

local function boot()
  local deadline = GetGameTimer() + 20000
  while (type(MySQL) ~= "table" or not MySQL.query) and GetGameTimer() < deadline do Wait(100) end
  if type(MySQL) ~= "table" or not settings.ensureTables() then
    w.print.error(("w_settings: no database in %s - the settings run with their code defaults"):format(RESOURCE))
    state.booted = true
    return
  end
  local ok, rows = pcall(MySQL.query.await,
    "SELECT skey, value, base, updated_at, updated_by FROM w_admin_settings WHERE resource = ?", { RESOURCE })
  if not ok or type(rows) ~= "table" then rows = {} end
  local safe = settings.safeMode()
  local applied, drift, orphans = 0, 0, 0
  -- apply in declaration order (a buff type before its strength)
  local order = {}
  for i, group in ipairs(state.def.groups) do
    order[group.id] = i * 1000
    for j, column in ipairs(group.columns or group.fields or {}) do order[group.id .. "|" .. column.key] = i * 1000 + j end
  end
  local function rank(key)
    local kind, field, group = settings.locate(state.def.index, key)
    if not kind then return math.huge end
    return order[group.id .. "|" .. field.key] or order[group.id] or math.huge
  end
  table.sort(rows, function(a, b)
    local ra, rb = rank(a.skey), rank(b.skey)
    if ra ~= rb then return ra < rb end
    return tostring(a.skey) < tostring(b.skey)
  end)
  for _, r in ipairs(rows) do
    local key = r.skey
    local value, base = decode(r.value), decode(r.base)
    local kind, field, group, row = settings.locate(state.def.index, key)
    local reason = nil
    local rowState = true
    if kind == "cell" then rowState = rowStateOf(group, row) end
    if safe then
      reason = "safe"
    elseif not kind or group.store ~= "central" or rowState == false then
      reason = "unknown"
    elseif rowState ~= true then
      reason = "locked"
    elseif settings.checkField(field, value) then
      reason = "invalid"
    end
    if reason then
      state.orphans[key] = { value = value, reason = reason }
      orphans = orphans + 1
    else
      capture(key, kind, field, row)
      local okWrite, err = pcall(writeLive, kind, field, row, value)
      if okWrite then
        state.overrides[key] = { value = value, base = base, by = r.updated_by or "", at = tonumber(r.updated_at) or 0,
          visible = group.clientVisible == true, live = true }
        applied = applied + 1
        if base ~= nil and not settings.equal(base, state.originals[key]) then drift = drift + 1 end
      else
        state.orphans[key] = { value = value, reason = "invalid" }
        orphans = orphans + 1
        w.print.error(("w_settings: %s could not be applied: %s"):format(key, tostring(err)))
      end
    end
  end
  state.booted = true
  if safe and #rows > 0 then
    w.print.warn(("w_settings: SAFE MODE - %d stored value(s) of %s ignored (setr w_settings:safe 0 to use them)"):format(#rows, RESOURCE))
  elseif applied > 0 or orphans > 0 then
    w.print.info(("w_settings: %d changed value(s) applied%s%s"):format(applied,
      drift > 0 and (", %d whose code default changed since"):format(drift) or "",
      orphans > 0 and (", %d stored but not applied (orphans)"):format(orphans) or ""))
  end
  schedulePush()
end

-------------
-- define (server)
-------------

function settings._server(def)
  if state then error(("w.settings.define: %s defines its settings twice"):format(RESOURCE), 3) end
  state = {
    def = def, booted = false, version = 0, pushPending = false,
    overrides = {}, originals = {}, captured = {}, orphans = {}, pending = {}, rowCache = {},
  }

  exports("WSettingsSchema", function()
    return buildSchema()
  end)
  exports("WSettingsValues", function(group)
    if not state.booted then return nil end
    return values(group)
  end)
  exports("WSettingsApply", function(changes, actor)
    return apply(changes, actor, GetInvokingResource())
  end)

  w.callback.register(SNAPSHOT, function()
    local deadline = GetGameTimer() + 10000
    while not state.booted and GetGameTimer() < deadline do Wait(100) end
    return snapshot()
  end)

  -- Every central value's original is read NOW, before any stored value is written: a column that
  -- depends on another one of its row (a buff's strength on its type) must not take the other's
  -- override as its default.
  for _, group in ipairs(def.groups) do
    if group.store == "central" then
      if group.type == "table" then
        local _, list = rowsOf(group)
        for _, row in ipairs(list) do
          for _, column in ipairs(group.columns) do capture(settings.cellKey(group.id, row.id, column.key), "cell", column, row.id) end
        end
      else
        for _, field in ipairs(group.fields or {}) do capture(field.key, "field", field) end
      end
    end
  end

  CreateThread(boot)

  local handle = {}
  function handle.onChange(fn)
    if type(fn) == "function" then def.hooks[#def.hooks + 1] = fn end
    return handle
  end
  function handle.apply(changes, actor)
    return apply(changes, actor, RESOURCE)
  end
  function handle.values(group)
    return values(group)
  end
  function handle.schema()
    return buildSchema()
  end
  function handle.get(key)
    local kind, field, group, row = settings.locate(def.index, key)
    if not kind then return nil end
    return currentOf(kind, field, group, row, key)
  end
  function handle.ready()
    return state.booted
  end
  return handle
end

return settings
