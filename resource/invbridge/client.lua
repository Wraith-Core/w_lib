-- ════════════════════════════════════════════════════════════════════════════
-- w_lib — جسر الحقائب المركزيّ (عميل): تسمية العنصر + إغلاق الحقيبة عبر الأنظمة
-- ════════════════════════════════════════════════════════════════════════════

local NAME
local INV_ORDER = { 'w_inventory', 'rsg-inventory', 'qbr-inventory', 'vorp_inventory' }
local ALIASES = {
    w = 'w_inventory',
    ox = 'w_inventory',
    vorp = 'vorp_inventory',
    rsg = 'rsg-inventory',
    qbr = 'qbr-inventory',
}

local function normalize(name)
    name = tostring(name or 'auto'):lower():gsub('%s+', '')
    return ALIASES[name] or name
end

--- الحقيبة الفعّالة — نفس مرجع الخادم: (1) ما بثّه الخادم، (2) تثبيت يدويّ، (3) كشف محلّي بنفس الترتيب.
local function detect()
    local fromServer = GetConvar('w_lib:activeInventory', '')
    if fromServer ~= '' then
        local selected = normalize(fromServer)
        if GetResourceState(selected) == 'started' then
            NAME = selected
            return NAME
        end
    end

    -- w_inventory provides the native bag names. Prefer the actual provider
    -- locally as well, even before the replicated server decision arrives.
    if GetResourceState('w_inventory') == 'started' then
        NAME = 'w_inventory'
        return NAME
    end

    if NAME and GetResourceState(NAME) == 'started' then return NAME end
    NAME = nil

    local forced = normalize(GetConvar('w_lib:inventory', 'auto'))
    if forced ~= 'auto' and GetResourceState(forced) == 'started' then
        NAME = forced
        return NAME
    end
    for _, n in ipairs(INV_ORDER) do
        if GetResourceState(n) == 'started' then NAME = n; return NAME end
    end
    return nil
end

--- اسم الحقيبة الفعّالة (عميل) — يوازي exports.w_lib:InvName الخادميّ
exports('InvName', function() return detect() end)

--- Calls one of the active inventory's own exports by name: exports[<inventory>][fn](...).
--- The consumer names the function and never the resource, so the same line runs on
--- w_inventory, vorp_inventory or rsg-inventory. nil (and false as the second value) when
--- no inventory is up or it has no such export; the export's own return values otherwise.
exports('InvCall', function(fn, ...)
    local n = detect()
    if not n or type(fn) ~= 'string' then return nil, false end
    local target = exports[n]
    local ok, a, b, c, d = pcall(function(...) return target[fn](target, ...) end, ...)
    if not ok then return nil, false end
    return a, b, c, d
end)

--- The inventory's own export only (never the bridge's adapters), by name.
exports('InvNativeCall', function(fn, ...)
    local n = detect()
    if not n or type(fn) ~= 'string' then return nil, false end
    local target = exports[n]
    local ok, a, b, c, d = pcall(function(...) return target[fn](target, ...) end, ...)
    if not ok then return nil, false end
    return a, b, c, d
end)

--- تسمية عنصر للعرض (fallback: الاسم نفسه)
exports('InvItemLabel', function(item)
    if not item then return 'Unknown' end
    if detect() == 'w_inventory' then
        local ok, d = pcall(function() return exports.w_inventory:Items(item) end)
        if ok and d and d.label then
            if type(d.label) == 'table' then
                local lang = GetConvar('w_lib:locale', 'ar') == 'en' and 'en' or 'ar'
                return d.label[lang] or d.label.ar or d.label.en or item
            end
            return d.label
        end
    end
    if exports and exports.w_lib then
        local ok, d = pcall(function() return exports.w_lib:FwGetSharedItem(item) end)
        if ok and type(d) == 'table' then
            local lang = GetConvar('w_lib:locale', 'ar') == 'en' and 'en' or 'ar'
            return (lang == 'ar' and d.label_ar) or d.label or item
        end
    end
    return item
end)

