w.require("callback")

w.callback.register(w.resourceName .. ":hook:callFilter", function(source, name, value, ...)
  return w.hook.applyFilters(name, value, source, ...)
end)
