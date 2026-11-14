-- ════════════════════════════════════════════════════════════════════════════
-- w.placer: a guided placement editor in the world, one spot per key press
-- (modules/placer/client.lua, loaded into the CALLING resource's VM on first use)
--
--   local values, reason = w.placer.run({
--     title        = 'Valentine' | false,        -- title of the key cards
--     maxDistance  = 60.0,                       -- every spot within this of the first one (0 = off)
--     aimDistance  = 12.0,                       -- default reach of an 'aim' step, from the admin
--     rotateStep   = 5.0,                        -- degrees per mouse-wheel notch
--     textPosition = 'bottom-center', keyPosition = 'bottom-right', fov = 42.0,
--     confirm      = true,                       -- a last "check, then save" step (default true)
--     cancelHold   = 1000,                       -- ms the cancel key is held
--     keys   = { place = 'J', skip = 'G', remove = 'DELETE', back = 'BACK', cancel = 'X', look = 'C' },
--     labels = { place, skip, keep, remove, back, cancel, look, save, rotate, confirm,
--                step = 'Step %d/%d - %s' | fn(n, total, text), tooFar = '... %d m ...' },
--     extraKeys = { { key = 'Q', label = 'Option', press = function(ctx, relabel, remodel) end }, ... },  -- the caller's
--                                                 -- own cards beside the editor's (a choice made while placing: the
--                                                 -- snap / capture read it); relabel(i, text) renames card i;
--                                                 -- remodel(model) swaps the active step's ghost for another model
--                                                 -- where it stands (the turn of the wheel is kept) -> true when it did
--     steps  = { {
--       id = 'preview',                           -- key of the value in the result
--       kind = 'ped' | 'object' | 'vehicle' | 'point' | 'camera',
--       model = 'a_c_horse_morgan_bay',           -- ped / object / vehicle: the ghost's model
--       anchor = 'aim' | 'front' | 'self',        -- camera ray (default) | N m ahead | the admin's spot
--       distance = 12.0,                          -- aim: reach from the admin; front: metres ahead (1.6)
--       height = 0.0,                             -- metres added to the spot (camera default 0.65 = the eye)
--       ground = true,                            -- snap to the ground (default: not for self / camera)
--       face = 'player' | 'away' | 'side' | 'free', heading = 0.0,   -- how the ghost starts turned
--       ring = 2.5,                               -- a ring of this radius at the admin's feet
--       text = 'Press E to place the horse',      -- the instruction line
--       current = vector4(...),                   -- the stored spot: faded marker, G keeps it
--       optional = true, removable = true,        -- G skips it / DELETE clears it (false)
--       when = function(values, ctx) return true end,               -- false = skipped by itself
--       capture = function(value, ctx) return { preview = value } end, -- fields a placement sets
--       skip = function(values, ctx) return fields | nil end, skipLabel = function(values, ctx) end,
--       lookAt = 'preview' | { 'wagonPreview', 'wagonSpawn' }, lookHeight = 0.4,   -- camera steps
--       frame = function(spot, target, ctx) return camCoords, pointAt, fov end,     -- C look-through
--       create = function(model, coords, heading) return entity end,              -- own ghost
--       snap = function(pos, heading, ctx) return pos, heading end,  -- moves the spot each frame (a wall, a
--                                                 -- shelf...); nil [, reason] = no spot here: red, place refused
--       lift = 0.0,                               -- metres between the spot and the ghost's origin (default:
--                                                 -- the model's base, so it stands on the ground)
--     }, ... },
--   })
--   w.placer.cancel()  w.placer.isActive()  w.placer.canStart() -> ok, reason
--
-- Blocking: call it from a thread. `values` holds the fields the admin set (a placement's
-- value, or whatever `capture` returned); a field the admin kept is absent (nil = keep as is),
-- a cleared one is `false`. nil plus a reason ('cancelled' | 'dead' | 'mounted' | 'stopped' |
-- 'busy' | 'invalid' | 'error') when the admin left without saving. A ped / object / vehicle
-- step returns a vector4 (x, y, ground z, heading 0-360), a point or camera step a vector3.
--
-- ★ Why a module and not the gizmo: w.gizmo draws into the caller's ui_page, so it only works
--   for a resource that borrows w_lib's page. The resources that place things (w_stables,
--   w_pets) ship their own NUI. This editor uses no NUI of the caller's: the key cards are a
--   library prompt group (exports, drawn in w_lib's frame), the instruction is w.showTextUI.
-- ════════════════════════════════════════════════════════════════════════════
w.createModule("placer")

local ENTITY_KINDS = { ped = true, object = true, vehicle = true }
local KINDS        = { ped = true, object = true, vehicle = true, point = true, camera = true }

local DEFAULT_KEYS = { place = "J", skip = "G", remove = "DELETE", back = "BACK", cancel = "X", look = "C" }

-- The caller normally passes its own translated labels; these only keep an unlabelled
-- caller readable in the library's two languages.
local DEFAULT_LABELS = {
  en = {
    place = "Place", skip = "Skip", keep = "Keep current", remove = "Clear", back = "Back",
    cancel = "Cancel", look = "Look through", save = "Save", step = "Step %d/%d - %s",
    confirm = "Check the spots, then save", rotate = "mouse wheel turns it",
    tooFar = "Too far from the first spot (%d m max)", invalid = "It cannot go here",
  },
  ar = {
    place = "وضع", skip = "تخطٍّ", keep = "إبقاء الحالي", remove = "حذف", back = "رجوع",
    cancel = "إلغاء", look = "نظرة الكاميرا", save = "حفظ", step = "الخطوة %d/%d — %s",
    confirm = "راجع النقاط ثم احفظ", rotate = "عجلة الفأرة للتدوير",
    tooFar = "بعيد جدًا عن النقطة الأولى (%d م كحد أقصى)", invalid = "لا يمكن وضعه هنا",
  },
}

-- The key cards read RAW keys (w.rawKeys), which also reach the game: E would mount the
-- ghost horse or open a door, X / C / G / Backspace have their own game actions. The game
-- control on each key the editor uses is disabled every frame (w_core/shared/keybinds.lua).
local KEY_CONTROLS = {
  A = 0x7065027D, B = 0x4CC0E2FE, C = 0x9959A6F0, D = 0xB4E465B4, E = 0xCEFD9220, F = 0xB2F377E8,
  G = 0x760A9C6F, H = 0x24978A28, J = 0xF3830D8E, Q = 0xDE794E3E, R = 0xE30CD707, V = 0x7F8D09B8, X = 0x8CC9CD42,
  Z = 0x26E9DC00, BACK = 0x156F7119, BACKSPACE = 0x156F7119, DELETE = 0x4AF4D473, DEL = 0x4AF4D473,
  RETURN = 0xC7B5340A, ENTER = 0xC7B5340A,
}
local WHEEL_NEXT = joaat("INPUT_SELECT_NEXT_WEAPON")
local WHEEL_PREV = joaat("INPUT_SELECT_PREV_WEAPON")
local BLOCKED = {
  0x07CE1E61,  -- INPUT_ATTACK: no shot while aiming a spot
  0xF84FA74F,  -- INPUT_AIM
  0xAC4BD4F1,  -- INPUT_OPEN_WHEEL_MENU
  WHEEL_NEXT,  -- the wheel turns the ghost instead of switching weapons
  WHEEL_PREV,
}

local MARKER_GROUND = 0x6903B113   -- flat ground cylinder (resource/essentials teleports)
local MARKER_SPHERE = 0x50638AB9   -- sphere (modules/debugger drawSphere)
-- ★ Ink, paper and one red (w_lib/nui/theme/tokens.css): the spot under the cursor is paper, a spot
--   already placed paper-dim, the one the record holds now paper-faint, the reach ring a paper wash,
--   and out of reach the theme's one red -- the mark for a refusal. (They were white, red, gold and
--   green.)
local COLOR = {
  active  = { 242, 242, 242, 150 },
  far     = { 203, 1, 1, 170 },
  current = { 122, 122, 122, 110 },
  placed  = { 180, 180, 180, 120 },
  ring    = { 242, 242, 242, 60 },
}

