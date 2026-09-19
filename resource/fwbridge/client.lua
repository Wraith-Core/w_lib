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
