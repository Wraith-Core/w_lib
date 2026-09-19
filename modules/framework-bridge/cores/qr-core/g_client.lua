RegisterNetEvent("w_clothes:ApplyClothes", function(clothes, ped, skin)
  ped = ped or PlayerPedId()
  TriggerServerEvent("w_lib:server:applySkinAndClothes", ped, skin, clothes)
end)

RegisterNetEvent("w_lib:client:openInventory", function(name, config)
  TriggerServerEvent("inventory:server:OpenInventory", "stash", name, { maxweight = config.maxWeight, slots = config.maxSlots })
  TriggerEvent("inventory:client:SetCurrentStash", name)
end)
