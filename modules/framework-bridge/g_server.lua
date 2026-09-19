w.require("framework-bridge")
w.require("callback")
w.file.load("@oxmysql.lib.MySQL")

-------------
-- CORE
-------------
w.framework:loadCoreFiles("g_server")

RegisterNetEvent("w_lib:server:applySkinAndClothes", function(ped, skin, clothes)
  local source = source

  if w.framework:is("vorp") then
    if table.count(w.framework:getUserIdentifiers(source)) > 0 then return end --will be fired by vorpcharacter:reloadedskinlistener
  end

  ped = ped
  skin = w.framework:standardizeSkin(UnJson(skin))
  clothes = w.framework:standardizeClothes(UnJson(clothes))

  if clothes.teeth then
    skin.teeth = clothes.teeth.hash
    clothes.teeth = nil
  end

  TriggerClientEvent("w_lib:client:applySkinAndClothes", source, ped, skin, clothes)
end)

RegisterNetEvent("w_lib:server:applyClothes", function(ped, clothes)
  local source = source
  ped = ped
  clothes = w.framework:standardizeClothes(UnJson(clothes))

  TriggerClientEvent("w_lib:client:applyClothes", source, ped, clothes)
end)

RegisterNetEvent("w_lib:server:applySkin", function(ped, skin)
  local source = source

  if w.framework:is("vorp") then
    if table.count(w.framework:getUserIdentifiers(source)) > 0 then return end --will be fired by vorpcharacter:reloadedskinlistener
  end

  ped = ped
  skin = w.framework:standardizeSkin(UnJson(skin))

  TriggerClientEvent("w_lib:client:applySkin", source, ped, skin)
end)


-------------
-- INVENTORIES
-------------
w.framework:loadInventoryFiles("g_server")
