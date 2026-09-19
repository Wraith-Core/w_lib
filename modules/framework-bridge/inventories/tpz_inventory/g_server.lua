--[[

SharedItems.item
SharedItems.label
SharedItems.weight
SharedItems.remove
SharedItems.type
SharedItems.description
SharedItems.action
SharedItems.stackable
SharedItems.droppable
SharedItems.closeInventory
]]

local function GetItemsList()
  return exports.tpz_inventory:getInventoryAPI().getSharedItems()
end

w.ready(function()
  Wait(1000)
  w.framework.inventoryItems = GetItemsList()
end)

local function waitInitInventoryItems()
  while table.isEmpty(w.framework.inventoryItems) do Wait(10) end
end

w.callback.register.latent("w_lib:server:w_framework_getInventoryItems", function()
  waitInitInventoryItems()
  return w.framework.inventoryItems
end)

function w.framework:getInventoryItems()
  waitInitInventoryItems()
  return w.framework.inventoryItems
end
