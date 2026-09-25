--[[
    واجهة التفاعل الصوتيّ — الرسم فقط

    ★ THE SPLIT: this draws a voice system, it does not run one. Matching what a player said to a
      command needs speech recognition, a language model, a list of phrases -- all of which
      belong to the script. What belongs here is the three things such a system must put on
      screen: what an NPC will answer to, that the game is listening, and what it heard.

    ⚠️ The bubbles are projected HERE, not in the frame. GetScreenCoordFromWorldCoord needs the
       camera, and the camera lives in the game -- the NUI has no idea where anything is. This
       is the same arrangement DrawText3D in resource/wnotify uses, and for the same reason.
]]

local hints = {}
local panelAnchor = nil
local ticking = false

-- ⚠️ FORWARD DECLARED, and it has to be. lib.voicePanel calls ensureThread, and in Lua a
--    `local function` declared further down is a DIFFERENT local that the earlier function
--    cannot see -- the name would resolve as a global, arrive as nil, and the call would fail
--    at runtime with no hint as to why. Declaring the local first is what puts them in the same
--    scope. A syntax check does not catch this; only running it does.
local ensureThread

---@class VoiceHint
---@field id string
---@field coords? vector3       where in the world -- a head bone reads best
---@field entity? number        optional: follow this entity instead (a ped's head bone, re-read every frame)
---@field bone? number          optional: the bone to follow on `entity`; SKEL_HEAD (21030) by default
---@field title? string         the ped's name
---@field icon? string          accepted, not drawn -- the dialogue card carries no emblem
---@field commands? string[]    the phrases it answers to
---@field says? string          what it is saying now -- shown under the name while set
---@field minimal? boolean      true: one bare line above the head ("Talk to <name>" + the key), no card
---@field talkKey? string       the push-to-talk key, drawn as a small cap on the minimal line
---@field name? string          the person alone, without the verb -- styled apart inside `title`

--- SKEL_HEAD. The card is placed beside this point, so it follows a ped that ducks or leans.
local HEAD_BONE = 21030

--- ★ Where an anchor is THIS frame: the entity's bone when one was given and still exists, else
---   the fixed coords. A person who walks off mid-conversation takes their card with them.
---@return vector3|nil
local function anchorPoint(anchor)
    local entity = anchor.entity

    if entity and DoesEntityExist(entity) then
        if IsEntityAPed(entity) then
            return GetPedBoneCoords(entity, anchor.bone or HEAD_BONE, 0.0, 0.0, 0.0)
        end

        return GetEntityCoords(entity)
    end

    return anchor.coords
end

--- ★ Metres from the camera, sent as `d`. The frame sizes the gap between the head and the card
---   from it, so a close face is cleared and a far one's card does not drift off into the air.
---
--- ⚠️ Component arithmetic, not `#(cam - point)`. `coords` may arrive as a plain {x, y, z} table
---    from a consumer, and vector3 minus a table throws -- inside the ONE projection thread, which
---    would die with `ticking` still true and freeze every card until the resource restarts.
local function cameraDistance(point)
    local cam = GetFinalRenderedCamCoord and GetFinalRenderedCamCoord() or GetGameplayCamCoord()
    local x, y, z = tonumber(point and point.x), tonumber(point and point.y), tonumber(point and point.z)
    if not (cam and x and y and z) then return nil end

    local dx, dy, dz = cam.x - x, cam.y - y, cam.z - z
    return math.sqrt(dx * dx + dy * dy + dz * dz)
end

---@class VoiceSubtitle
---@field text string
---@field state? 'listening'|'matched'|'unknown'
---@field speaker? string
---@field duration? number      milliseconds; defaults to 4000
---@field hold? boolean         true keeps it until replaced

--- ⚠️ `action`, not `type`. This library carries two NUI contracts: useNuiEvent keys on
---    `action` (the menus, the notices, this), and useNuiType keys on `type` (the prompt, the
---    minigames, the gizmo). Sending the wrong one is not an error -- the message simply
---    arrives and nothing is listening for it.

--- تشغيل/إيقاف مؤشّر الميكروفون
---@param active boolean
--- ★ `level` رقم واحد، و`levels` طيف كامل
---
--- Pass a number for a simple loudness meter, or an array of band values for a real spectrum --
--- a script with an analyser node can hand its bins straight over. `levels` wins when both are
--- given, so adding an analyser later needs no change here.
---@param active boolean
---@param level? number|number[]  0-100, or one value per band
---@param label? string
function lib.voiceListening(active, level, label)
    local single = type(level) == 'number' and level or nil
    local bands = type(level) == 'table' and level or nil

    SendNUIMessage({
        action = 'voiceListening',
        data = active and { active = true, level = single or 0, levels = bands, label = label } or false
    })
end

--- ★ الأوامر المتاحة الآن — النصف ثنائيّ الأبعاد من طبقة التلميحات
---
--- Group the phrases by whatever the script groups them by: a layer, an NPC, a shop. The panel
--- does not know what a layer is and should not -- it draws groups of phrases.
--- ★ مربوطة بشخص، أو في زاوية الشاشة
---
--- Pass `coords` (or `entity`) and the list is pinned beside that person, projected every frame
--- like the balloons -- and when a hint for the same person is up, the two are drawn as ONE card.
--- Leave them out and it sits in the corner named by `position`.
---
--- ★ Optional, all passed through to the frame: `speaker` (the name, when no hint carries one),
---   `talkKey` (the push-to-talk key, drawn once as a key cap) and `id` (the hint this list
---   belongs to -- without it the frame pairs them by position, which is exact for one head).
---@param data { title?: string, position?: string, coords?: vector3, entity?: number, bone?: number, speaker?: string, talkKey?: string, id?: string, groups?: { label?: string, commands: string[] }[] }|false
function lib.voicePanel(data)
    if type(data) == 'table' and (data.coords or data.entity) then
        panelAnchor = data
        ensureThread()
        return
    end

    panelAnchor = nil
    SendNUIMessage({ action = 'voicePanel', data = data or false })
end

--- سطر ما قيل
---@param data VoiceSubtitle|false
function lib.voiceSubtitle(data)
    SendNUIMessage({ action = 'voiceSubtitle', data = data or false })
end

--- ⚠️ ONE thread for every bubble, started when the first appears and stopped when the last one
---    goes. A thread per hint would put four of them on the same frame doing the same projection
---    work, and none of them would know when to stop.
function ensureThread()
    if ticking then return end
    ticking = true

    CreateThread(function()
        while next(hints) or panelAnchor do
            for id, hint in pairs(hints) do
                local point = anchorPoint(hint)
                local onScreen, x, y = false, 0, 0
                if point then onScreen, x, y = GetScreenCoordFromWorldCoord(point.x, point.y, point.z) end

                -- ★ Off-screen bubbles are REMOVED, not moved to the edge. A hint pinned to the
                --   side of the screen for a ped behind you is noise pretending to be help.
                -- ⚠️ Every field the frame draws has to be copied here by name: this table is
                --    rebuilt each frame, and a field left out never reaches the frame at all.
                --    `minimal`, `talkKey` and `name` were sent by w_voiceintract and dropped
                --    here, so the frame could only ever draw its prompt as a full card.
                SendNUIMessage({
                    action = onScreen and 'voiceHint' or 'voiceHintRemove',
                    data = onScreen
                        and {
                            id = id, x = x, y = y, d = cameraDistance(point),
                            title = hint.title, icon = hint.icon,
                            commands = hint.commands, says = hint.says,
                            minimal = hint.minimal == true or nil,
                            talkKey = hint.talkKey, name = hint.name,
                        }
                        or { id = id }
                })
            end

            -- ⚠️ The anchored panel rides the SAME thread as the balloons. A second one doing the
            --    same projection on the same frame would double the work to move one list.
            if panelAnchor then
                local point = anchorPoint(panelAnchor)
                local onScreen, px, py = false, 0, 0
                if point then onScreen, px, py = GetScreenCoordFromWorldCoord(point.x, point.y, point.z) end

                SendNUIMessage({
                    action = 'voicePanel',
                    data = onScreen and {
                        title = panelAnchor.title,
                        groups = panelAnchor.groups,
                        x = px, y = py, d = cameraDistance(point),
                        speaker = panelAnchor.speaker,
                        talkKey = panelAnchor.talkKey,
                        id = panelAnchor.id,
                    } or false
                })
            end

            Wait(0)
        end

        ticking = false
    end)
end

--- إظهار ما يستجيب له هذا الشخص
---@param hint VoiceHint
function lib.voiceHint(hint)
    if type(hint) ~= 'table' or not hint.id or not (hint.coords or hint.entity) then
        error('lib.voiceHint needs an id and coords (or an entity)')
    end

    hints[hint.id] = hint
    ensureThread()
end

--- إخفاء واحدة، أو كلّها بلا معرّف
---@param id? string
function lib.hideVoiceHint(id)
    if id then
        hints[id] = nil
    else
        table.wipe(hints)
    end

    SendNUIMessage({ action = 'voiceHintRemove', data = { id = id } })
end

--- إخفاء كل شيء دفعة واحدة
function lib.hideVoice()
    lib.hideVoiceHint()
    panelAnchor = nil
    lib.voicePanel(false)
    lib.voiceListening(false)
    lib.voiceSubtitle(false)
end
