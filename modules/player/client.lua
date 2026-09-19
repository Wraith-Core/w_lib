w.require("callback")

if GetCurrentResourceName() == "w_lib" then return end

local instanceChangedCallbacks = {}
local currentInstance = nil
local moveCallbacks = {}
local numberMoveCallback = 0
local lastCallDidMoveFunc = {}
local lastMoveEvent = 0

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

AddEventHandler("w_lib:player:update", function(values)
  local now = GetGameTimer()
  for i = 1, #values do
    local key, value = values[i][1], values[i][2]
    w.player[key] = value
    if key == "coords" and numberMoveCallback > 0 then
      lastMoveEvent = now
      for c = 1, numberMoveCallback do
        local callback = moveCallbacks[c]
        if not callback.inProgress and (callback.lastExec + callback.interval) < now then
          CreateThread(function()
            callback.lastExec = now
            callback.inProgress = true
            pcall(callback.cb)
            callback.inProgress = false
          end)
        end
      end
    end
  end
end)

--- A function to force the update of module value
function w.player.forceUpdate()
  exports.w_lib:w_player_force_update()
end

--- A function fired when the local player's routing bucket (instance) changes.
--- Also fires immediately if the current instance is already known, or requests it
--- from the server if not — guaranteeing exactly one initial call per registration.
---@param cb function (function called with `(newInstance, oldInstance)`)
function w.player.instanceChanged(cb)
  if not cb then return eprint("The callback function is nil") end
  w.waitLibLoading()
  instanceChangedCallbacks[#instanceChangedCallbacks + 1] = cb
  if currentInstance ~= nil then
    return CreateThread(function() pcall(cb, currentInstance, nil) end)
  end
  currentInstance = w.callback.triggerServer("w_lib:player:getPlayerInstance")
  if currentInstance then
    CreateThread(function() pcall(cb, currentInstance, nil) end)
  end
end

RegisterNetEvent("w_lib:player:instanceChanged", function(newInstance, oldInstance)
  currentInstance = newInstance
  for i = 1, #instanceChangedCallbacks do
    local status, err = pcall(instanceChangedCallbacks[i], newInstance, oldInstance)
    if not status then
      eprint("Error in w.player.instanceChanged callback: %s", err)
    end
  end
end)

--- A function fired when the player move every 100ms
---@param cb function (function to fired when the player moves)
---@param interval? integer (minimal duration in ms between two executions. Can't be lower than 100ms)
function w.player.move(cb, interval)
  if not cb then return eprint("The callback function is nil") end
  numberMoveCallback += 1
  moveCallbacks[numberMoveCallback] = {
    cb = cb,
    lastExec = GetGameTimer(),
    interval = interval or 0,
    inProgress = true
  }
  local currentMove = numberMoveCallback
  CreateThread(function()
    pcall(cb)
    moveCallbacks[currentMove].inProgress = false
  end)
end

--- A function to know if the player moved since the last called of the function
---@param id string (Unique ID of call)
---@return boolean (`true` if the player moved since the last call)
function w.player.didMoveSinceLastCall(id)
  local now = GetGameTimer()
  local move = false
  if (lastCallDidMoveFunc[id] or 0) <= lastMoveEvent then
    move = true
  end
  lastCallDidMoveFunc[id] = now
  return move
end

-------------
-- Shortcut
-------------
w.pl = w.player

-- ---- Health and stamina as 0-100, the way a HUD wants them --------------------
--
-- ★ The engine keeps health from 0 to GetEntityMaxHealth (100 below "dead" on a player,
--   so a live player sits between 100 and the max), and stamina from 0 to the max
--   stamina float. Both are turned into a plain percentage here so every HUD reads
--   one number.

--- The player's health as a percentage, 0-100.
---
--- ⚠️ RDR3, not GTA V: a player ped's health runs from 0 to GetEntityMaxHealth (600) and the
---    ped is dead at 0 -- the same scale w_hud's needs damage and vorp_core's dead spawn
---    (SetEntityHealth 0) assume. There is no "dead at 100" band here.
---@param ped? number (defaults to the player's ped)
---@return number
function w.player.healthPercent(ped)
  ped = ped or PlayerPedId()
  if not ped or ped == 0 or not DoesEntityExist(ped) then return 0 end
  local health = GetEntityHealth(ped)
  local max = GetEntityMaxHealth(ped)
  if not max or max <= 0 then max = 600 end
  return math.floor(math.max(0, math.min(100, health / max * 100)) + 0.5)
end

--- The player's stamina as a percentage, 0-100.
---@param ped? number
---@return number
function w.player.staminaPercent(ped)
  ped = ped or PlayerPedId()
  if not ped or ped == 0 or not DoesEntityExist(ped) then return 0 end
  local ok, stamina = pcall(GetPedStamina, ped)
  local okMax, max = pcall(GetPedMaxStamina, ped)
  if not ok or not okMax or not max or max <= 0 then return 0 end
  return math.floor(math.max(0, math.min(100, stamina / max * 100)) + 0.5)
end
