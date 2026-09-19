w.createModule("camera")

w.require("prompt")
w.require("math")

local keys = {
  moveX = GetConvar("w_lib:camera:keys:moveX", "INPUT_SCRIPTED_FLY_LR"),            -- A/D keys
  moveY = GetConvar("w_lib:camera:keys:moveY", "INPUT_SCRIPTED_FLY_UD"),            -- W/S keys
  moveUp = GetConvar("w_lib:camera:keys:moveUp", "INPUT_SCRIPTED_FLY_ZUP"),         -- Square/X button (keyboard: SPACE) - Context-aware (Move Up / Play-Pause)
  moveDown = GetConvar("w_lib:camera:keys:moveDown", "INPUT_SCRIPTED_FLY_ZDOWN"),   -- Right stick up (keyboard: F)
  speedUp = GetConvar("w_lib:camera:keys:speedUp", "INPUT_SELECT_PREV_WEAPON"),     -- Scroll up
  speedDown = GetConvar("w_lib:camera:keys:speedDown", "INPUT_SELECT_NEXT_WEAPON"), -- Scroll down
  exit = GetConvar("w_lib:camera:keys:exit", "INPUT_QUIT")
}
for k, v in pairs(keys) do
  keys[k] = GetHashFromString(v)
end

local strings = {
  move = GetConvar("w_lib:camera:strings:move", "Move"),
  moveUpDown = GetConvar("w_lib:camera:strings:moveUpDown", "Move Up/Down"),
  exit = GetConvar("w_lib:camera:strings:exit", "Exit"),
  speed = GetConvar("w_lib:camera:strings:speed", "Speed %.2f")
}

local cameraConfig = {
  movement = {
    baseSpeed = GetConvarFloat("w_lib:camera:movement:speed", 0.05),
    maxSpeed = GetConvarFloat("w_lib:camera:movement:maxSpeed", 0.5),
    minSpeed = GetConvarFloat("w_lib:camera:movement:minSpeed", 0.01),
    speedIncrement = GetConvarFloat("w_lib:camera:movement:speedIncrement", 0.05)
  },

  -- Rotation settings
  rotation = {
    baseSpeed = GetConvarFloat("w_lib:camera:rotation:speed", 5.0),
    minY = GetConvarFloat("w_lib:camera:rotation:minY", -80.0),
    maxY = GetConvarFloat("w_lib:camera:rotation:maxY", 80.0)
  }
}

local promptGroup = "interaction_freecam"
local previousCamera = -1
local freeCamera = -1
local previousCoords = vec3(0, 0, 0)
local previousRot = vec3(0, 0, 0)
local previousFov = 0
local currentSpeed = cameraConfig.movement.baseSpeed
local currentRotationSpeed = cameraConfig.rotation.baseSpeed
local canRotate = true
local freecamOptions = {}

-------------
-- FREECAM
-------------
w.camera.freeCamera = {}

--Internal functions

local function createCamera()
  previousCamera = GetRenderingCam()
  freeCamera = CreateCam("DEFAULT_SCRIPTED_CAMERA", false)
  AllowMotionBlurDecay(freeCamera, true)
  if previousCamera ~= -1 then
    previousCoords = GetCamCoord(previousCamera)
    previousRot = GetCamRot(previousCamera, 0)
    previousFov = GetCamFov(previousCamera)
    SetCamCoord(freeCamera, previousCoords.x, previousCoords.y, previousCoords.z)
    SetCamRot(freeCamera, previousRot.x, previousRot.y, previousRot.z)
    SetCamFov(freeCamera, previousFov)
    SetCamActiveWithInterp(previousCamera, freeCamera, freecamOptions.interpolate, true, true)
  else
    previousCoords = GetGameplayCamCoord()
    previousRot = GetGameplayCamRot()
    previousFov = GetGameplayCamFov()
    SetCamCoord(freeCamera, previousCoords.x, previousCoords.y, previousCoords.z)
    SetCamRot(freeCamera, previousRot.x, previousRot.y, previousRot.z)
    SetCamFov(freeCamera, previousFov)
    SetCamActive(freeCamera, true)
    RenderScriptCams(true, true, freecamOptions.interpolate, true, true)
  end
end

local function handleRotation()
  if w.camera.freeCamera.isLocked() then return end
  local rotationInput = {
    x = GetDisabledControlNormal(0, `INPUT_LOOK_LR`),
    y = GetDisabledControlNormal(0, `INPUT_LOOK_UD`)
  }
  if rotationInput.x == 0 and rotationInput.y == 0 then return end

  local rotation = GetCamRot(freeCamera, 0)
  if not rotation then return end

  local yValue = rotationInput.y * currentRotationSpeed
  local newZ = rotation.z + (rotationInput.x * -currentRotationSpeed * 2)
  local newX = rotation.x - yValue

  -- Clamp Y rotation
  newX = math.clamp(newX, cameraConfig.rotation.minY, cameraConfig.rotation.maxY)

  SetCamRot(freeCamera, newX, rotation.y, newZ, 0)
end

local function getSmartControlNormal(control, control2)
  if control2 then
    local normal1 = GetDisabledControlNormal(0, control)
    local normal2 = GetDisabledControlNormal(0, control2)
    return normal1 - normal2
  end
  return GetDisabledControlNormal(0, control)
end

