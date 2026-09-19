w.createModule("clipboard")

w.require("nui")

local nuiLoaded = false

-- ⚠️ The guard that used to be here returned WITHOUT setting nuiLoaded when this resource
--    owned the clipboard frame -- and clipboard_copy waits on that flag forever. With the frame
--    gone the branch could never be taken, but leaving a path that deadlocks the export is not
--    something to keep for sentiment.
CreateThread(function()
    Wait(1500)
    nuiLoaded = true
end)


exports("clipboard_copy", function(value)
    while not nuiLoaded do
        Wait(0)
    end
    SendNUIMessage({
        -- ★ The one frame: the copy handler lives in the unified app (App.tsx) now.
        messageTargetUiName = "wui",
        type = "copy",
        value = value

    })

    return true
end)

-- The same copy under the name the panels call it by (w_logs: exports.w_lib:setClipboard(url)).
exports("setClipboard", function(value)
    return exports.w_lib:clipboard_copy(value)
end)
