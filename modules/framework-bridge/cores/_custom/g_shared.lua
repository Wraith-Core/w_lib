-------------
-- Shaed Side: Add Overwrite for your inventory
-- ⚠️ This file is executed once in w_lib resource ⚠️
-------------

-- ============================================================
-- دعم كتالوج عناصر w_inventory داخل w_lib
-- الخطأ: g_shared.lua:21 attempt to call a nil value (getInventoryItems)
-- ⚠️ يُمسح عند تحديث w_lib — أعِد لصقه
-- ============================================================
if GetResourceState('w_inventory') == 'started' then
    ---@return table
    function w.framework:getInventoryItems()
        local items = {}

        local success, list = pcall(function()
            return exports.w_inventory:Items()
        end)

        if not success or type(list) ~= 'table' then
            return items
        end

        for id, item in pairs(list) do
            if type(item) == 'table' then
                local image = item.client and item.client.image or (id .. '.png')

                if not image:match('%.%w+$') then
                    image = image .. '.png'
                end

                items[id] = {
                    item = id,
                    label = item.label or id,
                    type = 'item_standard',
                    description = item.description,
                    image = image:match('^%w+://') and image
                        or ('nui://w_inventory/web/images/' .. image),
                }
            end
        end

        return items
    end
end
