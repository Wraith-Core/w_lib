-- ════════════════════════════════════════════════════════════════════════════
-- w_lib — resource/doorbridge/server.lua
--   Unified Server Doorlock Bridge (Door*): supports w_doorlock, ox_doorlock,
--   rsg-doorlock, and vorp_doorlocks with automatic provider detection,
--   normalized door summaries, and invoking-resource listener cleanup.
-- ════════════════════════════════════════════════════════════════════════════
if not IsDuplicityVersion() then return end

WDoorBridge = WDoorBridge or {}

local Adapters = {}
local A = nil
local Aname = nil
local warnedForced = nil
local stateListeners = {}
local runtimeStates = {}
local cachedConfigDoors = {}

local function isStarted(res)
    return type(GetResourceState) == 'function' and GetResourceState(res) == 'started'
end

local function currentInvoker()
    if type(GetInvokingResource) == 'function' then
        local inv = GetInvokingResource()
        if type(inv) == 'string' and inv ~= '' then
            return inv
        end
    end
    return 'w_lib'
end

local function emitStateChanged(src, doorId, isLocked, usedItem)
    local normId = tonumber(doorId) or doorId
    if normId == nil then return end
    local lockedBool = (isLocked == true or isLocked == 1)
    runtimeStates[normId] = lockedBool and 1 or 0
    if #stateListeners == 0 then return end
    local snap = {}
    for i = 1, #stateListeners do snap[i] = stateListeners[i] end
    for i = 1, #snap do
        pcall(snap[i].fn, src, normId, lockedBool, usedItem or false)
    end
end

local function decodeJsonSafe(raw)
    if type(raw) == 'table' then return raw end
    if type(raw) == 'string' and raw ~= '' and type(json) == 'table' and type(json.decode) == 'function' then
        local ok, dec = pcall(json.decode, raw)
        if ok and type(dec) == 'table' then return dec end
    end
    return nil
end

-- ───────────────────────── w_doorlock / ox_doorlock ─────────────────────────

