w.createModule("gizmo")

w.require("nui")
w.require("prompt")

-- ★ The loader thread is gone with the frame: it printed four debug lines and loaded a
--   frame that no longer exists. The gizmo draws in the unified app, which the shell has up
--   from boot, so there is nothing left to wait for.
local NativeSendNUIMessage = SendNUIMessage
local clockStart = nil
local function SendNUIMessage(data)
    local currentTime = GetGameTimer()
    dprint("[GIZMO DEBUG] SendNUIMessage called at:", currentTime)
    dprint("[GIZMO DEBUG] clockStart:", clockStart or "undefined", "currentTime:", currentTime)
    if clockStart == GetGameTimer() then
        dprint("[GIZMO DEBUG] clockStart equals current time, waiting 100ms")
        Wait(100)
    end
    -- ★ 'wui' -- the one frame. This interface lives in the unified app now
    --   (w_lib/web/src/features), and its own frame under nui/ has been removed.
    data.messageTargetUiName = "wui"
    dprint("[GIZMO DEBUG] Sending NUI message:", json.encode(data))
    NativeSendNUIMessage(data)
    dprint("[GIZMO DEBUG] NUI message sent successfully")
end

-- =============================================================================
--
-- =============================================================================

local config = {
    enableCam = GetConvarBool("w_lib:gizmo:enableCam", true),                                           -- Enable/Disable camera feature
    maxDistance = GetConvarInt("w_lib:gizmo:maxDistance", 100),                                         -- Maximum distance entity can be moved from starting position (set to false to disable)
    maxCamDistance = GetConvarInt("w_lib:gizmo:maxCamDistance", 80),                                    -- Maximum distance camera can be moved from player
    minY = GetConvarInt("w_lib:gizmo:minY", -40),                                                       -- Minimum Y value for camera rotation
    maxY = GetConvarInt("w_lib:gizmo:maxY", 40),                                                        -- Maximum Y value for camera rotation
    movementSpeed = GetConvarFloat("w_lib:gizmo:movementSpeed", 0.1),                                   -- Default movement speed for camera
    maxMovementSpeed = GetConvarFloat("w_lib:gizmo:maxMovementSpeed", 0.2),                             -- Maximum movement speed for camera
    minMovementSpeed = GetConvarFloat("w_lib:gizmo:minMovementSpeed", 0.001),                           -- Minimum movement speed for camera
    movementSpeedIncrement = GetConvarFloat("w_lib:gizmo:movementSpeedIncrement", 0.01),                -- Increment value when adjusting camera speed
    allowTranslateX = GetConvarBool("w_lib:gizmo:allowTranslateX", true),                               -- Allow translation on X-axis
    allowTranslateY = GetConvarBool("w_lib:gizmo:allowTranslateY", true),                               -- Allow translation on Y-axis
    allowTranslateZ = GetConvarBool("w_lib:gizmo:allowTranslateZ", true),                               -- Allow translation on Z-axis
    allowRotateX = GetConvarBool("w_lib:gizmo:allowRotateX", true),                                     -- Allow rotation on X-axis
    allowRotateY = GetConvarBool("w_lib:gizmo:allowRotateY", true),                                     -- Allow rotation on Y-axis
    allowRotateZ = GetConvarBool("w_lib:gizmo:allowRotateZ", true),                                     -- Allow rotation on Z-axis
    allowSnapToGround = GetConvarBool("w_lib:gizmo:allowSnapToGround", true),                           -- Allow snapping to ground
    rotationSnap = GetConvarInt("w_lib:gizmo:rotationSnap", 5),                                         -- Rotation snap value
    keys = {
        moveX = GetConvarInt("w_lib:gizmo:keys:moveX", `INPUT_SCRIPTED_FLY_LR`),                        -- Move left/right
        moveY = GetConvarInt("w_lib:gizmo:keys:moveY", `INPUT_SCRIPTED_FLY_UD`),                        -- Move forward/backward
        moveUp = GetConvarInt("w_lib:gizmo:keys:moveUp", `INPUT_FRONTEND_X`),                           -- Move up
        moveDown = GetConvarInt("w_lib:gizmo:keys:moveDown", `INPUT_FRONTEND_RUP`),                     -- Move down
        cancel = GetConvarInt("w_lib:gizmo:keys:cancel", `INPUT_GAME_MENU_TAB_RIGHT_SECONDARY`),        -- Cancel operation
        switchMode = GetConvarInt("w_lib:gizmo:keys:switchMode", `INPUT_RELOAD`),                       -- Switch between translate/rotate modes
        snapToGround = GetConvarInt("w_lib:gizmo:keys:snapToGround", `INPUT_INTERACT_OPTION1`),         -- Snap entity to ground
        confirm = GetConvarInt("w_lib:gizmo:keys:confirm", `INPUT_FRONTEND_ACCEPT`),                    -- Confirm placement
        focusEntity = GetConvarInt("w_lib:gizmo:keys:focusEntity", `INPUT_SHOP_SPECIAL`),               -- Toggle focus on entity
        cameraSpeedUp = GetConvarInt("w_lib:gizmo:keys:cameraSpeedUp", `INPUT_SELECT_PREV_WEAPON`),     -- Increase camera speed
        cameraSpeedDown = GetConvarInt("w_lib:gizmo:keys:cameraSpeedDown", `INPUT_SELECT_NEXT_WEAPON`), -- Decrease camera speed
        rotationSnap = GetConvarInt("w_lib:gizmo:keys:rotationSnap", `INPUT_FRONTEND_Y`),               -- Rotation snap key
    },
    onlyOnMove = GetConvarBool("w_lib:gizmo:onlyOnMove", false)
}

