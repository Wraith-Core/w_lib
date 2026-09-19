-- ════════════════════════════════════════════════════════════════════════════
-- w.logs — the w_logs resource through the library (server API; the client side only
-- answers IsReady() = false so shared code can be written once).
--
--   w.logs.IsReady()                      -> boolean (w_logs started and its database open)
--   w.logs.RegisterScript(data)           -> { ok = true, ... } | { ok = false, error = ... }
--   w.logs.RegisterLogType(definition)    -> same
--   w.logs.RegisterLogTypes(list)         -> same
--   w.logs.Emit(key, payload) / w.logs.Log(key, payload) -> the stored record or false
--   w.logs.GetPlayerLogs(charId, group, limit) -> rows
--   w.logs.GetPlayerThread(charId)        -> thread id | nil
--   w.logs.GetSources()                   -> the registered scripts / types tree
--
-- Every call is guarded: when w_logs is not running the functions return false / {} so a
-- resource never dies because logging is optional. The invoking resource is the caller
-- (the export is called from the consumer's VM), so w_logs attributes records correctly.
-- ════════════════════════════════════════════════════════════════════════════
w.createModule("logs")

local RESOURCE = "w_logs"

local function ready()
  return GetResourceState(RESOURCE) == "started"
end

local function call(name, fallback, ...)
  if not ready() then return fallback end
  local ok, result = pcall(function(...) return exports[RESOURCE][name](nil, ...) end, ...)
  if not ok then
    return fallback
  end
  return result
end

function w.logs.IsReady()
  if w.isClientSide() then return false end
  return call("IsReady", false) == true
end

function w.logs.RegisterScript(data)
  return call("RegisterScript", { ok = false, error = "w_logs is not running" }, data)
end

function w.logs.RegisterLogType(definition)
  return call("RegisterLogType", { ok = false, error = "w_logs is not running" }, definition)
end

function w.logs.RegisterLogTypes(list)
  return call("RegisterLogTypes", { ok = false, error = "w_logs is not running" }, list)
end

function w.logs.Emit(key, payload)
  return call("Emit", false, key, payload)
end

w.logs.Log = w.logs.Emit

function w.logs.GetPlayerLogs(charId, group, limit)
  return call("GetPlayerLogs", {}, charId, group, limit)
end

function w.logs.GetPlayerThread(charId)
  return call("GetPlayerThread", nil, charId)
end

function w.logs.GetSources()
  return call("GetSources", {})
end

-- lower-case aliases in the library's own style
w.logs.isReady = w.logs.IsReady
w.logs.emit = w.logs.Emit
w.logs.registerScript = w.logs.RegisterScript
w.logs.registerLogType = w.logs.RegisterLogType
w.logs.registerLogTypes = w.logs.RegisterLogTypes
