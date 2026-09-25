-------------
-- settings (client) — keeps this client's Config in step with the values an admin changed.
--
-- The server sends a SNAPSHOT: every central value of a clientVisible group that is in effect,
-- { v, values = { [key] = value } }. It arrives
--   · once when this resource starts on the client (the callback '<resource>:w_settings:snapshot':
--     a player who joins later, or a restart of the resource),
--   · after every change (the net event '<resource>:w_settings', 100 ms after the last change).
-- Each value is written through the SAME write function the server uses (the definition is shared),
-- so the client's Config changes in place and every reader that looks Config.* up at the moment of
-- use sees it. A key that left the snapshot (reset to its default) gets its original value back.
-------------
local settings = w.createModule("settings")

local RESOURCE = GetCurrentResourceName()
local EVENT = RESOURCE .. ":w_settings"
local SNAPSHOT = RESOURCE .. ":w_settings:snapshot"

local state

local function readLive(kind, field, row)
  if kind == "field" then return field.read() end
  return field.read(row)
end

local function writeLive(kind, field, row, value)
  if kind == "field" then field.write(settings.copy(value)) else field.write(row, settings.copy(value)) end
end

local function merge(snap)
  if type(snap) ~= "table" or type(snap.values) ~= "table" then return end
  local v = tonumber(snap.v) or 0
  if v < state.version then return end -- an older answer arriving after a newer push
  state.version = v
  local changed = {}
  -- keys that went back to their default
  for key, info in pairs(state.written) do
    if snap.values[key] == nil then
      local ok, err = pcall(writeLive, info.kind, info.field, info.row, state.originals[key])
      if not ok then w.print.error(("w_settings: restoring %s failed: %s"):format(key, tostring(err))) end
      state.written[key] = nil
      changed[#changed + 1] = { key = key, reset = true }
    end
  end
  -- keys in apply order (a buff type before its strength): the declaration order
  local keys = {}
  for key in pairs(snap.values) do keys[#keys + 1] = key end
  table.sort(keys, function(a, b)
    local ra, rb = state.rank(a), state.rank(b)
    if ra ~= rb then return ra < rb end
    return a < b
  end)
  for _, key in ipairs(keys) do
    local value = snap.values[key]
    local kind, field, group, row = settings.locate(state.def.index, key)
    if kind and group.store == "central" and group.clientVisible and settings.checkField(field, value) == nil then
      local previous = state.written[key]
      if not previous or not settings.equal(previous.value, value) then
        if not state.captured[key] then
          local ok, original = pcall(readLive, kind, field, row)
          if ok then state.originals[key] = settings.copy(original) else state.originals[key] = nil end
          state.captured[key] = true
        end
        local ok, err = pcall(writeLive, kind, field, row, value)
        if ok then
          state.written[key] = { kind = kind, field = field, row = row, value = settings.copy(value) }
          changed[#changed + 1] = { key = key, value = settings.copy(value) }
        else
          w.print.error(("w_settings: %s could not be applied: %s"):format(key, tostring(err)))
        end
      end
    end
  end
  if #changed > 0 then
    for _, fn in ipairs(state.def.hooks) do
      local ok, err = pcall(fn, changed)
      if not ok then w.print.error(("w_settings: onChange hook failed: %s"):format(tostring(err))) end
    end
  end
end

function settings._client(def)
  if state then error(("w.settings.define: %s defines its settings twice"):format(RESOURCE), 3) end
  state = { def = def, version = -1, written = {}, originals = {}, captured = {} }
  local order = {}
  for i, group in ipairs(def.groups) do
    for j, column in ipairs(group.columns or group.fields or {}) do order[group.id .. "|" .. column.key] = i * 1000 + j end
  end
  function state.rank(key)
    local kind, field, group = settings.locate(def.index, key)
    if not kind then return math.huge end
    return order[group.id .. "|" .. field.key] or math.huge
  end

  -- the originals, read before the first snapshot writes anything (see server.lua)
  for _, group in ipairs(def.groups) do
    if group.store == "central" and group.clientVisible then
      if group.type == "table" then
        local ok, rows = pcall(group.rows)
        for _, row in ipairs(ok and type(rows) == "table" and rows or {}) do
          if type(row) == "table" and type(row.id) == "string" then
            for _, column in ipairs(group.columns) do
              local key = settings.cellKey(group.id, row.id, column.key)
              local okRead, value = pcall(readLive, "cell", column, row.id)
              if okRead then state.originals[key] = settings.copy(value) end
              state.captured[key] = okRead
            end
          end
        end
      else
        for _, field in ipairs(group.fields or {}) do
          local okRead, value = pcall(readLive, "field", field)
          if okRead then state.originals[field.key] = settings.copy(value) end
          state.captured[field.key] = okRead
        end
      end
    end
  end

  local anyVisible = false
  for _, group in ipairs(def.groups) do
    if group.store == "central" and group.clientVisible then anyVisible = true end
  end

  if anyVisible then
    RegisterNetEvent(EVENT, function(snap) merge(snap) end)
    CreateThread(function()
      -- the server may still be reading its stored values: ask again a few times
      for attempt = 1, 5 do
        local ok, snap = pcall(w.callback.triggerServer, SNAPSHOT)
        if ok and type(snap) == "table" then
          merge(snap)
          return
        end
        Wait(1500 * attempt)
      end
      w.print.warn(("w_settings: %s got no settings snapshot from the server"):format(RESOURCE))
    end)
  end

  local handle = {}
  function handle.onChange(fn)
    if type(fn) == "function" then def.hooks[#def.hooks + 1] = fn end
    return handle
  end
  function handle.get(key)
    local kind, field, _, row = settings.locate(def.index, key)
    if not kind then return nil end
    local ok, value = pcall(readLive, kind, field, row)
    if ok then return value end
    return nil
  end
  function handle.ready()
    return state.version >= 0
  end
  return handle
end

return settings
