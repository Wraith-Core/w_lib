w.require("string")

w.createModule("resource")

--- Check if a resource matches the expected state and version/convar condition
--- A "!" prefixed resource must NOT be running; otherwise the resource must be running and satisfy its condition
---@param str string ((resourceName:convar(< > <= >= ==)value) or "!resourceName")
---@return boolean (true if the resource matches)
function w.resource.isConvarMatching(str)
  local negated = str:sub(1, 1) == "!"
  if negated then str = str:sub(2) end

  local resource, convar, comparator, value = str:extractConvarComparator()
  local state = GetResourceState(resource)

  -- "!" prefix: the resource must NOT be running
  if negated then
    return state ~= "starting" and state ~= "started"
  end

  -- Positive matches accept only resources that are actually booting or ready.
  -- Treat "stopping" and any unknown state as unavailable; otherwise the
  -- framework loader can enter an endless wait while a resource is shutting down.
  if state ~= "starting" and state ~= "started" then
    return false
  end

  -- optional version/convar condition (convar defaults to "version")
  if not comparator then return true end
  local currentValue = tostring(GetValue(GetResourceMetadata(resource, convar or "version", 0), 1))
  local compare = currentValue:compareVersionWith(value)
  if comparator == "<=" then
    return compare <= 0
  elseif comparator == ">=" then
    return compare >= 0
  elseif comparator == "==" or comparator == "=" then
    return compare == 0
  elseif comparator == "<" then
    return compare < 0
  elseif comparator == ">" then
    return compare > 0
  end
  return true
end