local SET_ANIMAL_IS_WILD     = 0xAEB97D84CDF3C00B   -- (Ped, BOOL)
local DISABLE_NATIVE_PROMPTS = 0xF1622CE88A1946FB   -- _UI_PROMPT_DISABLE_PROMPTS_THIS_FRAME
local HIDE_LOCAL_PLAYER      = 0xE5F773C1A1D9D168   -- SET_LOCAL_PLAYER_INVISIBLE_LOCALLY (per frame)

local GHOST_ALPHA  = 170
local PLACED_ALPHA = 110
local MOVE_EPSILON = 0.025   -- metres a ghost must shift before it is moved again
local EYE_HEIGHT   = 0.65    -- a camera step's default spot: the admin's eye above the root

local session = nil          -- the running editor (one at a time per resource)

-- ---------------------------------------------------------------------------
-- small helpers
-- ---------------------------------------------------------------------------

--- Named BOOL natives answer 1 / 0 on this client, never true / false: 0 is truthy in Lua.
local function yes(v)
  return v == true or v == 1
end

local function vec3of(v)
  local t = type(v)
  if t == "vector3" then return v end
  if t == "vector4" then return vector3(v.x, v.y, v.z) end
  if t == "table" then
    local x, y, z = tonumber(v.x or v[1]), tonumber(v.y or v[2]), tonumber(v.z or v[3])
    if x and y and z then return vector3(x + 0.0, y + 0.0, z + 0.0) end
  end
  return nil
end

local function headingOf(v)
  local t = type(v)
  if t == "vector4" then return v.w end
  if t == "table" then return tonumber(v.w or v[4]) end
  return nil
end

--- 0-360: servers limit stored headings to ±360, and a wheel spun long enough passes it
local function norm(h)
  return (tonumber(h) or 0.0) % 360.0
end

--- The heading that looks along (dx, dy), in the game's convention (forward = -sin h, cos h)
local function headingTo(dx, dy)
  return norm(math.deg(math.atan(-dx, dy)))
end

local function format(template, ...)
  if type(template) == "function" then
    local ok, text = pcall(template, ...)
    return ok and tostring(text) or ""
  end
  local ok, text = pcall(string.format, tostring(template or ""), ...)
  return ok and text or tostring(template or "")
end

--- Ground under a point: probes from just above (a spot taken from a standing player sits a
--- metre over the ground), gives up beyond 6 m and keeps the given height
local function groundZ(x, y, z)
  for _, start in ipairs({ z + 1.0, z + 3.0, z + 0.3 }) do
    local found, gz = GetGroundZFor_3dCoord(x, y, start, false)
    if yes(found) and gz and gz <= start and (start - gz) <= 6.0 then return gz end
  end
  return z
end

