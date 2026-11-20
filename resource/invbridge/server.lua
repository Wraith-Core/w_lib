-- ════════════════════════════════════════════════════════════════════════════
-- w_lib — جسر الحقائب المركزيّ (خادم)
--   المكتبة تدير الحقيبة لكل السكربتات (بدل جسر منفصل بكل سكربت).
--   يدعم: w_inventory | vorp_inventory | rsg-inventory | qbr-inventory (كشف تلقائيّ).
--   السكربتات تستدعي exports.w_lib:Inv* (أو وسيطها الرفيع Inv.*).
--   تجاوز يدويّ اختياريّ: setr w_lib:inventory "vorp_inventory"
-- ════════════════════════════════════════════════════════════════════════════

local Adapters = {}
local StashDefinitions = {}
local UsableDefinitions = {}

-- يحوّل نداء كولباك (vorp) إلى قيمة متزامنة
local function await1(caller)
    local p = promise.new()
    local done = false
    local function resolve(res)
        if done then return end
        done = true
        p:resolve(res)
    end

    local ok, direct = pcall(caller, resolve)

    if not ok then
        resolve(nil)
    elseif direct ~= nil then
        resolve(direct)
    end

    -- A broken third-party callback must not suspend the calling resource
    -- forever. Native VORP callbacks normally resolve immediately.
    SetTimeout(5000, function() resolve(nil) end)

    return Citizen.Await(p)
end
local function isWeapon(name) local n = tostring(name):upper(); return n:sub(1, 7) == 'WEAPON_' end

-- A function handed across an export is not a Lua function on this side: the
-- scheduler packs every function as a funcref and it arrives as a table with a
-- __call metamethod. type() alone therefore refuses every caller from another
-- resource - which is every caller of an export.
local function isCallable(f)
    local t = type(f)
    if t == 'function' then return true end
    if t == 'table' then
        local mt = getmetatable(f)
        return type(mt) == 'table' and mt.__call ~= nil
    end
    return false
end

local IGNORED_META_KEYS = {
    _w_rsg = true,
    _vorp = true,
    durability = true,
    degrade = true,
    quality = true,
    decay = true,
}

local function matchMetaValue(actual, expected, strict)
    if actual == expected then return true end
    if type(actual) ~= 'table' or type(expected) ~= 'table' then return false end
    for k, v in pairs(expected) do
        if not matchMetaValue(actual[k], v, strict) then return false end
    end
    if strict == true then
        for k in pairs(actual) do
            if not IGNORED_META_KEYS[k] and expected[k] == nil then
                return false
            end
        end
    end
    return true
end

local function matchesItemMeta(itemMeta, filterMeta, strict)
    if filterMeta == nil then return true end
    if type(filterMeta) ~= 'table' then return itemMeta == filterMeta end
    local actual = type(itemMeta) == 'table' and itemMeta or {}
    return matchMetaValue(actual, filterMeta, strict)
end

-- ───────────────────────── w_inventory (مُتحقَّق) ─────────────────────────
Adapters['w_inventory'] = {
    resource = 'w_inventory',
    GetItemCount = function(src, item, meta, strict)
        if strict ~= nil then
            local ok, n = pcall(function() return exports.w_inventory:GetItemCount(src, item, meta, strict) end)
            if ok and tonumber(n) then return tonumber(n) end
        end
        return exports.w_inventory:Search(src, 'count', item, meta) or 0
    end,
    CanCarry = function(src, item, count) return exports.w_inventory:CanCarryItem(src, item, count) == true end,
    AddItem = function(src, item, count, meta) return exports.w_inventory:AddItem(src, item, count, meta) == true end,
    RemoveItem = function(src, item, count, meta, slot) return exports.w_inventory:RemoveItem(src, item, count, meta, slot) == true end,
    RegisterStash = function(id, label, slots, maxWeight, options)
        options = type(options) == 'table' and options or {}
        exports.w_inventory:RegisterStash(id, label, slots, maxWeight, options.owner, options.groups, options.coords)
        return true
    end,
    AddItemToStash = function(stashId, item, count, meta) return exports.w_inventory:AddItem(stashId, item, count, meta) == true end,
    OpenStash = function(src, stashId) exports.w_inventory:forceOpenInventory(src, 'stash', stashId); return true end,
    RegisterUsable = function(item, closeAfterUsed, callback)
        return exports.w_inventory:RegisterUsableItem(item, function(source, data)
            data = type(data) == 'table' and data or {}
            callback(source, {
                metadata = data.metadata or {},
                slot = data.slot,
                item = data,
            })

            if closeAfterUsed then
                TriggerClientEvent('w_inventory:closeInventory', source, true)
            end
        end) ~= false
    end,
}

