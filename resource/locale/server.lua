--[[
    https://github.com/overextended/ox_lib

    This file is licensed under LGPL-3.0 or higher <https://www.gnu.org/licenses/lgpl-3.0.en.html>

    Copyright © 2025 Linden <https://github.com/thelindat>
]]

--[[
    ⚠️ Exported for the same reason as the client half: a consumer's lib.locale() reaches this
       through exports.w_lib:getLocaleKey(), and an unregistered export throws.

    ★ w_lib:i18n:locale is the FALLBACK, and that is not tidiness.

      This server sets `setr w_lib:i18n:locale "ar"` because that is the convar modules/i18n
      reads. Nothing sets w_lib:locale, so this returned 'en' and every resource loading its
      dictionary through lib.locale() got English on an Arabic server -- while the interface
      beside it was Arabic. Two locale systems, two convar names, one language.
]]
function lib.getLocaleKey()
    return GetConvar('w_lib:locale', GetConvar('w_lib:i18n:locale', 'en'))
end

exports('getLocaleKey', lib.getLocaleKey)

--- The language a player sees: his own choice (mirrored by the client into
--- Player(src).state['w_lib:locale']) or the server's language.
---@param src number
---@return string
function lib.getPlayerLocaleKey(src)
    src = tonumber(src)
    if src and src > 0 then
        local key = Player(src).state['w_lib:locale']
        if type(key) == 'string' and key ~= '' then return key end
    end
    return lib.getLocaleKey()
end

exports('getPlayerLocaleKey', lib.getPlayerLocaleKey)

-- the client reports its language (resource/locale/client.lua); two lower-case letters only
RegisterNetEvent('w_lib:playerLocale', function(key)
    local src = source
    if type(key) ~= 'string' then return end
    key = key:lower():match('^%s*([a-z][a-z])') or nil
    if not key then return end
    Player(src).state:set('w_lib:locale', key, true)
end)
