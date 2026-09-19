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
---@field coords vector3        where in the world -- a head bone reads best
---@field title? string         the ped's name
---@field icon? string
---@field commands? string[]    the phrases it answers to
---@field says? string          what it is saying now -- replaces the phrases while set

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
--- Pass `coords` and the list is pinned beside that person, projected every frame like the
--- balloons. Leave them out and it sits in the corner named by `position`.
---@param data { title?: string, position?: string, coords?: vector3, groups?: { label?: string, commands: string[] }[] }|false
function lib.voicePanel(data)
    if type(data) == 'table' and data.coords then
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
                local onScreen, x, y = GetScreenCoordFromWorldCoord(hint.coords.x, hint.coords.y, hint.coords.z)

                -- ★ Off-screen bubbles are REMOVED, not moved to the edge. A hint pinned to the
                --   side of the screen for a ped behind you is noise pretending to be help.
                SendNUIMessage({
                    action = onScreen and 'voiceHint' or 'voiceHintRemove',
                    data = onScreen
                        and {
                            id = id, x = x, y = y,
                            title = hint.title, icon = hint.icon,
                            commands = hint.commands, says = hint.says,
                        }
                        or { id = id }
                })
            end

            -- ⚠️ The anchored panel rides the SAME thread as the balloons. A second one doing the
            --    same projection on the same frame would double the work to move one list.
            if panelAnchor then
                local onScreen, px, py =
                    GetScreenCoordFromWorldCoord(panelAnchor.coords.x, panelAnchor.coords.y, panelAnchor.coords.z)

                SendNUIMessage({
                    action = 'voicePanel',
                    data = onScreen and {
                        title = panelAnchor.title,
                        groups = panelAnchor.groups,
                        x = px, y = py,
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
    if type(hint) ~= 'table' or not hint.id or not hint.coords then
        error('lib.voiceHint needs an id and coords')
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
