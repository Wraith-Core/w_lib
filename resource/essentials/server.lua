--[[ w_lib · essentials (server) — see resource/essentials/shared.lua for every switch. ]]
local E = WEssentials

-- ── the host switch (shared.lua header) ──
-- convar w_lib:essentials on | off wins; otherwise ON only where a resource named w_core exists
-- (Wraith Core), OFF on a host without it (VORP / MajestyRP). Every feature below checks `on`;
-- clients follow GlobalState['w_lib:essentials'] and start nothing until it is true.
local SWITCH = 'w_lib:essentials'   -- the convar and the GlobalState key
local on, decided = false, false
local turnedOn = {}                 -- run when the switch turns ON after start (w_core started late)

local function decide()
    local v = GetConvar(SWITCH, ''):lower():match('^%s*(.-)%s*$')
    if v == 'on' or v == 'true' or v == '1' then return true, 'convar ' .. SWITCH end
    if v == 'off' or v == 'false' or v == '0' then return false, 'convar ' .. SWITCH end
    if v ~= '' then lib.print.warn(("essentials: convar %s = '%s' is neither on nor off; w_core decides"):format(SWITCH, v)) end
    if GetResourceState('w_core') ~= 'missing' then return true, 'w_core is on this host' end
    return false, ('no w_core on this host; set %s on to run it'):format(SWITCH)
end

local function apply()
    local value, why = decide()
    if GlobalState[SWITCH] ~= value then GlobalState[SWITCH] = value end
    if decided and value == on then return end
    local late = decided and value
    on, decided = value, true
    lib.print.info(('essentials: %s (%s)'):format(value and 'ON' or 'OFF', why))
    if late then for _, fn in ipairs(turnedOn) do pcall(fn) end end
end

-- ── the player count (Discord presence reads it) ──
local function recount() GlobalState['w_lib:playerCount'] = #GetPlayers() end
AddEventHandler('playerJoining', function() if on then SetTimeout(500, recount) end end)
AddEventHandler('playerDropped', function() if on then SetTimeout(500, recount) end end)
CreateThread(function() if on then recount() end end)
turnedOn[#turnedOn + 1] = recount

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
    local function mark(src)
        if GetPlayerName(src) then Player(src).state:set('w_lib:afkExempt', exempt(src), true) end
    end
    AddEventHandler('playerJoining', function()
        local src = source
        if not on then return end
        SetTimeout(5000, function() if on then mark(src) end end)
    end)
    -- ON after start: the players already here get their flag too
    turnedOn[#turnedOn + 1] = function() for _, id in ipairs(GetPlayers()) do mark(tonumber(id)) end end
    RegisterNetEvent('w_lib:essentials:afk', function(reason)
        local src = source
        if not on then return end   -- OFF kicks nobody
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
    if not on then return end   -- OFF cancels nothing
    if E.blacklistEntities[GetEntityModel(entity)] then return CancelEvent() end
    if E.blockAmbientBoats and GetEntityType(entity) == 2 then
        local pop = GetEntityPopulationType(entity)
        if pop ~= 7 and pop ~= 8 and GetVehicleType(entity) == 'boat' then CancelEvent() end
    end
end)

-- ── decide now (GlobalState is set before any client starts w_lib), and again when w_core
-- starts / stops or the convar changes ──
apply()
AddEventHandler('onResourceStart', function(res) if res == 'w_core' then apply() end end)
AddEventHandler('onResourceStop', function(res) if res == 'w_core' then apply() end end)
if AddConvarChangeListener then
    AddConvarChangeListener(SWITCH, function() apply() end)
end