-- ───────────────────────── vorp_inventory ─────────────────────────
Adapters['vorp_inventory'] = {
    resource = 'vorp_inventory',
    GetItemCount = function(src, item, meta)
        if isWeapon(item) then
            local ws = await1(function(cb) exports.vorp_inventory:getUserInventoryWeapons(src, cb) end) or {}
            local c = 0
            for _, w in pairs(ws) do if tostring(w.name):upper() == tostring(item):upper() then c = c + 1 end end
            return c
        end
        -- getItemCount(source, callback, item, metadata) sums EVERY stack of the item: getItem answers one
        -- stack only (inventoryApiService.lua GET_ITEM "we get a random item") while subItem takes from all
        -- of them, so a player whose item is split (decay, metadata) was refused what they hold.
        -- An older vorp_inventory without getItemCount answers through getItem as before.
        local n = await1(function(cb) return exports.vorp_inventory:getItemCount(src, cb, item, meta) end)
        if type(n) == 'number' then return n end
        -- getItem(source, item, callback, metadata) — الكولباك هو الوسيط الثالث
        local it = await1(function(cb) exports.vorp_inventory:getItem(src, item, cb, meta) end)
        if type(it) ~= 'table' then return 0 end
        return it.count or it.amount or 0
    end,
    CanCarry = function(src, item, count)
        if isWeapon(item) then
            return await1(function(cb) exports.vorp_inventory:canCarryWeapons(src, count, cb, item) end) == true
        end
        return await1(function(cb) exports.vorp_inventory:canCarryItem(src, item, count, cb) end) == true
    end,
    AddItem = function(src, item, count, meta)
        if isWeapon(item) then
            -- createWeapon(source, weaponName, ammo(table), ignored, comps(table), callback, wepid, custom_serial, ...)
            local m = type(meta) == 'table' and meta or {}
            local ammo = type(m.ammo) == 'table' and m.ammo or {}          -- يجب أن يكون جدولاً (VORP يمرّ عليه pairs)
            local components = type(m.components) == 'table' and m.components or {}
            local serial = m.serial                                         -- custom_serial (الوسيط الثامن)
            local res = await1(function(cb)
                exports.vorp_inventory:createWeapon(src, item, ammo, {}, components, cb, nil, serial)
            end)
            return res ~= nil and res ~= false
        end
        return await1(function(cb) exports.vorp_inventory:addItem(src, item, count, meta, cb) end) == true
    end,
    RemoveItem = function(src, item, count, meta, slot)
        if isWeapon(item) then
            -- الأسلحة في vorp تُحذف بـsubWeapon(معرّف السلاح) — نبحث بالسيريل/المعرّف/الاسم
            local ws = await1(function(cb) exports.vorp_inventory:getUserInventoryWeapons(src, cb) end) or {}
            local wantSerial = meta and (meta.serial or meta.serial_number)
            local wantId = meta and meta.weaponId
            for _, w in pairs(ws) do
                local match = (wantId and w.id == wantId)
                    or (wantSerial and w.serial_number == wantSerial)
                    or (not wantSerial and not wantId and tostring(w.name):upper() == tostring(item):upper())
                if match then
                    local ok, result = pcall(function() return exports.vorp_inventory:subWeapon(src, w.id) end)
                    return ok and result ~= false
                end
            end
            return false
        end
        -- The slot our use-callbacks hand out is vorp's own item id: when the caller
        -- gives it back, remove that exact stack (after checking it still holds the
        -- item) rather than whichever stack of that name vorp finds first.
        local id = tonumber(slot)
        local wanted = tonumber(count) or 1
        if id and (meta == nil or next(meta) == nil) then
            local owned = await1(function(cb) exports.vorp_inventory:getItemById(src, id, cb) end)
            if type(owned) == 'table' and tostring(owned.name) == tostring(item)
                and (tonumber(owned.count) or 0) >= wanted then
                return await1(function(cb) exports.vorp_inventory:subItemById(src, id, cb, nil, wanted) end) == true
            end
            -- a stack that no longer holds the item, or not enough of it: by name below
            -- (subItemById would clamp at zero and still answer true; a caller who named
            -- metadata wants vorp's exact-metadata match, not a stack picked by id)
        end
        -- meta goes through as given. `meta or {}` sent vorp down its exact-metadata
        -- branch, which only ever matches a stack whose metadata is empty - a stack
        -- carrying any metadata at all could never be removed; nil takes its by-name
        -- removal instead.
        return await1(function(cb) exports.vorp_inventory:subItem(src, item, count, meta, cb) end) == true
    end,
    RegisterStash = function(id, label, slots, maxWeight)
        pcall(function()
            exports.vorp_inventory:registerInventory({
                id = id, name = label, limit = slots, acceptWeapons = true, shared = true,
                ignoreItemStackLimit = true, whitelistItems = false, UsePermissions = false,
                UseBlackList = false, whitelistWeapons = false,
            })
        end)
        return true
    end,
    AddItemToStash = function(stashId, item, count, meta)
        -- addItemsToCustomInventory(id, items[], charid, callback) — عناصر كمصفوفة، ويتطلّب charid
        local m = type(meta) == 'table' and meta or {}
        -- VORP rejects zero even for a shared custom inventory. The character
        -- id is bookkeeping only for shared stashes, so use a stable non-zero
        -- fallback when the caller has no player context.
        local charid = tonumber(m.charid or m.charId) or 1
        local res = await1(function(cb)
            exports.vorp_inventory:addItemsToCustomInventory(stashId,
                { { name = item, amount = count, metadata = m } }, charid, cb)
        end)
        return res ~= false and res ~= nil
    end,
    OpenStash = function(src, stashId) pcall(function() exports.vorp_inventory:openInventory(src, stashId) end); return true end,
    RegisterUsable = function(item, closeAfterUsed, callback)
        local ok = pcall(function()
            exports.vorp_inventory:registerUsableItem(item, function(data)
                data = type(data) == 'table' and data or {}
                local source = tonumber(data.source)
                local entry = type(data.item) == 'table' and data.item or {}
                if not source then return end

                if closeAfterUsed then
                    pcall(function() exports.vorp_inventory:closeInventory(source) end)
                end

                callback(source, {
                    metadata = entry.metadata or {},
                    slot = entry.slot or entry.id or entry.mainid,
                    item = entry,
                })
            end)
        end)
        return ok
    end,
}

-- ───────────────────────── rsg-inventory ─────────────────────────
Adapters['rsg-inventory'] = {
    resource = 'rsg-inventory',
    GetItemCount = function(src, item, meta) local it = exports['rsg-inventory']:GetItemByName(src, item); return (it and (it.amount or it.count)) or 0 end,
    CanCarry = function(src, item, count) local ok = exports['rsg-inventory']:CanAddItem(src, item, count); if ok == nil then return true end; return ok == true end,
    AddItem = function(src, item, count, meta) return exports['rsg-inventory']:AddItem(src, item, count, false, meta, GetCurrentResourceName()) == true end,
    RemoveItem = function(src, item, count, meta) return exports['rsg-inventory']:RemoveItem(src, item, count, false, GetCurrentResourceName()) == true end,
    RegisterStash = function(id, label, slots, maxWeight)
        local config = { label = label, slots = slots, maxweight = maxWeight }
        local ok, result = pcall(function()
            return exports['rsg-inventory']:CreateInventory(id, config)
        end)
        -- Older RSG versions create the stash when OpenInventory is called.
        return not ok or result ~= false
    end,
    AddItemToStash = function(stashId, item, count, meta) local ok = pcall(function() exports['rsg-inventory']:AddItem(stashId, item, count, false, meta, GetCurrentResourceName()) end); return ok == true end,
    OpenStash = function(src, stashId)
        local config = StashDefinitions[tostring(stashId)] or {}
        local ok = pcall(function() exports['rsg-inventory']:OpenInventory(src, stashId, config) end)
        return ok
    end,
    RegisterUsable = function(item, closeAfterUsed, callback)
        local ok = pcall(function()
            local core = exports['rsg-core']:GetCoreObject()
            core.Functions.CreateUseableItem(item, function(source, data)
                data = type(data) == 'table' and data or {}
                callback(source, {
                    metadata = data.info or data.metadata or {},
                    slot = data.slot,
                    item = data,
                })
                if closeAfterUsed then
                    TriggerClientEvent('rsg-inventory:client:closeinv', source)
                end
            end)
        end)
        return ok
    end,
}

-- ───────────────────────── qbr-inventory (يطابق rsg بنيويّاً) ─────────────────────────
Adapters['qbr-inventory'] = {
    resource = 'qbr-inventory',
    GetItemCount = function(src, item, meta) local it = exports['qbr-inventory']:GetItemByName(src, item); return (it and (it.amount or it.count)) or 0 end,
    CanCarry = function(src, item, count) local ok = exports['qbr-inventory']:CanAddItem(src, item, count); if ok == nil then return true end; return ok == true end,
    AddItem = function(src, item, count, meta) return exports['qbr-inventory']:AddItem(src, item, count, false, meta, GetCurrentResourceName()) == true end,
    RemoveItem = function(src, item, count, meta) return exports['qbr-inventory']:RemoveItem(src, item, count, false, GetCurrentResourceName()) == true end,
    RegisterStash = function(id, label, slots, maxWeight)
        local config = { label = label, slots = slots, maxweight = maxWeight }
        local ok, result = pcall(function()
            return exports['qbr-inventory']:CreateInventory(id, config)
        end)
        return not ok or result ~= false
    end,
    AddItemToStash = function(stashId, item, count, meta) local ok = pcall(function() exports['qbr-inventory']:AddItem(stashId, item, count, false, meta, GetCurrentResourceName()) end); return ok == true end,
    OpenStash = function(src, stashId)
        local config = StashDefinitions[tostring(stashId)] or {}
        local ok = pcall(function() exports['qbr-inventory']:OpenInventory(src, stashId, config) end)
        return ok
    end,
    RegisterUsable = function(item, closeAfterUsed, callback)
        local ok = pcall(function()
            exports['qbr-core']:CreateUseableItem(item, function(source, data)
                data = type(data) == 'table' and data or {}
                callback(source, {
                    metadata = data.info or data.metadata or {},
                    slot = data.slot,
                    item = data,
                })
                if closeAfterUsed then
                    TriggerClientEvent('qbr-inventory:client:closeinv', source)
                end
            end)
        end)
        return ok
    end,
}

-- ═══════════ عمليّات تفصيليّة للعناصر (GetItems/GetSlot) — مُتحقَّقة ═══════════
--   يستخدمها أي سكربت يقرأ محتوى الحقيبة (w_marketplace وغيره) عبر exports.w_lib.

-- w_inventory
Adapters['w_inventory'].GetItems = function(src)
    local inv = exports.w_inventory:GetInventory(src)
    local out = {}
    if inv and inv.items then
        for _, s in pairs(inv.items) do
            if type(s) == 'table' and s.name then
                out[#out + 1] = { slot = s.slot, name = s.name, label = s.label or s.name,
                                  count = s.count, weight = s.weight, metadata = s.metadata or {} }
            end
        end
    end
    return out
end
Adapters['w_inventory'].GetSlot = function(src, slot)
    local s = exports.w_inventory:GetSlot(src, slot)
    if not s then return nil end
    return { name = s.name, label = s.label or s.name, count = s.count, metadata = s.metadata or {} }
end

-- vorp_inventory (عناصر + أسلحة؛ الميتاداتا/السيريل يسافر)
Adapters['vorp_inventory'].GetItems = function(src)
    local out = {}
    local items = await1(function(cb) exports.vorp_inventory:getUserInventoryItems(src, cb) end) or {}
    for _, v in pairs(items) do
        out[#out + 1] = { slot = v.id, name = v.name, label = v.label or v.name,
                          count = v.count or v.amount or 1, weight = v.weight, metadata = v.metadata or {} }
    end
    local weapons = await1(function(cb) exports.vorp_inventory:getUserInventoryWeapons(src, cb) end) or {}
    for _, w in pairs(weapons) do
        out[#out + 1] = { slot = 'w' .. tostring(w.id), name = w.name, label = w.custom_label or w.label or w.name,
                          count = 1, weight = 0,
                          metadata = { serial = w.serial_number, weaponId = w.id, isWeapon = true,
                                       ammo = w.ammo, components = w.components } }
    end
    return out
end
Adapters['vorp_inventory'].GetSlot = function(src, slot)
    for _, it in pairs(Adapters['vorp_inventory'].GetItems(src)) do
        if tostring(it.slot) == tostring(slot) then return it end
    end
    return nil
end

-- rsg-inventory
local function rsgPlayer(src) local RSG = exports['rsg-core']:GetCoreObject(); return RSG and RSG.Functions.GetPlayer(src) end
Adapters['rsg-inventory'].GetItems = function(src)
    local p = rsgPlayer(src); if not p then return {} end
    local out = {}
    for slot, it in pairs(p.PlayerData.items or {}) do
        if type(it) == 'table' and it.name then
            out[#out + 1] = { slot = it.slot or slot, name = it.name, label = it.label or it.name,
                              count = it.amount or it.count or 1, weight = it.weight, metadata = it.info or {} }
        end
    end
    return out
end
Adapters['rsg-inventory'].GetSlot = function(src, slot)
    local p = rsgPlayer(src); if not p then return nil end
    local it = p.PlayerData.items and p.PlayerData.items[slot]
    if not it then return nil end
    return { name = it.name, label = it.label or it.name, count = it.amount or it.count or 1, metadata = it.info or {} }
end

-- qbr-inventory (QBR exposes GetPlayer directly; it has no GetCoreObject export)
local function qbrPlayer(src)
    local ok, player = pcall(function() return exports['qbr-core']:GetPlayer(src) end)
    return ok and player or nil
end
Adapters['qbr-inventory'].GetItems = function(src)
    local p = qbrPlayer(src); if not p then return {} end
    local out = {}
    for slot, it in pairs(p.PlayerData.items or {}) do
        if type(it) == 'table' and it.name then
            out[#out + 1] = { slot = it.slot or slot, name = it.name, label = it.label or it.name,
                              count = it.amount or it.count or 1, weight = it.weight, metadata = it.info or {} }
        end
    end
    return out
end
Adapters['qbr-inventory'].GetSlot = function(src, slot)
    local p = qbrPlayer(src); if not p then return nil end
    local it = p.PlayerData.items and p.PlayerData.items[slot]
    if not it then return nil end
    return { name = it.name, label = it.label or it.name, count = it.amount or it.count or 1, metadata = it.info or {} }
end

-- ═══════════ Items: an item's definition by name (or full catalogue when name == nil) ═══════════
--   w_inventory answers from its item list; vorp_inventory from getItemDB / CompatItems;
--   RSG / QBR from the core's Shared.Items.
Adapters['w_inventory'].Items = function(name)
    local ok, def = pcall(function() return exports.w_inventory:Items(name) end)
    return (ok and type(def) == 'table') and def or nil
end
Adapters['vorp_inventory'].Items = function(name)
    if name == nil then
        if exports and exports.w_lib then
            local okC, all = pcall(function() return exports.w_lib:CompatItems() end)
            if okC and type(all) == 'table' then return all end
            local okS, shared = pcall(function() return exports.w_lib:FwGetSharedItems() end)
            if okS and type(shared) == 'table' then return shared end
        end
        return {}
    end
    local ok, def = pcall(function() return exports.vorp_inventory:getItemDB(name) end)
    if ok and type(def) == 'table' then return def end
    if exports and exports.w_lib then
        local okC, all = pcall(function() return exports.w_lib:CompatItems() end)
        if okC and type(all) == 'table' and type(all[name]) == 'table' then return all[name] end
    end
    return nil
end
Adapters['rsg-inventory'].Items = function(name)
    local ok, items = pcall(function() return exports['rsg-core']:GetCoreObject().Shared.Items end)
    if not ok or type(items) ~= 'table' then
        if exports and exports.w_lib then
            local okS, shared = pcall(function() return exports.w_lib:FwGetSharedItems() end)
            if okS and type(shared) == 'table' then items = shared end
        end
    end
    if type(items) ~= 'table' then return name == nil and {} or nil end
    if name == nil then return items end
    return type(items[name]) == 'table' and items[name] or nil
end
Adapters['qbr-inventory'].Items = function(name)
    local ok, items = pcall(function() return exports['qbr-core']:GetItems() end)
    if not ok or type(items) ~= 'table' then
        if exports and exports.w_lib then
            local okS, shared = pcall(function() return exports.w_lib:FwGetSharedItems() end)
            if okS and type(shared) == 'table' then items = shared end
        end
    end
    if type(items) ~= 'table' then return name == nil and {} or nil end
    if name == nil then return items end
    return type(items[name]) == 'table' and items[name] or nil
end

-- ═══════════ SetMetadata: writing an item's metadata in place (by slot) ═══════════
--   w_gunsmith keeps a weapon's customisation inside the item's metadata on the
--   inventories that carry one per item (w_inventory, rsg, qbr). VORP has no per-item
--   metadata for weapons ('w...' slot); regular VORP items delegate to setItemMetadata.
Adapters['w_inventory'].SetMetadata = function(src, slot, meta)
    local ok, r = pcall(function() return exports.w_inventory:SetMetadata(src, slot, meta) end)
    return ok and r ~= false
end

local function rsgFamilySetMetadata(getPlayer, invResource)
    return function(src, slot, meta)
        local p = getPlayer(src); if not p then return false end
        slot = tonumber(slot); if not slot then return false end
        local items = p.PlayerData.items or {}
        local it = items[slot]
        if type(it) ~= 'table' or not it.name then return false end

        -- the inventory's own setter when it has one (rsg-inventory v2 and later)
        local okApi, done = pcall(function()
            return exports[invResource]:SetItemData(src, it.name, 'info', meta, slot)
        end)
        if okApi and done ~= false and done ~= nil then return true end

        -- otherwise straight into PlayerData and a full save through the player object
        it.info = meta
        if p.Functions and p.Functions.SetInventory then
            local okSet = pcall(function() p.Functions.SetInventory(items, true) end)
            if okSet then return true end
        end
        if p.Functions and p.Functions.SetPlayerData then
            local okSet = pcall(function() p.Functions.SetPlayerData('items', items) end)
            return okSet
        end
        return false
    end
end
Adapters['rsg-inventory'].SetMetadata = rsgFamilySetMetadata(rsgPlayer, 'rsg-inventory')
Adapters['qbr-inventory'].SetMetadata = rsgFamilySetMetadata(qbrPlayer, 'qbr-inventory')
Adapters['vorp_inventory'].SetMetadata = function(src, slot, meta)
    if type(slot) == 'string' and slot:sub(1, 1):lower() == 'w' then return false end
    local id = tonumber(slot)
    if not id or type(meta) ~= 'table' then return false end
    local row = await1(function(cb) return exports.vorp_inventory:getItemById(src, id, cb) end)
    local amount = (type(row) == 'table' and (tonumber(row.count) or tonumber(row.amount))) or 1
    local res = await1(function(cb) return exports.vorp_inventory:setItemMetadata(src, id, meta, amount, cb) end)
    return res == true or (type(res) == 'table' and res ~= false)
end

-- ───────────────────────── الاختيار (كسول) ─────────────────────────
local INV_ORDER = { 'w_inventory', 'rsg-inventory', 'qbr-inventory', 'vorp_inventory' }
local A, Aname
local lastWarning
local inventoryAliases = {
    w = 'w_inventory',
    ox = 'w_inventory',
    vorp = 'vorp_inventory',
    rsg = 'rsg-inventory',
    qbr = 'qbr-inventory',
}

local function normalizeInventory(name)
    name = tostring(name or 'auto'):lower():gsub('%s+', '')
    return inventoryAliases[name] or name
end

local function isStarted(name)
    local adapter = Adapters[name]
    return adapter and GetResourceState(adapter.resource) == 'started'
end

local function registerUsableDefinition(definition)
    if not A or not A.RegisterUsable or definition.registeredWith == Aname then return false end

    local ok, result = pcall(A.RegisterUsable,
        definition.item, definition.closeAfterUsed, definition.callback)

    if ok and result ~= false then
        definition.registeredWith = Aname
        return true
    end

    if not ok then
        print(('^1[w_lib] failed to register usable item "%s" on %s: %s^0')
            :format(definition.item, tostring(Aname), tostring(result)))
    end

    return false
end

local function registerPendingUsables()
    for _, definition in pairs(UsableDefinitions) do
        registerUsableDefinition(definition)
    end
end

local function ensure()
    -- Re-evaluate a previously selected native adapter when w_inventory starts
    -- later in the boot sequence. w_lib itself starts before w_inventory, so a
    -- native bag can otherwise remain cached for the lifetime of the server.
    if A and isStarted(Aname)
        and (Aname == 'w_inventory' or not isStarted('w_inventory')) then
        return true
    end

    A, Aname = nil, nil
    for _, definition in pairs(UsableDefinitions) do
        definition.registeredWith = nil
    end

    -- w_inventory is a provider for the native inventory names. When it is
    -- running it is always the real authority, even if an old force-convar was
    -- left in a copied server.cfg.
    if isStarted('w_inventory') then
        Aname = 'w_inventory'
    else
        local forcedRaw = GetConvar('w_lib:inventory', 'auto')
        local forced = normalizeInventory(forcedRaw)

        if forced ~= 'auto' then
            if not Adapters[forced] then
                local warning = ('invalid w_lib:inventory value: %s'):format(tostring(forcedRaw))
                if lastWarning ~= warning then
                    lastWarning = warning
                    print(('^1[w_lib] %s^0'):format(warning))
                end
                return false
            elseif isStarted(forced) then
                Aname = forced
            else
                local warning = ('configured inventory is not started yet: %s'):format(forced)
                if lastWarning ~= warning then
                    lastWarning = warning
                    print(('^3[w_lib] %s^0'):format(warning))
                end
                return false
            end
        else
            for _, name in ipairs(INV_ORDER) do
                if isStarted(name) then Aname = name; break end
            end
        end
    end

    if not Aname then return false end

    A = Adapters[Aname]
    lastWarning = nil
    -- بثّ الحقيبة الفعّالة للعميل ليتّفق كشف العميل مع الخادم (مصدر واحد للحقيقة)
    SetConvarReplicated('w_lib:activeInventory', Aname)
    print(('^2[w_lib] inventory bridge -> %s^0'):format(Aname))
    registerPendingUsables()
    return true
end

-- ───────────────────────── API عبر exports.w_lib ─────────────────────────
exports('InvName', function() return ensure() and Aname or nil end)
exports('InvReady', function() return ensure() end)
exports('InvIsReady', function() return ensure() end)
exports('InvGetItemCount', function(src, item, meta, strict)
    if not ensure() then return 0 end
    if meta ~= nil and Aname ~= 'w_inventory' then
        local total = 0
        for _, it in ipairs(A.GetItems and A.GetItems(src) or {}) do
            if it.name == item and matchesItemMeta(it.metadata, meta, strict) then
                total = total + (tonumber(it.count) or 1)
            end
        end
        return total
    end
    return A.GetItemCount(src, item, meta, strict) or 0
end)
exports('InvCanCarry', function(src, item, count) return ensure() and A.CanCarry(src, item, count) == true or false end)
exports('InvAddItem', function(src, item, count, meta) return ensure() and A.AddItem(src, item, count, meta) == true or false end)
exports('InvRemoveItem', function(src, item, count, meta, slot, strict)
    if not ensure() then return false end
    if meta ~= nil and slot == nil and Aname ~= 'w_inventory' then
        local want = tonumber(count) or 1
        if want <= 0 then return false end
        local matchedSlots = {}
        local available = 0
        for _, it in ipairs(A.GetItems and A.GetItems(src) or {}) do
            if it.name == item and matchesItemMeta(it.metadata, meta, strict) then
                local c = tonumber(it.count) or 1
                available = available + c
                matchedSlots[#matchedSlots + 1] = { slot = it.slot, count = c, meta = it.metadata }
            end
        end
        if available < want then return false end
        local left = want
        for _, s in ipairs(matchedSlots) do
            if left <= 0 then break end
            local take = math.min(left, s.count)
            if A.RemoveItem(src, item, take, s.meta, s.slot) ~= true then
                return false
            end
            left = left - take
        end
        return left == 0
    end
    return A.RemoveItem(src, item, count, meta, slot) == true
end)
--- options (optional): either 5th arg `{ owner, groups, coords }` OR positional `(owner, groups, coords)`
exports('InvRegisterStash', function(id, label, slots, maxWeight, ownerOrOptions, groups, coords)
    id = tostring(id or '')
    if id == '' then return false end

    local options
    if type(ownerOrOptions) == 'table' and groups == nil and coords == nil
        and (ownerOrOptions.owner ~= nil or ownerOrOptions.groups ~= nil or ownerOrOptions.coords ~= nil) then
        options = ownerOrOptions
    elseif ownerOrOptions ~= nil or groups ~= nil or coords ~= nil then
        options = { owner = ownerOrOptions, groups = groups, coords = coords }
    end

    StashDefinitions[id] = {
        id = id,
        label = label or id,
        slots = tonumber(slots) or 50,
        maxweight = tonumber(maxWeight) or 100000,
        options = options,
    }

    return ensure() and A.RegisterStash(id, label or id,
        StashDefinitions[id].slots, StashDefinitions[id].maxweight, options) or false
end)
exports('InvAddItemToStash', function(stashId, item, count, meta) return ensure() and A.AddItemToStash(stashId, item, count, meta) == true or false end)
exports('InvOpenStash', function(src, stashId) return ensure() and A.OpenStash(src, stashId) or false end)
-- عمليّات تفصيليّة (قراءة محتوى الحقيبة) — w_marketplace وغيره
exports('InvGetItems', function(src) return ensure() and ((A.GetItems and A.GetItems(src)) or {}) or {} end)
exports('InvGetSlot', function(src, slot) return ensure() and A.GetSlot and A.GetSlot(src, slot) or nil end)
exports('InvSetMetadata', function(src, slot, meta) return ensure() and A.SetMetadata and A.SetMetadata(src, slot, meta) == true or false end)
exports('InvItems', function(name) return ensure() and A.Items and A.Items(name) or nil end)

--- Calls a function by name: first the bridge's own adapter method (GetSlot, SetMetadata,
--- GetItems ...), else one of the active inventory's exports: exports[<inventory>][fn](...).
--- The consumer names the function and never the resource. nil (and false as the second
--- value) when no inventory is up or nothing answers to that name.
exports('InvCall', function(fn, ...)
    if not ensure() or type(fn) ~= 'string' then return nil, false end
    if A[fn] then
        local ok, a, b, c, d = pcall(A[fn], ...)
        if not ok then return nil, false end
        return a, b, c, d
    end
    local target = exports[Aname]
    local ok, a, b, c, d = pcall(function(...) return target[fn](target, ...) end, ...)
    if not ok then return nil, false end
    return a, b, c, d
end)

--- The inventory's own export only (never the bridge's adapters), by name -- for the
--- callback-style vorp_inventory calls (getUserInventoryWeapons, getWeaponComponents ...).
exports('InvNativeCall', function(fn, ...)
    if not ensure() or type(fn) ~= 'string' then return nil, false end
    local target = exports[Aname]
    local ok, a, b, c, d = pcall(function(...) return target[fn](target, ...) end, ...)
    if not ok then return nil, false end
    return a, b, c, d
end)
exports('InvRegisterUsableItem', function(item, closeAfterUsed, callback)
    item = tostring(item or '')

    if isCallable(closeAfterUsed) then
        callback = closeAfterUsed
        closeAfterUsed = true
    end

    -- ! isCallable, not type() == 'function': that test refused every registration
    --   that came through the export (w_hud's consumables, w_crafting's kit and
    --   books) on every boot, silently - "REFUSED 179 item(s)" in the log.
    if item == '' or not isCallable(callback) then return false end

    local definition = {
        item = item,
        closeAfterUsed = closeAfterUsed ~= false,
        callback = callback,
        owner = GetInvokingResource(),
    }

    UsableDefinitions[item] = definition

    -- A missing inventory during folder startup is not a registration failure:
    -- the background detector applies this definition as soon as one starts.
    if ensure() then registerUsableDefinition(definition) end
    return true
end)

