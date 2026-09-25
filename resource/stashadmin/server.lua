-- Central stash administration for every supported inventory.
-- All consumers call exports.w_lib:Inv*; framework-specific details stay here.
if not IsDuplicityVersion() then return end

local ManagedStashes = {}
local schemaReady = promise.new()
local columnCache = {}

local function activeInventory()
    local ok, name = pcall(function() return exports.w_lib:InvName() end)
    return ok and name or nil
end

local function frameworkName()
    local ok, name = pcall(function() return exports.w_lib:FwName() end)
    return ok and name or nil
end

local function safeQuery(query, parameters)
    local ok, rows = pcall(MySQL.query.await, query, parameters or {})
    return ok and type(rows) == 'table' and rows or {}
end

local function tableColumns(tableName)
    local cached = columnCache[tableName]

    -- A table may be created after w_lib during folder startup. Keep valid
    -- schemas cached, but retry an empty lookup instead of caching "missing"
    -- forever for the lifetime of the server.
    if cached and (next(cached.columns) or os.time() < cached.retryAt) then
        return cached.columns
    end

    local rows = safeQuery([[
        SELECT COLUMN_NAME
        FROM information_schema.COLUMNS
        WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = ?
    ]], { tableName })
    local columns = {}

    for i = 1, #rows do
        columns[rows[i].COLUMN_NAME] = true
    end

    columnCache[tableName] = {
        columns = columns,
        retryAt = os.time() + 10,
    }
    return columns
end

local function notEmpty(value)
    return value ~= nil and value ~= '' and value ~= '[]' and value ~= '{}'
        and value ~= 'null' and value ~= 'false'
end

local function decodeItems(value)
    if type(value) == 'table' then return value end
    if not notEmpty(value) then return {} end

    local ok, decoded = pcall(json.decode, value)
    if not ok or type(decoded) ~= 'table' then return {} end
    if type(decoded.items) == 'table' then return decoded.items end
    return decoded
end

local function normalizeItems(items)
    local out = {}

    for key, value in pairs(type(items) == 'table' and items or {}) do
        if type(value) == 'table' then
            local name = value.name or value.item

            if name then
                out[#out + 1] = {
                    slot = value.slot or value.id or value.crafted_id
                        or value.item_crafted_id or tonumber(key) or key,
                    name = name,
                    item = name,
                    label = value.label or value.custom_label
                        or value.metadata?.label or value.info?.label or name,
                    count = tonumber(value.count or value.amount) or 1,
                    amount = tonumber(value.amount or value.count) or 1,
                    metadata = value.metadata or value.info or {},
                    isWeapon = value.isWeapon == true,
                }
            end
        end
    end

    table.sort(out, function(a, b)
        local left, right = tonumber(a.slot), tonumber(b.slot)
        if left and right then return left < right end
        return tostring(a.slot) < tostring(b.slot)
    end)

    return out
end

local function classify(name, owner)
    local value = tostring(name or ''):lower()
    if value:find('propert') or value:find('house') or value:find('home')
        or value:find('motel') or value:find('apartment') then return 'house' end
    if value:find('tribe') or value:find('gang') or value:find('faction')
        or value:find('camp') then return 'tribe' end
    if value:find('trunk') or value:find('glove') or value:find('vehicle')
        or value:find('wagon') or value:find('cart') then return 'vehicle' end
    if value:find('horse') or value:find('stable') or value:find('mount')
        or value:find('saddle') then return 'horse' end
    if value:find('shop') or value:find('store') or value:find('market') then return 'shop' end
    if owner and owner ~= '' and owner ~= 'nil' and owner ~= 'false' then return 'player' end
    return 'custom'
end