--- 4.1.0 (the owner 2026-10-23): the game's glitter instead of DrawMarker (imports/glow): a spot = look 2, the
--- reach ring = look 4 round the player; out of reach the spot is tinted the theme's red. `key` names the mark.
--- 4.2.0 (the owner 2026-11-02: polygons, no particles when placing): lib.glow draws the polygon look by default; the
--- mark is again what it was before 4.1.0 -- a flat ring on the ground or a sphere, `size` across, in its own colour.
local function mark(key, kind, pos, size, color)
  local ground = kind == MARKER_GROUND
  local opts = { look = (ground and size > 1.2) and 4 or 2, range = 150.0,
    color = color == COLOR.far and { color[1], color[2], color[3] } or nil,
    solid = { shape = ground and "ring" or "sphere", color = { color[1], color[2], color[3] }, alpha = color[4], size = size / 2.0 } }
  if ground and size > 1.2 then
    opts.step = 1.5
    opts.ground = false -- the ring's centre is already on the ground (groundZ)
    lib.glow.frame("placer:" .. key, "circle", pos, size / 2.0, opts)
  else
    lib.glow.frame("placer:" .. key, "point", pos, opts)
  end
end

local function player()
  local ped = PlayerPedId()
  return { ped = ped, coords = GetEntityCoords(ped), heading = norm(GetEntityHeading(ped)) }
end

--- Why the editor cannot run (or must stop) for this player right now
local function stopReason(p)
  if yes(IsEntityDead(p.ped)) or yes(IsPedDeadOrDying(p.ped, true)) then return "dead" end
  -- a mount or a wagon carries the admin away from every spot being set, and E would dismount
  if yes(IsPedOnMount(p.ped)) or yes(IsPedInAnyVehicle(p.ped, false)) then return "mounted" end
  return nil
end

-- ---------------------------------------------------------------------------
-- ghosts: LOCAL entities only. Nobody else sees an admin's draft, and no state bag is ever
-- read on them (Entity(x).state on a non-networked entity throws native 0x3BB78F05).
-- ---------------------------------------------------------------------------

--- How far a vehicle / object's origin sits above its lowest point, so a frozen ghost
--- (no physics to settle it) stands on the ground instead of half sunk into it
local function baseLift(hash)
  local ok, mn = pcall(GetModelDimensions, hash)
  if ok and mn and tonumber(mn.z) and mn.z < 0 then return -mn.z end
  return 0.0
end

local function ghostify(entity, kind)
  SetEntityAlpha(entity, GHOST_ALPHA, false)
  SetEntityCollision(entity, false, false)
  FreezeEntityPosition(entity, true)
  SetEntityInvincible(entity, true)
  SetEntityCanBeDamaged(entity, false)
  if kind == "ped" then
    SetBlockingOfNonTemporaryEvents(entity, true)
    SetPedCanBeTargetted(entity, false)
    Citizen.InvokeNative(SET_ANIMAL_IS_WILD, entity, false)
  end
end

--- Create a ghost for a step (blocking: run it in a thread)
---@return table? ghost { entity, viaLib, lift, pos, heading }
local function spawnGhost(step, pos, heading)
  if step.model == nil then return nil end
  local hash = type(step.model) == "number" and step.model or joaat(step.model)
  local entity, viaLib

  if step.create then
    local ok, created = pcall(step.create, step.model, pos, heading)
    entity = ok and created or nil
  elseif step.kind == "ped" then
    -- w.entity.create streams the model and gives a random outfit, so the ped is visible;
    -- its own delete keeps the module's cleanup list right (a raw DeleteEntity would leave a
    -- stale handle there that a reused handle could later match)
    local ok, created = pcall(w.entity.create, hash, pos, heading, false)
    entity, viaLib = ok and created or nil, true
  else
    if not pcall(w.requestModel, hash, 8000) then return nil end
    if step.kind == "vehicle" then
      -- bDontAutoCreateDraftAnimals: a draft vehicle is born without its team, nothing to strip
      entity = CreateVehicle(hash, pos.x, pos.y, pos.z, heading + 0.0, false, false, true, false)
    else
      entity = CreateObject(hash, pos.x, pos.y, pos.z, false, false, false, false, false)
    end
    SetModelAsNoLongerNeeded(hash)
  end

  if not entity or entity == 0 or not DoesEntityExist(entity) then return nil end
  ghostify(entity, step.kind)
  return { entity = entity, viaLib = viaLib, lift = step.kind == "ped" and 0.0 or (tonumber(step.lift) or baseLift(hash)) }
end

local function removeGhost(g)
  if not g or not g.entity then return end
  if g.viaLib then
    w.entity.delete(g.entity)
  elseif DoesEntityExist(g.entity) then
    SetEntityAsMissionEntity(g.entity, true, true)
    DeleteEntity(g.entity)
  end
  g.entity = nil
end

local function moveGhost(g, kind, pos, heading)
  if not g or not g.entity or not DoesEntityExist(g.entity) then return end
  if not g.pos or #(g.pos - pos) > MOVE_EPSILON then
    if kind == "ped" then
      -- this build puts a ped's FEET on the z it is given (w_stables client/preview.lua)
      SetEntityCoords(g.entity, pos.x, pos.y, pos.z, false, false, false, false)
    else
      SetEntityCoordsNoOffset(g.entity, pos.x, pos.y, pos.z + (g.lift or 0.0), false, false, false)
    end
    g.pos = pos
  end
  if not g.heading or math.abs(g.heading - heading) > 0.5 then
    SetEntityHeading(g.entity, heading)
    g.heading = heading
  end
end

-- ---------------------------------------------------------------------------
-- session state
-- ---------------------------------------------------------------------------

--- The fields every resolved step set so far, in step order (a later step may override one)
local function merged(s)
  local out = {}
  for i = 1, #s.steps do
    local o = s.outcomes[i]
    if o and o.fields then
      for k, v in pairs(o.fields) do out[k] = v end
    end
  end
  return out
end

--- Where a step's spot stands now: what the admin placed or kept, the stored spot for a step
--- not reached yet, nil when it was skipped or cleared
local function valueOf(s, id)
  local i = s.byId[id]
  if not i then return nil end
  local o = s.outcomes[i]
  if o then return o.value end
  if i >= s.index then return s.steps[i].current end
  return nil
