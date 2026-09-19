w.require("emit", true)

RegisterServerEvent("w_lib:server:emit:dispatch", function(eventName, src, ...)
    w.emit.triggerClient(eventName, src, ...)
end)
