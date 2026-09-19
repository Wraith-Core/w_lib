w.require("callback")

--- Calls the server filters from the client side
---@param name string (The name of the filter)
---@param value any (The value to filter)
---@param ...? any (Additional arguments which are passed on the functions hooked.)
---@return any (The filtered value)
function w.hook.applyServerFilters(name, value, ...)
  if w.debug then
    bprint("Server filter fired: %s", name)
  end
  return w.callback.triggerServer(w.resourceName .. ":hook:callFilter", name, value, ...)
end
