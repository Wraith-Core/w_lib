function generateEventName(action, requestId)
    return "w_callback:" .. action .. ":" .. requestId
end

function w.callback.trigger(name, cb, latent)
    local func = w.isClientSide() and w.callback.triggerClient or w.callback.triggerServer
    func(name, cb, latent)
end
