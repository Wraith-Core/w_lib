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
    return t == 'function' or (t == 'table' and getmetatable(f)?.__call ~= nil)
end

-- ───────────────────────── w_inventory (مُتحقَّق) ─────────────────────────
Adapters['w_inventory'] = {
    resource = 'w_inventory',
    GetItemCount = function(src, item, meta) return exports.w_inventory:Search(src, 'count', item, meta) or 0 end,
    CanCarry = function(src, item, count) return exports.w_inventory:CanCarryItem(src, item, count) == true end,
    AddItem = function(src, item, count, meta) return exports.w_inventory:AddItem(src, item, count, meta) == true end,
    RemoveItem = function(src, item, count, meta, slot) return exports.w_inventory:RemoveItem(src, item, count, meta, slot) == true end,
    RegisterStash = function(id, label, slots, maxWeight) exports.w_inventory:RegisterStash(id, label, slots, maxWeight); return true end,
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

-- ═══════════ Items: an item's definition by name (nil when the inventory has none) ═══════════
--   w_inventory answers from its item list; vorp_inventory from the items table (getItemDB);
--   RSG / QBR from the core's Shared.Items. w_gunsmith asks this at boot to report items it
--   needs that the server never defined.
Adapters['w_inventory'].Items = function(name)
    local ok, def = pcall(function() return exports.w_inventory:Items(name) end)
    return (ok and type(def) == 'table') and def or nil
end
Adapters['vorp_inventory'].Items = function(name)
    local ok, def = pcall(function() return exports.vorp_inventory:getItemDB(name) end)
    return (ok and type(def) == 'table') and def or nil
end
Adapters['rsg-inventory'].Items = function(name)
    local ok, def = pcall(function() return exports['rsg-core']:GetCoreObject().Shared.Items[name] end)
    return (ok and type(def) == 'table') and def or nil
end
Adapters['qbr-inventory'].Items = function(name)
    local ok, def = pcall(function() return exports['qbr-core']:GetItems()[name] end)
    return (ok and type(def) == 'table') and def or nil
end

-- ═══════════ SetMetadata: writing an item's metadata in place (by slot) ═══════════
--   w_gunsmith keeps a weapon's customisation inside the item's metadata on the
--   inventories that carry one per item (w_inventory, rsg, qbr). VORP has no per-item
--   metadata for weapons; its adapter answers false and the caller keeps its own table.
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
Adapters['vorp_inventory'].SetMetadata = function() return false end

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
exports('InvGetItemCount', function(src, item, meta) return ensure() and (A.GetItemCount(src, item, meta) or 0) or 0 end)
exports('InvCanCarry', function(src, item, count) return ensure() and A.CanCarry(src, item, count) == true or false end)
exports('InvAddItem', function(src, item, count, meta) return ensure() and A.AddItem(src, item, count, meta) == true or false end)
exports('InvRemoveItem', function(src, item, count, meta, slot) return ensure() and A.RemoveItem(src, item, count, meta, slot) == true or false end)
exports('InvRegisterStash', function(id, label, slots, maxWeight)
    id = tostring(id or '')
    if id == '' then return false end

    StashDefinitions[id] = {
        id = id,
        label = label or id,
        slots = tonumber(slots) or 50,
        maxweight = tonumber(maxWeight) or 100000,
    }

    return ensure() and A.RegisterStash(id, label or id,
        StashDefinitions[id].slots, StashDefinitions[id].maxweight) or false
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

-- ───────────────────────── several lines at once (w_shops, voice orders) ─────────────────────────
-- lines = { { item = 'bread', count = 2, metadata = {...} }, ... } (`name` is accepted for `item`)

--- Can the player take every line? -> ok, reason ('inventory_full' | 'unavailable')
exports('InvCanCarryItems', function(src, lines)
    if not ensure() then return false, 'unavailable' end
    if type(lines) ~= 'table' then return false, 'unavailable' end
    for _, line in ipairs(lines) do
        local item = line.item or line.name
        if not item then return false, 'unavailable' end
        if A.CanCarry(src, item, tonumber(line.count) or 1) ~= true then return false, 'inventory_full' end
    end
    return true
end)

--- Give every line; on a failure the lines already given are taken back.
--- -> ok, reason ('inventory_full' | 'rollback_pending' | 'unavailable')
exports('InvAddItems', function(src, lines)
    if not ensure() then return false, 'unavailable' end
    if type(lines) ~= 'table' then return false, 'unavailable' end
    local given = {}
    for _, line in ipairs(lines) do
        local item = line.item or line.name
        local count = tonumber(line.count) or 1
        if not item or A.AddItem(src, item, count, line.metadata) ~= true then
            for i = #given, 1, -1 do
                local g = given[i]
                if A.RemoveItem(src, g.item, g.count, g.metadata) ~= true then
                    return false, 'rollback_pending'
                end
            end
            return false, 'inventory_full'
        end
        given[#given + 1] = { item = item, count = count, metadata = line.metadata }
    end
    return true
end)