-- =============================================================================
--
-- =============================================================================


local gizmoActive = false
local responseData = nil
local mode = "translate"
local cam = nil
local previousCam = -1
local enableCam = false
local maxDistance = 0
local maxCamDistance = 0
local minY = 0
local maxY = 0
local focusEntity = true
local movementSpeed = 0
local allowTranslateX = true
local allowTranslateY = true
local allowTranslateZ = true
local allowRotateX = true
local allowRotateY = true
local allowRotateZ = true
local allowSnapToGround = true
local stored = nil
local hookedFunc = nil
local target = 0
local needUpdateCamNUI = false
local onMove = nil
local groupName = "interaction_GizmoPrompts"
local rotationSnap = nil
local onlyOnMove = false

-- the key cards in the player's language (w_lib's locale, as the placer's): Arabic, else English
local LABELS = {
    en = { title = "Place it", move = "Move", rotate = "Rotate", cancel = "Cancel", confirm = "Confirm", toRotate = "Switch to rotate", toMove = "Switch to move",
        snap = "Snap to ground", finish = "Finish", freeCam = "Free camera", focus = "Look at the object",
        speed = "Camera speed: x%.3f", rotSnap = "Rotation snap (hold)", moveLR = "Camera left / right",
        moveFB = "Camera forward / back", moveUp = "Camera up", moveDown = "Camera down" },
    ar = { title = "ضعه", move = "تحريك", rotate = "تدوير", cancel = "إلغاء", confirm = "تأكيد", toRotate = "التبديل إلى التدوير", toMove = "التبديل إلى التحريك",
        snap = "إلصاق بالأرض", finish = "إنهاء", freeCam = "كاميرا حرة", focus = "النظر إلى الشيء",
        speed = "سرعة الكاميرا: x%.3f", rotSnap = "تدوير بخطوات (اضغط مطولاً)", moveLR = "الكاميرا يمين / يسار",
        moveFB = "الكاميرا أمام / خلف", moveUp = "الكاميرا للأعلى", moveDown = "الكاميرا للأسفل" },
}
-- (the owner 2026-11-10: Arabic players get Arabic on w_lib's own cards; every other language: the game's native
-- prompts, in English)
local function language()
    local okKey, k = pcall(function() return lib.getLocaleKey() end)
    return okKey and k or "en"
end
local function L(key)
    local set = LABELS[language()] or LABELS.en
    return set[key] or LABELS.en[key] or key
end

--- the texts of the buttons on the screen (features/gizmo/Toolbar)
local function uiLabels()
    return { move = L("move"), rotate = L("rotate"), confirm = L("confirm"), cancel = L("cancel") }
end

