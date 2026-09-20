-- ════════════════════════════════════════════════════════════════════════════
-- w_lib · resource/compat/shared.lua — the dialect-host status and the shared item
-- catalogue (both sides, inside w_lib's own VM).
--
--   exports.w_lib:CompatStatus()  -> { host = 'w_core', dialect = 'rsg', inboundAliases = { 'rsg-core', ... } }
--                                    or false on a plain VORP / RSG / QBR server
--   exports.w_lib:CompatHost()    -> 'w_core' | nil
--   exports.w_lib:CompatItems()   -> RSG-shaped item table for the host core (WCore.Shared.Items)
--
-- The item catalogue of record is w_inventory/data/items.lua (+ data/weapons_RDR3.lua);
-- the host core receives an RSG-shaped copy so RSG-written resources read
-- Core.Shared.Items[name].label / .weight / .useable exactly as they would on RSG-Core.
-- ════════════════════════════════════════════════════════════════════════════

local dialects = { 'rsg-core', 'qbr-core', 'vorp_core', 'vorp_menu', 'vorp_inputs', 'vorp_progressbar', 'ox_lib' }
local dialectSet = {}
for _, name in ipairs(dialects) do dialectSet[name] = true end

local status

--- Find the resource whose manifest `provide`s the dialect names.
local function scan()
    for i = 0, GetNumResources() - 1 do
        local name = GetResourceByFindIndex(i)
        if name and not dialectSet[name] then
            local state = GetResourceState(name)
            if state == 'started' or state == 'starting' then
                local aliases = {}
                for j = 0, GetNumResourceMetadata(name, 'provide') - 1 do
                    local provided = GetResourceMetadata(name, 'provide', j)
                    if dialectSet[provided] then aliases[#aliases + 1] = provided end
                end
                if #aliases > 0 then
                    return { host = name, dialect = 'rsg', inboundAliases = aliases }
                end
            end
        end
    end
    return false
end

local function getStatus()
    if status == nil then status = scan() end
    return status
end

-- a core that starts later than w_lib (or restarts) is picked up again
AddEventHandler(IsDuplicityVersion() and 'onResourceStart' or 'onClientResourceStart', function()
    status = nil
end)
AddEventHandler(IsDuplicityVersion() and 'onResourceStop' or 'onClientResourceStop', function()
    status = nil
end)

exports('CompatStatus', function()
    local s = getStatus()
    if not s then return false end
    return { host = s.host, dialect = s.dialect, inboundAliases = s.inboundAliases }
end)

exports('CompatHost', function()
    local s = getStatus()
    return s and s.host or nil
end)

--- The core object behind a dialect: 'wcore' (the host, WCore), 'rsg', 'qbr' or 'vorp'. On a
--- Wraith Core server every name answers with WCore; elsewhere the real core of that name.
exports('CompatGetCore', function(kind)
    kind = tostring(kind or 'wcore'):lower()
    local s = getStatus()
    local host = s and s.host or (GetResourceState('w_core') == 'started' and 'w_core' or nil)
    if host then
        local ok, core = pcall(function() return exports[host]:GetCoreObject() end)
        if ok and type(core) == 'table' then return core end
    end
    if kind == 'vorp' then
        local ok, core = pcall(function() return exports.vorp_core:GetCore() end)
        return ok and core or nil
    end
    local name = kind == 'qbr' and 'qbr-core' or 'rsg-core'
    local ok, core = pcall(function() return exports[name]:GetCoreObject() end)
    return ok and core or nil
end)

-- ───────────────────────────── items ─────────────────────────────
local items
local INVENTORY = 'w_inventory'

local function loadTable(resource, path)
    local source = LoadResourceFile(resource, path)
    if not source then return nil end
    local env = setmetatable({}, { __index = _G })
    local fn, err = load(source, ('@%s/%s'):format(resource, path), 't', env)
    if not fn then
        print(('^1[w_lib] CompatItems: cannot parse %s/%s: %s^0'):format(resource, path, err))
        return nil
    end
    local ok, result = pcall(fn)
    if not ok then
        print(('^1[w_lib] CompatItems: cannot run %s/%s: %s^0'):format(resource, path, result))
        return nil
    end
    return result
end

local function text(value, fallback)
    if type(value) == 'table' then return value.en or value.ar or fallback end
    if type(value) == 'string' and value ~= '' then return value end
    return fallback
end

local function build()
    local out = {}
    local rows = loadTable(INVENTORY, 'data/items.lua')
    if type(rows) ~= 'table' then
        if IsDuplicityVersion() or GetResourceState(INVENTORY) == 'started' then
            print('^1[w_lib] CompatItems: w_inventory/data/items.lua is unavailable - the core has no items^0')
        end
        return out
    end

    for name, row in pairs(rows) do
        if type(name) == 'string' and type(row) == 'table' then
            local key = name:sub(1, 7):lower() == 'weapon_' and name:lower() or name
            local image = row.client and row.client.image or (key .. '.png')
            out[key] = {
                name        = key,
                label       = text(row.label, name),
                weight      = tonumber(row.weight) or 0,
                type        = 'item',
                image       = image,
                unique      = row.stack == false,
                useable     = true,
                shouldClose = row.close ~= false,
                combinable  = nil,
                level       = 0,
                description = text(row.description, ''),
                label_ar    = row.label_ar or (type(row.label) == 'table' and row.label.ar) or nil,
                label_en    = row.label_en or (type(row.label) == 'table' and row.label.en) or nil,
                description_ar = row.description_ar or (type(row.description) == 'table' and row.description.ar) or nil,
                description_en = row.description_en or (type(row.description) == 'table' and row.description.en) or nil,
                metadata    = row.metadata,
                consume     = row.consume,
                degrade     = row.degrade,
                decay       = row.decay,
            }
        end
    end

    local weapons = loadTable(INVENTORY, 'data/weapons_RDR3.lua')
    local list = type(weapons) == 'table' and (weapons.Weapons or weapons) or {}
    for name, row in pairs(list) do
        if type(name) == 'string' and type(row) == 'table' and name:sub(1, 7):upper() == 'WEAPON_' then
            local key = name:lower()
            out[key] = out[key] or {
                name        = key,
                label       = text(row.label, name),
                weight      = tonumber(row.weight) or 0,
                type        = 'weapon',
                image       = row.client and row.client.image or (key .. '.png'),
                unique      = true,
                useable     = true,
                shouldClose = true,
                combinable  = nil,
                level       = 0,
                description = text(row.description, ''),
                ammotype    = row.ammoname and row.ammoname:upper() or nil,
                ammoname    = row.ammoname,
                durability  = row.durability,
                throwable   = row.throwable,
                label_ar    = row.label_ar,
                description_ar = row.description_ar,
            }
        end
    end

    local ammoList = type(weapons) == 'table' and weapons.Ammo or {}
    for name, row in pairs(ammoList) do
        if type(name) == 'string' and type(row) == 'table' then
            local key = name:lower()
            out[key] = out[key] or {
                name        = key,
                label       = text(row.label, name),
                weight      = tonumber(row.weight) or 0,
                type        = 'item',
                image       = row.client and row.client.image or (key .. '.png'),
                unique      = false,
                useable     = true,
                shouldClose = true,
                combinable  = nil,
                level       = 0,
                description = text(row.description, ''),
                label_ar    = row.label_ar,
                description_ar = row.description_ar,
            }
        end
    end

    return out
end

-- The client can only read w_inventory's files once that resource has started on the
-- client, which is after w_core; an empty result is therefore not cached so the host
-- can ask again (w_core/shared/items.lua fills its table in place on the retry).
exports('CompatItems', function()
    if not items or next(items) == nil then items = build() end
    return items
end)

--- Drop the cached catalogue (after editing w_inventory/data/items.lua) — the core keeps its copy.
exports('CompatItemsReload', function()
    items = nil
    return true
end)
