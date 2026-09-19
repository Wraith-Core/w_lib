-- ════════════════════════════════════════════════════════════════════════════
-- w.navigation — the player's waypoint. w_map owns the map and its waypoint when it runs
-- (exports.w_map:SetWaypoint / ClearWaypoint / GetWaypoint); without it the library draws a
-- waypoint blip of its own and routes the GPS to it.
--
--   w.navigation.setWaypoint(x, y, z?) -> boolean
--   w.navigation.clearWaypoint()
--   w.navigation.getWaypoint()         -> { x, y, z } | nil
--   w.navigation.isWaypointActive()    -> boolean
-- ════════════════════════════════════════════════════════════════════════════
w.createModule("navigation")

local blip
local current

local function mapRunning()
  return GetResourceState("w_map") == "started"
end

local function ownClear()
  if blip and DoesBlipExist(blip) then RemoveBlip(blip) end
  blip = nil
  current = nil
  ClearGpsMultiRoute()
end

function w.navigation.setWaypoint(x, y, z)
  x, y = tonumber(x), tonumber(y)
  if not x or not y then return false end
  z = tonumber(z) or 0.0

  if mapRunning() then
    local ok, result = pcall(function() return exports.w_map:SetWaypoint(x + 0.0, y + 0.0) end)
    if ok then return result ~= false end
  end

  ownClear()
  blip = BlipAddForCoords(`BLIP_STYLE_WAYPOINT`, x + 0.0, y + 0.0, z + 0.0)
  if not blip or blip == 0 then return false end
  current = { x = x + 0.0, y = y + 0.0, z = z + 0.0 }
  StartGpsMultiRoute(`COLOR_WHITE`, true, true)
  AddPointToGpsMultiRoute(x + 0.0, y + 0.0, z + 0.0)
  SetGpsMultiRouteRender(true)
  return true
end

function w.navigation.clearWaypoint()
  if mapRunning() then
    pcall(function() exports.w_map:ClearWaypoint() end)
  end
  ownClear()
  return true
end

function w.navigation.getWaypoint()
  if mapRunning() then
    local ok, wp = pcall(function() return exports.w_map:GetWaypoint() end)
    if ok and type(wp) == "table" then return wp end
  end
  return current
end

function w.navigation.isWaypointActive()
  return w.navigation.getWaypoint() ~= nil
end

w.stopped(ownClear)
