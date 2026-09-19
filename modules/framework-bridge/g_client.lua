w.require("framework-bridge")

-------------
-- CORE
-------------
w.framework:loadCoreFiles("g_client")

RegisterNetEvent("w_lib:client:applySkinAndClothes", function(ped, skin, clothes)
  ped = ped or PlayerPedId()
  if not (w.isModuleLoaded("component", false)) then
    return dprint("NO NEED skin. Component module is not")
  end
  w.component.waitPedLoaded(ped)
  w.timeout.delay("w_lib:client:applySkinAndClothes:" .. ped, 100, function()
    w.hook.doActions("w_lib:applySkinAndClothes:before", ped, skin, clothes)

    w.component.applySkin(ped, skin)
    w.component.applyComponents(ped, clothes)

    w.component.refreshPed(ped)

    w.hook.doActions("w_lib:applySkinAndClothes:after", ped, skin, clothes)
  end)
end)

RegisterNetEvent("w_lib:client:applySkin", function(ped, skin)
  if not (w.isModuleLoaded("component", false)) then
    return
  end
  ped = ped or PlayerPedId()
  w.timeout.delay("w_lib:client:applySkin:" .. ped, 100, function()
    w.hook.doActions("w_lib:applySkin:before", ped, skin)

    w.component.applySkin(ped, skin)

    w.component.refreshPed(ped)

    w.hook.doActions("w_lib:applySkinAndClothes:after", ped, skin)
  end)
end)

RegisterNetEvent("w_lib:client:applyClothes", function(ped, clothes)
  if not (w.isModuleLoaded("component", false)) then
    return
  end
  ped = ped or PlayerPedId()
  w.timeout.delay("w_lib:client:applyClothes:" .. ped, 100, function()
    w.hook.doActions("w_lib:applyClothes:before", ped, clothes)

    w.component.applyComponents(ped, clothes)

    w.component.refreshPed(ped)

    w.hook.doActions("w_lib:applyClothes:after", ped, clothes)
  end)
end)

-------------
-- INVENTORIES
-------------
w.framework:loadInventoryFiles("g_client")
