-------------
-- Shaed Side: Add Overwrite for your inventory
-- ⚠️ This file is executed once in w_lib resource ⚠️
-------------

-- This override is intentionally loaded after the detected inventory adapter.
-- w_lib starts before w_inventory, so selecting an adapter from resource state
-- during w_lib startup can be stale by the time consumers request the item
-- catalogue. Resolve w_inventory at call time and keep the detected adapter as
-- a safe fallback for native inventories.
local inheritedGetInventoryItems = w.framework.getInventoryItems

---@return table
function w.framework:getInventoryItems()
  if GetResourceState("w_inventory") == "started" then
    local items = {}
    local success, list = pcall(function()
      return exports.w_inventory:Items()
    end)

    if success and type(list) == "table" then
      for id, item in pairs(list) do
        if type(item) == "table" then
          local image = item.client and item.client.image or (id .. ".png")

          if not image:match("%.%w+$") then image = image .. ".png" end

          items[id] = {
            item = id,
            label = item.label or id,
            type = item.weapon and "item_weapon" or "item_standard",
            description = item.description,
            image = image:match("^%w+://") and image
              or ("nui://w_inventory/web/images/" .. image),
          }
        end
      end
    end

    return items
  end

  if inheritedGetInventoryItems then
    local ok, items = pcall(inheritedGetInventoryItems, self)
    if ok and type(items) == "table" then return items end
  end

  return {}
end
