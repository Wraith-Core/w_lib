w.require("timeout")

-------------
-- FUNCTIONS
-------------

w.player = setmetatable({}, {
  __call = function()
    return w.player.ped
  end
})
w.player.ped = PlayerPedId()
w.player.coords = GetEntityCoords(w.player.ped)
w.player.playerId = PlayerId()
w.player.serverId = GetPlayerServerId(w.player.playerId)
w.player.isMale = IsPedMale(w.player.ped)

local function sendUpdate(values)
  if #values == 0 then return end
  TriggerEvent("w_lib:player:update", values)
end

local function updateValues()
  local updated = {}
  local ped = PlayerPedId()
  if ped ~= w.player.ped then
    w.player.ped = ped
    w.player.playerId = PlayerId()
    w.player.isMale = IsPedMale(w.player.ped)
    updated[#updated + 1] = { "ped", w.player.ped }
    updated[#updated + 1] = { "playerId", w.player.playerId }
    updated[#updated + 1] = { "isMale", w.player.isMale }
  end
  local coords = GetEntityCoords(w.player.ped)
  if #(coords - w.player.coords) > 0.0001 then
    w.player.coords = GetEntityCoords(w.player.ped)
    updated[#updated + 1] = { "coords", w.player.coords }
  end
  sendUpdate(updated)
end

exports("w_player_force_update", updateValues)


w.timeout.loop(100, updateValues)

function w.player.forceUpdate()
  updateValues(true)
end

-------------
-- Shortcut
-------------
w.pl = w.player
