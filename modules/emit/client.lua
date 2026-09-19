w.createModule("emit")

local eventsInProgress = {}

local msgpack_pack_args = msgpack.pack_args
local emitBps = GetConvarInt("w_lib:emit:bps", 20000) --Default bit/s for latent events

AddConvarChangeListener("w_lib:emit:bps", function(value)
  bprint("New bit/s for emit module: ", value)
  emitBps = tonumber(value)
end)

--- A function to update the bit/s of emit module
---@param bps integer (bit/s)
function w.emit.updateBps(bps)
  emitBps = tonumber(bps)
end

--- A function to trigger the server with limited bandwith
---@alias w.emit.triggerServer.latent function
---@param eventName string (The event name)
---@param ... any (Other arguments)
local function triggerServerLatent(eventName, ...)
  local payload = msgpack_pack_args(...)
  local payloadLen = #payload

  TriggerLatentServerEventInternal(eventName, payload, payloadLen, emitBps)
end

--- A function to trigger the server
---@alias w.emit.triggerServer function
---@param eventName string (The event name)
---@param ... any (Other arguments)
local function triggerServer(eventName, ...)
  local payload = msgpack_pack_args(...)
  local payloadLen = #payload

  TriggerServerEventInternal(eventName, payload, payloadLen)
end

w.emit.triggerServer = setmetatable({
  latent = triggerServerLatent
}, {
  __call = function(_, ...)
    triggerServer(...)
  end
})

--- A function to check if an event is currently getting data with emit module
---@param eventName string the event name
function w.emit.isEventInProgress(eventName)
  return eventsInProgress[eventName] or nil
end

RegisterNetEvent("w_lib:client:emit:start", function(eventName)
  local handler
  local time = GetGameTimer()
  eventsInProgress[eventName] = true
  RegisterNetEvent(eventName)
  handler = AddEventHandler(eventName, function()
    eventsInProgress[eventName] = nil
    RemoveEventHandler(handler)
    dprint(("Emit: %s takes %dms"):format(eventName, GetGameTimer() - time))
  end)
end)

---@deprecated since v2.12.2. Unsafe: the server relays this without validation, so any client can trigger arbitrary events on any client. Use a server-authoritative event instead.
--- A function to trigger client(s)
---@param eventName string (The event name)
---@param source integer|table (The player ID or list of players ID)
---@param ... any (Other arguments)
function w.emit.triggerClient(eventName, source, ...)
  TriggerServerEvent("w_lib:server:emit:dispatch", eventName, source, ...)
end
