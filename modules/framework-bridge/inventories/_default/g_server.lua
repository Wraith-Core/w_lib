RegisterNetEvent("inventory:OnItemRemoved", function(source, item, quantity, metadata, reason)
  TriggerEvent("w_lib:inventory:listenerItemRemoved", source, item, { quantity = quantity, metadata = metadata }, reason)
end)