-- the buttons on the screen, clicked: { action = 'mode' (mode) | 'confirm' | 'cancel' | 'snap' | 'camera' }
local webActions = {}
RegisterNUICallback("gizmo:Action", function(data, cb)
    if gizmoActive and type(data) == "table" and type(data.action) == "string" then webActions[#webActions + 1] = data end
    cb({ status = "ok" })
end)

--- The gizmo's key cards: J keep, R move / turn, C camera, G ground, X leave -> { add, label, show, next, close }
---   Arabic   w_lib's own cards (its frame, its fonts): the game's prompts draw Arabic as white squares
---   other    the game's native prompts (English), each card on its gizmo key (config.keys)
local NATIVE = { J = "confirm", X = "cancel", R = "switchMode", C = "focusEntity", G = "snapToGround" }
local function makeCards(title)
    if language() == "ar" then
        local group = w.prompt.createGroup(title, "bottom-right")
        local pressed = {}
        local handler = AddEventHandler("w_lib:promptCompleted", function(id, key)
            if id == group.id then pressed[#pressed + 1] = tostring(key):upper() end
        end)
        return {
            add = function(k, label) group.addPrompt(k, label, false) end,
            label = function(k, label) pcall(group.setLabel, k, label) end,
            show = function() group.display() end,
            next = function()
                if not group.isVisible() then pcall(group.display) end
                return table.remove(pressed, 1)
            end,
            close = function()
                RemoveEventHandler(handler)
                pcall(group.hide)
                pcall(group.delete)
            end,
        }
    end
    local keys = {}
    return {
        add = function(k, label)
            local c = config.keys[NATIVE[k] or ""]
            if c then keys[#keys + 1] = { k = k, c = c } w.prompt.create(groupName, label, c) end
        end,
        label = function(k, label)
            local c = config.keys[NATIVE[k] or ""]
            if c then w.prompt.editKeyLabel(groupName, c, label) end
        end,
        show = function() end,
        next = function()
            for _, e in ipairs(keys) do
                if w.prompt.isCompleted(groupName, e.c) then return e.k end
            end
        end,
        close = function() w.prompt.deleteGroup(groupName) end,
    }
end

local function pointEntity()
    PointCamAtEntity(cam, target)
    needUpdateCamNUI = true
end

-- Initializes UI focus, camera, and other misc
-- @param bool boolean
local function showNUI(bool)
    dprint("[GIZMO DEBUG] showNUI called with bool:", bool, "at", GetGameTimer())
    if bool then
        dprint("[GIZMO DEBUG] Setting NUI focus to true")
        SetNuiFocus(true, true)
        -- the frame's clicks follow its focus (web/src/wc/sound.ts, 'wl:focus' - as lib.setNuiFocus tells it)
        NativeSendNUIMessage({ action = 'wl:focus', data = true, messageTargetUiName = 'wui' })
        dprint("[GIZMO DEBUG] NUI focus set, checking IsNuiFocused:", IsNuiFocused())
        SetNuiFocusKeepInput(true)
        dprint("[GIZMO DEBUG] NUI focus keep input set, IsNuiFocusKeepingInput:", IsNuiFocusKeepingInput())

        if enableCam then
            dprint("[GIZMO DEBUG] Setting up camera, enableCam:", enableCam)
            local currentCam = GetRenderingCam()
            previousCam = currentCam
            local coords, rot, fov
            if currentCam == -1 then
                coords = GetGameplayCamCoord()
                rot = GetGameplayCamRot(0)
                fov = GetGameplayCamFov()
            else
                coords = GetCamCoord(currentCam)
                rot = GetCamRot(currentCam, 0)
                fov = GetCamFov(currentCam)
            end
            dprint("[GIZMO DEBUG] Camera coords:", coords.x, coords.y, coords.z)
            dprint("[GIZMO DEBUG] Camera rotation:", rot.x, rot.y, rot.z)
            dprint("[GIZMO DEBUG] Camera FOV:", fov)

            cam = CreateCam("DEFAULT_SCRIPTED_CAMERA", false)
            dprint("[GIZMO DEBUG] Camera created, cam handle:", cam)

            SetCamCoord(cam, coords.x, coords.y, coords.z + 0.5)
            SetCamRot(cam, rot.x, rot.y, rot.z)
            SetCamFov(cam, fov)
            if currentCam == -1 then
                SetCamActive(cam, true)
                RenderScriptCams(true, true, 500, true, true)
            else
                SetCamActiveWithInterp(cam, currentCam, 500)
            end
            FreezeEntityPosition(PlayerPedId(), true)
            dprint("[GIZMO DEBUG] Camera setup complete, focusEntity:", focusEntity)
            if focusEntity then
                pointEntity()
            end
            needUpdateCamNUI = true
        else
            dprint("[GIZMO DEBUG] Camera disabled, enableCam:", enableCam)
        end

        SetCurrentPedWeapon(PlayerPedId(), GetHashKey("WEAPON_UNARMED"), true)
        dprint("[GIZMO DEBUG] NUI setup complete, weapon set to unarmed")
    else
        dprint("[GIZMO DEBUG] Disabling NUI, setting focus to false")
        SetNuiFocus(false, false)
        NativeSendNUIMessage({ action = 'wl:focus', data = false, messageTargetUiName = 'wui' })
        dprint("[GIZMO DEBUG] NUI focus disabled, IsNuiFocused:", IsNuiFocused())
        SetNuiFocusKeepInput(IsNuiFocusKeepingInput())
        dprint("[GIZMO DEBUG] NUI focus keep input reset")
        FreezeEntityPosition(PlayerPedId(), false)
        dprint("[GIZMO DEBUG] Player unfrozen")

        if cam then
            dprint("[GIZMO DEBUG] Cleaning up camera, cam handle:", cam)
            local closingCam = cam
            if previousCam == -1 then
                RenderScriptCams(false, true, 500, true, true)
            else
                SetCamActiveWithInterp(previousCam, closingCam, 500)
            end
            cam = nil
            CreateThread(function()
                Wait(500)
                if DoesCamExist(closingCam) then
                    SetCamActive(closingCam, false)
                    DetachCam(closingCam)
                    DestroyCam(closingCam, true)
                end
            end)
            dprint("[GIZMO DEBUG] Camera cleanup deferred and reset")
        else
            dprint("[GIZMO DEBUG] No camera to clean up")
        end

        stored = nil
        hookedFunc = nil

        SendNUIMessage({
            action = "SetupGizmo",
            data = {
                handle = nil,
            }
        })
    end

    gizmoActive = bool
    dprint("[GIZMO DEBUG] showNUI complete, gizmoActive:", gizmoActive)
end

-- Disables controls, Radar, and Player Firing
local function disableControls()
    -- dprint("[GIZMO DEBUG] disableControls: Disabling INPUT_ATTACK")
    DisableControlAction(0, `INPUT_ATTACK`, true)
end

-- Get the normal value of a control(s) used for movement & rotation
-- @param control number | table
-- @return number
local function getSmartControlNormal(control, control2)
    if control2 then
        local normal1 = GetDisabledControlNormal(0, control)
        local normal2 = GetDisabledControlNormal(0, control2)
        return normal1 - normal2
    end

    return GetDisabledControlNormal(0, control)
end

-- Handle camera rotations
local function rotations()
    if focusEntity then
        -- dprint("[GIZMO DEBUG] rotations: Skipping rotation, focusEntity is true")
        return
    end
    local newX
    local rAxisX = GetControlNormal(0, `INPUT_LOOK_LR`)
    local rAxisY = GetControlNormal(0, `INPUT_LOOK_UD`)

    if rAxisX ~= 0 or rAxisY ~= 0 then
        dprint("[GIZMO DEBUG] rotations: Mouse movement detected - X:", rAxisX, "Y:", rAxisY)
    end

    if rAxisX == 0 and rAxisY == 0 then
        -- dprint("[GIZMO DEBUG] rotations: No rotation input, returning")
        return
    end

    local rot = GetCamRot(cam, 0)

    local yValue = rAxisY * 5
    local newZ = rot.z + (rAxisX * -10)
    local newXval = rot.x - yValue

    if (newXval >= minY) and (newXval <= maxY) then
        newX = newXval
    end

    if newX and newZ then
        dprint("[GIZMO DEBUG] rotations: Setting camera rotation to:", newX, rot.y, newZ)
        SetCamRot(cam, vector3(newX, rot.y, newZ), 0)
        needUpdateCamNUI = true
    else
        dprint("[GIZMO DEBUG] rotations: Rotation blocked - newX:", newX, "newZ:", newZ)
    end
end

-- Handle camera movement
local function movement()
    local moveX = getSmartControlNormal(config.keys.moveX)                        -- Left & Right
    local moveY = getSmartControlNormal(config.keys.moveY)                        -- Forward & Backward
    local moveZ = getSmartControlNormal(config.keys.moveUp, config.keys.moveDown) -- Up & Down

    if moveX ~= 0 or moveY ~= 0 or moveZ ~= 0 then
        dprint("[GIZMO DEBUG] movement: Movement input detected - X:", moveX, "Y:", moveY, "Z:", moveZ)
    end

    if moveX == 0 and moveY == 0 and moveZ == 0 then
        -- dprint("[GIZMO DEBUG] movement: No movement input, returning")
        return
    end

    local x, y, z = table.unpack(GetCamCoord(cam))
    local rot = GetCamRot(cam, 0)

    local dx = math.sin(-rot.z * math.pi / 180) * movementSpeed
    local dy = math.cos(-rot.z * math.pi / 180) * movementSpeed

    local dx2 = math.sin(math.floor(rot.z + 90.0) % 360 * -1.0 * math.pi / 180) * movementSpeed
    local dy2 = math.cos(math.floor(rot.z + 90.0) % 360 * -1.0 * math.pi / 180) * movementSpeed

    if moveX ~= 0.0 then
        x -= dx2 * moveX
        y -= dy2 * moveX
    end

    if moveY ~= 0.0 then
        x -= dx * moveY
        y -= dy * moveY
    end

    if moveZ ~= 0.0 then
        z += moveZ * movementSpeed
    end

    local newPos = vec3(x, y, z)
    local playerPos = GetEntityCoords(PlayerPedId())
    local distance = #(playerPos - newPos)

    if distance <= maxCamDistance and (not hookedFunc or hookedFunc(newPos)) then
        dprint("[GIZMO DEBUG] movement: Moving camera to:", x, y, z, "Distance from player:", distance)
        SetCamCoord(cam, x, y, z)
        needUpdateCamNUI = true
    else
        dprint("[GIZMO DEBUG] movement: Camera movement blocked - Distance:", distance, "Max:", maxCamDistance, "HookFunc passed:", not hookedFunc or hookedFunc(newPos))
    end
end

-- Handle camera controls (movement & rotation)
local function camControls()
    rotations()
    movement()
end

local function updateCamNUI()
    if not needUpdateCamNUI then
        -- dprint("[GIZMO DEBUG] updateCamNUI: needUpdateCamNUI is false, skipping")
        return
    end
    if getSmartControlNormal(`INPUT_ATTACK`) > 0 then
        dprint("[GIZMO DEBUG] updateCamNUI: INPUT_ATTACK pressed, skipping camera update")
        return
    end

    local camPos = GetFinalRenderedCamCoord()
    local camRot = GetFinalRenderedCamRot(0)
    dprint("[GIZMO DEBUG] updateCamNUI: Updating camera position - Pos:", camPos.x, camPos.y, camPos.z, "Rot:", camRot.x, camRot.y, camRot.z)

    SendNUIMessage({
        action = "SetCameraPosition",
        data = {
            position = camPos,
            rotation = camRot
        }
    })
    needUpdateCamNUI = false
    dprint("[GIZMO DEBUG] updateCamNUI: Camera position message sent")
end

local function refreshSpeedPrompt()
    w.prompt.editKeyLabel(groupName, config.keys.cameraSpeedUp, L("speed"):format(movementSpeed))
end

--- Setup a gizmo interface to move an entity in 3D space
--- Allows for precise positioning and rotation of entities through a visual interface
--- Uses a camera system for better manipulation when enabled
---@param entity integer (The entity to move)
---@param cfg? table (Configuration options to override [defaults](#default-configuration))
--- cfg.enableCam boolean (Enable/disable camera feature - default based on config)
--- cfg.maxDistance number (Max distance the entity can be moved from starting position - default based on config)
--- cfg.maxCamDistance number (Max distance the camera can be moved from player - default based on config)
--- cfg.minY number (Min Y value from starting position for camera - default based on config)
--- cfg.maxY number (Max Y value from starting position for camera - default based on config)
--- cfg.movementSpeed number (Movement speed for camera - default based on config)
--- cfg.allowTranslateX boolean (Allow translation on X-axis - default `true`)
--- cfg.allowTranslateY boolean (Allow translation on Y-axis - default `true`)
--- cfg.allowTranslateZ boolean (Allow translation on Z-axis - default `true`)
--- cfg.allowRotateX boolean (Allow rotation on X-axis - default `true`)
--- cfg.allowRotateY boolean (Allow rotation on Y-axis - default `true`)
--- cfg.allowRotateZ boolean (Allow rotation on Z-axis - default `true`)
--- cfg.allowSnapToGround boolean (Allow snapping to ground - default `true`)
--- cfg.rotationSnap number (Rotation snap value - default `5`)
--- cfg.onMove function (Optional function fired when the entity move with the gizmo)
--- cfg.onlyOnMove boolean (Optional if onMove set the position or rotation will only be send to the function)
---@param allowPlace? function (Optional callback to validate placement - receives proposed position as parameter)
---@return table|nil (Returns entity position and rotation data when completed, nil if already active)
function w.gizmo.moveEntity(entity, cfg, allowPlace)
    dprint("[GIZMO DEBUG] *** w.gizmo.moveEntity called at:", GetGameTimer(), "***")
    dprint("[GIZMO DEBUG] Current gizmoActive state:", gizmoActive)

    if gizmoActive then return dprint("Gizmo is already started") end
    if not entity then
        dprint("[GIZMO DEBUG] ERROR: No entity provided")
        return
    end

    if gizmoActive then
        dprint("[GIZMO DEBUG] WARNING: gizmoActive was true, showing NUI false")
        showNUI(false)
    end

    target = entity
    dprint("[GIZMO DEBUG] Target entity set to:", target)

    enableCam = GetValue(cfg?.enableCam, config.enableCam)
    maxDistance = GetValue(cfg?.maxDistance, config.maxDistance)
    maxCamDistance = GetValue(cfg?.maxCamDistance, config.maxCamDistance)
    minY = GetValue(cfg?.minY, config.minY)
    maxY = GetValue(cfg?.maxY, config.maxY)
    movementSpeed = GetValue(cfg?.movementSpeed, config.movementSpeed)
    allowTranslateX = GetValue(cfg?.allowTranslateX, config.allowTranslateX)
    allowTranslateY = GetValue(cfg?.allowTranslateY, config.allowTranslateY)
    allowTranslateZ = GetValue(cfg?.allowTranslateZ, config.allowTranslateZ)
    allowRotateX = GetValue(cfg?.allowRotateX, config.allowRotateX)
    allowRotateY = GetValue(cfg?.allowRotateY, config.allowRotateY)
    allowRotateZ = GetValue(cfg?.allowRotateZ, config.allowRotateZ)
    allowSnapToGround = GetValue(cfg?.allowSnapToGround, config.allowSnapToGround)
    rotationSnap = GetValue(cfg?.rotationSnap, config.rotationSnap) * math.pi / 180
    mode = "translate"
    onMove = cfg?.onMove
    onlyOnMove = GetValue(cfg?.onlyOnMove, config.onlyOnMove)

    stored = {
        coords = GetEntityCoords(entity),
        rotation = GetEntityRotation(entity)
    }

    hookedFunc = allowPlace

    responseData = {}
    showNUI(true)
    DisplayHud(false)
    dprint("[GIZMO DEBUG] HUD disabled, waiting 500ms before sending initial message")

    Wait(500)
    dprint("[GIZMO DEBUG] Wait complete, current time:", GetGameTimer())

    dprint("[GIZMO DEBUG] About to send initial SetupGizmo message")
    dprint("[GIZMO DEBUG] Entity handle:", entity)
    dprint("[GIZMO DEBUG] Stored position:", json.encode(stored.coords))
    dprint("[GIZMO DEBUG] Stored rotation:", json.encode(stored.rotation))
    dprint("[GIZMO DEBUG] Initial gizmo mode:", mode)

    SendNUIMessage({
        action = "SetupGizmo",
        data = {
            handle = entity,
            position = stored.coords,
            rotation = stored.rotation,
            gizmoMode = mode,
            allowTranslateX = allowTranslateX,
            allowTranslateY = allowTranslateY,
            allowTranslateZ = allowTranslateZ,
            allowRotateX = allowRotateX,
            allowRotateY = allowRotateY,
            allowRotateZ = allowRotateZ,
            rotationSnap = rotationSnap,
            allowSnapToGround = allowSnapToGround,
            labels = uiLabels(),
        }
    })

    dprint("[GIZMO DEBUG] Initial SetupGizmo message sent")

    CreateThread(function()
        while gizmoActive do
            disableControls()
            if cam then
                camControls()
            end
            updateCamNUI()
            Wait(0)
        end
    end)


    -- ★ The key cards are w_lib's own (its frame and its fonts: Arabic shows), not the game's native prompts -- those
    --   drew Arabic as white squares. Their keys come back as w_lib:promptCompleted; the buttons on the screen
    --   (gizmo:Action, the mouse is free while the gizmo is open) do the same.
    local cards = makeCards(L("title"))
    cards.add("J", L("confirm"))
    cards.add("R", L("toRotate"))
    if cam then cards.add("C", L("freeCam")) end
    if allowSnapToGround then cards.add("G", L("snap")) end
    cards.add("X", L("cancel"))
    cards.show()
    webActions = {}
    -- turning goes in steps of rotationSnap degrees
    SendNUIMessage({ action = "EnableRotationSnap", data = true })

    local function setMode(m)
        if m ~= "translate" and m ~= "rotate" then return end
        mode = m
        SendNUIMessage({ action = "SetGizmoMode", data = mode })
        cards.label("R", mode == "translate" and L("toRotate") or L("toMove"))
    end
    local function on(v) return v == true or v == 1 end

    while gizmoActive do
        local key = cards.next()
        local act = table.remove(webActions, 1)
        local action = act and act.action

        if key == "R" then setMode(mode == "translate" and "rotate" or "translate") end
        if action == "mode" then setMode(act.mode) end

        if allowSnapToGround and (key == "G" or action == "snap") then
            PlaceObjectOnGroundProperly(entity)
            local newPos = GetEntityCoords(entity)
            local newRot = GetEntityRotation(entity)
            if onMove then onMove(newPos, newRot) end
            SendNUIMessage({
                action = "SetupGizmo",
                data = {
                    handle = entity,
                    position = newPos,
                    rotation = newRot,
                    gizmoMode = mode,
                    allowTranslateX = allowTranslateX,
                    allowTranslateY = allowTranslateY,
                    allowTranslateZ = allowTranslateZ,
                    allowRotateX = allowRotateX,
                    allowRotateY = allowRotateY,
                    allowRotateZ = allowRotateZ,
                    rotationSnap = rotationSnap,
                    allowSnapToGround = allowSnapToGround,
                    labels = uiLabels(),
                }
            })
        end

        -- the camera's speed: the mouse wheel
        if on(IsControlJustPressed(0, config.keys.cameraSpeedUp)) then
            movementSpeed = math.min(config.maxMovementSpeed, movementSpeed + config.movementSpeedIncrement)
        end
        if on(IsControlJustPressed(0, config.keys.cameraSpeedDown)) then
            movementSpeed = math.max(config.minMovementSpeed, movementSpeed - config.movementSpeedIncrement)
        end

        if cam and (key == "C" or action == "camera") then
            focusEntity = not focusEntity
            cards.label("C", focusEntity and L("freeCam") or L("focus"))
            if focusEntity then
                pointEntity()
            else
                StopCamPointing(cam)
            end
            Wait(10) --fix the refresh of the gizmo
            needUpdateCamNUI = true
        end

        if key == "J" or action == "confirm" then
            local coords = GetEntityCoords(entity)
            responseData = {
                entity = entity,
                coords = coords,
                position = coords, -- Alias
                rotation = GetEntityRotation(entity)
            }

            if cfg?.onBeforeClose then
                local closeCam = cfg.onBeforeClose(responseData, cam, previousCam)
                if closeCam then
                    previousCam = closeCam
                end
            end

            showNUI(false)
            break
        end

        if key == "X" or action == "cancel" then
            responseData = {
                canceled = true,
                entity = entity,
                coords = stored.coords,
                position = stored.coords, -- Alias
                rotation = stored.rotation
            }

            SetEntityCoordsNoOffset(entity, stored.coords.x, stored.coords.y, stored.coords.z, true, true, true)
            SetEntityRotation(entity, stored.rotation.x, stored.rotation.y, stored.rotation.z)

            showNUI(false)
            break
        end

        Wait(0)
    end

    cards.close()
    webActions = {}
    DisplayHud(true)
    dprint("[GIZMO DEBUG] Cleanup complete, returning response data:", json.encode(responseData))

    return responseData
end

--- Cancels the currently active gizmo interface
function w.gizmo.cancel()
    showNUI(false)
end

-- Register NUI Callback for updating entity position and rotation
-- @param data table
-- @param cb function
RegisterNUICallback("gizmo:UpdateEntity", function(data, cb)
    dprint("[GIZMO DEBUG] *** NUI CALLBACK RECEIVED *** at", GetGameTimer())
    dprint("[GIZMO DEBUG] Callback data received:", json.encode(data))

    local entity = data.handle
    local position = vec3(data.position.x, data.position.y, data.position.z)
    local rotation = vec3(data.rotation.x, data.rotation.y, data.rotation.z)

    dprint("[GIZMO DEBUG] Entity handle:", entity)
    dprint("[GIZMO DEBUG] Position:", position and json.encode(position) or "nil")
    dprint("[GIZMO DEBUG] Rotation:", rotation and json.encode(rotation) or "nil")
    dprint("[GIZMO DEBUG] Stored coords:", stored and json.encode(stored.coords) or "nil")
    dprint("[GIZMO DEBUG] MaxDistance:", maxDistance)
    dprint("[GIZMO DEBUG] HookedFunc exists:", hookedFunc ~= nil)

    if (maxDistance and #(position - stored.coords) <= maxDistance) and (not hookedFunc or hookedFunc(position)) then
        if (not onlyOnMove and onMove) or not onMove then
            dprint("[GIZMO DEBUG] Position validation passed, updating entity")
            SetEntityCoordsNoOffset(entity, position.x, position.y, position.z)
            SetEntityRotation(entity, rotation.x, rotation.y, rotation.z)
            dprint("[GIZMO DEBUG] Entity updated successfully")
        else
            dprint("[GIZMO DEBUG] onlyOnMove configuration passed, updating onMove")
        end
        needUpdateCamNUI = true
        if onMove then
            onMove(position, rotation)
        end
        return cb({ status = "ok" })
    end

    dprint("[GIZMO DEBUG] Position validation failed, reverting to entity position")
    position = GetEntityCoords(entity)
    rotation = GetEntityRotation(entity)

    local response = {
        status = "Distance is too far",
        position = position,
        rotation = rotation
    }
    dprint("[GIZMO DEBUG] Sending error response:", json.encode(response))
    cb(response)
end)

--- If DevMode is enabled, register a command to spawn a crate for testing
if w.debug then
    local tempEntity = nil
    RegisterCommand("gizmo", function()
        RequestModel("p_crate14x")

        while not HasModelLoaded("p_crate14x") do
            Wait(100)
        end

        local ped = PlayerPedId()
        local offset = GetOffsetFromEntityInWorldCoords(ped, 0., 3., 0.)
        tempEntity = CreateObject(joaat("p_crate14x"), offset.x, offset.y, offset.z, true, true, true)

        while not DoesEntityExist(tempEntity) do
            Wait(100)
        end

        local data = w.gizmo.moveEntity(tempEntity, {
            enableCam = true
        })

        dprint(json.encode(data, { indent = true }))

        if tempEntity then
            DeleteEntity(tempEntity)
            tempEntity = nil
        end
    end, true)

    w.stopped(function()
        if tempEntity then
            DeleteEntity(tempEntity)
            tempEntity = nil
        end
    end)
end

w.stopped(function()
    if gizmoActive then
        showNUI(false)
    end
end)
