-------------
-- Server Side: Add Overwrite for your inventory
-- ⚠️ This file is executed in all resources that load the framework module ⚠️
-------------

-- The old w framework bridge used to bind permanently to whichever inventory
-- happened to be running while a consumer resource started. Delegate the
-- common operations to w_lib's lazy invbridge instead, making startup order and
-- framework provider aliases irrelevant.

function w.framework:canUseItem(source, item, amount, meta, remove)
  amount = tonumber(amount) or 1
  local count = exports.w_lib:InvGetItemCount(source, item, meta) or 0

  if count < amount then return false end
  if remove then
    return exports.w_lib:InvRemoveItem(source, item, amount, meta) == true
  end

  return true
end

function w.framework:getItemCount(source, item, meta)
  return exports.w_lib:InvGetItemCount(source, item, meta) or 0
end

function w.framework:registerUseItem(item, closeAfterUsed, callback)
  if type(closeAfterUsed) == "function" then
    callback = closeAfterUsed
    closeAfterUsed = true
  end

  if closeAfterUsed == nil then closeAfterUsed = true end
  if type(callback) ~= "function" then return false end

  return exports.w_lib:InvRegisterUsableItem(item, closeAfterUsed, callback) == true
end

function w.framework:giveItem(source, item, quantity, meta)
  quantity = tonumber(quantity) or 1
  if exports.w_lib:InvCanCarry(source, item, quantity) ~= true then return false end
  return exports.w_lib:InvAddItem(source, item, quantity, meta) == true
end

function w.framework:createInventory(id, name, invConfig)
  invConfig = type(invConfig) == "table" and invConfig or {}
  return exports.w_lib:InvRegisterStash(
    id,
    name or id,
    tonumber(invConfig.maxSlots) or tonumber(invConfig.slots) or 50,
    (tonumber(invConfig.maxWeight) or 100) * 1000
  ) == true
end

function w.framework:openInventory(source, id)
  return exports.w_lib:InvOpenStash(source, id) == true
end

function w.framework:addItemInInventory(_, id, item, quantity, metadata)
  return exports.w_lib:InvAddItemToStash(id, item, quantity, metadata) == true
end
