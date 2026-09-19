local RSGCore = exports["rsg-core"]:GetCoreObject()
w.framework.core = RSGCore

RegisterNetEvent("rsg-appearance:client:ApplyClothes", function(clothes, ped, skin)
  ped = ped or PlayerPedId()
  if skin and not clothes then
    return TriggerServerEvent("w_lib:server:applySkin", ped, skin)
  end
  if clothes and not skin then
    return TriggerServerEvent("w_lib:server:applyClothes", ped, clothes)
  end
  TriggerServerEvent("w_lib:server:applySkinAndClothes", ped, skin, clothes)
end)
