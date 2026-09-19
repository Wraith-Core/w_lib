w.require("timeout")
w.require("callback")

-- Last known routing bucket per player source, used to detect changes between polls.
local playersInstances = {}

-------------
-- POLLING
-------------

-- Poll every player's routing bucket and broadcast a global event when it changes.
-- Consumer resources listen to `w_lib:player:instanceChanged` from their scoped server.lua.
local function getPlayersInstances()
    local players = GetPlayers()
    for i = 1, #players do
        local source = tonumber(players[i])

        if source then
            local instance = GetPlayerRoutingBucket(source)
            local previous = playersInstances[source]
            if previous ~= instance then
                playersInstances[source] = instance
                TriggerEvent("w_lib:player:instanceChanged", source, instance, previous)
                TriggerClientEvent("w_lib:player:instanceChanged", source, instance, previous)
            end
        end
    end
end

w.ready(function()
    w.timeout.loop(2000, getPlayersInstances)
end)

w.callback.register("w_lib:player:getPlayerInstance", function(source)
    local instance = GetPlayerRoutingBucket(source)
    playersInstances[source] = instance
    return instance
end)

-------------
-- CLEANUP
-------------

-- Drop the cached instance so a reconnect under the same source doesn't compare against stale data.
AddEventHandler("playerDropped", function()
    local source = source
    playersInstances[source] = nil
end)
