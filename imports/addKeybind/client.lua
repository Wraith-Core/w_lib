--[[
    https://github.com/overextended/ox_lib

    This file is licensed under LGPL-3.0 or higher <https://www.gnu.org/licenses/lgpl-3.0.en.html>

    Copyright © 2025 Linden <https://github.com/thelindat>
]]

-- RedM DOES expose RegisterKeyMapping (0xD7664FD1 is in rdr3_universal natives), so keybinds
-- work here just as they do in FiveM. The one native RDR3 lacks is GET_CONTROL_INSTRUCTIONAL_BUTTON,
-- which only affects reading a binding back -- see getCurrentKey below.

---@class KeybindProps
---@field name string
---@field description string
---@field defaultMapper? string (see: https://docs.fivem.net/docs/game-references/input-mapper-parameter-ids/)
---@field defaultKey? string
---@field disabled? boolean
---@field disable? fun(self: CKeybind, toggle: boolean)
---@field onPressed? fun(self: CKeybind)
---@field onReleased? fun(self: CKeybind)
---@field [string] any

---@class CKeybind : KeybindProps
---@field currentKey string
---@field disabled boolean
---@field isPressed boolean
---@field hash number
---@field getCurrentKey fun(): string
---@field isControlPressed fun(): boolean

local keybinds = {}

local IsPauseMenuActive = IsPauseMenuActive
local GetControlInstructionalButton = GetControlInstructionalButton

local keybind_mt = {
    disabled = false,
    isPressed = false,
    defaultKey = '',
    defaultMapper = 'keyboard',
}

function keybind_mt:__index(index)
    return index == 'currentKey' and self:getCurrentKey() or keybind_mt[index]
end

function keybind_mt:getCurrentKey()
    -- RDR3 has no GET_CONTROL_INSTRUCTIONAL_BUTTON, so a RedM client cannot be asked what the
    -- player actually rebound this to. Report the default we requested rather than erroring:
    -- a stale-but-plausible glyph beats a nil-call crash in every consumer that reads .currentKey.
    if not GetControlInstructionalButton then return self.defaultKey or '' end
    return GetControlInstructionalButton(0, self.hash, true):sub(3)
end

function keybind_mt:isControlPressed()
    return self.isPressed
end

function keybind_mt:disable(toggle)
    self.disabled = toggle
    self.isPressed = false
end

---@param data KeybindProps
---@return CKeybind
--- The label the game shows in Settings > Key Bindings. That page draws Latin only:
--- an Arabic label comes out as boxes. So a label with any non-ASCII character is
--- replaced -- by `descriptionEn` when the caller gave one, else by the bind's name
--- made readable ("w_hud_menu" -> "W Hud Menu").
local function keybindLabel(data)
    local text = data.descriptionEn or data.description
    if type(text) ~= 'string' or text == '' or text:find('[\128-\255]') then
        text = data.descriptionEn
        if type(text) ~= 'string' or text == '' or text:find('[\128-\255]') then
            text = tostring(data.name or 'keybind'):gsub('[_%-]+', ' '):gsub('(%a)([%w]*)', function(a, b) return a:upper() .. b end)
        end
    end
    return text
end

function lib.addKeybind(data)
    ---@cast data CKeybind
    data.hash = joaat('+' .. data.name) | 0x80000000
    data.description = keybindLabel(data)
    keybinds[data.name] = setmetatable(data, keybind_mt)

    RegisterCommand('+' .. data.name, function()
        if data.disabled or (IsPauseMenuActive() and not data.allowInPauseMenu) then return end
        data.isPressed = true
        if data.onPressed then data:onPressed() end
    end)

    RegisterCommand('-' .. data.name, function()
        if data.disabled or (IsPauseMenuActive() and not data.allowInPauseMenu) then return end
        data.isPressed = false
        if data.onReleased then data:onReleased() end
    end)

    RegisterKeyMapping('+' .. data.name, data.description, data.defaultMapper, data.defaultKey)

    if data.secondaryKey then
        RegisterKeyMapping('~!+' .. data.name, data.description, data.secondaryMapper or data.defaultMapper, data.secondaryKey)
    end

    SetTimeout(500, function()
        TriggerEvent('chat:removeSuggestion', ('/+%s'):format(data.name))
        TriggerEvent('chat:removeSuggestion', ('/-%s'):format(data.name))
    end)

    return data
end

return lib.addKeybind
