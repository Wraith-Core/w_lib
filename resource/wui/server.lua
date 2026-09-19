-- ============================================================
-- w_lib — الوجه الخادمي للإشعارات الموحّدة
-- ============================================================

--- إشعار لاعبٍ بواجهة RK-text3d
--- @param source number
--- @param title string
--- @param message string
--- @param style? string 'success' | 'error' | 'info'
--- @param duration? number مللي ثانية (افتراضي 5000)
local function NotifyPlayer(source, title, message, style, duration)
    if not source then return end

    TriggerClientEvent('w_lib:notify', source, title, message, style, duration)
end

exports('NotifyPlayer', NotifyPlayer)