--- إغلاق واجهة الحقيبة (تحرير التركيز/السكرول)
exports('InvClose', function()
    local n = detect()
    if n == 'w_inventory' then
        pcall(function() exports.w_inventory:closeInventory() end)
    elseif n == 'vorp_inventory' then
        pcall(function() TriggerEvent('vorp_inventory:closeInventory') end)
    elseif n == 'rsg-inventory' then
        pcall(function() TriggerEvent('rsg-inventory:client:closeinv') end)
    elseif n == 'qbr-inventory' then
        pcall(function() TriggerEvent('qbr-inventory:client:closeinv') end)
    end
end)

exports('InvReady', function() return detect() ~= nil end)
exports('InvIsReady', function() return detect() ~= nil end)

local IMAGE_BASES = {
    w_inventory = 'nui://w_inventory/web/images/',
    vorp_inventory = 'nui://vorp_inventory/html/img/items/',
    ['rsg-inventory'] = 'nui://rsg-inventory/html/images/',
    ['qbr-inventory'] = 'nui://qbr-inventory/html/images/',
}

local function invImageBase()
    local n = detect() or 'w_inventory'
    return IMAGE_BASES[n] or IMAGE_BASES.w_inventory
end

exports('InvImageBase', invImageBase)

local function invItems(name)
    local n = detect()
    if n == 'w_inventory' then
        local ok, res = pcall(function() return exports.w_inventory:Items(name) end)
        if ok and type(res) == 'table' then return res end
    end
    if exports and exports.w_lib then
        if name ~= nil then
            local ok, def = pcall(function() return exports.w_lib:FwGetSharedItem(name) end)
            if ok and type(def) == 'table' then return def end
        else
            local ok, all = pcall(function() return exports.w_lib:FwGetSharedItems() end)
            if ok and type(all) == 'table' then return all end
        end
    end
    return name == nil and {} or nil
end

exports('InvItems', invItems)

exports('InvWeapons', function(name)
    if not exports or not exports.w_lib then return name == nil and {} or nil end
    if name ~= nil then
        local ok, w = pcall(function() return exports.w_lib:FwGetSharedWeapon(name) end)
        return ok and w or nil
    end
    local ok, all = pcall(function() return exports.w_lib:FwGetSharedWeapons() end)
    return (ok and type(all) == 'table') and all or {}
end)

exports('InvItemImage', function(item)
    if type(item) ~= 'string' or item == '' then return nil end
    local def = invItems(item)
    local img = (type(def) == 'table' and type(def.image) == 'string' and def.image ~= '') and def.image or (item .. '.png')
    if img:find('^nui://') or img:find('^https?://') then
        return img
    end
    return invImageBase() .. img
end)

exports('InvDisplayMetadata', function(key, label)
    local n = detect()
    if n == 'w_inventory' then
        local ok, res = pcall(function() return exports.w_inventory:displayMetadata(key, label) end)
        return ok and res ~= false
    end
    return true
end)

local function clientGetItemCount(item, meta)
    if type(item) ~= 'string' or item == '' then return 0 end
    local n = detect()
    if n == 'w_inventory' then
        local ok, cnt = pcall(function() return exports.w_inventory:Search('count', item, meta) end)
        if ok and tonumber(cnt) then return tonumber(cnt) end
        local ok2, cnt2 = pcall(function() return exports.w_inventory:GetItemCount(item, meta) end)
        if ok2 and tonumber(cnt2) then return tonumber(cnt2) end
    elseif n == 'rsg-inventory' or n == 'qbr-inventory' then
        if exports and exports.w_lib then
            local ok, pd = pcall(function() return exports.w_lib:FwGetPlayerData() end)
            if ok and type(pd) == 'table' and type(pd.items) == 'table' then
                local total = 0
                for _, it in pairs(pd.items) do
                    if type(it) == 'table' and it.name == item then
                        total = total + (tonumber(it.amount or it.count) or 1)
                    end
                end
                return total
            end
        end
    elseif n == 'vorp_inventory' then
        local ok, cnt = pcall(function() return exports.vorp_inventory:getItemCount(item) end)
        if ok and tonumber(cnt) then return tonumber(cnt) end
    end
    return 0
end

exports('InvGetItemCount', clientGetItemCount)

