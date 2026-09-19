RegisterNetEvent("vorpcharacter:reloadedskinlistener", function()
  local source = source

  if table.count(w.framework:getUserIdentifiers(source)) == 0 then return end --Character not selected

  local skin = w.framework:getUserSkin(source)
  local clothes = w.framework:getUserClothes(source)

  TriggerClientEvent("w_lib:client:applySkinAndClothes", source, nil, skin, clothes)
end)
