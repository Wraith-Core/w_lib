local nextRequestId = 0
local responseCallback = {}
local registeredCallback = {}
local promise = promise
local pack = table.pack
local unpack = table.unpack
local insert = table.insert
w.require("emit")

w.createModule("callback")

local function isAFunction(cb)
  local cbType = type(cb)

  if cbType == "function" then return true end

  if cbType == "table" and getmetatable(cb)?.__call then
    return true
  end
  return false
end

--- A function to register a server callback
---@alias w.callback.register function
---@param name string (The name of the callback event)
---@param cb function (The function executed when the callback is triggered <br> ⚠️ `source` is always the first argument)
function w.callback.registerCallback(name, cb, latent)
  if registeredCallback[name] then return eprint("Callback already registered:", name) end
  registeredCallback[name] = {
    cb = cb,
    resource = GetInvokingResource(),
    latent = latent or false
  }
end

--- A function to register a latent server callback
---@alias w.callback.registerLatent function
---@param name string (The name of the callback event)
---@param cb function (The function executed when the callback is triggered <br> ⚠️ `source` is always the first argument)
function w.callback.registerLatentCallback(name, cb)
  w.callback.registerCallback(name, cb, true)
end

w.callback.register = setmetatable({},
  {
    __index = function(_, key)
      if key == "latent" then
        return w.callback.registerLatentCallback
      end
      return w.callback["register" .. key]
    end,
    __call = function(_, ...)
      w.callback.registerCallback(...)
    end,
  }
)

AddEventHandler("onResourceStop", function(resource)
  for name, callback in pairs(registeredCallback) do
    if callback.resource == resource and name:split(":")[1] ~= "w_lib" then
      registeredCallback[name] = nil
    end
  end
end)

local function executeCallback(name, ...)
  if not registeredCallback[name] then return false, eprint(("No callback for: %s"):format(name)) end
  return registeredCallback[name].cb(...)
end

local function doesCallbackExist(name)
  if registeredCallback[name] ~= nil then return true end
  Wait(5000)
  return registeredCallback[name] ~= nil
end

--- A function to trigger a server callback
---@param name string (Name of the callback event)
---@param cb? function (Function to receive the result of the event)
---@param ...? any (The list of parameters to send to the callback event)
function w.callback.triggerServer(name, cb, ...)
  if not doesCallbackExist(name) then return false, eprint("Function: No server callback for:", name) end

  local cbType = isAFunction(cb) and "function" or "other"
  local args = { ... }

  if cbType == "function" then
    cb(executeCallback(name, unpack(args)))
  else
    if cb then
      insert(args, 1, cb)
    end
    return executeCallback(name, unpack(args))
  end
end

RegisterServerEvent("w_lib:triggerCallback", function(name, requestId, fromRessource, ...)
  local source = source
  if not doesCallbackExist(name) then
    TriggerClientEvent(generateEventName("response", requestId), source, fromRessource, nil)
    return eprint("Event: No server callback for:", name, fromRessource)
  end

  local trigger = registeredCallback[name].latent and w.emit.triggerClient.latent or TriggerClientEvent

  local result = pack(pcall(executeCallback, name, source, ...))
  if result[1] then
    trigger(generateEventName("response", requestId), source, fromRessource, unpack(result, 2, result.n))
  else
    print(('^1[w_lib]^7 Callback %s failed for player %s: %s'):format(tostring(name), tostring(source), tostring(result[2])))
    trigger(generateEventName("response", requestId), source, fromRessource, nil)
  end
end)

--- A function to trigger a client callback
---@param name string (The name of the callback event)
---@param source integer (The source of the client to trigger)
---@param cb? function (Function to receive the result of the event)
---@param ...? any (The list of parameters to send to the callback event)
function w.callback.triggerClient(name, source, cb, ...)
  if not source then
    return eprint("Source value is missing in your callback: ", name)
  end
  if not GetPlayerIdentifier(source, 1) then
    return eprint("Callback Module: Player is not connected - source: " .. source)
  end

  local cbType = isAFunction(cb) and "function" or "other"

  local currentRequestId = nextRequestId
  local args = { ... }
  local responseCallback

  if cbType == "function" then
    responseCallback = cb
  else
    if cb then
      insert(args, 1, cb)
    end
    responseCallback = promise.new()
  end

  -- ★ The answer counts only from the player who was asked. The event name is a sequential number any
  --   client can guess, and `source` is shadowed by this function's parameter, so the sender is read
  --   from _G.source. Without this a seller answered 'confirm' for the buyer (w_stables trade offer)
  --   and the buyer was charged before ever seeing the dialog. A stranger's answer is dropped and the
  --   handler stays registered for the real one.
  local target = tonumber(source)
  local handler
  handler = RegisterNetEvent(generateEventName("response", currentRequestId), function(fromResource, ...)
    if tonumber(_G.source) ~= target then return end
    dprint("Response received for request ID: %d from resource: %s", currentRequestId, fromResource)
    if isAFunction(responseCallback) then
      responseCallback(...)
    else
      responseCallback:resolve(pack(...))
    end
    RemoveEventHandler(handler)
  end)


  TriggerClientEvent("w_lib:triggerCallback", source, name, currentRequestId, GetInvokingResource() or "unknown", unpack(args))

  nextRequestId = nextRequestId < 65535 and nextRequestId + 1 or 0
  if cbType == "function" then
    return
  end
  return unpack(Await(responseCallback) or {})
end

--- Server mirror of the client's w.callback.await: ask a client and wait for its answer.
---@param name string (The name of the client callback)
---@param source integer (The player to ask)
---@param ... any (The arguments)
---@return any (The values the client callback returned)
function w.callback.await(name, source, ...)
  return w.callback.triggerClient(name, source, nil, ...)
end

exports("getCallbackAPI", function()
  return w.callback
end)

setmetatable(w.callback, {
  __call = function(self, name, source, cb, ...)
    if isAFunction(source) then
      return self.triggerServer(name, source, cb, ...)
    elseif type(source) == "number" or (type(source) == "string" and tonumber(source)) then
      return self.triggerClient(name, tonumber(source), cb, ...)
    else
      return self.triggerServer(name, source, cb, ...)
    end
  end
})