exports('InvHasItem', function(item, count)
    local need = tonumber(count) or 1
    return clientGetItemCount(item) >= need
end)

exports('InvSearch', function(search, item, meta)
    local n = detect()
    if n == 'w_inventory' then
        local ok, res = pcall(function() return exports.w_inventory:Search(search, item, meta) end)
        if ok then return res end
    end
    if search == 'count' then
        return clientGetItemCount(item, meta)
    end
    return nil
end)

exports('InvOpenInventory', function(invType, data)
    local n = detect()
    if not n then return false end
    if n == 'w_inventory' then
        local ok, res = pcall(function() return exports.w_inventory:openInventory(invType, data) end)
        return ok and res ~= false
    end
    local target = exports[n]
    local ok, res = pcall(function() return target:openInventory(invType, data) end)
    if ok and res ~= false then return true end
    return false
end)

-- Weapon Wheel Client Exports
local function callWInvClient(method, fallback, ...)
    if detect() == 'w_inventory' then
        local packed = table.pack(pcall(function(...)
            return exports.w_inventory[method](exports.w_inventory, ...)
        end, ...))
        if packed[1] then
            return table.unpack(packed, 2, packed.n)
        end
    end
    return fallback
end

exports('InvGetWeaponWheelState', function() return callWInvClient('getWeaponWheelState', nil) end)
exports('InvSelectWeaponSlot', function(slot) return callWInvClient('selectWeaponSlot', false, slot) end)
exports('InvUseSlot', function(slot) return callWInvClient('useSlot', false, slot) end)
exports('InvSwitchWeaponAmmo', function(slotOrId, ammoItem) return callWInvClient('switchWeaponAmmo', false, slotOrId, ammoItem) end)
exports('InvBeginWeaponInspection', function(...) return callWInvClient('beginWeaponInspection', false, ...) end)
exports('InvCleanInspectedWeapon', function(...) return callWInvClient('cleanInspectedWeapon', false, ...) end)
exports('InvEndWeaponInspection', function() return callWInvClient('endWeaponInspection', false) end)
exports('InvGetHeldAmmoState', function() return callWInvClient('getHeldAmmoState', nil) end)
exports('InvSetWeaponWheelDefault', function(ids) return callWInvClient('setWeaponWheelDefault', false, ids) end)
exports('InvGetWeaponWheelDefault', function() return callWInvClient('getWeaponWheelDefault', nil) end)

-- Client Inventory & Weapon Event Subscriptions (with invoking-resource cleanup)
local function isCallable(cb)
    return type(cb) == 'function' or (type(cb) == 'table' and getmetatable(cb) and getmetatable(cb).__call ~= nil)
end

local function currentInvoker()
    if type(GetInvokingResource) == 'function' then
        local inv = GetInvokingResource()
        if type(inv) == 'string' and inv ~= '' then return inv end
    end
    return 'w_lib'
end

local CurrentWeaponListeners = {}
local InventoryUpdatedListeners = {}
local WeaponEquippedListeners = {}
local QbrUseWeaponListeners = {}
local WheelRefreshListeners = {}
local InvStateListeners = {}
local WheelDefaultReqListeners = {}
local WheelDefaultDropListeners = {}

local function fireClientListeners(list, ...)
    if #list == 0 then return end
    local snap = {}
    for i = 1, #list do snap[i] = list[i] end
    for i = 1, #snap do
        pcall(snap[i].fn, ...)
    end
end