local function handleMovement()
  local movementInput = {
    x = getSmartControlNormal(keys.moveX),
    y = getSmartControlNormal(keys.moveY),
    z = getSmartControlNormal(keys.moveUp, keys.moveDown)
  }
  if movementInput.x == 0 and movementInput.y == 0 and movementInput.z == 0 then return end

  local coords = GetCamCoord(freeCamera)
  local rotation = GetCamRot(freeCamera, 0)
  if not coords or not rotation then return end

  local speed = currentSpeed

  -- Calculate forward/backward movement
  local dx = math.sin(-rotation.z * math.pi / 180) * speed
  local dy = math.cos(-rotation.z * math.pi / 180) * speed

  -- Calculate left/right movement
  local rightAngle = (rotation.z + 90.0) % 360
  local dx2 = math.sin(-rightAngle * math.pi / 180) * speed
  local dy2 = math.cos(-rightAngle * math.pi / 180) * speed

  local newX = coords.x
  local newY = coords.y
  local newZ = coords.z

  -- Apply movement
  if movementInput.x ~= 0.0 then
    newX = newX - dx2 * movementInput.x
    newY = newY - dy2 * movementInput.x
  end

  if movementInput.y ~= 0.0 then
    newX = newX - dx * movementInput.y
    newY = newY - dy * movementInput.y
  end

  if movementInput.z ~= 0.0 then
    newZ = newZ + movementInput.z * speed
  end

  if (#(previousCoords - vec3(newX, newY, newZ)) > freecamOptions.range) then
    return
  end

  SetCamCoord(freeCamera, newX, newY, newZ)
end

local function handleSpeedControls()
  local coef = 0
  if IsDisabledControlJustPressed(0, keys.speedUp) then
    coef = 1
  elseif IsDisabledControlJustPressed(0, keys.speedDown) then
    coef = -1
  end
  if coef ~= 0 then
    local newSpeed = math.clamp(cameraConfig.movement.minSpeed, currentSpeed + cameraConfig.movement.speedIncrement * coef, cameraConfig.movement.maxSpeed)
    if newSpeed ~= currentSpeed then
      currentSpeed = newSpeed
      return true
    end
  end
  return false
end

--- A function to stop the free camera
function w.camera.freeCamera.stop()
  if not w.camera.freeCamera.isActive() then return end


  if freecamOptions.showPrompts then
    w.prompt.deleteGroup(promptGroup)
    freecamOptions.showPrompts = false
  end

  if previousCamera == -1 then
    SetCamActive(freeCamera, false)
    RenderScriptCams(false, true, freecamOptions.interpolate, true, true)
  else
    SetCamActive(previousCamera, true)
    SetCamCoord(previousCamera, previousCoords.x, previousCoords.y, previousCoords.z)
    SetCamRot(previousCamera, previousRot.x, previousRot.y, previousRot.z)
    SetCamFov(previousCamera, previousFov)
    SetCamActiveWithInterp(previousCamera, freeCamera, freecamOptions.interpolate, true, true)
  end
  DestroyCam(freeCamera)
  freeCamera = -1
end

--- A function to lock the freecam rotation
function w.camera.freeCamera.lockRotate()
  canRotate = false
end

--- A function to unlock the freecam rotation
function w.camera.freeCamera.unlockRotate()
  canRotate = true
end

--- A function to get the freecam camera
---@return integer (The camera id)
function w.camera.freeCamera.getCam()
  return freeCamera
end

--- A function to get the freecam prompt group
---@return string (The prompt group name)
function w.camera.freeCamera.getPromptGroup()
  return promptGroup
end

--- A function to check if the freecam is active
---@return boolean (Whether the freecam is active)
function w.camera.freeCamera.isActive()
  return freeCamera ~= -1
end

--- A function to check if the freecam rotation is locked
---@return boolean (Whether the freecam rotation is locked)
function w.camera.freeCamera.isLocked()
  return not canRotate
end

--- A function to start the freecam
---@param options? table (The freecam option options)
--- options.interpolate number (The interpolate time - default `0`)
--- options.showPrompts boolean (Whether to show prompts - default `true`)
--- options.range number (The range of the freecam - default `10000`)
---@alias w.camera.freeCamera function
function w.camera.freeCamera.start(options)
  if w.camera.freeCamera.isActive() then return end
  freecamOptions.interpolate = GetValue(options?.interpolate, 0)
  freecamOptions.showPrompts = GetValue(options?.showPrompts, true)
  freecamOptions.range = GetValue(options?.range, 10000)

  if freecamOptions.showPrompts then
    w.prompt.create(promptGroup, strings.speed:format(currentSpeed), { keys.speedUp, keys.speedDown })
    w.prompt.create(promptGroup, strings.moveUpDown, { keys.moveDown, keys.moveUp })
    w.prompt.create(promptGroup, strings.move, { keys.moveX, keys.moveY })
    w.prompt.create(promptGroup, strings.exit, { keys.exit })
  end

  createCamera()

  while true do
    Wait(0)
    handleMovement()
    handleRotation()
    if handleSpeedControls() then
      w.prompt.editKeyLabel(promptGroup, keys.speedUp, strings.speed:format(currentSpeed))
    end
    if IsControlJustPressed(0, keys.exit) then
      break
    end
  end

  if freecamOptions.showPrompts then
    w.prompt.deleteGroup(promptGroup)
  end
  w.camera.freeCamera.stop()
end

w.camera.freeCamera = setmetatable(
  w.camera.freeCamera,
  {
    __call = function(_, ...)
      return w.camera.freeCamera.start(...)
    end
  }
)

--Alias
w.cam = w.camera
w.freecam = w.camera.freeCamera

w.stopped(function()
  w.camera.freeCamera.stop()
end)
