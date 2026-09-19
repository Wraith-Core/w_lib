w.me = PlayerPedId()
w.meCoords = GetEntityCoords(w.me)
w.mePlayerId = PlayerId()
w.meServerId = GetPlayerServerId(w.mePlayerId)
w.meIsMale = IsPedMale(PlayerPedId())

local valueUpdated = false

AddEventHandler('w_me:updateMe', function(me, meCoords, mePlayerId, meServerId, meIsMale)
  w.me = me
  w.meCoords = meCoords
  w.mePlayerId = mePlayerId
  w.meServerId = meServerId
  w.meIsMale = meIsMale
  valueUpdated = true
end)

---Deprecated
function w.updateMeTimer()
end

function w.forceUpdateMe()
  valueUpdated = false
  exports.w_lib:w_me_forceUpdateMe()
  while not valueUpdated do Wait(0) end
end
