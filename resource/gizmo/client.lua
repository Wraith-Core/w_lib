-- ════════════════════════════════════════════════════════════════════════════
-- w_lib · the gizmo for every resource (exports.w_lib:GizmoMoveEntity)
--
--   exports.w_lib:GizmoMoveEntity(entity, cfg, done)   -> true (started) | false (one is open already)
--     entity  a local or networked entity of the caller's (handles are the game's: they work here too)
--     cfg     w.gizmo.moveEntity's options (tables only -- no functions cross over: enableCam, maxDistance,
--             allowTranslateX/Y/Z, allowRotateX/Y/Z, allowSnapToGround, rotationSnap, movementSpeed ...)
--     done    function(res): res = { coords, rotation, canceled? } as w.gizmo.moveEntity returns it, nil on error
--
-- ★ Why an export: w.gizmo draws in w_lib's frame and hears back on an NUI callback (gizmo:UpdateEntity) -- both
--   only reach the resource whose page it is. Loaded into another resource (w_flags has no page) it sent its
--   messages nowhere. Here it runs in w_lib itself, for whoever asks.
-- ⚠️ An export cannot wait (no yielding across resources): it starts the gizmo in a thread here and answers
--    through `done` when the player confirms or cancels.
-- ════════════════════════════════════════════════════════════════════════════
local running = false

exports('GizmoMoveEntity', function(entity, cfg, done)
    if running then return false end
    if not entity or not DoesEntityExist(entity) then return false end
    running = true
    CreateThread(function()
        while not w.libLoaded do Wait(50) end
        pcall(w.require, 'gizmo')
        local ok, res = pcall(w.gizmo.moveEntity, entity, type(cfg) == 'table' and cfg or {})
        running = false
        if done then pcall(done, ok and res or nil) end
    end)
    return true
end)

exports('GizmoIsActive', function() return running end)
