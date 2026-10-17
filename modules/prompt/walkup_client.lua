-- ════════════════════════════════════════════════════════════════════════════
-- Walk-up prompts: w.prompt.at / w.prompt.atEntity / w.prompt.atClosestPlayer
-- (loaded by modules/prompt/client.lua; runs in the consumer's VM)
--
--   local rec = w.prompt.at({
--     coords = vector3(x, y, z), distance = 2.0, title = 'Bank' | false, position = 'bottom-right',
--     prompts = { { key = 'J', label = 'Open', hold = false | true | 1500, onComplete = function(rec) end,
--                   enabled = true, visible = true } },
--     canInteract = function() return true end,   -- optional, checked every frame
--     onEnter = function(rec) end, onExit = function(rec) end,
--   })
--   rec.remove()  rec.setTitle(t)  rec.setLabel(key, label)  rec.setVisible(key, bool) / rec.setVisible(bool)
--   rec.setEnabled(key, bool)  rec.setCoords(c)  rec.setDistance(d)  rec.setPrompts(rows)  rec.isShown()
--   rec.suspend(bool)  fields: rec.inside, rec.shown, rec.suspended, rec.entity, rec.group,
--   rec.point.currentDistance (metres to the target this tick), rec.canInteract
--
--   w.prompt.atEntity(entity, opts)      -- follows the entity (skipped while it does not exist)
--   w.prompt.atClosestPlayer(opts)       -- the nearest other player; onComplete(rec, playerId, ped)
--
-- One record shows at a time per resource: every frame the closest record whose
-- canInteract() passes wins, the others hide; the group is restored when the player comes
-- back, hidden while a NUI has focus. Across resources the library arbitrates through
-- exports.w_lib:WalkupClaim (closest wins there too). The keys fire through the group's
-- completion event (w_lib:promptCompleted), so nothing polls controls.
-- ════════════════════════════════════════════════════════════════════════════
local walkups = {}
local walkupOrder = {}
local walkupNext = 0
local walkupShown = nil
local walkupLoop = false

local function toVector(coords)
  if type(coords) == "vector3" then return coords end
  if type(coords) == "vector4" then return vector3(coords.x, coords.y, coords.z) end
  if type(coords) == "table" then
    local x, y, z = coords.x or coords[1], coords.y or coords[2], coords.z or coords[3]
    if x and y then return vector3(x + 0.0, y + 0.0, (z or 0.0) + 0.0) end
  end
  return nil
end

local function holdTime(hold)
  if hold == true then return 1000 end
  local n = tonumber(hold)
  if n and n > 0 then return n end
  return false
end

local function keyOf(key)
  return tostring(key or "J"):upper()   -- J, not E: E grabs the nearby player (owner, 2026-10-17)
end

local function walkupHide(rec)
  if rec.group then
    rec.group.hide()
  end
  if rec.shown then
    rec.shown = false
    if walkupShown == rec then walkupShown = nil end
    pcall(function() exports.w_lib:WalkupRelease() end)
    if rec.onExit then pcall(rec.onExit, rec) end
  end
end

local function walkupBuildGroup(rec)
  if rec.group then
    rec.group.delete()
    rec.group = nil
  end
  local group = w.prompt.createGroup(rec.title or false, rec.position or "bottom-right")
  rec.group = group
  rec.groupId = group.id
  for i = 1, #rec.prompts do
    local row = rec.prompts[i]
    local key = keyOf(row.key)
    group.addPrompt(key, row.label or "", holdTime(row.hold), row.page)
    if row.enabled == false then group.setEnabled(key, false) end
    if row.visible == false then group.setVisible(key, false) end
  end
end

local function walkupShow(rec)
  if not rec.group then walkupBuildGroup(rec) end
  rec.group.display()
  if not rec.shown then
    rec.shown = true
    walkupShown = rec
    if rec.onEnter then pcall(rec.onEnter, rec) end
  end
end

--- Where the record is right now: coords (and the ped / player for dynamic targets).
local function walkupTarget(rec, playerCoords)
  if rec.entity then
    if not DoesEntityExist(rec.entity) then return nil end
    return GetEntityCoords(rec.entity), rec.entity
  end
  if rec.closestPlayer then
    local best, bestDist, bestPed
    local me = PlayerId()
    for _, player in ipairs(GetActivePlayers()) do
      if player ~= me then
        local ped = GetPlayerPed(player)
        if ped and ped ~= 0 and DoesEntityExist(ped) then
          local d = #(GetEntityCoords(ped) - playerCoords)
          if d <= rec.distance and (not bestDist or d < bestDist) then
            best, bestDist, bestPed = player, d, ped
          end
        end
      end
    end
    if not best then return nil end
    return GetEntityCoords(bestPed), bestPed, GetPlayerServerId(best)
  end
  return rec.coords
end

local function walkupTick()
  local ped = PlayerPedId()
  local at = GetEntityCoords(ped)
  local winner, winnerDist, near = nil, nil, false

  if IsNuiFocused() then
    if walkupShown then walkupHide(walkupShown) end
    return true
  end

  for i = 1, #walkupOrder do
    local rec = walkups[walkupOrder[i]]
    if rec then
      local target, targetPed, targetPlayer = walkupTarget(rec, at)
      rec.target, rec.targetPed, rec.targetPlayer = target, targetPed, targetPlayer
      local d = target and #(target - at) or math.huge
      rec.point.currentDistance = d
      rec.inside = d <= rec.distance
      if target and rec.enabled ~= false and not rec.suspended and #rec.prompts > 0 then
        if d <= rec.distance + 1.5 then near = true end
        if d <= rec.distance and (not winnerDist or d < winnerDist) then
          local ok, allowed = true, true
          if rec.canInteract then
            ok, allowed = pcall(rec.canInteract, rec, targetPed, targetPlayer)
          end
          if ok and allowed ~= false then
            winner, winnerDist = rec, d
          end
        end
      end
    end
  end

  if winner then
    local claimed = true
    pcall(function() claimed = exports.w_lib:WalkupClaim(winnerDist) ~= false end)
    if not claimed then
      if walkupShown then walkupHide(walkupShown) end
    else
      if walkupShown and walkupShown ~= winner then walkupHide(walkupShown) end
      if winner.shown then
        if not winner.group.isVisible() then
          -- displaced by another group (a menu, the weapon wheel): step back, retry shortly
          walkupHide(winner)
          winner.displacedUntil = GetGameTimer() + 500
        end
      elseif not winner.displacedUntil or GetGameTimer() > winner.displacedUntil then
        walkupShow(winner)
      end
    end
  elseif walkupShown then
    walkupHide(walkupShown)
  end

  return near
end

local function walkupEnsureLoop()
  if walkupLoop then return end
  walkupLoop = true
  CreateThread(function()
    while next(walkups) do
      local near = walkupTick()
      Wait(near and 0 or 250)
    end
    walkupLoop = false
  end)
end

AddEventHandler("w_lib:promptCompleted", function(groupId, key)
  local rec = walkupShown
  if not rec or rec.groupId ~= groupId then return end
  key = keyOf(key)
  for i = 1, #rec.prompts do
    local row = rec.prompts[i]
    if keyOf(row.key) == key and row.enabled ~= false and row.visible ~= false then
      if row.onComplete then
        CreateThread(function()
          local ok, err = pcall(row.onComplete, rec, rec.targetPlayer or rec.targetPed, rec.targetPed)
          if not ok then eprint(("w.prompt.at: onComplete of %s failed: %s"):format(key, tostring(err))) end
        end)
      end
      return
    end
  end
end)

local function copyRows(rows)
  local out = {}
  for i = 1, #(rows or {}) do
    local r = rows[i]
    out[i] = {
      key = r.key, label = r.label, hold = r.hold, onComplete = r.onComplete,
      enabled = r.enabled, visible = r.visible, page = r.page,
    }
  end
  return out
end

local function walkupCreate(opts, target)
  if type(opts) ~= "table" then return eprint("w.prompt.at: options table expected") end
  walkupNext = walkupNext + 1

  local rec = {
    id = walkupNext,
    coords = toVector(opts.coords),
    entity = target and target.entity or nil,
    closestPlayer = target and target.closestPlayer or false,
    distance = tonumber(opts.distance) or 2.0,
    title = opts.title == nil and false or opts.title,
    position = opts.position,
    prompts = copyRows(opts.prompts),
    canInteract = opts.canInteract,
    onEnter = opts.onEnter,
    onExit = opts.onExit,
    enabled = opts.enabled ~= false,
    shown = false,
    inside = false,
    suspended = false,
    point = { currentDistance = math.huge },
  }
  if not rec.coords and not rec.entity and not rec.closestPlayer then
    return eprint("w.prompt.at: coords expected")
  end

  local function row(key)
    key = keyOf(key)
    for i = 1, #rec.prompts do
      if keyOf(rec.prompts[i].key) == key then return rec.prompts[i] end
    end
  end

  function rec.remove()
    walkupHide(rec)
    if rec.group then rec.group.delete() rec.group = nil end
    walkups[rec.id] = nil
    for i = #walkupOrder, 1, -1 do
      if walkupOrder[i] == rec.id then table.remove(walkupOrder, i) end
    end
  end
  rec.destroy = rec.remove
  rec.delete = rec.remove

  function rec.setTitle(title)
    rec.title = title == nil and false or title
    if rec.group then rec.group.setTitle(rec.title or "") end
  end

  function rec.setLabel(key, label)
    local r = row(key)
    if not r then return false end
    r.label = label
    if rec.group then rec.group.setLabel(keyOf(key), label or "") end
    return true
  end

  function rec.setVisible(key, visible)
    if type(key) == "boolean" then
      rec.enabled = key
      if not key then walkupHide(rec) end
      return true
    end
    local r = row(key)
    if not r then return false end
    r.visible = visible ~= false
    if rec.group then rec.group.setVisible(keyOf(key), r.visible) end
    return true
  end

  function rec.setEnabled(key, enabled)
    if type(key) == "boolean" then
      rec.enabled = key
      if not key then walkupHide(rec) end
      return true
    end
    local r = row(key)
    if not r then return false end
    r.enabled = enabled ~= false
    if rec.group then rec.group.setEnabled(keyOf(key), r.enabled) end
    return true
  end

  --- Step aside (the action opened a menu, the player is climbing on): the record hides and
  --- never wins while suspended; suspend(false) lets it come back on the next tick.
  function rec.suspend(state)
    rec.suspended = state ~= false
    if rec.suspended then walkupHide(rec) end
    return rec.suspended
  end

  function rec.setCoords(coords)
    rec.coords = toVector(coords) or rec.coords
  end

  function rec.setEntity(entity)
    rec.entity = entity
  end

  function rec.setDistance(distance)
    rec.distance = tonumber(distance) or rec.distance
  end

  function rec.setCanInteract(fn)
    rec.canInteract = fn
  end

  function rec.setPrompts(rows)
    rec.prompts = copyRows(rows)
    local wasShown = rec.shown
    walkupHide(rec)
    if rec.group then rec.group.delete() rec.group = nil end
    if wasShown then walkupShow(rec) end
  end

  function rec.isShown()
    return rec.shown == true
  end

  function rec.getTarget()
    return rec.target, rec.targetPed, rec.targetPlayer
  end

  walkups[rec.id] = rec
  walkupOrder[#walkupOrder + 1] = rec.id
  walkupEnsureLoop()
  return rec
end

--- A walk-up prompt at fixed coordinates.
---@param opts table (see the header of this file)
---@return table rec
function w.prompt.at(opts)
  return walkupCreate(opts)
end

--- A walk-up prompt that follows an entity.
---@param entity integer
---@param opts table
---@return table rec
function w.prompt.atEntity(entity, opts)
  if not entity or entity == 0 then return eprint("w.prompt.atEntity: entity expected") end
  return walkupCreate(opts, { entity = entity })
end

--- A walk-up prompt on the closest other player; onComplete(rec, playerServerId, ped).
---@param opts table
---@return table rec
function w.prompt.atClosestPlayer(opts)
  return walkupCreate(opts, { closestPlayer = true })
end

w.stopped(function()
  for id, rec in pairs(walkups) do
    if rec.group then rec.group.delete() end
    walkups[id] = nil
  end
end)
