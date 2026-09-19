function w.framework:getInventoryItems()
  local itemsRSG = self.core and self.core.Shared and self.core.Shared.Items
  local items = {}
  if type(itemsRSG) ~= "table" then return items end
  for id, item in pairs(itemsRSG) do
    local image = item.image or id
    if not image:match("%.%w+$") then
      image = image .. ".png"
    end
    items[id] = {
      item = id,
      label = item.label,
      type = item.type,
      description = item.description,
      image = "nui://rsg-inventory/html/images/" .. image
    }
  end
  return items
end
