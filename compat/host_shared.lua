-- ════════════════════════════════════════════════════════════════════════════
-- w_lib · compat/host_shared.lua — runs INSIDE the core that provides the dialect
-- names (w_core), on both sides. Loaded by init.lua when the resource's manifest has
-- `provide 'rsg-core'` / 'qbr-core' / 'vorp_core' / 'vorp_menu' / 'vorp_inputs' /
-- 'vorp_progressbar' / 'ox_lib'.
--
-- What it does: registers the public exports of those names under the ALIAS name, so
--   exports['rsg-core']:GetCoreObject()   exports.vorp_core:GetCore()
--   exports['qbr-core']:GetPlayer(src)    exports.ox_lib:notify(...)
-- resolve although no resource of that name exists. FXServer resolves an export call
-- to the event `__cfx_export_<resource>_<name>`; only code running in the providing
-- resource's VM can answer it, which is why this file is loaded here and not in w_lib.
--
-- The core object itself is the host's (WCore). RSG-Core and QBCore-RedM share its
-- PlayerData contract; the VORP contract is a facade built in host_server / host_client.
-- ════════════════════════════════════════════════════════════════════════════

local host = WCompat.host
local provided = {}
for _, name in ipairs(WCompat.provided) do provided[name] = true end
WCompat.isServer = IsDuplicityVersion()

--- Register `fn` as export `name` of the aliased resource `alias`.
function WCompat.alias(alias, name, fn)
    if not provided[alias] then return end
    AddEventHandler(('__cfx_export_%s_%s'):format(alias, name), function(setCB)
        setCB(fn)
    end)
end

--- The host's core object (WCore). Resolved lazily: the host's main script defines it
--- after this file has run.
function WCompat.core()
    local core = rawget(_G, 'WCore')
    if type(core) == 'table' then return core end
    local ok, obj = pcall(function() return exports[host]:GetCoreObject() end)
    return ok and obj or nil
end

--- The list of dialect names this host answers for (read by exports.w_lib:CompatStatus()).
exports('CompatAliases', function()
    return WCompat.provided
end)

-- ───────────────────────────── rsg-core ─────────────────────────────
-- RSG resources: `local RSGCore = exports['rsg-core']:GetCoreObject()`
WCompat.alias('rsg-core', 'GetCoreObject', function()
    return WCompat.core()
end)

-- ───────────────────────────── qbr-core ─────────────────────────────
-- QBR exposes small functions instead of one object (w_lib's fwbridge reads these).
WCompat.alias('qbr-core', 'GetCoreObject', function() return WCompat.core() end)
WCompat.alias('qbr-core', 'GetItems',      function() local c = WCompat.core() return c and c.Shared and c.Shared.Items or {} end)
WCompat.alias('qbr-core', 'GetJobs',       function() local c = WCompat.core() return c and c.Shared and c.Shared.Jobs or {} end)
WCompat.alias('qbr-core', 'GetGangs',      function() local c = WCompat.core() return c and c.Shared and c.Shared.Gangs or {} end)
WCompat.alias('qbr-core', 'GetWeapons',    function() local c = WCompat.core() return c and c.Shared and c.Shared.Weapons or {} end)
WCompat.alias('qbr-core', 'GetVehicles',   function() local c = WCompat.core() return c and c.Shared and c.Shared.Vehicles or {} end)
if WCompat.isServer then
    WCompat.alias('qbr-core', 'GetPlayer', function(source)
        local c = WCompat.core()
        return c and c.Functions.GetPlayer(source) or nil
    end)
    WCompat.alias('qbr-core', 'GetPlayers', function()
        local c = WCompat.core()
        return c and c.Functions.GetPlayers() or {}
    end)
else
    WCompat.alias('qbr-core', 'GetPlayerData', function()
        local c = WCompat.core()
        return c and c.PlayerData or {}
    end)
end

-- ───────────────────────────── ox_lib ─────────────────────────────
-- `@ox_lib/init.lua` already resolves to the host's init.lua (which loads w_lib's).
-- exports.ox_lib:<fn>() is forwarded to exports.w_lib:<fn>() for the names ox_lib ships.
local oxExports = {
    -- shared / server
    'hasLoaded', 'cache', 'getLocale', 'getLocales', 'getLocaleKey', 'setLocale', 'checkDependency', 'versionCheck',
    'addAce', 'removeAce', 'addPrincipal', 'removePrincipal', 'notify', 'defaultNotify',
    'getVehicleProperties', 'setVehicleProperties', 'triggerClientEvent',
    -- client interface
    'registerContext', 'showContext', 'hideContext', 'getOpenContextMenu',
    'inputDialog', 'closeInputDialog', 'alertDialog', 'closeAlertDialog',
    'progressBar', 'progressActive', 'cancelProgress', 'showProgress', 'setProgress', 'hideProgress',
    'showTextUI', 'hideTextUI', 'isTextUIOpen',
    'skillCheck', 'cancelSkillCheck', 'skillCheckActive',
    'registerMenu', 'showMenu', 'hideMenu', 'getOpenMenu', 'setMenuOptions',
    'registerRadial', 'addRadialItem', 'removeRadialItem', 'clearRadialItems', 'hideRadial', 'disableRadial', 'getCurrentRadialId',
    'setNuiFocus', 'resetNuiFocus', 'setClipboard', 'playSound',
    'blockControl', 'unblockControl', 'isControlBlocked',
    'replaceRadar', 'isRadarReplaced', 'setRadarVisible', 'setRadarMode', 'getRadarMode',
    'setMinimapVisible', 'setMinimapRotation', 'setMinimapExpanded',
    'showPanel', 'hidePanel', 'panelActive',
}
if provided['ox_lib'] then
    for _, name in ipairs(oxExports) do
        WCompat.alias('ox_lib', name, function(...)
            return exports.w_lib[name](nil, ...)
        end)
    end
end

-- ───────────────────────────── vorp_core ─────────────────────────────
-- The facade is filled by host_server.lua / host_client.lua (WCompat.vorp). Both the
-- modern export and the legacy `TriggerEvent('getCore', cb)` hand it out.
WCompat.vorp = WCompat.vorp or {}
WCompat.alias('vorp_core', 'GetCore', function()
    return WCompat.vorp
end)
if provided['vorp_core'] then
    AddEventHandler('getCore', function(cb)
        if type(cb) == 'function' or (type(cb) == 'table' and getmetatable(cb) and getmetatable(cb).__call) then
            cb(WCompat.vorp)
        end
    end)
end

--- VORP currency index -> host money type (0 dollar, 1 gold, 2 rol).
WCompat.currency = { [0] = 'cash', [1] = 'gold', [2] = 'rol' }
function WCompat.currencyName(index)
    if type(index) == 'string' then return index end
    return WCompat.currency[tonumber(index) or 0] or 'cash'
end

--- Is `v` a function or a funcref (a function handed across an export boundary)?
function WCompat.isCallable(v)
    local t = type(v)
    if t == 'function' then return true end
    return t == 'table' and getmetatable(v) ~= nil and getmetatable(v).__call ~= nil
end