AddEventHandler('onResourceStop', function(resource)
    -- The bag itself going down takes its usable registry with it. Forget the
    -- selection: the next export call (w_hud polls InvName) re-detects the bag once
    -- it is back and registerPendingUsables() applies every stored definition again -
    -- so owners that never learned to re-register still come back to life.
    if A and resource == A.resource then
        for _, definition in pairs(UsableDefinitions) do definition.registeredWith = nil end
        A, Aname = nil, nil
        return
    end

    -- When the bridge itself stops every wrapper it registered dies with it, so
    -- take them all back; otherwise only the stopping owner's.
    local own = resource == GetCurrentResourceName()

    for item, definition in pairs(UsableDefinitions) do
        if own or definition.owner == resource then
            UsableDefinitions[item] = nil
            if Aname == 'w_inventory' and isStarted('w_inventory') then
                pcall(function() exports.w_inventory:UnregisterUsableItem(item) end)
            elseif Aname == 'vorp_inventory' and isStarted('vorp_inventory') then
                -- vorp keeps the callback for ever and never notices its owner is
                -- gone: every use would hit a dead funcref and print an error until
                -- somebody registered the name again.
                pcall(function() exports.vorp_inventory:unRegisterUsableItem(item) end)
            end
        end
    end
end)

-- تثبيت مبكّر: انتظر بدء حقيبة معروفة ثم احسم الاختيار وابثثه للعميل قبل أن يسأل
CreateThread(function()
    local attempts = 0
    while not ensure() do
        attempts = attempts + 1
        if attempts == 150 then
            print('^1[w_lib] inventory bridge: no supported inventory is running yet; detection will continue.^0')
        end
        Wait(attempts < 150 and 200 or 2000)
    end
end)

