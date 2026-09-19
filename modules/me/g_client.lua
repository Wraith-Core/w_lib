w.me = PlayerPedId()
w.meCoords = GetEntityCoords(me)
w.mePlayerId = PlayerId()
w.meServerId = GetPlayerServerId(w.mePlayerId)
w.meIsMale = IsPedMale(PlayerPedId())
local timer = 1000
local timeout

w.require("timeout")

local function updateMe()
  w.forceUpdateMe()
end
timeout = w.timeout.loop(timer, updateMe)

---@param value integer the new interval to update me values
function w.updateMeTimer(value)
  timer = value
  if timeout then
    timeout:clear()
  end
  if timer then
    timeout = w.timeout.loop(timer, updateMe)
  end
end

function w.forceUpdateMe()
  w.me = PlayerPedId()
  w.meCoords = GetEntityCoords(w.me)
  w.mePlayerId = PlayerId()
  w.meServerId = GetPlayerServerId(w.mePlayerId)
  w.meIsMale = IsPedMale(w.me)
  TriggerEvent("w_me:updateMe", w.me, w.meCoords, w.mePlayerId, w.meServerId, w.meIsMale)
end

exports("w_me_forceUpdateMe", w.forceUpdateMe)
