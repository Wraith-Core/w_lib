-------------
-- INVENTORY
-------------

---@param source integer source ID
---@param item string name of the item
---@param amount integer amount to use
---@param meta table metadata of the item
---@param remove boolean if removed after used
function w.framework:canUseItem(source, item, amount, meta, remove)
  local count = exports.w_inventory:GetItem(source, item, meta, true)
  if not count then
    count = 0
  end
  if count >= amount then
    if remove then
      local res = exports.w_inventory:RemoveItem(source, item, amount, meta)
      return res
    end
  end
  return false
end

---@param item string name of the item
---@param callback function function fired when the item is used
---@param closeAfterUsed boolean if inventory needs to be closes
---@return boolean
function w.framework:registerUseItem(item, closeAfterUsed, callback)
  if type(closeAfterUsed) == "function" then
    callback = closeAfterUsed
    closeAfterUsed = true
  end
  local registered = exports.w_inventory:RegisterUsableItem(item, function(source, data)
    data = type(data) == "table" and data or {}
    callback(source, { metadata = data.metadata or {}, slot = data.slot, item = data })
    if closeAfterUsed then
      TriggerClientEvent("w_inventory:closeInventory", source)
    end
  end)
  return registered ~= false
end

---@param source integer source ID
---@param item string name of the item
---@param quantity integer quantity
---@param meta table metadata of the item
---@return boolean
function w.framework:giveItem(source, item, quantity, meta)
  if exports.w_inventory:CanCarryItem(source, item, quantity, meta) then
    local res = exports.w_inventory:AddItem(source, item, quantity, meta)
    return res
  end
  return false
end

---@param invName string unique ID of the inventory
---@param name string name of the inventory
---@param invConfig table Configuration of the inventory
---@return boolean
function w.framework:createInventory(invName, name, invConfig)
  local inventoryConfig = {
    id = invName,
    name = name,
    slots = invConfig.maxSlots,
    maxWeight = invConfig.maxWeight * 1000,
  }
  inventories[invName] = inventoryConfig
  exports.w_inventory:RegisterStash(inventoryConfig.id, inventoryConfig.name, inventoryConfig.slots, inventoryConfig.maxWeight)
  return true
end

---@param invName string unique ID of the inventory
---@return boolean
function w.framework:removeInventory(invName)
  return exports.w_inventory:RemoveInventory(invName)
end

---@param source integer sourceIdentifier
---@param invName string name of the inventory
---@return boolean
function w.framework:openInventory(source, invName)
  TriggerClientEvent("w_inventory:openInventory", source, "stash", { id = invName })
  return true
end

---@param invId string unique ID of the inventory
---@param item string name of the item
---@param quantity integer quantity
---@param metadata table metadata of the item
---@param needWait? boolean wait after the adding
---@return boolean
function w.framework:addItemInInventory(source, invId, item, quantity, metadata, needWait)
  return exports.w_inventory:AddItem(invId, item, quantity, metadata)
end

---@param invId string name of the inventory
---@return table
function w.framework:getItemsFromInventory(invId)
  return exports.w_inventory:GetInventoryItems(invId)
end

-------------
-- END INVENTORY
-------------
