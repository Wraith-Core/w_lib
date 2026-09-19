-------------
-- VARIABLES
-------------
local initInventoryItemsInProcess = false

-------------
-- CORE
-------------
w.framework:loadCoreFiles("g_shared")

-------------
-- INVENTORIES
-------------
w.framework:loadInventoryFiles("g_shared")

---@return table (The list of items)
exports("w_framework_getInventoryItems", function()
  while initInventoryItemsInProcess do Wait(10) end
  if table.isEmpty(w.framework.inventoryItems) then
    initInventoryItemsInProcess = true
    local ok, items = pcall(w.framework.getInventoryItems, w.framework)
    w.framework.inventoryItems = ok and type(items) == "table" and items or {}

    if not ok then
      print(("^1[w_lib] inventory item catalogue failed: %s^0"):format(tostring(items)))
    end

    dprint("%d items inventory loaded", table.count(w.framework.inventoryItems))
    initInventoryItemsInProcess = false
  end
  return w.framework.inventoryItems
end)