local function addUnique(out, seen, entry)
    if not entry or not entry.id then return end
    entry.id = tostring(entry.id)
    entry.name = entry.name or entry.label or entry.id
    entry.owner = entry.owner == nil and '' or tostring(entry.owner)
    entry.kind = entry.kind or classify(entry.id, entry.owner)
    entry.source = entry.source or 'stash'

    local key = ('%s\0%s\0%s'):format(entry.source, entry.id, entry.owner)
    if seen[key] then return end

    seen[key] = true
    out[#out + 1] = entry
end

local function vehicleSpec()
    local framework = frameworkName()
    local tableName = framework == 'qbr' and 'horses'
        or framework == 'rsgcore' and 'player_horses' or 'stables'
    local columns = tableColumns(tableName)

    if not columns.id then return nil end
    return tableName, columns
end

local function vehicleColumn(source)
    source = tostring(source or '')
    local column = source:match('^vehicle:(.+)$') or source
    if column == 'inventory' or column == 'trunk' or column == 'glovebox' then
        return column
    end
end

local function vehicleId(name, owner)
    local id = tonumber(owner)
    if id then return id end
    return tonumber(tostring(name or ''):match('(%d+)$'))
end

local function loadedWVehicleInventory(id, column)
    if activeInventory() ~= 'w_inventory'
        or (column ~= 'trunk' and column ~= 'glovebox') then return nil end

    local ok, inventoryId = pcall(function()
        return exports.w_inventory:GetLoadedVehicleInventoryId(id, column)
    end)

    return ok and inventoryId or nil
end

local function listVehicleStorage(out, seen)
    local tableName, columns = vehicleSpec()
    if not tableName then return end

    local selected = { '`id`' }
    if columns.name then selected[#selected + 1] = '`name`' end
    if columns.type then selected[#selected + 1] = '`type`' end
    for _, column in ipairs({ 'inventory', 'trunk', 'glovebox' }) do
        if columns[column] then selected[#selected + 1] = ('`%s`'):format(column) end
    end
    if #selected == 1 then return end

    local rows = safeQuery(('SELECT %s FROM `%s`'):format(table.concat(selected, ', '), tableName))

    for i = 1, #rows do
        local row = rows[i]
        for _, column in ipairs({ 'inventory', 'trunk', 'glovebox' }) do
            if columns[column] then
                local rideType = tostring(row.type or ''):lower()
                local isVehicle = rideType:find('wagon', 1, true)
                    or rideType:find('cart', 1, true)
                    or rideType:find('vehicle', 1, true)
                local rideName = tostring(row.name or '')

                addUnique(out, seen, {
                    id = ('%s-%s'):format(column, row.id),
                    name = rideName ~= '' and ('%s (#%s)'):format(rideName, row.id)
                        or ('#%s'):format(row.id),
                    owner = row.id,
                    kind = isVehicle and 'vehicle'
                        or (column == 'inventory' and 'horse' or 'vehicle'),
                    source = 'vehicle:' .. column,
                    storageType = column,
                    vehicleType = row.type,
                })
            end
        end
    end
end

local function getVehicleItems(name, owner, source)
    local column = vehicleColumn(source)
    local tableName, columns = vehicleSpec()
    local id = vehicleId(name, owner)
    if not column or not tableName or not columns[column] or not id then return {} end

    local loadedInventory = loadedWVehicleInventory(id, column)
    if loadedInventory then
        local ok, items = pcall(function()
            return exports.w_inventory:GetInventoryItems(loadedInventory)
        end)
        if ok and type(items) == 'table' then return normalizeItems(items) end
    end

    local rows = safeQuery(('SELECT `%s` AS data FROM `%s` WHERE `id` = ? LIMIT 1')
        :format(column, tableName), { id })
    return normalizeItems(decodeItems(rows[1] and rows[1].data))
end

local function metadataEmpty(metadata)
    return type(metadata) ~= 'table' or next(metadata) == nil
end

local function mutateStoredItems(raw, itemName, count, metadata, slot, remove, qbShape)
    local source = decodeItems(raw)
    local items = {}
    local changed = false
    local highestSlot = 0

    for _, value in pairs(source) do
        if type(value) == 'table' and (value.name or value.item) then
            local valueSlot = tonumber(value.slot) or 0
            highestSlot = math.max(highestSlot, valueSlot)
            local matchesSlot = slot ~= nil and tostring(value.slot or value.id) == tostring(slot)
            local matchesName = (value.name or value.item) == itemName

            if remove and not changed and (matchesSlot or (slot == nil and matchesName)) then
                local current = math.max(0, tonumber(value.count or value.amount) or 0)
                local remaining = current - count

                if remaining > 0 then
                    if value.amount ~= nil or qbShape then value.amount = remaining else value.count = remaining end
                    items[#items + 1] = value
                end

                changed = current >= count
                if not changed then items[#items + 1] = value end
            else
                if not remove and not changed and matchesName and metadataEmpty(metadata)
                    and metadataEmpty(value.metadata or value.info) then
                    local nextCount = math.max(0, tonumber(value.count or value.amount) or 0) + count
                    if value.amount ~= nil or qbShape then value.amount = nextCount else value.count = nextCount end
                    changed = true
                end
                items[#items + 1] = value
            end
        end
    end

    if not remove and not changed then
        local value = { name = itemName, slot = highestSlot + 1 }
        if qbShape then
            value.amount, value.info = count, metadata or {}
        else
            value.count, value.metadata = count, metadata or {}
        end
        items[#items + 1] = value
        changed = true
    end

    return changed and items or nil
end

local function mutateVehicle(name, owner, source, item, count, metadata, slot, remove)
    local column = vehicleColumn(source)
    local tableName, columns = vehicleSpec()
    local id = vehicleId(name, owner)
    if not column or not tableName or not columns[column] or not id then return false end

    local loadedInventory = loadedWVehicleInventory(id, column)
    if loadedInventory then
        if remove then
            return exports.w_inventory:RemoveItem(loadedInventory, item, count, nil,
                tonumber(slot) or slot) == true
        end

        return exports.w_inventory:AddItem(loadedInventory, item, count,
            type(metadata) == 'table' and metadata or {}) == true
    end

    local rows = safeQuery(('SELECT `%s` AS data FROM `%s` WHERE `id` = ? LIMIT 1')
        :format(column, tableName), { id })
    if not rows[1] then return false end

    local items = mutateStoredItems(rows[1].data, item, count, metadata, slot, remove, false)
    if not items then return false end

    local ok, affected = pcall(MySQL.update.await,
        ('UPDATE `%s` SET `%s` = ? WHERE `id` = ?'):format(tableName, column),
        { json.encode(items), id })
    return ok and affected ~= false
end

CreateThread(function()
    local ok, err = pcall(function()
        MySQL.query.await([[
            CREATE TABLE IF NOT EXISTS `w_lib_stashes` (
                `id` varchar(100) NOT NULL,
                `label` varchar(150) NOT NULL,
                `slots` int unsigned NOT NULL DEFAULT 50,
                `max_weight` int unsigned NOT NULL DEFAULT 100000,
                PRIMARY KEY (`id`)
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci
        ]])

        local rows = MySQL.query.await('SELECT id, label, slots, max_weight FROM w_lib_stashes') or {}
        for i = 1, #rows do ManagedStashes[tostring(rows[i].id)] = rows[i] end
    end)

    schemaReady:resolve(ok)
    if not ok then print(('^1[w_lib] stash catalogue setup failed: %s^0'):format(tostring(err))) end
end)

CreateThread(function()
    Citizen.Await(schemaReady)
    while not activeInventory() do Wait(500) end

    for id, stash in pairs(ManagedStashes) do
        exports.w_lib:InvRegisterStash(id, stash.label or id,
            tonumber(stash.slots) or 50, tonumber(stash.max_weight) or 100000)
    end
end)

local function listInventoryStashes(out, seen)
    local bag = activeInventory()

    if bag == 'w_inventory' then
        local rows = safeQuery('SELECT owner, name FROM w_inventory')
        for i = 1, #rows do
            addUnique(out, seen, {
                id = rows[i].name,
                name = rows[i].name,
                owner = rows[i].owner,
                source = 'stash',
            })
        end

        local ok, registered = pcall(function() return exports.w_inventory:GetRegisteredStashes() end)
        if ok and type(registered) == 'table' then
            for id, stash in pairs(registered) do
                if stash.owner ~= true then
                    addUnique(out, seen, {
                        id = stash.name or id,
                        name = stash.label or stash.name or id,
                        owner = type(stash.owner) == 'string' and stash.owner or '',
                        source = 'stash',
                    })
                end
            end
        end
    elseif bag == 'vorp_inventory' then
        local rows = safeQuery([[
            SELECT DISTINCT inventory_type AS id FROM character_inventories
            WHERE inventory_type IS NOT NULL AND inventory_type <> '' AND inventory_type <> 'default'
            UNION
            SELECT DISTINCT curr_inv AS id FROM loadout
            WHERE curr_inv IS NOT NULL AND curr_inv <> '' AND curr_inv <> 'default'
        ]])

        for i = 1, #rows do
            local id = tostring(rows[i].id)
            local label = id
            local ok, data = pcall(function() return exports.vorp_inventory:getCustomInventoryData(id) end)
            if ok and type(data) == 'table' then label = data.name or label end
            addUnique(out, seen, { id = id, name = label, source = 'stash' })
        end
    elseif bag == 'rsg-inventory' or bag == 'qbr-inventory' then
        local columns = tableColumns('stashitems')
        if columns.stash then
            local rows = safeQuery('SELECT stash FROM stashitems')
            for i = 1, #rows do
                addUnique(out, seen, { id = rows[i].stash, name = rows[i].stash, source = 'stash' })
            end
        elseif tableColumns('inventories').identifier then
            local rows = safeQuery('SELECT identifier FROM inventories')
            for i = 1, #rows do
                addUnique(out, seen, { id = rows[i].identifier, name = rows[i].identifier, source = 'stash' })
            end
        end
    end

    for id, stash in pairs(ManagedStashes) do
        addUnique(out, seen, {
            id = id,
            name = stash.label or id,
            source = 'stash',
            kind = classify(id, ''),
        })
    end
end

exports('InvListStashes', function()
    local out, seen = {}, {}
    listInventoryStashes(out, seen)
    listVehicleStorage(out, seen)
    table.sort(out, function(a, b) return tostring(a.name) < tostring(b.name) end)
    return out
end)

local function wInventoryContents(name, owner)
    local normalizedOwner = owner ~= nil and owner ~= '' and owner or nil
    local ok, items = pcall(function()
        return exports.w_inventory:GetInventoryItems(name, normalizedOwner)
    end)

    if ok and type(items) == 'table' then return normalizeItems(items) end

    local rows = safeQuery('SELECT data FROM w_inventory WHERE name = ? AND owner = ? LIMIT 1',
        { name, normalizedOwner and tostring(normalizedOwner) or '' })
    return normalizeItems(decodeItems(rows[1] and rows[1].data))
end

local function vorpContents(name)
    local out = {}
    local okItems, items = pcall(function()
        return exports.vorp_inventory:getCustomInventoryItems(name)
    end)

    if okItems and type(items) == 'table' then
        local normalized = normalizeItems(items)
        for i = 1, #normalized do out[#out + 1] = normalized[i] end
    end

    local okWeapons, weapons = pcall(function()
        return exports.vorp_inventory:getCustomInventoryWeapons(name)
    end)

    if okWeapons and type(weapons) == 'table' then
        for _, weapon in pairs(weapons) do
            out[#out + 1] = {
                slot = 'w' .. tostring(weapon.id),
                name = weapon.name,
                item = weapon.name,
                label = weapon.custom_label or weapon.label or weapon.name,
                count = 1,
                amount = 1,
                metadata = {
                    isWeapon = true,
                    weaponId = weapon.id,
                    serial = weapon.serial_number,
                    components = weapon.components or weapon.comps,
                },
                isWeapon = true,
            }
        end
    end

    return out
end

local function qbContents(bag, name)
    local ok, inventory = pcall(function() return exports[bag]:GetInventory(name) end)
    if ok and type(inventory) == 'table' then
        return normalizeItems(inventory.items or inventory)
    end

    local columns = tableColumns('stashitems')
    if columns.stash and columns.items then
        local rows = safeQuery('SELECT items FROM stashitems WHERE stash = ? LIMIT 1', { name })
        return normalizeItems(decodeItems(rows[1] and rows[1].items))
    end

    local inventoryColumns = tableColumns('inventories')
    if inventoryColumns.identifier and inventoryColumns.items then
        local rows = safeQuery('SELECT items FROM inventories WHERE identifier = ? LIMIT 1', { name })
        return normalizeItems(decodeItems(rows[1] and rows[1].items))
    end

    return {}
end

exports('InvGetStashContents', function(name, owner, source)
    if vehicleColumn(source) then return getVehicleItems(name, owner, source) end

    local bag = activeInventory()
    if bag == 'w_inventory' then return wInventoryContents(name, owner) end
    if bag == 'vorp_inventory' then return vorpContents(name) end
    if bag == 'rsg-inventory' or bag == 'qbr-inventory' then return qbContents(bag, name) end
    return {}
end)

local function ensureWStash(name, owner)
    local normalizedOwner = owner ~= nil and owner ~= '' and owner or nil
    local ok, inventory = pcall(function()
        return exports.w_inventory:GetInventory(name, normalizedOwner)
    end)
    if ok and type(inventory) == 'table' then return inventory end

    local managed = ManagedStashes[tostring(name)] or {}
    exports.w_inventory:RegisterStash(name, managed.label or name,
        tonumber(managed.slots) or 100, tonumber(managed.max_weight) or 1000000,
        normalizedOwner and true or nil)

    ok, inventory = pcall(function()
        return exports.w_inventory:GetInventory(name, normalizedOwner)
    end)
    return ok and type(inventory) == 'table' and inventory or nil
end

local function mutateQbDatabase(name, item, count, metadata, slot, remove)
    local tableName, idColumn = 'stashitems', 'stash'
    local columns = tableColumns(tableName)

    if not columns.stash or not columns.items then
        tableName, idColumn = 'inventories', 'identifier'
        columns = tableColumns(tableName)
        if not columns.identifier or not columns.items then return false end
    end

    local rows = safeQuery(('SELECT items FROM `%s` WHERE `%s` = ? LIMIT 1')
        :format(tableName, idColumn), { name })
    local items = mutateStoredItems(rows[1] and rows[1].items, item, count,
        metadata, slot, remove, true)
    if not items then return false end

    local encoded = json.encode(items)
    local ok

    if rows[1] then
        ok = pcall(MySQL.update.await,
            ('UPDATE `%s` SET items = ? WHERE `%s` = ?'):format(tableName, idColumn),
            { encoded, name })
    else
        ok = pcall(MySQL.insert.await,
            ('INSERT INTO `%s` (`%s`, items) VALUES (?, ?)'):format(tableName, idColumn),
            { name, encoded })
    end

    return ok == true
end

exports('InvStashAddItem', function(name, owner, item, count, metadata, source)
    count = math.max(1, math.floor(tonumber(count) or 1))
    metadata = type(metadata) == 'table' and metadata or {}

    if vehicleColumn(source) then
        return mutateVehicle(name, owner, source, item, count, metadata, nil, false)
    end

    local bag = activeInventory()

    if bag == 'w_inventory' then
        local inventory = ensureWStash(name, owner)
        return inventory and exports.w_inventory:AddItem(inventory.id, item, count, metadata) == true or false
    elseif bag == 'vorp_inventory' then
        local registered = false
        pcall(function() registered = exports.vorp_inventory:isCustomInventoryRegistered(name) == true end)
        if not registered then
            pcall(function()
                exports.vorp_inventory:registerInventory({
                    id = name, name = name, limit = 100, acceptWeapons = true,
                    shared = true, ignoreItemStackLimit = true,
                })
            end)
        end

        local characterId = tonumber(metadata.charid or metadata.charId or owner) or 1
        if tostring(item):upper():sub(1, 7) == 'WEAPON_' then
            local ok, result = pcall(function()
                return exports.vorp_inventory:addWeaponsToCustomInventory(name, {
                    {
                        name = item,
                        serial_number = metadata.serial or metadata.serial_number,
                        components = metadata.components or {},
                        custom_label = metadata.label,
                        custom_desc = metadata.description,
                    }
                }, characterId)
            end)
            return ok and result ~= false
        end

        local ok, result = pcall(function()
            return exports.vorp_inventory:addItemsToCustomInventory(name,
                { { name = item, amount = count, metadata = metadata } }, characterId)
        end)
        return ok and result ~= false
    elseif bag == 'rsg-inventory' or bag == 'qbr-inventory' then
        local ok, result = pcall(function()
            return exports[bag]:AddItem(name, item, count, false, metadata, 'w_lib:stashadmin')
        end)
        if ok and result ~= false then return true end
        return mutateQbDatabase(name, item, count, metadata, nil, false)
    end

    return false
end)

exports('InvStashRemoveItem', function(name, owner, item, count, slot, source)
    count = math.max(1, math.floor(tonumber(count) or 1))

    if vehicleColumn(source) then
        return mutateVehicle(name, owner, source, item, count, nil, slot, true)
    end

    local bag = activeInventory()

    if bag == 'w_inventory' then
        local inventory = ensureWStash(name, owner)
        return inventory and exports.w_inventory:RemoveItem(inventory.id, item, count, nil,
            tonumber(slot) or slot) == true or false
    elseif bag == 'vorp_inventory' then
        if tostring(slot or ''):sub(1, 1) == 'w' then
            local weaponId = tonumber(tostring(slot):sub(2))
            local ok, result = pcall(function()
                return exports.vorp_inventory:removeCustomInventoryWeaponById(name, weaponId)
            end)
            return ok and result ~= false
        end

        local ok, result = pcall(function()
            return exports.vorp_inventory:removeItemFromCustomInventory(name, item, count,
                tonumber(slot) or slot)
        end)
        return ok and result ~= false
    elseif bag == 'rsg-inventory' or bag == 'qbr-inventory' then
        local ok, result = pcall(function()
            return exports[bag]:RemoveItem(name, item, count, tonumber(slot) or false,
                'w_lib:stashadmin')
        end)
        if ok and result ~= false then return true end
        return mutateQbDatabase(name, item, count, nil, slot, true)
    end

    return false
end)

exports('InvCreateStash', function(id, label, slots, maxWeight)
    id = tostring(id or '')
    if id == '' then return false end

    label = tostring(label or id)
    slots = math.max(1, math.floor(tonumber(slots) or 50))
    maxWeight = math.max(1, math.floor(tonumber(maxWeight) or 100000))

    Citizen.Await(schemaReady)
    local ok = pcall(MySQL.query.await, [[
        INSERT INTO w_lib_stashes (id, label, slots, max_weight)
        VALUES (?, ?, ?, ?)
        ON DUPLICATE KEY UPDATE label = VALUES(label), slots = VALUES(slots),
            max_weight = VALUES(max_weight)
    ]], { id, label, slots, maxWeight })

    if not ok then return false end

    ManagedStashes[id] = { id = id, label = label, slots = slots, max_weight = maxWeight }
    return exports.w_lib:InvRegisterStash(id, label, slots, maxWeight) == true
end)
