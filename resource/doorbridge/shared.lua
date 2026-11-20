-- ════════════════════════════════════════════════════════════════════════════
-- w_lib — resource/doorbridge/shared.lua
--   Unified Doorlock Bridge (Door*): provider priority, state & door
--   normalization across w_doorlock, ox_doorlock, rsg-doorlock, vorp_doorlocks.
-- ════════════════════════════════════════════════════════════════════════════

WDoorBridge = WDoorBridge or {}

WDoorBridge.ORDER = {
    'w_doorlock',
    'ox_doorlock',
    'rsg-doorlock',
    'vorp_doorlocks',
}

WDoorBridge.ALIASES = {
    w = 'w_doorlock',
    w_doorlock = 'w_doorlock',
    ['w-doorlock'] = 'w_doorlock',
    ox = 'ox_doorlock',
    ox_doorlock = 'ox_doorlock',
    ['ox-doorlock'] = 'ox_doorlock',
    rsg = 'rsg-doorlock',
    ['rsg-doorlock'] = 'rsg-doorlock',
    rsg_doorlock = 'rsg-doorlock',
    rsg_doorlocks = 'rsg-doorlock',
    vorp = 'vorp_doorlocks',
    vorp_doorlocks = 'vorp_doorlocks',
    ['vorp-doorlocks'] = 'vorp_doorlocks',
    vorp_doorlock = 'vorp_doorlocks',
}

function WDoorBridge.normalizeName(name)
    if type(name) ~= 'string' then return nil end
    local s = name:lower():match('^%s*(.-)%s*$')
    if not s or s == '' then return nil end
    return WDoorBridge.ALIASES[s] or s
end

function WDoorBridge.isCallable(fn)
    if type(fn) == 'function' then return true end
    if type(fn) == 'table' then
        local mt = getmetatable(fn)
        return type(mt) == 'table' and mt.__call ~= nil
    end
    return false
end

function WDoorBridge.normalizeState(state)
    if state == 1 or state == true then return 1 end
    if state == 0 or state == false then return 0 end
    if type(state) == 'string' then
        local s = state:lower():match('^%s*(.-)%s*$')
        if s == '1' or s == 'true' or s == 'locked' then return 1 end
        if s == '0' or s == 'false' or s == 'unlocked' then return 0 end
    end
    return nil
end

function WDoorBridge.normalizeCoords(c)
    if c == nil then return nil end
    if type(c) == 'vector3' or type(c) == 'vector4' then
        return c
    end
    if type(c) == 'table' then
        local x = tonumber(c.x or c[1])
        local y = tonumber(c.y or c[2])
        local z = tonumber(c.z or c[3])
        if x and y and z then
            if type(vector3) == 'function' then
                local ok, vec = pcall(vector3, x + 0.0, y + 0.0, z + 0.0)
                if ok and vec then return vec end
            end
            return { x = x + 0.0, y = y + 0.0, z = z + 0.0 }
        end
    end
    return nil
end

function WDoorBridge.normalizeDoor(door, fallbackId)
    if type(door) ~= 'table' then return nil end
    local rawId = door.id or door.doorId or door.doorid or fallbackId or door.name
    if rawId == nil then return nil end
    local id = tonumber(rawId) or rawId

    local state = WDoorBridge.normalizeState(door.state)
    if state == nil and door.DoorState ~= nil then
        state = WDoorBridge.normalizeState(door.DoorState)
    end
    if state == nil and door.locked ~= nil then
        state = WDoorBridge.normalizeState(door.locked)
    end
    if state == nil then
        state = 1
    end

    local coords = WDoorBridge.normalizeCoords(door.coords or door.textCoords or door.text_coords or door.objCoords or door.doorCoords or door.Pos)
    if not coords and type(door.doors) == 'table' and type(door.doors[1]) == 'table' then
        local c1 = WDoorBridge.normalizeCoords(door.doors[1].coords or door.doors[1].objCoords)
        local c2 = type(door.doors[2]) == 'table' and WDoorBridge.normalizeCoords(door.doors[2].coords or door.doors[2].objCoords) or nil
        if c1 and c2 and c1.x and c2.x then
            coords = WDoorBridge.normalizeCoords({
                x = (c1.x + c2.x) * 0.5,
                y = (c1.y + c2.y) * 0.5,
                z = (c1.z + c2.z) * 0.5,
            })
        else
            coords = c1
        end
    end

    local name = door.name or door.doorName or door.Name
    if type(name) ~= 'string' or name == '' then
        name = tostring(id)
    end

    local maxDist = tonumber(door.maxDistance or door.distance or door.Distance) or 2.0

    local out = {
        id = id,
        name = name,
        state = state,
        locked = (state == 1),
        coords = coords,
        characters = door.characters or door.UniquePermissions,
        groups = door.groups or door.authorizedJobs or door.jobs or door.Permissions,
        items = door.items,
        maxDistance = maxDist,
        distance = tonumber(door.distance),
        hash = door.hash or door.doorid,
        doors = door.doors,
        doubleDoor = door.doubleDoor or door.DoubleDoor,
    }
    return out
end
