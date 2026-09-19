local RSGCore = exports["rsg-core"]:GetCoreObject()
w.framework.core = RSGCore

RegisterNetEvent("rsg-clothes:ApplyClothes", function(clothes, ped, skin)
  ped = ped or PlayerPedId()
  TriggerServerEvent("w_lib:server:applySkinAndClothes", ped, skin, clothes)
end)