exports('InvOnCurrentWeapon', function(cb)
    if not isCallable(cb) then return false end
    CurrentWeaponListeners[#CurrentWeaponListeners + 1] = { fn = cb, owner = currentInvoker() }
    return true
end)

exports('InvOnInventoryUpdated', function(cb)
    if not isCallable(cb) then return false end
    InventoryUpdatedListeners[#InventoryUpdatedListeners + 1] = { fn = cb, owner = currentInvoker() }
    return true
end)

exports('InvOnWeaponEquipped', function(cb)
    if not isCallable(cb) then return false end
    WeaponEquippedListeners[#WeaponEquippedListeners + 1] = { fn = cb, owner = currentInvoker() }
    return true
end)

exports('InvOnUseWeapon', function(cb)
    if not isCallable(cb) then return false end
    QbrUseWeaponListeners[#QbrUseWeaponListeners + 1] = { fn = cb, owner = currentInvoker() }
    return true
end)

exports('InvOnWheelRefresh', function(cb)
    if not isCallable(cb) then return false end
    WheelRefreshListeners[#WheelRefreshListeners + 1] = { fn = cb, owner = currentInvoker() }
    return true
end)

exports('InvOnInvStateChange', function(cb)
    if not isCallable(cb) then return false end
    InvStateListeners[#InvStateListeners + 1] = { fn = cb, owner = currentInvoker() }
    return true
end)

exports('InvOnWheelDefaultRequest', function(cb)
    if not isCallable(cb) then return false end
    WheelDefaultReqListeners[#WheelDefaultReqListeners + 1] = { fn = cb, owner = currentInvoker() }
    return true
end)

exports('InvOnWheelDefaultDropped', function(cb)
    if not isCallable(cb) then return false end
    WheelDefaultDropListeners[#WheelDefaultDropListeners + 1] = { fn = cb, owner = currentInvoker() }
    return true
end)

exports('InvAnnounceWeaponEquipped', function(weaponId, name, dual)
    if detect() == 'vorp_inventory' then
        TriggerEvent('vorp_inventory:onWeaponEquipped', {}, weaponId, name, dual == true, {})
        return true
    end
    return false
end)

AddEventHandler('w_inventory:currentWeapon', function(weapon)
    fireClientListeners(CurrentWeaponListeners, weapon)
end)

AddEventHandler('w_inventory:updateInventory', function(changes)
    fireClientListeners(InventoryUpdatedListeners, changes)
end)

AddEventHandler('ox_inventory:updateInventory', function(changes)
    if detect() ~= 'w_inventory' then
        fireClientListeners(InventoryUpdatedListeners, changes)
    end
end)

AddEventHandler('vorp_inventory:onWeaponEquipped', function(...)
    fireClientListeners(WeaponEquippedListeners, ...)
    fireClientListeners(WheelRefreshListeners, 'vorp_inventory:onWeaponEquipped')
end)

for _, ev in ipairs({
    'w_inventory:setPlayerInventory',
    'w_inventory:weaponUsageChanged',
    'vorp_inventory:componentAdded',
    'vorp_inventory:componentRemoved',
    'vorpinventory:loaded',
}) do
    RegisterNetEvent(ev, function()
        fireClientListeners(WheelRefreshListeners, ev)
    end)
end

RegisterNetEvent('RSGCore:Player:SetPlayerData', function()
    fireClientListeners(WheelRefreshListeners, 'RSGCore:Player:SetPlayerData')
end)

RegisterNetEvent('RSGCore:Client:UseItem', function()
    fireClientListeners(WheelRefreshListeners, 'RSGCore:Client:UseItem')
end)

RegisterNetEvent('vorp_inventory:Client:OnInvStateChange', function(isOpen)
    fireClientListeners(InvStateListeners, isOpen)
end)

AddEventHandler('vorp_inventory:weaponWheelDefaultRequest', function(id)
    fireClientListeners(WheelDefaultReqListeners, id)
end)

AddEventHandler('vorp_inventory:weaponWheelDefaultDropped', function(id)
    fireClientListeners(WheelDefaultDropListeners, id)
end)

RegisterNetEvent('qbr-weapons:client:UseWeapon', function(weaponData)
    fireClientListeners(QbrUseWeaponListeners, weaponData)
end)

AddEventHandler('onResourceStop', function(resource)
    local own = resource == GetCurrentResourceName()
    for _, list in ipairs({
        CurrentWeaponListeners, InventoryUpdatedListeners, WeaponEquippedListeners,
        QbrUseWeaponListeners, WheelRefreshListeners, InvStateListeners,
        WheelDefaultReqListeners, WheelDefaultDropListeners,
    }) do
        for i = #list, 1, -1 do
            if own or list[i].owner == resource then
                table.remove(list, i)
            end
        end
    end
end)
