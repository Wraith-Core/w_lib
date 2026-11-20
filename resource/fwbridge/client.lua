-- ════════════════════════════════════════════════════════════════════════════
-- w_lib — جسر الفريمورك الشامل (fwbridge) — الدوال العميلة
--   الإشعارات تمرّ عبر w.notify (مظهر w_notify الموحّد) في السكربت المستهلِك،
--   لذا هنا نوفّر فقط قراءة بيانات اللاعب المحليّة (RSGCore).
-- ════════════════════════════════════════════════════════════════════════════
if IsDuplicityVersion() then return end

exports('FwGetPlayerData', function()
    if WFW.Name == "vorp" then
        return nil -- فورب لا يخزّن بيانات لاعب محليّة كـ RSGCore
    elseif WFW.Name == "rsgcore" then -- includes the normalized QBR core shape
        local ok, pd = pcall(function() return WFW.Core.Functions.GetPlayerData() end)
        if ok then return pd end
    end
    return nil
end)

--- The serial of the weapon in hand, and its hash.
--- RSG tracks the instance by serial (rsg-weapons); VORP keeps no client-side serial, so
--- there only the hash comes back and the caller resolves the instance on the server.
---@return string|nil serial
---@return number hash
exports('FwWeaponSerial', function()
    local ok, _, hash = pcall(function() return GetCurrentPedWeapon(PlayerPedId(), true, 0, true) end)
    hash = ok and hash or 0
    if GetResourceState('rsg-weapons') == 'started' then
        local okSerial, serial = pcall(function() return exports['rsg-weapons']:CheckWeaponSerial() end)
        if okSerial and type(serial) == 'string' and serial ~= '' then return serial, hash end
    end
    return nil, hash
end)

local function isWCoreClient()
    return WFW.Host == 'w_core' or (type(GetResourceState) == 'function' and GetResourceState('w_core') == 'started')
end

local function isPlayerLoaded()
    if WFW._Client and WFW._Client.isLoaded and WFW._Client.isLoaded() then
        return true
    end
    if WFW._Client and WFW._Client.hasExplicitState and WFW._Client.hasExplicitState() then
        return false
    end
    if type(LocalPlayer) == 'table' and type(LocalPlayer.state) == 'table' then
        if LocalPlayer.state.isLoggedIn == true or LocalPlayer.state.IsInSession == true then
            return true
        end
    end
    if WFW.Name == 'rsgcore' then
        local pd = exports.w_lib:FwGetPlayerData()
        if type(pd) == 'table' and pd.citizenid ~= nil and pd.citizenid ~= '' then
            return true
        end
    end
    return false
end

exports('FwIsPlayerLoaded', isPlayerLoaded)
exports('FwIsLoggedIn', isPlayerLoaded)

local function setHudVisible(visible)
    local show = (visible ~= false)
    pcall(TriggerEvent, show and 'hud:client:showui' or 'hud:client:Hideui')
    pcall(TriggerEvent, show and 'hud:client:showUiWithHoutStement' or 'hud:client:hideUiWithHoutStement')
    if WFW.Name == 'vorp' or (type(GetResourceState) == 'function' and GetResourceState('vorp_core') == 'started' and not isWCoreClient()) then
        pcall(TriggerEvent, 'vorp:showUi', show)
    end
    if not show then
        pcall(TriggerEvent, 'chat:clear')
    end
    return true
end

exports('FwSetHudVisible', setHudVisible)
exports('FwHideFrameworkHud', function(hide)
    return setHudVisible(not (hide == true))
end)

exports('FwToggleDuty', function()
    if type(TriggerServerEvent) == 'function' then
        TriggerServerEvent('w_lib:fw:server:toggleDuty')
        return true
    end
    return false
end)

exports('FwReloadAppearance', function()
    if type(GetResourceState) == 'function' and GetResourceState('vorp_character') == 'started' then
        Wait(200)
        TriggerEvent('vorpcharacter:reloadafterdeath')
        return true
    end
    return false
end)
