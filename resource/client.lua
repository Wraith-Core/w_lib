--[[
    https://github.com/overextended/ox_lib

    This file is licensed under LGPL-3.0 or higher <https://www.gnu.org/licenses/lgpl-3.0.en.html>

    Copyright © 2025 Linden <https://github.com/thelindat>
]]

local _registerCommand = RegisterCommand

---@param commandName string
---@param callback fun(source, args, raw)
---@param restricted boolean?
function RegisterCommand(commandName, callback, restricted)
    _registerCommand(commandName, function(source, args, raw)
        if not restricted or lib.callback.await('w_lib:checkPlayerAce', 100, ('command.%s'):format(commandName)) then
            callback(source, args, raw)
        end
    end)
end

-- ★ 'wraith' and shade 1 are the w_crafting look: a near-white accent on near-black plates.
--   It used to default to Mantine's 'blue' at shade 8, which is why every dialog in this
--   library arrived looking like a web form rather than like the rest of the server.
--
-- ⚠️ The convars still win, so a server can repaint it. The UI ignores a colour it has no
--    ramp for and keeps its own -- a typo in the convar dulls the accent, it does not break
--    the interface.
RegisterNUICallback('getConfig', function(_, cb)
    cb({
        primaryColor = GetConvar('w_lib:primaryColor', 'wraith'),
        primaryShade = GetConvarInt('w_lib:primaryShade', 1)
    })
end)

local function isSpawned() return not NetworkIsInTutorialSession() and true or nil end

local playerState = LocalPlayer.state

RegisterNetEvent('w_lib:setStateBagValue', function(key, value)
    if source == '' then return end

    playerState[key] = value
end)

AddStateBagChangeHandler('w_entity_setonground', '', function(bag, key, value)
    if not value then return end

    lib.waitFor(isSpawned, nil, false)

    local handle = lib.waitFor(function()
        local entity = GetEntityFromStateBagName(bag)

        if entity ~= 0 then return entity end

    end, 'failed to get entity from statebag', 10000)

    lib.waitFor(function()
        return not IsEntityWaitingForWorldCollision(handle) and true or nil
    end)

    local entity = IsEntityAVehicle(handle) and lib.vehicle:new(handle) or lib.object:new(handle)

    if IsEntityInAir(handle) then
        local coords = GetEntityCoords(handle)
        local hit, _, dest = lib.raycast.fromCoords(coords, vector3(coords.x, coords.y, coords.z - 1000), 511, 4)

        if hit then
            entity:setCoords(dest.x, dest.y, dest.z + 2)
        else
            local z = GetHeightmapBottomZForPosition(coords.x, coords.y)
            entity:setCoords(coords.x, coords.y, z + 10)
        end
    end

    if entity:setOnGround() then
        if entity:setr('w_entity_setonground', nil) then return end
    end

    error(('failed to set "%s" on ground'):format(bag))
end)