-- ───────────────────────── several lines at once (w_shops, voice orders, stashes) ─────────────────────────
-- lines = { { item = 'bread', count = 2, metadata = {...} }, ... } (`name` is accepted for `item`)

local function isStashTarget(target)
    return type(target) == 'string' and tonumber(target) == nil
end

--- Can the player (or stash) take every line? -> ok, reason ('inventory_full' | 'unavailable')
exports('InvCanCarryItems', function(target, lines)
    if not ensure() then return false, 'unavailable' end
    if type(lines) ~= 'table' then return false, 'unavailable' end
    if Aname == 'w_inventory' then
        local okCall, res, why = pcall(function() return exports.w_inventory:CanCarryItems(target, lines) end)
        if okCall and res ~= nil then
            return res == true, res == true and nil or (why or 'inventory_full')
        end
    end
    if isStashTarget(target) then
        return StashDefinitions[target] ~= nil or Aname == 'w_inventory', nil
    end
    for _, line in ipairs(lines) do
        local item = line.item or line.name
        if not item then return false, 'unavailable' end
        if A.CanCarry(target, item, tonumber(line.count) or 1) ~= true then return false, 'inventory_full' end
    end
    return true
end)

--- Give every line; on a failure the lines already given are taken back.
--- -> ok, reason ('inventory_full' | 'rollback_pending' | 'unavailable')
exports('InvAddItems', function(target, lines)
    if not ensure() then return false, 'unavailable' end
    if type(lines) ~= 'table' then return false, 'unavailable' end
    if Aname == 'w_inventory' then
        local okCall, res, why = pcall(function() return exports.w_inventory:AddItems(target, lines) end)
        if okCall and res ~= nil then
            return res == true, res == true and nil or (why or 'inventory_full')
        end
    end
    if isStashTarget(target) then
        for _, line in ipairs(lines) do
            local item = line.item or line.name
            local count = tonumber(line.count) or 1
            if not item or A.AddItemToStash(target, item, count, line.metadata) ~= true then
                return false, 'inventory_full'
            end
        end
        return true
    end
    local given = {}
    for _, line in ipairs(lines) do
        local item = line.item or line.name
        local count = tonumber(line.count) or 1
        if not item or A.AddItem(target, item, count, line.metadata) ~= true then
            for i = #given, 1, -1 do
                local g = given[i]
                if A.RemoveItem(target, g.item, g.count, g.metadata) ~= true then
                    return false, 'rollback_pending'
                end
            end
            return false, 'inventory_full'
        end
        given[#given + 1] = { item = item, count = count, metadata = line.metadata }
    end
    return true
end)

-- ════════════════════════════════════════════════════════════════════════════
-- Extended Inv* Server Surface (M1c: Catalogues, Images, Slots, Stashes, Hooks,
-- Shops, OpenInventory, Weapon Wheel, and Specialized Passthroughs)
-- ════════════════════════════════════════════════════════════════════════════

local IMAGE_BASES = {
    w_inventory = 'nui://w_inventory/web/images/',
    vorp_inventory = 'nui://vorp_inventory/html/img/items/',
    ['rsg-inventory'] = 'nui://rsg-inventory/html/images/',
    ['qbr-inventory'] = 'nui://qbr-inventory/html/images/',
}

local function invImageBase()
    local active = ensure() and Aname or 'w_inventory'
    return IMAGE_BASES[active] or IMAGE_BASES.w_inventory
end

exports('InvImageBase', invImageBase)

exports('InvItemImage', function(item)
    if type(item) ~= 'string' or item == '' then return nil end
    local def = ensure() and A.Items and A.Items(item) or nil
    local img = (type(def) == 'table' and type(def.image) == 'string' and def.image ~= '') and def.image or (item .. '.png')
    if img:find('^nui://') or img:find('^https?://') then
        return img
    end
    return invImageBase() .. img
end)

exports('InvWeapons', function(name)
    if not exports or not exports.w_lib then return name == nil and {} or nil end
    if name ~= nil then
        local ok, w = pcall(function() return exports.w_lib:FwGetSharedWeapon(name) end)
        return ok and w or nil
    end
    local ok, all = pcall(function() return exports.w_lib:FwGetSharedWeapons() end)
    return (ok and type(all) == 'table') and all or {}
end)

local function getSlotsWithItem(src, item, meta, strict)
    if not ensure() or type(item) ~= 'string' or item == '' then return {} end
    if Aname == 'w_inventory' and strict == nil then
        local ok, rows = pcall(function() return exports.w_inventory:GetSlotsWithItem(src, item, meta) end)
        if ok and type(rows) == 'table' then return rows end
    end
    local out = {}
    for _, it in ipairs(A.GetItems and A.GetItems(src) or {}) do
        if it.name == item and matchesItemMeta(it.metadata, meta, strict) then
            out[#out + 1] = it
        end
    end
    table.sort(out, function(a, b)
        local sa, sb = tonumber(a.slot), tonumber(b.slot)
        if sa and sb then return sa < sb end
        return tostring(a.slot) < tostring(b.slot)
    end)
    return out
end

exports('InvGetSlotsWithItem', getSlotsWithItem)

local function getSlotWithItem(src, item, meta, strict)
    if not ensure() or type(item) ~= 'string' or item == '' then return nil end
    if Aname == 'w_inventory' and meta == nil and strict == nil then
        local ok, row = pcall(function() return exports.w_inventory:GetSlotWithItem(src, item) end)
        if ok and type(row) == 'table' then return row end
    end
    local rows = getSlotsWithItem(src, item, meta, strict)
    return rows[1]
end

exports('InvGetSlotWithItem', getSlotWithItem)

exports('InvGetSlotIdWithItem', function(src, item, meta, strict)
    if not ensure() or type(item) ~= 'string' or item == '' then return nil end
    if Aname == 'w_inventory' and meta == nil and strict == nil then
        local ok, slotId = pcall(function() return exports.w_inventory:GetSlotIdWithItem(src, item) end)
        if ok and slotId ~= nil then return slotId end
    end
    local row = getSlotWithItem(src, item, meta, strict)
    return row and row.slot or nil
end)

exports('InvGetInventory', function(srcOrId)
    if not ensure() then return nil end
    if Aname == 'w_inventory' then
        local ok, inv = pcall(function() return exports.w_inventory:GetInventory(srcOrId) end)
        if ok and inv ~= nil then return inv end
    end
    local numSrc = tonumber(srcOrId)
    if numSrc and A.GetItems then
        return { id = numSrc, items = A.GetItems(numSrc) }
    end
    return nil
end)

exports('InvGetInventoryItems', function(invId, owner)
    if not ensure() then return {} end
    if Aname == 'w_inventory' then
        local ok, items = pcall(function() return exports.w_inventory:GetInventoryItems(invId, owner) end)
        if ok and type(items) == 'table' then return items end
    end
    local numSrc = tonumber(invId)
    if numSrc and A.GetItems then
        return A.GetItems(numSrc)
    end
    if exports and exports.w_lib then
        local ok, contents = pcall(function() return exports.w_lib:InvGetStashContents(tostring(invId)) end)
        if ok and type(contents) == 'table' then return contents end
    end
    return {}
end)

exports('InvRemoveInventory', function(invId)
    if not ensure() or invId == nil then return false end
    if Aname == 'w_inventory' then
        local ok, res = pcall(function() return exports.w_inventory:RemoveInventory(invId) end)
        return ok and res ~= false
    end
    StashDefinitions[tostring(invId)] = nil
    return true
end)

exports('InvSetMaxWeight', function(srcOrId, maxWeight)
    if not ensure() or not tonumber(maxWeight) then return false end
    if Aname == 'w_inventory' then
        local ok, res = pcall(function() return exports.w_inventory:SetMaxWeight(srcOrId, tonumber(maxWeight)) end)
        return ok and res ~= false
    end
    return false
end)

exports('InvRegisterShop', function(shopId, cfg)
    if not shopId or type(cfg) ~= 'table' then return false end
    if ensure() and Aname == 'w_inventory' then
        local ok, res = pcall(function() return exports.w_inventory:RegisterShop(shopId, cfg) end)
        return ok and res ~= false
    end
    return true
end)

exports('InvOpenInventory', function(src, invType, data)
    if not ensure() or not tonumber(src) then return false end
    src = tonumber(src)
    invType = tostring(invType or 'stash')
    if Aname == 'w_inventory' then
        local ok, res = pcall(function() return exports.w_inventory:forceOpenInventory(src, invType, data) end)
        return ok and res ~= false
    end
    if invType == 'stash' then
        local stashId = type(data) == 'table' and (data.id or data.name) or data
        if stashId then return A.OpenStash(src, tostring(stashId)) == true end
    end
    return false
end)

-- Hooks, Restart, and ItemAdded listeners
local HookRegistrations = {}
local RestartListeners = {}
local ItemAddedListeners = {}

local function currentInvoker()
    if type(GetInvokingResource) == 'function' then
        local inv = GetInvokingResource()
        if type(inv) == 'string' and inv ~= '' then return inv end
    end
    return 'w_lib'
end

exports('InvRegisterHook', function(eventName, fn, opts)
    if type(eventName) ~= 'string' or eventName == '' or not isCallable(fn) then return nil end
    local owner = currentInvoker()
    if ensure() and Aname == 'w_inventory' then
        local ok, hookId = pcall(function() return exports.w_inventory:registerHook(eventName, fn, opts) end)
        if ok and hookId ~= nil then
            HookRegistrations[#HookRegistrations + 1] = { id = hookId, owner = owner }
            return hookId
        end
    end
    local syntheticId = #HookRegistrations + 1
    HookRegistrations[syntheticId] = { id = syntheticId, owner = owner, event = eventName, fn = fn, opts = opts }
    return syntheticId
end)

exports('InvOnRestart', function(cb)
    if not isCallable(cb) then return false end
    RestartListeners[#RestartListeners + 1] = { fn = cb, owner = currentInvoker() }
    return true
end)

exports('InvOnItemAdded', function(cb)
    if not isCallable(cb) then return false end
    ItemAddedListeners[#ItemAddedListeners + 1] = { fn = cb, owner = currentInvoker() }
    return true
end)

local function fireItemAdded(src, item, count, meta, rawData)
    src = tonumber(src)
    if not src or type(item) ~= 'string' or item == '' then return end
    local amt = tonumber(count) or 1
    if #ItemAddedListeners == 0 then return end
    local snap = {}
    for i = 1, #ItemAddedListeners do snap[i] = ItemAddedListeners[i] end
    for i = 1, #snap do
        pcall(snap[i].fn, src, item, amt, meta, rawData)
    end
end

AddEventHandler('w_inventory:server:itemAdded', function(src, item, count, meta, rawData)
    fireItemAdded(src, item, count, meta, rawData)
end)

AddEventHandler('rsg-inventory:server:itemAdded', function(src, item, count, meta, rawData)
    if not isStarted('w_inventory') then
        fireItemAdded(src, item, count, meta, rawData)
    end
end)

AddEventHandler('vorp_inventory:Server:OnItemCreated', function(data, src)
    if not isStarted('w_inventory') and type(data) == 'table' then
        fireItemAdded(src or source, data.name or data.item, data.count or data.amount or 1, data.metadata, data)
    end
end)

AddEventHandler('vorp_inventory:Server:OnItemAdded', function(data, src)
    if type(data) == 'table' then
        fireItemAdded(src or source, data.name or data.item, data.count or data.amount or 1, data.metadata, data)
    end
end)

AddEventHandler('onResourceStart', function(resource)
    if Adapters[resource] then
        ensure()
        local snap = {}
        for i = 1, #RestartListeners do snap[i] = RestartListeners[i] end
        for i = 1, #snap do
            pcall(snap[i].fn, resource)
        end
    end
end)

AddEventHandler('onResourceStop', function(resource)
    local own = resource == GetCurrentResourceName()
    for i = #RestartListeners, 1, -1 do
        if own or RestartListeners[i].owner == resource then
            table.remove(RestartListeners, i)
        end
    end
    for i = #ItemAddedListeners, 1, -1 do
        if own or ItemAddedListeners[i].owner == resource then
            table.remove(ItemAddedListeners, i)
        end
    end
    for i = #HookRegistrations, 1, -1 do
        if own or HookRegistrations[i].owner == resource then
            local h = HookRegistrations[i]
            table.remove(HookRegistrations, i)
            if h.id and Aname == 'w_inventory' and isStarted('w_inventory') then
                pcall(function() exports.w_inventory:removeHooks(h.id) end)
            end
        end
    end
end)

-- Weapon Wheel & Specialized w_inventory Server Passthroughs
local function callWInvServer(method, fallback, ...)
    if ensure() and Aname == 'w_inventory' then
        local packed = table.pack(pcall(function(...)
            return exports.w_inventory[method](exports.w_inventory, ...)
        end, ...))
        if packed[1] then
            return table.unpack(packed, 2, packed.n)
        end
    end
    return fallback
end

exports('InvUseItem', function(src, itemData)
    if ensure() and Aname == 'vorp_inventory' then
        if type(TriggerClientEvent) == 'function' then
            TriggerClientEvent('vorp_inventory:useItem', src, itemData)
            return true
        end
        return false
    end
    return callWInvServer('UseItem', false, src, itemData)
end)
exports('InvGetEquippedWeapons', function(src) return callWInvServer('GetEquippedWeapons', {}, src) end)
exports('InvGetLoadedVehicleInventoryId', function(netId) return callWInvServer('GetLoadedVehicleInventoryId', nil, netId) end)
exports('InvBeginDebtAssetStorage', function(...) return callWInvServer('BeginDebtAssetStorage', false, ...) end)
exports('InvDebtAssetStorageVersion', function(...) return callWInvServer('DebtAssetStorageVersion', nil, ...) end)
exports('InvFinishDebtAssetStorage', function(...) return callWInvServer('FinishDebtAssetStorage', false, ...) end)
exports('InvDebtAssetStorageValue', function(...) return callWInvServer('DebtAssetStorageValue', 0, ...) end)
exports('InvEscrowMarketListing', function(...) return callWInvServer('EscrowMarketListing', false, ...) end)
exports('InvDeliverMarketClaim', function(...) return callWInvServer('DeliverMarketClaim', false, ...) end)
exports('InvSettleGatheringNode', function(...)
    if not (ensure() and Aname == 'w_inventory') then return false, 'unavailable' end
    return exports.w_inventory:SettleGatheringNode(...)
end)
exports('InvWashJobGold', function(...) return callWInvServer('WashJobGold', false, ...) end)
exports('InvEnsureGatheringMaterial', function(...) return callWInvServer('EnsureGatheringMaterial', false, ...) end)
exports('InvGatheringMaterials', function(...) return callWInvServer('GatheringMaterials', {}, ...) end)

local GatheringMaterialListeners = {}
exports('InvOnGatheringMaterialChanged', function(cb)
    if not isCallable(cb) then return false end
    GatheringMaterialListeners[#GatheringMaterialListeners + 1] = { fn = cb, owner = currentInvoker() }
    return true
end)
AddEventHandler('w_inventory:gatheringMaterialChanged', function(item)
    for i = 1, #GatheringMaterialListeners do
        pcall(GatheringMaterialListeners[i].fn, item)
    end
end)

local GatheringNodeListeners = {}
exports('InvOnGatheringNodeSettled', function(cb)
    if not isCallable(cb) then return false end
    GatheringNodeListeners[#GatheringNodeListeners + 1] = { fn = cb, owner = currentInvoker() }
    return true
end)
AddEventHandler('w_inventory:gatheringNodeSettled', function(cid, track)
    for i = 1, #GatheringNodeListeners do
        pcall(GatheringNodeListeners[i].fn, cid, track)
    end
end)
