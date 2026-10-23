-- w_lib 4.1.0 · /glow: the shapes of imports/glow in front of the player, to see the five looks and choose (owner 2026-10-23)
--   /glow                    every shape in its own look: a wall (5) round a square ahead, a path (1) to it, a point
--                            (2), an arrow (3) and a circle (4) in a row; a minute long
--   /glow <shape> [look]     one shape (wall · line · point · arrow · circle) in look 1-5
--   /glow off                hides them
-- Only the player who types it sees them (particles are local).

local SHAPES = { wall = true, line = true, point = true, arrow = true, circle = true }
local shown, seq = {}, 0

local function L(key, ...) return locale('glow.' .. key, ...) end

local function hide()
    for _, id in ipairs(shown) do lib.glow.remove(id) end
    shown = {}
end

--- A point `ahead` metres in front of the player and `side` metres to his right, on the ground
local function at(origin, h, ahead, side)
    local r = math.rad(h)
    local fx, fy = -math.sin(r), math.cos(r)
    local x, y = origin.x + fx * ahead + fy * side, origin.y + fy * ahead - fx * side
    local found, gz = GetGroundZFor_3dCoord(x + 0.0, y + 0.0, origin.z + 5.0, false)
    return vector3(x, y, (found == true or found == 1) and gz or origin.z - 1.0)
end

local function draw(shape, look, origin, h)
    local opts = { look = look, range = 120.0 }
    if shape == 'wall' then
        local c = { at(origin, h, 14.0, -4.0), at(origin, h, 14.0, 4.0), at(origin, h, 22.0, 4.0), at(origin, h, 22.0, -4.0) }
        return lib.glow.wall(c, opts)
    elseif shape == 'line' then
        return lib.glow.line({ at(origin, h, 1.5, 0.0), at(origin, h, 6.0, 1.0), at(origin, h, 10.0, -1.0), at(origin, h, 14.0, 0.0) }, opts)
    elseif shape == 'point' then
        local p = at(origin, h, 6.0, -3.0)
        opts.lift = 1.0
        return lib.glow.point(p, opts)
    elseif shape == 'arrow' then
        local p = at(origin, h, 6.0, 0.0)
        opts.lift = 0.3
        return lib.glow.arrow(vector3(p.x, p.y, p.z + 0.3), opts)
    else
        return lib.glow.circle(at(origin, h, 6.0, 3.0), 1.5, opts)
    end
end

RegisterCommand('glow', function(_, args)
    local first = tostring(args and args[1] or ''):lower()
    hide()
    if first == 'off' then
        lib.notify({ description = L('off'), type = 'inform' })
        return
    end
    local ped = PlayerPedId()
    local origin, h = GetEntityCoords(ped), GetEntityHeading(ped)
    if first == '' then
        for _, shape in ipairs({ 'wall', 'line', 'point', 'arrow', 'circle' }) do
            shown[#shown + 1] = draw(shape, nil, origin, h)
        end
        lib.notify({ description = L('all'), type = 'inform', duration = 10000 })
    elseif SHAPES[first] then
        local look = math.floor(tonumber(args[2]) or 0)
        if look < 1 or look > #lib.glow.looks then look = nil end
        shown[#shown + 1] = draw(first, look, origin, h)
        lib.notify({ description = L('one', first, look or '-'), type = 'inform', duration = 8000 })
    else
        lib.notify({ description = L('usage'), type = 'error', duration = 8000 })
        return
    end
    seq = seq + 1
    local mine = seq
    SetTimeout(60000, function()
        if seq == mine then hide() end
    end)
end, false)
