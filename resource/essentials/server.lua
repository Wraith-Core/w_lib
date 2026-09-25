--[[ w_lib · essentials (server) — see resource/essentials/shared.lua for every switch. ]]
local E = WEssentials

-- ── the player count (Discord presence reads it) ──
local function recount() GlobalState['w_lib:playerCount'] = #GetPlayers() end
AddEventHandler('playerJoining', function() SetTimeout(500, recount) end)
AddEventHandler('playerDropped', function() SetTimeout(500, recount) end)
CreateThread(recount)

-- ── AFK: staff (mod and above) is never kicked ──
if E.afk.enabled then
    local function exempt(src)
        -- 'god' on its own: under w_core each wcore.<group> principal holds only its own ace (no
        -- inheritance), so a god granted in-session is neither 'mod' nor 'admin'. Plain strings:
        -- only the rsg / qbr path takes a table, the VORP fallback compares strings.
        local ok, staff = pcall(function()
            return exports.w_lib:HasPermission(src, 'mod') or exports.w_lib:HasPermission(src, 'god') or exports.w_lib:IsAdmin(src)
        end)
        return ok and staff == true
    end
    AddEventHandler('playerJoining', function()
        local src = source
        SetTimeout(5000, function()
            if GetPlayerName(src) then Player(src).state:set('w_lib:afkExempt', exempt(src), true) end
        end)
    end)
    RegisterNetEvent('w_lib:essentials:afk', function(reason)
        local src = source
        if exempt(src) then return end
        -- the reason arrives in the player's own language; anything odd falls back to the server's
        if type(reason) ~= 'string' or #reason == 0 or #reason > 128 then
            -- nothing in w_lib's server VM reads lib.locale, so locale() is loaded here, on first
            -- need; by now resource/locale/server.lua has defined lib.getLocaleKey (the server's
            -- language). Not at file top: this folder loads before locale/.
            if not locale then lib.locale() end
            reason = locale('essentials.afk.kicked')
        end
        DropPlayer(src, reason)
    end)
end

-- ── models that may never spawn, and ambient boats ──
AddEventHandler('entityCreating', function(entity)
    if E.blacklistEntities[GetEntityModel(entity)] then return CancelEvent() end
    if E.blockAmbientBoats and GetEntityType(entity) == 2 then
        local pop = GetEntityPopulationType(entity)
        if pop ~= 7 and pop ~= 8 and GetVehicleType(entity) == 'boat' then CancelEvent() end
    end
end)