end

local function contextFor(s, step, p, index)
  return {
    id = step.id, step = step, index = index or s.index,
    ped = p.ped, playerCoords = p.coords, playerHeading = p.heading,
    entity = s.ghost and s.ghost.entity or nil, heading = s.heading,
    values = merged(s),
    position = function(id) return valueOf(s, id) end,
  }
end

--- The first spot set in this run: every other spot must stay near it
local function origin(s)
  for i = 1, #s.steps do
    local o = s.outcomes[i]
    if o and o.position then return o.position end
  end
  return nil
end

local function tooFar(s, pos)
  if not pos or not s.maxDistance or s.maxDistance <= 0 then return false end
  local first = origin(s)
  return first ~= nil and #(pos - first) > s.maxDistance
end

local function flash(s, text)
  s.flash, s.flashUntil = text, GetGameTimer() + 2500
end

local function tooFarText(s)
  return format(s.labels.tooFar, math.floor(s.maxDistance + 0.5))
end

--- The step a camera step looks at: its spot, the ghost standing there and the raw value
local function lookTarget(s, step)
  local ids = step.lookAt
  if type(ids) == "string" then ids = { ids } end
  for _, id in ipairs(type(ids) == "table" and ids or {}) do
    local value = valueOf(s, id)
    local pos = vec3of(value)
    if pos then
      local i = s.byId[id]
      local g = i and s.ghosts[i]
      local entity = g and g.entity or nil
      if entity and not DoesEntityExist(entity) then entity = nil end
      return pos, entity, value
    end
  end
  return nil
end

--- The point a camera step's line / default view aims at (the ghost's root when it stands)
local function lookPoint(step, pos, entity)
  local at = entity and GetEntityCoords(entity) or pos
  return vector3(at.x, at.y, at.z + (tonumber(step.lookHeight) or 0.0))
end

-- ---------------------------------------------------------------------------
-- the look-through camera (camera steps, C)
-- ---------------------------------------------------------------------------

local function lookOff(s)
  s.looking = false
  if s.cam then
    RenderScriptCams(false, true, 400, true, true)
    DestroyCam(s.cam, false)
    s.cam = nil
  end
end

--- What the camera would show from `spot`: the step's own framing when it has one (so the
--- admin sees exactly the picture the players will get), else straight at the target
local function lookFrame(s, step, spot)
  local target, entity, value = lookTarget(s, step)
  if not target then return nil end
  if step.frame then
    local ok, coords, at, fov = pcall(step.frame, spot, target,
      { targetEntity = entity, targetHeading = headingOf(value), step = step })
    if ok and coords and at then return coords, at, tonumber(fov) or s.fov end
    return nil
  end
  return spot, lookPoint(step, target, entity), s.fov
end

local function look(s, step)
  if not s.looking then return end
  if not step or step.kind ~= "camera" or not s.candidate then return lookOff(s) end

  local coords, at, fov = lookFrame(s, step, s.candidate)
  if not coords then return lookOff(s) end

  if not s.cam then
    s.cam = CreateCam("DEFAULT_SCRIPTED_CAMERA", true)
    SetCamCoord(s.cam, coords.x, coords.y, coords.z)
    PointCamAtCoord(s.cam, at.x, at.y, at.z)
    SetCamFov(s.cam, fov + 0.0)
    SetCamActive(s.cam, true)
    RenderScriptCams(true, true, 400, true, true)
  else
    SetCamCoord(s.cam, coords.x, coords.y, coords.z)
    PointCamAtCoord(s.cam, at.x, at.y, at.z)
    SetCamFov(s.cam, fov + 0.0)
  end

  -- the camera stands where the admin's head is: hide his own ped from it (this client only)
  Citizen.InvokeNative(HIDE_LOCAL_PLAYER, true)
end

-- ---------------------------------------------------------------------------
-- aiming (anchor 'aim')
-- ---------------------------------------------------------------------------

--- The spot the admin looks at, capped at `reach` metres from him. The probe is read one
--- frame after it starts instead of waiting for it (w.raycast waits a frame): the loop must
--- run EVERY frame, or the game controls it disables come back for that frame (E mounts).
local function aimPoint(s, reach, p)
  local cam = GetGameplayCamCoord()
  local rot = GetGameplayCamRot(2)
  local rx, rz = math.rad(rot.x), math.rad(rot.z)
  local flat = math.abs(math.cos(rx))
  local dir = vector3(-math.sin(rz) * flat, math.cos(rz) * flat, math.sin(rx))
  local length = reach + #(cam - p.coords)

  if s.probe then
    local status, hit, endCoords = GetShapeTestResult(s.probe)
    if status ~= 1 then                        -- 1 = still running
      s.probe = nil
      s.aimHit = (status == 2 and yes(hit) and endCoords) or false
    end
  end
  if not s.probe then
    local to = cam + dir * length
    -- flag 1: the map's collision only, so the ray goes through peds, horses and the ghosts
    s.probe = StartShapeTestLosProbe(cam.x, cam.y, cam.z, to.x, to.y, to.z, 1, p.ped, 7)
  end

  local point = s.aimHit
  if not point then
    -- the sky: along the look, at the admin's height (the ground probe then finds his floor)
    local far = cam + dir * length
    point = vector3(far.x, far.y, p.coords.z)
  end

  local dx, dy = point.x - p.coords.x, point.y - p.coords.y
  local d = math.sqrt(dx * dx + dy * dy)
  if d > reach and d > 0.0 then
    point = vector3(p.coords.x + dx / d * reach, p.coords.y + dy / d * reach, point.z)
  end
  return point
end

