local resources = {}

exports("w_nui_init", function()
  local resourceName = GetInvokingResource()
  for r = 1, #resources do
    if resources[r] == resourceName then return end
  end
  resources[#resources + 1] = resourceName
end)

exports("w_nui_is_global_hovering", function()
  for r = 1, #resources do
    if exports[resources[r]]:w_nui_is_hovering() then
      return true
    end
  end
  return false
end)

AddEventHandler("onResourceStop", function(resourceName)
  for r = 1, #resources do
    if resources[r] == resourceName then
      table.remove(resources, r)
      return
    end
  end
end)
