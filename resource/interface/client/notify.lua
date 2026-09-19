--[[
    https://github.com/overextended/ox_lib

    This file is licensed under LGPL-3.0 or higher <https://www.gnu.org/licenses/lgpl-3.0.en.html>

    Copyright © 2025 Linden <https://github.com/thelindat>
]]

---@alias NotificationPosition 'top' | 'top-right' | 'top-left' | 'bottom' | 'bottom-right' | 'bottom-left' | 'center-right' | 'center-left'
---@alias NotificationType 'info' | 'warning' | 'success' | 'error'
---@alias IconAnimationType 'spin' | 'spinPulse' | 'spinReverse' | 'pulse' | 'beat' | 'fade' | 'beatFade' | 'bounce' | 'shake'

---@class NotifyProps
---@field id? string
---@field title? string
---@field description? string
---@field duration? number
---@field showDuration? boolean
---@field position? NotificationPosition
---@field type? NotificationType
---@field style? { [string]: any }
---@field icon? string | { [1]: IconProp, [2]: string }
---@field iconAnimation? IconAnimationType
---@field iconColor? string
---@field alignIcon? 'top' | 'center'
---@field sound? { bank?: string, set: string, name: string }

local settings = require 'resource.settings'

---`client`
---@param data NotifyProps
---@diagnostic disable-next-line: duplicate-set-field
function lib.notify(data)
    -- تسامح: بعض الموارد تمرّر نصّاً بدل جدول → نلفّه (يتفادى: bad argument to 'clone')
    if type(data) == 'string' then data = { description = data } end
    if type(data) ~= 'table' then return end

    -- ★ One renderer for the whole server: the RDR-style notice of resource/wnotify, at the
    --   right-centre. The React toast this used to draw was a second look for the same news.
    local sound = settings.notification_audio and data.sound
    exports.w_lib:NotifyStyled(data.title, data.description, data.type, data.duration)

    if not sound or not sound.name then return end
    -- RDR3: PLAY_SOUND_FRONTEND(audioName, audioRef, p2, p3) -- no sound id as in GTA V
    if sound.bank then lib.requestAudioBank(sound.bank) end
    PlaySoundFrontend(sound.name, sound.set or '', true, 0)
    if sound.bank then ReleaseNamedScriptAudioBank(sound.bank) end
end

---@class DefaultNotifyProps
---@field title? string
---@field description? string
---@field duration? number
---@field position? NotificationPosition
---@field status? 'info' | 'warning' | 'success' | 'error'
---@field id? number

---@param data DefaultNotifyProps
function lib.defaultNotify(data)
    -- Backwards compat for v3
    data.type = data.status
    if data.type == 'inform' then data.type = 'info' end
    return lib.notify(data --[[@as NotifyProps]])
end

-- w_lib:notify is answered in resource/wui/client.lua (title, message, style, duration); a second
-- handler here drew every server notice twice.
RegisterNetEvent('w_lib:defaultNotify', lib.defaultNotify)
