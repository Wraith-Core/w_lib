-- ════════════════════════════════════════════════════════════════════════════
-- w_lib — resource/doorbridge/client.lua
--   Unified Client Doorlock Bridge (Door*): supports w_doorlock, ox_doorlock,
--   rsg-doorlock, and vorp_doorlocks.
-- ════════════════════════════════════════════════════════════════════════════
if IsDuplicityVersion() then return end

WDoorBridge = WDoorBridge or {}

local NAME = nil

local function isStarted(res)
    return type(GetResourceState) == 'function' and GetResourceState(res) == 'started'
end

local function detect()
    if type(GetConvar) == 'function' then
        local active = WDoorBridge.normalizeName(GetConvar('w_lib:activeDoorlock', ''))
        if active and active ~= '' and active ~= 'auto' and isStarted(active) then
            NAME = active
            return NAME
        end
    end
    if NAME and isStarted(NAME) then
        return NAME
    end
    NAME = nil
    if type(GetConvar) == 'function' then
        local forced = WDoorBridge.normalizeName(GetConvar('w_lib:doorlock', 'auto'))
        if forced and forced ~= 'auto' and isStarted(forced) then
            NAME = forced
            return NAME
        end
    end
    for i = 1, #WDoorBridge.ORDER do
        local candidate = WDoorBridge.ORDER[i]
        if isStarted(candidate) then
            NAME = candidate
            return NAME
        end
    end
    return nil
end

local function onStop(res)
    if res == NAME then
        NAME = nil
    end
end

AddEventHandler('onClientResourceStop', onStop)
AddEventHandler('onResourceStop', onStop)

exports('DoorName', function()
    return detect()
end)

exports('DoorReady', function()
    return detect() ~= nil
end)

exports('DoorIsReady', function()
    return detect() ~= nil
end)

local function getClosest()
    local provider = detect()
    if not provider then return nil end

    for _, fnName in ipairs({ 'getClosestDoor', 'GetClosestDoor' }) do
        local ok, d = pcall(function() return exports[provider][fnName](exports[provider]) end)
        if ok and type(d) == 'table' then
            return WDoorBridge.normalizeDoor(d)
        end
    end

    if provider == 'vorp_doorlocks' then
        local okId, doorId = pcall(function() return exports.vorp_doorlocks:getDoorIdByDistance() end)
        if okId and doorId ~= nil then
            local okSt, st = pcall(function() return exports.vorp_doorlocks:getDoorState(doorId) end)
            return WDoorBridge.normalizeDoor({ id = doorId, state = okSt and st or 1 }, doorId)
        end
    end
    return nil
end

exports('DoorGetClosest', getClosest)

local function getClosestId()
    local provider = detect()
    if not provider then return nil end
    for _, fnName in ipairs({ 'getClosestDoorId', 'GetClosestDoorId', 'getDoorIdByDistance' }) do
        local ok, id = pcall(function() return exports[provider][fnName](exports[provider]) end)
        if ok and id ~= nil then
            return tonumber(id) or id
        end
    end
    local closest = getClosest()
    return closest and closest.id or nil
end

exports('DoorGetClosestId', getClosestId)

exports('DoorUseClosest', function()
    local provider = detect()
    if not provider then return false end

    if provider == 'w_doorlock' then
        local ok, res = pcall(function() return exports.w_doorlock:useClosestDoor() end)
        return ok and res == true
    elseif provider == 'ox_doorlock' then
        local closestId = getClosestId()
        local ok, res = pcall(function() return exports.ox_doorlock:useClosestDoor() end)
        if not ok or res == false then return false end
        return res == true or closestId ~= nil
    elseif provider == 'vorp_doorlocks' then
        local okUse, resUse = pcall(function() return exports.vorp_doorlocks:useClosestDoor() end)
        if okUse and resUse ~= nil then return resUse == true end
        local doorId = getClosestId()
        if not doorId then return false end
        local okSt, cur = pcall(function() return exports.vorp_doorlocks:getDoorState(doorId) end)
        local target = (okSt and cur == 1) and 0 or 1
        local okSet, resSet = pcall(function() return exports.vorp_doorlocks:setDoorState(doorId, target) end)
        return okSet and resSet == true
    else
        local okUse, resUse = pcall(function() return exports[provider]:useClosestDoor() end)
        return okUse and resUse == true
    end
end)

exports('DoorPickClosest', function()
    local provider = detect()
    if not provider then return false end

    if provider == 'w_doorlock' then
        local ok, res = pcall(function() return exports.w_doorlock:pickClosestDoor() end)
        return ok and res == true
    elseif provider == 'ox_doorlock' then
        local closestId = getClosestId()
        if not closestId then return false end
        local ok, res = pcall(function() return exports.ox_doorlock:pickClosestDoor() end)
        if not ok or res == false then return false end
        return true
    else
        local ok, res = pcall(function() return exports[provider]:pickClosestDoor() end)
        return ok and res == true
    end
end)

exports('DoorGetIdFromEntity', function(entity)
    if not entity or entity == 0 then return nil end
    local provider = detect()
    if not provider then return nil end

    local ok, id = pcall(function() return exports[provider]:getDoorIdFromEntity(entity) end)
    if ok and id ~= nil then
        return tonumber(id) or id
    end
    return nil
end)
