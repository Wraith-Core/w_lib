--[[
    https://github.com/overextended/ox_lib

    This file is licensed under LGPL-3.0 or higher <https://www.gnu.org/licenses/lgpl-3.0.en.html>

    Copyright © 2025 Linden <https://github.com/thelindat>
]]

local settings = require 'resource.settings'

local function loadLocaleFile(key)
    local file = LoadResourceFile(cache.resource, ('locales/%s.json'):format(key))
        or LoadResourceFile(cache.resource, 'locales/en.json')

    return file and json.decode(file) or {}
end

--[[
    ⚠️ EXPORTED, AND IT MUST BE.

       imports/locale/shared.lua runs inside the CONSUMER resource, and its lib.locale() opens
       with `local lang = key or lib.getLocaleKey()`. This file does not run there -- it is
       w_lib's own client script -- so in a consumer that call falls through init.lua's export
       fallback to exports.w_lib:getLocaleKey().

       Without this line that export does not exist, the call throws, and lib.locale() takes
       down whatever thread or chunk it was written in. Every consumer. Silently.
]]
function lib.getLocaleKey() return settings.locale end

exports('getLocaleKey', lib.getLocaleKey)

---@param key string
function lib.setLocale(key)
    TriggerEvent('w_lib:setLocale', key)
    SendNUIMessage({
        action = 'setLocale',
        data = loadLocaleFile(key)
    })
end

RegisterNUICallback('init', function(_, cb)
    cb(1)

    SendNUIMessage({
        action = 'setLocale',
        data = loadLocaleFile(settings.locale)
    })
end)

lib.locale(settings.locale)