local function makeOxAdapter(resName)
    local function coerceKey(idOrDoor)
        if type(idOrDoor) == 'table' then
            if idOrDoor.id ~= nil then
                return tonumber(idOrDoor.id) or idOrDoor.id
            end
            return idOrDoor
        end
        return tonumber(idOrDoor) or idOrDoor
    end

    local adapter = {
        resource = resName,
    }

    function adapter.Get(idOrDoor)
        if idOrDoor == nil then return nil end
        if type(idOrDoor) == 'table' and idOrDoor.id == nil then
            return WDoorBridge.normalizeDoor(idOrDoor)
        end
        local key = coerceKey(idOrDoor)
        local ok, d = pcall(function() return exports[resName]:getDoor(key) end)
        if ok and type(d) == 'table' then
            return WDoorBridge.normalizeDoor(d, key)
        end
        return nil
    end

    function adapter.GetFromName(name)
        if type(name) ~= 'string' or name == '' then return nil end
        local ok, d = pcall(function() return exports[resName]:getDoorFromName(name) end)
        if ok and type(d) == 'table' then
            return WDoorBridge.normalizeDoor(d)
        end
        return nil
    end

    function adapter.GetAll()
        local out = {}
        local ok, list = pcall(function() return exports[resName]:getAllDoors() end)
        if ok and type(list) == 'table' then
            for k, d in pairs(list) do
                local norm = WDoorBridge.normalizeDoor(d, k)
                if norm then out[#out + 1] = norm end
            end
            table.sort(out, function(a, b)
                return (tonumber(a.id) or 0) < (tonumber(b.id) or 0)
            end)
            return out
        end
        if resName == 'ox_doorlock' and type(MySQL) == 'table' and MySQL.query and MySQL.query.await then
            local okDb, rows = pcall(MySQL.query.await, 'SELECT id, name, data FROM ox_doorlock')
            if okDb and type(rows) == 'table' then
                for _, r in ipairs(rows) do
                    local data = decodeJsonSafe(r.data) or {}
                    data.id = r.id
                    data.name = r.name or data.name
                    local norm = WDoorBridge.normalizeDoor(data, r.id)
                    if norm then out[#out + 1] = norm end
                end
                table.sort(out, function(a, b)
                    return (tonumber(a.id) or 0) < (tonumber(b.id) or 0)
                end)
            end
        end
        return out
    end

    function adapter.SetState(id, norm01)
        local key = coerceKey(id)
        if key == nil then return false end
        local ok, res = pcall(function() return exports[resName]:setDoorState(key, norm01) end)
        if ok then
            return res == true
        end
        return false
    end

    function adapter.Edit(id, data)
        local key = coerceKey(id)
        if key == nil or type(data) ~= 'table' then return false end
        if resName == 'ox_doorlock' then
            local existing = adapter.Get(key)
            if not existing then return false end
            local ok, res = pcall(function() return exports[resName]:editDoor(key, data) end)
            if not ok then return false end
            return res ~= false
        end
        local ok, res = pcall(function() return exports[resName]:editDoor(key, data) end)
        return ok and res == true
    end

    return adapter
end

Adapters['w_doorlock'] = makeOxAdapter('w_doorlock')
Adapters['ox_doorlock'] = makeOxAdapter('ox_doorlock')

-- ───────────────────────── rsg-doorlock ─────────────────────────

local function loadConfigTable(resName, fileName)
    if cachedConfigDoors[resName] then return cachedConfigDoors[resName] end
    if type(LoadResourceFile) ~= 'function' then return nil end
    local okLoad, src = pcall(LoadResourceFile, resName, fileName or 'config.lua')
    if not okLoad or type(src) ~= 'string' or src == '' then return nil end
    local env = {
        Config = {},
        vector3 = type(vector3) == 'function' and vector3 or function(x, y, z) return { x = x, y = y, z = z } end,
        vec3 = type(vec3) == 'function' and vec3 or function(x, y, z) return { x = x, y = y, z = z } end,
        vector4 = type(vector4) == 'function' and vector4 or function(x, y, z, w) return { x = x, y = y, z = z, w = w } end,
        vec4 = type(vec4) == 'function' and vec4 or function(x, y, z, w) return { x = x, y = y, z = z, w = w } end,
        joaat = type(joaat) == 'function' and joaat or tostring,
        GetHashKey = type(GetHashKey) == 'function' and GetHashKey or tostring,
        math = math,
        string = string,
        table = table,
        pairs = pairs,
        ipairs = ipairs,
        tonumber = tonumber,
        tostring = tostring,
    }
    local chunk = load(src, '@' .. resName .. '/config.lua', 't', env)
    if not chunk then return nil end
    local okRun, ret = pcall(chunk)
    if not okRun then return nil end
    local cfg = (type(ret) == 'table' and (ret.CONFIG or ret.Config or ret)) or env.Config
    if type(cfg) == 'table' then
        cachedConfigDoors[resName] = cfg
        return cfg
    end
    return nil
end

local function normalizeRsgDbRow(row)
    if type(row) ~= 'table' then return nil end
    local id = tonumber(row.id) or row.id
    local state = runtimeStates[id]
    if state == nil then
        state = WDoorBridge.normalizeState(row.locked)
        if state == nil then state = WDoorBridge.normalizeState(row.state) end
    end
    return WDoorBridge.normalizeDoor({
        id = id,
        name = row.name,
        state = state ~= nil and state or 1,
        coords = decodeJsonSafe(row.text_coords) or row.textCoords or row.coords,
        doors = decodeJsonSafe(row.doors) or row.doors,
        groups = decodeJsonSafe(row.jobs) or row.jobs or row.authorizedJobs,
        maxDistance = tonumber(row.distance) or 2.0,
    }, id)
end

Adapters['rsg-doorlock'] = {
    resource = 'rsg-doorlock',
    GetAll = function()
        local out = {}
        for _, fnName in ipairs({ 'getAllDoors', 'GetDoorList', 'GetDoors' }) do
            local ok, list = pcall(function() return exports['rsg-doorlock'][fnName](exports['rsg-doorlock']) end)
            if ok and type(list) == 'table' then
                for k, d in pairs(list) do
                    local norm = WDoorBridge.normalizeDoor(d, k)
                    if norm then
                        if runtimeStates[norm.id] ~= nil then
                            norm.state = runtimeStates[norm.id]
                            norm.locked = (norm.state == 1)
                        end
                        out[#out + 1] = norm
                    end
                end
                table.sort(out, function(a, b) return (tonumber(a.id) or 0) < (tonumber(b.id) or 0) end)
                return out
            end
        end
        if type(MySQL) == 'table' and MySQL.query and MySQL.query.await then
            local okDb, rows = pcall(MySQL.query.await, 'SELECT * FROM rsg_doorlocks')
            if okDb and type(rows) == 'table' and #rows > 0 then
                for _, r in ipairs(rows) do
                    local norm = normalizeRsgDbRow(r)
                    if norm then out[#out + 1] = norm end
                end
                table.sort(out, function(a, b) return (tonumber(a.id) or 0) < (tonumber(b.id) or 0) end)
                return out
            end
        end
        local cfg = loadConfigTable('rsg-doorlock', 'config.lua')
        local list = cfg and (cfg.DoorList or cfg.Doors)
        if type(list) == 'table' then
            for k, d in pairs(list) do
                local norm = WDoorBridge.normalizeDoor(d, k)
                if norm then
                    if runtimeStates[norm.id] ~= nil then
                        norm.state = runtimeStates[norm.id]
                        norm.locked = (norm.state == 1)
                    end
                    out[#out + 1] = norm
                end
            end
            table.sort(out, function(a, b) return (tonumber(a.id) or 0) < (tonumber(b.id) or 0) end)
        end
        return out
    end,
    Get = function(idOrDoor)
        if type(idOrDoor) == 'table' then
            return WDoorBridge.normalizeDoor(idOrDoor)
        end
        local key = tonumber(idOrDoor) or idOrDoor
        for _, fnName in ipairs({ 'getDoor', 'GetDoor' }) do
            local ok, d = pcall(function() return exports['rsg-doorlock'][fnName](exports['rsg-doorlock'], key) end)
            if ok and type(d) == 'table' then
                local norm = WDoorBridge.normalizeDoor(d, key)
                if norm and runtimeStates[norm.id] ~= nil then
                    norm.state = runtimeStates[norm.id]
                    norm.locked = (norm.state == 1)
                end
                return norm
            end
        end
        for _, d in ipairs(Adapters['rsg-doorlock'].GetAll()) do
            if tostring(d.id) == tostring(key) then return d end
        end
        return nil
    end,
    GetFromName = function(name)
        if type(name) ~= 'string' or name == '' then return nil end
        local ok, d = pcall(function() return exports['rsg-doorlock']:getDoorFromName(name) end)
        if ok and type(d) == 'table' then
            return WDoorBridge.normalizeDoor(d)
        end
        for _, item in ipairs(Adapters['rsg-doorlock'].GetAll()) do
            if item.name == name then return item end
        end
        return nil
    end,
    SetState = function(id, norm01)
        local key = tonumber(id) or id
        if key == nil then return false end
        for _, fnName in ipairs({ 'setDoorState', 'SetDoorState' }) do
            local ok, res = pcall(function() return exports['rsg-doorlock'][fnName](exports['rsg-doorlock'], key, norm01) end)
            if ok and res ~= nil then
                if res ~= false then
                    runtimeStates[key] = norm01
                    return true
                end
                return false
            end
        end
        local existing = Adapters['rsg-doorlock'].Get(key)
        if not existing then return false end
        local lockedBool = (norm01 == 1)
        runtimeStates[key] = norm01
        if type(MySQL) == 'table' and MySQL.update and MySQL.update.await then
            pcall(MySQL.update.await, 'UPDATE rsg_doorlocks SET locked = ? WHERE id = ?', { norm01, key })
        end
        if type(TriggerClientEvent) == 'function' then
            pcall(TriggerClientEvent, 'rsg-doorlock:client:setState', -1, key, lockedBool)
            pcall(TriggerClientEvent, 'rsg-doorlock:setState', -1, key, lockedBool)
        end
        emitStateChanged(nil, key, lockedBool, false)
        return true
    end,
    Edit = function(id, data)
        local key = tonumber(id) or id
        if key == nil or type(data) ~= 'table' then return false end
        local ok, res = pcall(function() return exports['rsg-doorlock']:editDoor(key, data) end)
        return ok and res == true
    end,
}

-- ───────────────────────── vorp_doorlocks ─────────────────────────

Adapters['vorp_doorlocks'] = {
    resource = 'vorp_doorlocks',
    GetAll = function()
        local out = {}
        for _, fnName in ipairs({ 'GetDoors', 'getAllDoors' }) do
            local ok, list = pcall(function() return exports['vorp_doorlocks'][fnName](exports['vorp_doorlocks']) end)
            if ok and type(list) == 'table' then
                for k, d in pairs(list) do
                    local norm = WDoorBridge.normalizeDoor(d, k)
                    if norm then
                        if runtimeStates[norm.id] ~= nil then
                            norm.state = runtimeStates[norm.id]
                            norm.locked = (norm.state == 1)
                        end
                        out[#out + 1] = norm
                    end
                end
                table.sort(out, function(a, b) return (tonumber(a.id) or 0) < (tonumber(b.id) or 0) end)
                return out
            end
        end
        local cfg = loadConfigTable('vorp_doorlocks', 'config.lua')
        local doors = cfg and cfg.Doors
        if type(doors) == 'table' then
            for k, d in pairs(doors) do
                local norm = WDoorBridge.normalizeDoor(d, k)
                if norm then
                    if runtimeStates[norm.id] ~= nil then
                        norm.state = runtimeStates[norm.id]
                        norm.locked = (norm.state == 1)
                    end
                    out[#out + 1] = norm
                end
            end
            table.sort(out, function(a, b) return (tonumber(a.id) or 0) < (tonumber(b.id) or 0) end)
        end
        return out
    end,
    Get = function(idOrDoor)
        if type(idOrDoor) == 'table' then
            return WDoorBridge.normalizeDoor(idOrDoor)
        end
        local key = tonumber(idOrDoor) or idOrDoor
        for _, fnName in ipairs({ 'GetDoor', 'getDoor', 'GetDoorInfo' }) do
            local ok, d = pcall(function() return exports['vorp_doorlocks'][fnName](exports['vorp_doorlocks'], key) end)
            if ok and type(d) == 'table' then
                local norm = WDoorBridge.normalizeDoor(d, key)
                if norm and runtimeStates[norm.id] ~= nil then
                    norm.state = runtimeStates[norm.id]
                    norm.locked = (norm.state == 1)
                end
                return norm
            end
        end
        for _, d in ipairs(Adapters['vorp_doorlocks'].GetAll()) do
            if tostring(d.id) == tostring(key) then return d end
        end
        return nil
    end,
    GetFromName = function(name)
        if type(name) ~= 'string' or name == '' then return nil end
        local ok, d = pcall(function() return exports['vorp_doorlocks']:getDoorFromName(name) end)
        if ok and type(d) == 'table' then
            return WDoorBridge.normalizeDoor(d)
        end
        for _, item in ipairs(Adapters['vorp_doorlocks'].GetAll()) do
            if item.name == name then return item end
        end
        return nil
    end,
    SetState = function(id, norm01)
        local key = tonumber(id) or id
        if key == nil then return false end
        for _, fnName in ipairs({ 'setDoorState', 'SetDoorState', 'UpdateDoorState' }) do
            local ok, res = pcall(function() return exports['vorp_doorlocks'][fnName](exports['vorp_doorlocks'], key, norm01) end)
            if ok and res ~= nil then
                if res ~= false then
                    runtimeStates[key] = norm01
                    return true
                end
                return false
            end
        end
        local existing = Adapters['vorp_doorlocks'].Get(key)
        if not existing then return false end
        runtimeStates[key] = norm01
        if existing.doubleDoor then
            runtimeStates[existing.doubleDoor] = norm01
        end
        if type(TriggerClientEvent) == 'function' then
            pcall(TriggerClientEvent, 'vorp_doorlocks:Client:UpdateDoorState', -1, key, norm01, existing.doubleDoor)
        end
        emitStateChanged(nil, key, norm01 == 1, false)
        return true
    end,
    Edit = function(id, data)
        local key = tonumber(id) or id
        if key == nil or type(data) ~= 'table' then return false end
        local ok, res = pcall(function() return exports['vorp_doorlocks']:editDoor(key, data) end)
        return ok and res == true
    end,
}

-- ───────────────────────── Detection & Lifecycle ─────────────────────────

local function ensure()
    if A and isStarted(Aname) then
        return true
    end
    A, Aname = nil, nil

    local rawForced = type(GetConvar) == 'function' and GetConvar('w_lib:doorlock', 'auto') or 'auto'
    local forced = WDoorBridge.normalizeName(rawForced)
    if forced and forced ~= 'auto' then
        if Adapters[forced] and isStarted(forced) then
            Aname = forced
            A = Adapters[forced]
        elseif warnedForced ~= forced then
            warnedForced = forced
            print(('^3[w_lib] warning: forced doorlock "%s" is not running; falling back to auto detection^7'):format(tostring(rawForced)))
        end
    end

    if not A then
        for i = 1, #WDoorBridge.ORDER do
            local candidate = WDoorBridge.ORDER[i]
            if isStarted(candidate) then
                Aname = candidate
                A = Adapters[candidate]
                break
            end
        end
    end

    if A then
        if type(SetConvarReplicated) == 'function' then
            pcall(SetConvarReplicated, 'w_lib:activeDoorlock', Aname)
        end
        return true
    end
    if type(SetConvarReplicated) == 'function' then
        pcall(SetConvarReplicated, 'w_lib:activeDoorlock', '')
    end
    return false
end

CreateThread(function()
    local attempts = 0
    while not A do
        attempts = attempts + 1
        if ensure() then break end
        if type(Wait) == 'function' then
            Wait(attempts < 60 and 500 or 2000)
        else
            break
        end
    end
end)

AddEventHandler('onResourceStart', function(res)
    if type(res) ~= 'string' then return end
    cachedConfigDoors[res] = nil
    if Adapters[res] then
        A, Aname = nil, nil
        ensure()
    end
end)

AddEventHandler('onResourceStop', function(res)
    if type(res) ~= 'string' or res == '' then return end
    cachedConfigDoors[res] = nil
    if A and res == Aname then
        A, Aname = nil, nil
        if type(SetConvarReplicated) == 'function' then
            pcall(SetConvarReplicated, 'w_lib:activeDoorlock', '')
        end
    end
    local selfName = type(GetCurrentResourceName) == 'function' and GetCurrentResourceName() or 'w_lib'
    for i = #stateListeners, 1, -1 do
        if res == selfName or stateListeners[i].owner == res then
            table.remove(stateListeners, i)
        end
    end
end)

AddEventHandler('w_doorlock:stateChanged', function(src, doorId, isLocked, usedItem)
    if ensure() and Aname == 'w_doorlock' then
        emitStateChanged(src, doorId, isLocked, usedItem)
    end
end)

AddEventHandler('ox_doorlock:stateChanged', function(src, doorId, isLocked, usedItem)
    if ensure() and Aname == 'ox_doorlock' then
        emitStateChanged(src, doorId, isLocked, usedItem)
    end
end)

AddEventHandler('rsg-doorlock:server:updateState', function(doorId, state)
    if ensure() and Aname == 'rsg-doorlock' then
        emitStateChanged(source, doorId, state == true or state == 1, false)
    end
end)

AddEventHandler('vorp_doorlocks:Server:UpdateDoorState', function(doorId, state)
    if ensure() and Aname == 'vorp_doorlocks' then
        local locked = (state == nil) and false or (state == true or state == 1)
        emitStateChanged(source, doorId, locked, false)
    end
end)

-- ───────────────────────── Server Exports ─────────────────────────

exports('DoorName', function()
    if ensure() then return Aname end
    return nil
end)

exports('DoorReady', function()
    return ensure()
end)

exports('DoorIsReady', function()
    return ensure()
end)

local function doorGet(idOrDoor)
    if idOrDoor == nil or not ensure() then return nil end
    return A.Get(idOrDoor)
end

exports('DoorGet', doorGet)
exports('DoorGetDoor', doorGet)

exports('DoorGetFromName', function(name)
    if type(name) ~= 'string' or name == '' or not ensure() then return nil end
    return A.GetFromName(name)
end)

local function doorGetAll()
    if not ensure() then return {} end
    return A.GetAll()
end

exports('DoorGetAll', doorGetAll)
exports('DoorGetAllDoors', doorGetAll)

exports('DoorGetState', function(id)
    local d = doorGet(id)
    return d and d.state or nil
end)

exports('DoorSetState', function(id, state)
    if id == nil then return false end
    local norm = WDoorBridge.normalizeState(state)
    if norm == nil then return false end
    if not ensure() then return false end
    return A.SetState(id, norm) == true
end)

exports('DoorEdit', function(id, data)
    if id == nil or type(data) ~= 'table' then return false end
    if not ensure() then return false end
    return A.Edit(id, data) == true
end)

exports('DoorOnStateChanged', function(cb)
    if not WDoorBridge.isCallable(cb) then return false end
    stateListeners[#stateListeners + 1] = { fn = cb, owner = currentInvoker() }
    return true
end)