--- Where the active step's spot is this frame, and the heading its ghost takes
local function candidate(s, step, p)
  local anchor = step.anchor or (step.kind == "camera" and "self" or "aim")
  local pos

  if anchor == "self" then
    pos = p.coords
  elseif anchor == "front" then
    local rad = math.rad(p.heading)
    local d = tonumber(step.distance) or 1.6
    pos = vector3(p.coords.x - math.sin(rad) * d, p.coords.y + math.cos(rad) * d, p.coords.z)
  else
    pos = aimPoint(s, tonumber(step.distance) or s.aimDistance, p)
  end

  local ground = step.ground
  if ground == nil then ground = anchor ~= "self" and step.kind ~= "camera" end
  if ground then pos = vector3(pos.x, pos.y, groundZ(pos.x, pos.y, pos.z)) end

  local lift = tonumber(step.height) or (step.kind == "camera" and EYE_HEIGHT or 0.0)
  if lift ~= 0.0 then pos = vector3(pos.x, pos.y, pos.z + lift) end

  local face = step.face or (step.kind == "vehicle" and "side" or (step.kind == "ped" and "player" or "free"))
  local dx, dy = p.coords.x - pos.x, p.coords.y - pos.y
  local onTop = (dx * dx + dy * dy) < 0.01
  local base
  if face == "player" then
    base = onTop and p.heading or headingTo(dx, dy)
  elseif face == "away" then
    base = onTop and p.heading or (headingTo(dx, dy) + 180.0)
  elseif face == "side" then
    base = (onTop and p.heading or headingTo(dx, dy)) + 90.0
  else
    base = tonumber(step.heading) or s.entryHeading
  end

  local heading = norm(base + s.rotation)
  -- the step's own snap (a flag on a wall): the spot moved, or none here (a reason, else true: red, place refused)
  if step.snap then
    local ok, sp, sh, why = pcall(step.snap, pos, heading, { ped = p.ped, playerCoords = p.coords,
      reach = tonumber(step.distance) or s.aimDistance, rotation = s.rotation })
    if not ok then
      eprint(("w.placer: snap() of step '%s' failed: %s"):format(step.id, tostring(sp)))
      return pos, heading, true
    end
    if sp == nil then return pos, heading, why or true end
    return sp, sh and norm(sh) or heading, nil
  end
  return pos, heading, nil
end

-- ---------------------------------------------------------------------------
-- steps
-- ---------------------------------------------------------------------------

local function dropGhost(s)
  s.spawnToken = s.spawnToken + 1   -- a spawn still in flight deletes its entity on arrival
  if s.ghost then removeGhost(s.ghost) end
  s.ghost = nil
end

--- The G card: the step's own alternative (skipLabel / skip), else keep the stored spot,
--- else skip an optional step; nil = G does nothing here
local function skipLabelOf(s, step, p)
  s.customSkip = false
  if step.skipLabel and step.skip then
    local ok, label = pcall(step.skipLabel, merged(s), contextFor(s, step, p))
    if ok and label then
      s.customSkip = true
      return label
    end
  end
  if step.current ~= nil then return s.labels.keep end
  if step.optional then return s.labels.skip end
  return nil
end

