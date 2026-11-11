-- ════════════════════════════════════════════════════════════════════════════
-- w_lib · resource/closeui/client.lua -- the two way-outs a stuck player types
--
--   /closeui    every wraith MENU closes: w_lib's own (context, input, alert, menu, panel, radial), then the event
--               'w_lib:closeUi' reaches every resource that loads @w_lib/init.lua: each runs what it registered with
--               w.onCloseUi(fn) and gives back the cursor and keyboard it holds (NUI focus is per resource: only the
--               holder can free it). Overlays that take no focus (a mission tracker, a HUD), the text line and the
--               prompts stay: they are not menus.
--   /resetcam   the camera back on the player: every resource drops its own camera first ('w_lib:resetCam'), then
--               no scripted camera renders and none is left (DestroyAllCams, the w_gunsmith/client.lua:609 way), and
--               the streaming focus is back on the player (ClearFocus, w_admin/client/cl_spectate.lua:8).
-- ════════════════════════════════════════════════════════════════════════════

local CLOSE_OWN = { 'hideContext', 'closeInputDialog', 'closeAlertDialog', 'hideMenu', 'hidePanel', 'hideRadial' }

local function closeUi()
    for _, name in ipairs(CLOSE_OWN) do
        local fn = lib[name]
        if type(fn) == 'function' then pcall(fn) end
    end
    TriggerEvent('w_lib:closeUi')
    SetNuiFocus(false, false)
    pcall(SetNuiFocusKeepInput, false)
end

local function resetCam()
    TriggerEvent('w_lib:resetCam')
    pcall(RenderScriptCams, false, false, 0, true, true, 0)
    pcall(DestroyAllCams, true)
    pcall(ClearFocus)
end

RegisterCommand('closeui', closeUi, false)
RegisterCommand('resetcam', resetCam, false)

exports('CloseUi', closeUi)
exports('ResetCam', resetCam)

CreateThread(function()
    Wait(2000)
    TriggerEvent('chat:addSuggestion', '/closeui', 'يقفل كل القوائم المفتوحة لو علقت على الشاشة')
    TriggerEvent('chat:addSuggestion', '/resetcam', 'يرجّع الكاميرا على شخصيتك لو علقت')
end)
