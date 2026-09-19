w.createModule("gameEvents")

w.gameEvents.eventListened = {}

--- Register a listener for a specific game event
---@param eventName string (The name of the event to listen for, or "all" to listen for all events)
---@param callback function (The function that will be called when the event is triggered)
function w.gameEvents.listen(eventName, callback)
    TriggerEvent("w_lib:gameEvents:register", eventName)
    AddEventHandler("w_lib:gameEvents:" .. eventName, callback)
end
