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
