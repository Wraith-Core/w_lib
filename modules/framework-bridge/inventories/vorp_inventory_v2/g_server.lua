local function getItemsFromDB()
  local itemsWaiter = promise.new()
  MySQL.ready(function()
    local itemsDB = MySQL.query.await("SELECT * FROM items")
    local items = {}
    for i = 1, #itemsDB do
      local item = itemsDB[i]
      items[item.item] = {
        item = item.item,
        label = item.label,
        type = item.type,
        description = item.description,
        image = "nui://vorp_inventory/html/img/items/" .. item.item .. ".png"
      }
    end
    itemsWaiter:resolve(items)
  end)
  return Await(itemsWaiter)
end

w.ready(function()
  Wait(1000)
  w.framework.inventoryItems = getItemsFromDB()
end)

local function waitInitInventoryItems()
  while table.isEmpty(w.framework.inventoryItems) do Wait(10) end
end

-- ★ التسجيل مباشرةً لا داخل w.ready.
--
-- كان ملفوفاً بـw.ready، فيبقى الكولباك غير مسجَّل طوال نافذة الإقلاع
-- (w.ready + ‎Wait(1000)‎ + استعلام SELECT * FROM items). وأيّ مورد يسأل في
-- تلك النافذة — مثل w_forge — يتلقّى «No server callback for».
--
-- التسجيل المبكّر آمن: المُعالِج نفسه ينتظر جهوز القائمة عبر
-- waitInitInventoryItems، فالنداء المبكّر يُعلَّق حتّى تجهز البيانات بدل أن
-- يسقط. وهذا نفس ما يفعله محوّل tpz_inventory أصلاً.
w.callback.register.latent("w_lib:server:w_framework_getInventoryItems", function()
  waitInitInventoryItems()
  return w.framework.inventoryItems
end)

function w.framework:getInventoryItems()
  waitInitInventoryItems()
  return w.framework.inventoryItems
end

-- Listener for item removed of the player inventory
RegisterNetEvent("vorp_inventory:Server:OnItemRemoved", function(data, source)
  local item = data.name
  local quantity = data.count
  local metadata = data.metadata
  TriggerEvent("w_lib:inventory:listenerItemRemoved", source, item, { quantity = quantity, metadata = metadata }, "dropped")
end)