local function configureKeys(s, p)
  local g, K, L = s.group, s.keys, s.labels
  local step = s.steps[s.index]
  pcall(function()
    g.setVisible(K.back, #s.history > 0)
    if not step then
      g.setLabel(K.place, L.save)
      g.setVisible(K.skip, false)
      g.setVisible(K.remove, false)
      g.setVisible(K.look, false)
      return
    end
    g.setLabel(K.place, step.placeLabel or L.place)
    local skip = skipLabelOf(s, step, p)
    g.setVisible(K.skip, skip ~= nil)
    if skip then g.setLabel(K.skip, skip) end
    g.setVisible(K.remove, step.removable == true and step.current ~= nil)
    g.setVisible(K.look, step.kind == "camera")
  end)
end

--- The active step's ghost, spawned in a thread: streaming a model takes frames, and the frame
--- loop must keep disabling the game controls meanwhile. Born under the ground, moved on the next frame.
local function spawnActive(s, step, p)
  if not (step and ENTITY_KINDS[step.kind] and step.model ~= nil) then return end
  local token = s.spawnToken
  local at = vector3(p.coords.x, p.coords.y, p.coords.z - 25.0)
  CreateThread(function()
    local g = spawnGhost(step, at, p.heading)
    if not g then return end
    if s.closed or s.spawnToken ~= token then return removeGhost(g) end
    s.ghost = g
  end)
end

local function enter(s, index, p)
  lookOff(s)
  dropGhost(s)
  s.index = index
  s.rotation = 0.0
  s.entryHeading = p.heading
  s.candidate, s.heading = nil, nil
  -- a second press queued behind the one that got here belongs to the step it was aimed at
  s.pressed = {}
  configureKeys(s, p)
  spawnActive(s, s.steps[index], p)
end

--- A resolved spot the admin kept: its ghost stands there for the rest of the run
local function keptGhost(s, index, outcome)
  local step = s.steps[index]
  local pos = outcome.position
  local heading = norm(headingOf(outcome.value) or 0.0)
  CreateThread(function()
    local g = spawnGhost(step, vector3(pos.x, pos.y, pos.z - 25.0), heading)
    if not g then return end
    if s.closed or s.outcomes[index] ~= outcome then return removeGhost(g) end
    moveGhost(g, step.kind, pos, heading)
    SetEntityAlpha(g.entity, PLACED_ALPHA, false)
    s.ghosts[index] = g
  end)
end

--- Walk forward from `from`, letting each step's when() skip it
local function advance(s, from, p)
  local i = from
  while i <= #s.steps do
    local step = s.steps[i]
    if not step.when then break end
    local ok, allowed = pcall(step.when, merged(s), contextFor(s, step, p, i))
    if not ok then
      eprint(("w.placer: when() of step '%s' failed: %s"):format(step.id, tostring(allowed)))
      break                                   -- a broken condition shows the step
    end
    if allowed then break end
    -- skipped by itself: the stored value stays as it is (no field)
    s.outcomes[i] = { kind = "auto", value = step.current, position = vec3of(step.current), fields = {} }
    i = i + 1
  end

  if i > #s.steps and not s.confirm then
    s.done = true
    return
  end
  enter(s, i, p)
end

local function resolve(s, outcome, p)
  local i = s.index
  local step = s.steps[i]
  outcome.position = vec3of(outcome.value)
  s.outcomes[i] = outcome

  -- the ghost stays where the spot was taken: later steps (a camera looking at the horse) and
  -- the confirm step show every spot together
  if outcome.kind == "placed" and s.ghost then
    s.ghosts[i] = s.ghost
    if s.ghost.entity and DoesEntityExist(s.ghost.entity) then SetEntityAlpha(s.ghost.entity, PLACED_ALPHA, false) end
    s.ghost = nil
  elseif (outcome.kind == "kept" or outcome.kind == "placed") and outcome.position and ENTITY_KINDS[step.kind] and step.model ~= nil then
    -- kept, or placed before its ghost had streamed in (that spawn is dropped by the next
    -- step's token): a ghost stands on the spot anyway, since a camera step frames from its root
    keptGhost(s, i, outcome)
  end

  s.history[#s.history + 1] = i
  advance(s, i + 1, p)
end

--- Back to the last step the admin resolved; that step and every later one start over
local function goBack(s, p)
  local j = table.remove(s.history)
  if not j then return end
  for k = j, #s.steps do
    s.outcomes[k] = nil
    if s.ghosts[k] then removeGhost(s.ghosts[k]) end
    s.ghosts[k] = nil
  end
  enter(s, j, p)
end

local function act(s, action, p)
  if action == "cancel" then
    s.cancelled = "cancelled"
    return
  end
  if action == "back" then return goBack(s, p) end

  -- the caller's own card: its press, which may rename any of its cards
  local xi = tonumber(tostring(action):match("^extra(%d+)$"))
  if xi then
    local e = s.extra[xi]
    if not e then return end
    local function relabel(i, text)
      local x = s.extra[i]
      if x and s.group then x.label = tostring(text) pcall(s.group.setLabel, x.key, x.label) end
    end
    local st = s.steps[s.index]
    -- another model for the active step: the old ghost goes, the new one streams in where the aim is
    local function remodel(model)
      if not st or not ENTITY_KINDS[st.kind] or model == nil or model == st.model then return false end
      st.model = model
      dropGhost(s)
      spawnActive(s, st, p)
      return true
    end
    local ok, err = pcall(e.press, st and contextFor(s, st, p) or { playerCoords = p.coords }, relabel, remodel)
    if not ok then eprint(("w.placer: the %s key's press failed: %s"):format(e.key, tostring(err))) end
    return
  end

  local step = s.steps[s.index]
  if not step then                            -- the confirm step
    if action == "place" then
      -- a caller's server checks the spots against where the admin stands when he saves
      -- (w_stables: 120 m); saving from far away would throw the whole run away
      if tooFar(s, p.coords) then return flash(s, tooFarText(s)) end
      s.done = true
    end
    return
  end

  if action == "look" then
    if step.kind == "camera" then
      if s.looking then lookOff(s) else s.looking = true end
    end
    return
  end

  if action == "place" then
    local pos = s.candidate
    if not pos then return end
    if s.bad then return flash(s, type(s.bad) == "string" and s.bad or s.labels.invalid) end
    if tooFar(s, pos) then return flash(s, tooFarText(s)) end

    local value = pos
    if ENTITY_KINDS[step.kind] or (step.kind == "point" and step.withHeading) then
      value = vector4(pos.x, pos.y, pos.z, s.heading or 0.0)
    end

    local fields = { [step.id] = value }
    if step.capture then
      local ok, out = pcall(step.capture, value, contextFor(s, step, p))
      if not ok then
        eprint(("w.placer: capture() of step '%s' failed: %s"):format(step.id, tostring(out)))
        return
      end
      if type(out) == "table" then fields = out end
    end
    return resolve(s, { kind = "placed", value = value, fields = fields }, p)
  end

  if action == "skip" then
    if s.customSkip then
      local ok, fields = pcall(step.skip, merged(s), contextFor(s, step, p))
      if ok and type(fields) == "table" then
        local v = fields[step.id]
        if v == false then v = nil end
        if v ~= nil and tooFar(s, vec3of(v)) then return flash(s, tooFarText(s)) end
        return resolve(s, { kind = "custom", value = v, fields = fields }, p)
      end
    end
    if step.current ~= nil then
      -- a kept spot far from the new first one would split the set: place it again instead
      if tooFar(s, vec3of(step.current)) then return flash(s, tooFarText(s)) end
      return resolve(s, { kind = "kept", value = step.current, fields = {} }, p)
    end
    if step.optional then return resolve(s, { kind = "skipped", fields = {} }, p) end
    return
  end

  if action == "remove" and step.removable and step.current ~= nil then
    return resolve(s, { kind = "removed", fields = { [step.id] = false } }, p)
  end
end

-- ---------------------------------------------------------------------------
-- drawing
-- ---------------------------------------------------------------------------

local function drawStep(s, step, pos, far, p)
  local color = far and COLOR.far or COLOR.active

  if tonumber(step.ring) then
    local feet = vector3(p.coords.x, p.coords.y, groundZ(p.coords.x, p.coords.y, p.coords.z) + 0.02)
    mark("ring", MARKER_GROUND, feet, step.ring * 2.0, COLOR.ring)
  end

  local current = vec3of(step.current)
  if current then
    if step.kind == "camera" then mark("current", MARKER_SPHERE, current, 0.3, COLOR.current)
    else mark("current", MARKER_GROUND, current, 0.9, COLOR.current) end
  end

  if step.kind == "camera" then
    if not s.looking then mark("cursor", MARKER_SPHERE, pos, 0.22, color) end
    local target, entity = lookTarget(s, step)
    if target then
      local at = lookPoint(step, target, entity)
      DrawLine(pos.x, pos.y, pos.z, at.x, at.y, at.z, color[1], color[2], color[3], 230)
    end
  else
    mark("cursor", MARKER_GROUND, vector3(pos.x, pos.y, pos.z + 0.02), ENTITY_KINDS[step.kind] and 0.7 or 0.5, color)
  end
end

--- The spots already set: ghosts stand by themselves, points and cameras need a marker
local function drawResolved(s)
  for i = 1, #s.steps do
    local o = s.outcomes[i]
    local step = s.steps[i]
    if o and o.position and o.kind ~= "auto" and not ENTITY_KINDS[step.kind] then
      if step.kind == "camera" then
        mark("placed:" .. i, MARKER_SPHERE, o.position, 0.22, COLOR.placed)
        local target, entity = lookTarget(s, step)
        if target then
          local at = lookPoint(step, target, entity)
          DrawLine(o.position.x, o.position.y, o.position.z, at.x, at.y, at.z,
            COLOR.placed[1], COLOR.placed[2], COLOR.placed[3], 200)
        end
      else
        mark("placed:" .. i, MARKER_GROUND, o.position, 0.5, COLOR.placed)
      end
    end
  end
end

local function instruction(s)
  if s.flash and GetGameTimer() < (s.flashUntil or 0) then return s.flash end
  local total = #s.steps + (s.confirm and 1 or 0)
  local step = s.steps[s.index]
  if not step then return format(s.labels.step, total, total, s.labels.confirm) end
  local text = step.text or step.id
  if ENTITY_KINDS[step.kind] and s.labels.rotate and s.labels.rotate ~= "" then
    text = ("%s · %s"):format(text, s.labels.rotate)
  end
  return format(s.labels.step, s.index, total, text)
end

--- The text line is re-sent when it changes and once a second: w.showTextUI drops a repeat of
--- the text it shows, and another resource hiding the line must not leave the admin blind
local function showText(s)
  local text = instruction(s)
  local now = GetGameTimer()
  if text ~= s.text or now >= (s.textAt or 0) then
    s.text, s.textAt = text, now + 1000
    pcall(function() w.showTextUI(text, { position = s.textPosition }) end)
  end
end

-- ---------------------------------------------------------------------------
-- the frame loop
-- ---------------------------------------------------------------------------

local function block(s)
  for i = 1, #BLOCKED do DisableControlAction(0, BLOCKED[i], true) end
  for i = 1, #s.controls do DisableControlAction(0, s.controls[i], true) end
  -- the game's own prompts (mount the ghost horse, open a door) would show under the cards
  Citizen.InvokeNative(DISABLE_NATIVE_PROMPTS)
end

--- Only one prompt group shows at a time, and another resource's walk-up prompt would take
--- the screen from ours: claiming distance 0 every frame wins every walk-up arbitration
--- (exports.w_lib:WalkupClaim). A group displaced anyway is displayed again.
local function keepGroup(s)
  pcall(function() exports.w_lib:WalkupClaim(0) end)
  local now = GetGameTimer()
  if now >= (s.groupAt or 0) then
    s.groupAt = now + 200
    local ok, visible = pcall(s.group.isVisible)
    if not ok or not visible then pcall(s.group.display) end
  end
end

local function loop(s)
  advance(s, 1, player())

  while not s.done and not s.cancelled do
    local p = player()
    local why = stopReason(p)
    if why then
      s.cancelled = why
      break
    end

    block(s)
    keepGroup(s)

    local step = s.steps[s.index]
    if step then
      if ENTITY_KINDS[step.kind] then
        if yes(IsDisabledControlJustPressed(0, WHEEL_NEXT)) then
          s.rotation = s.rotation + s.rotateStep
        elseif yes(IsDisabledControlJustPressed(0, WHEEL_PREV)) then
          s.rotation = s.rotation - s.rotateStep
        end
      end
      local pos, heading, bad = candidate(s, step, p)
      s.candidate, s.heading, s.bad = pos, heading, bad
      if s.ghost then
        moveGhost(s.ghost, step.kind, pos, heading)
        -- no spot here (a snap found none): the ghost is not shown hanging in the air
        local show = bad == nil
        if s.ghost.entity and s.ghost.shown ~= show and DoesEntityExist(s.ghost.entity) then
          SetEntityVisible(s.ghost.entity, show)
          s.ghost.shown = show
        end
      end
      drawStep(s, step, pos, tooFar(s, pos) or bad ~= nil, p)
    end

    drawResolved(s)
    showText(s)
    look(s, step)

    local key = table.remove(s.pressed, 1)
    if key and s.actions[key] then act(s, s.actions[key], p) end

    Wait(0)
  end
end

local function close(s)
  if s.closed then return end
  s.closed = true
  lookOff(s)
  dropGhost(s)
  for i, g in pairs(s.ghosts) do
    removeGhost(g)
    s.ghosts[i] = nil
  end
  if s.group then
    pcall(s.group.hide)
    pcall(s.group.delete)
    s.group = nil
  end
  pcall(function() exports.w_lib:WalkupRelease() end)
  if s.text then
    -- only our own line: another resource may have taken the text UI meanwhile
    local ok, open, current = pcall(function() return w.isTextUIOpen() end)
    if ok and (current == s.text or (current == nil and yes(open))) then
      pcall(function() w.hideTextUI() end)
    end
  end
  if session == s then session = nil end
end

--- Read the options into a session (nil when a step is malformed)
local function build(opts)
  local okKey, localeKey = pcall(function() return lib.getLocaleKey() end)
  local defaults = DEFAULT_LABELS[okKey and localeKey or "en"] or DEFAULT_LABELS.en

  local labels = {}
  for k, v in pairs(DEFAULT_LABELS.en) do labels[k] = defaults[k] or v end
  for k, v in pairs(type(opts.labels) == "table" and opts.labels or {}) do labels[k] = v end

  local keys, actions, controls = {}, {}, {}
  for action, default in pairs(DEFAULT_KEYS) do
    local key = tostring((type(opts.keys) == "table" and opts.keys[action]) or default):upper()
    keys[action] = key
    actions[key] = action
    if KEY_CONTROLS[key] then controls[#controls + 1] = KEY_CONTROLS[key] end
  end

  -- the caller's own cards: action 'extra<i>' (a key the editor already uses is left out)
  local extra = {}
  for i, e in ipairs(type(opts.extraKeys) == "table" and opts.extraKeys or {}) do
    local key = type(e) == "table" and tostring(e.key or ""):upper() or ""
    if key ~= "" and not actions[key] and type(e.press) == "function" then
      extra[#extra + 1] = { key = key, label = tostring(e.label or key), press = e.press }
      actions[key] = "extra" .. #extra
      if KEY_CONTROLS[key] then controls[#controls + 1] = KEY_CONTROLS[key] end
    end
  end

  local steps, byId = {}, {}
  for i, raw in ipairs(opts.steps) do
    if type(raw) ~= "table" or type(raw.id) ~= "string" or byId[raw.id] then return nil end
    local step = {}
    for k, v in pairs(raw) do step[k] = v end
    step.kind = step.kind or "point"
    if not KINDS[step.kind] then return nil end
    steps[i] = step
    byId[step.id] = i
  end

  return {
    steps = steps, byId = byId, keys = keys, actions = actions, controls = controls, labels = labels, extra = extra,
    maxDistance = tonumber(opts.maxDistance) or 60.0,
    aimDistance = tonumber(opts.aimDistance) or 12.0,
    rotateStep = tonumber(opts.rotateStep) or 5.0,
    fov = tonumber(opts.fov) or 42.0,
    confirm = opts.confirm ~= false,
    textPosition = opts.textPosition or "bottom-center",
    keyPosition = opts.keyPosition or "bottom-right",
    title = opts.title or false,
    cancelHold = tonumber(opts.cancelHold) or 1000,
    index = 1, outcomes = {}, ghosts = {}, history = {}, pressed = {},
    rotation = 0.0, entryHeading = 0.0, spawnToken = 0,
  }
end

local function openGroup(s)
  local K, L = s.keys, s.labels
  local group = w.prompt.createGroup(s.title, s.keyPosition)
  group.addPrompt(K.place, L.place, false)
  group.addPrompt(K.skip, L.skip, false)
  group.addPrompt(K.remove, L.remove, false)
  group.addPrompt(K.back, L.back, false)
  group.addPrompt(K.look, L.look, false)
  group.addPrompt(K.cancel, L.cancel, s.cancelHold)
  for _, e in ipairs(s.extra or {}) do group.addPrompt(e.key, e.label, false) end
  group.display()
  s.group = group
end

-- ---------------------------------------------------------------------------
-- public
-- ---------------------------------------------------------------------------

--- Can the local player start an editor now? false + 'dead' | 'mounted' | 'busy'
---@return boolean ok
---@return string? reason
function w.placer.canStart()
  if session then return false, "busy" end
  local why = stopReason(player())
  if why then return false, why end
  return true, nil
end

--- Run the editor (blocking; call from a thread). See the header for the options.
---@param opts table
---@return table? values nil when the admin left without saving
---@return string? reason
function w.placer.run(opts)
  if session then return nil, "busy" end
  if type(opts) ~= "table" or type(opts.steps) ~= "table" or #opts.steps == 0 then return nil, "invalid" end

  local s = build(opts)
  if not s then return nil, "invalid" end

  local ok, why = w.placer.canStart()
  if not ok then return nil, why end

  session = s
  local ran, err = pcall(function()
    openGroup(s)
    loop(s)
  end)

  local values = (ran and s.done and not s.cancelled) and merged(s) or nil
  local reason = s.cancelled or ((not ran) and "error") or nil
  close(s)
  if not ran then eprint(("w.placer: %s"):format(tostring(err))) end
  return values, reason
end

--- Leave the running editor without saving (its run() returns nil, 'cancelled')
function w.placer.cancel()
  if session then session.cancelled = session.cancelled or "cancelled" end
end

---@return boolean
function w.placer.isActive()
  return session ~= nil
end

-- the cards fire once per press through the library's completion event (polling IsCompleted
-- only answers in the very frame of the press); presses made in a menu or the pause map are dropped
AddEventHandler("w_lib:promptCompleted", function(groupId, key)
  local s = session
  if not s or not s.group or s.group.id ~= groupId then return end
  if yes(IsNuiFocused()) or yes(IsPauseMenuActive()) then return end
  s.pressed[#s.pressed + 1] = tostring(key):upper()
end)

-- the resource stopping mid-edit: no ghost, camera or card may outlive it
w.stopped(function()
  local s = session
  if not s then return end
  s.cancelled = "stopped"
  close(s)
end)
