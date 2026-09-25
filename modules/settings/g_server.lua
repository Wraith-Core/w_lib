-------------
-- settings (w_lib's own VM) — the server-console command for the live settings of every resource.
--
--   wsettings                        the resources that opted in (w_settings 'yes') and how many of
--   wsettings list                   their values an admin changed
--   wsettings show <resource>        the changed values of one resource (and the stored-but-unused ones)
--   wsettings reset <resource> [key] back to the code default: one key, or every changed value
--
-- Console only: it is the way back when a value broke something and nobody can open the panel.
-- `setr w_settings:safe 1` + a restart of the resource boots it with its code defaults instead.
-- Loaded once in w_lib, the first time a resource uses w.settings.
-------------
if not IsDuplicityVersion() then return end

local function optedIn()
  local list = {}
  for i = 0, GetNumResources() - 1 do
    local res = GetResourceByFindIndex(i)
    if res and GetResourceMetadata(res, "w_settings", 0) == "yes" then list[#list + 1] = res end
  end
  table.sort(list)
  return list
end

local function call(res, name, ...)
  if GetResourceState(res) ~= "started" then return nil, "not started" end
  local args = table.pack(...)
  local ok, result = pcall(function() return exports[res][name](nil, table.unpack(args, 1, args.n)) end)
  if not ok then return nil, tostring(result) end
  return result
end

local function short(value)
  local ok, text = pcall(json.encode, value)
  text = ok and text or tostring(value)
  if #text > 60 then text = text:sub(1, 57) .. "..." end
  return text
end

--- every changed value of a resource: { { key, value, default, orphan } }
local function changed(res)
  local schema, err = call(res, "WSettingsSchema")
  if type(schema) ~= "table" then return nil, err or "no schema" end
  local out, seen = {}, {}
  local function add(key, value, default, orphan)
    if seen[key] then return end
    seen[key] = true
    out[#out + 1] = { key = key, value = value, default = default, orphan = orphan }
  end
  local form = call(res, "WSettingsValues")
  if type(form) == "table" then
    for key in pairs(form.overridden or {}) do add(key, (form.values or {})[key], (form.defaults or {})[key]) end
    for _, key in ipairs(form.orphans or {}) do add(key, nil, nil, true) end
  end
  for _, group in ipairs(schema.groups or {}) do
    if group.type == "table" then
      local v = call(res, "WSettingsValues", group.id)
      if type(v) == "table" then
        for _, row in ipairs(v.rows or {}) do
          for _, col in ipairs(row.overridden or {}) do
            add(("%s.%s.%s"):format(group.id, row.id, col), (row.cells or {})[col], (row.defaults or {})[col])
          end
        end
        for _, key in ipairs(v.orphans or {}) do add(key, nil, nil, true) end
      end
    end
  end
  table.sort(out, function(a, b) return a.key < b.key end)
  return out
end

RegisterCommand("wsettings", function(source, args)
  if source ~= 0 then return end
  local verb = args[1] or "list"
  if verb == "list" then
    local list = optedIn()
    if #list == 0 then return print("[w_settings] no resource declares w_settings 'yes'") end
    for _, res in ipairs(list) do
      local values = changed(res)
      print(("[w_settings] %-18s %-9s %s changed value(s)"):format(res, GetResourceState(res), values and #values or "?"))
    end
    if GetConvar("w_settings:safe", "0") ~= "0" then print("[w_settings] SAFE MODE is on (setr w_settings:safe 0)") end
    return
  end
  local res = args[2]
  if not res or GetResourceMetadata(res, "w_settings", 0) ~= "yes" then
    return print("[w_settings] usage: wsettings list | show <resource> | reset <resource> [key]")
  end
  local values, err = changed(res)
  if not values then return print(("[w_settings] %s: %s"):format(res, tostring(err))) end
  if verb == "show" then
    if #values == 0 then return print(("[w_settings] %s runs with its code defaults"):format(res)) end
    for _, v in ipairs(values) do
      if v.orphan then
        print(("  %s  (stored, not applied)"):format(v.key))
      else
        print(("  %s = %s   (default %s)"):format(v.key, short(v.value), short(v.default)))
      end
    end
    return
  end
  if verb ~= "reset" then return print("[w_settings] usage: wsettings list | show <resource> | reset <resource> [key]") end
  local key = args[3]
  local batch = {}
  for _, v in ipairs(values) do
    if not key or v.key == key then batch[#batch + 1] = { key = v.key, from = v.value, reset = true } end
  end
  if #batch == 0 then return print(("[w_settings] %s: nothing to reset%s"):format(res, key and (" for " .. key) or "")) end
  local result = call(res, "WSettingsApply", batch, { src = 0, name = "console", via = "console" })
  if type(result) == "table" and result.ok then
    print(("[w_settings] %s: %d value(s) back to the code default"):format(res, #batch))
  else
    local first = type(result) == "table" and result.rejected and result.rejected[1] or nil
    print(("[w_settings] %s: refused (%s)"):format(res, first and (first.key .. ": " .. first.reason) or "no answer"))
  end
end, true)
