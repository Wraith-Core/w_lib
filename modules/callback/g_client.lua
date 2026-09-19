local nextRequestId = 0
local registeredCallback = {}
local promise = promise
local await = Citizen.Await
local pack = table.pack
local unpack = table.unpack
local insert = table.insert

w.createModule("callback")

--- Function to check if a variable is a callable function.
--- Checks both direct functions and tables with __call metamethod.
--@param cb any (The variable to check)
--@return boolean (True if the variable is a function or callable, false otherwise)
local function isAFunction(cb)
  local cbType = type(cb)

  if cbType == "function" then return true end

  if cbType == "table" and getmetatable(cb)?.__call then
    return true
  end
  return false
end

--- A function to register a client callback
---@param name string (The name of the callback event)
---@param cb function (The function executed when the callback is triggered)
function w.callback.register(name, cb)
  if registeredCallback[name] then return eprint("Callback already registered:", name) end
  registeredCallback[name] = {
    cb = cb,
    resource = GetInvokingResource()
  }
end

AddEventHandler("onResourceStop", function(resource)
  for name, callback in pairs(registeredCallback) do
    if callback.resource == resource then
      registeredCallback[name] = nil
    end
  end
end)

--- Execute a registered callback by name.
--- Internal function that runs the callback and returns its results.
---@param name string (The name of the registered callback to execute)
---@param ...? any (Parameters to pass to the callback)
---@return any (Return values from the executed callback)
local function executeCallback(name, ...)
  if not registeredCallback[name] then return false, eprint(("No callback for: %s"):format(name)) end
  return registeredCallback[name].cb(...)
end

--- A function to trigger a client callback
---@param name string (The name of the callback event)
---@param cb? function|nil (Function to receive the result of the event)
---@param ...? mixed (The list of parameters to send to the callback event)
function w.callback.triggerClient(name, cb, ...)
  if not registeredCallback[name] then return false, eprint("No client callback for:", name) end

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

--- A function to trigger a server callback
---@param name string (Name of the callback event)
---@param cb? function (Function to receive the result of the event)
---@param ...? mixed (The list of parameters to send to the callback event)
function w.callback.triggerServer(name, cb, ...)
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

  local handler
  local finished = false
  local function finish(...)
    if finished then return end
    finished = true
    if handler then RemoveEventHandler(handler) end
    if isAFunction(responseCallback) then
      responseCallback(...)
    else
      responseCallback:resolve(pack(...))
    end
  end
  handler = RegisterNetEvent(generateEventName("response", currentRequestId), function(fromResource, ...)
    dprint("Response received for request ID: %d from resource: %s", currentRequestId, fromResource)
    finish(...)
  end)

  -- A lost reply or a server exception must not leave a menu busy forever.
  -- Remove the listener too; retrying must not accumulate pending handlers.
  SetTimeout(math.max(1000, GetConvarInt('w_lib:callbackTimeout', 30000)), function()
    if not finished then
      print(('^3[w_lib]^7 Callback timed out: %s'):format(tostring(name)))
      finish(nil)
    end
  end)

  TriggerServerEvent("w_lib:triggerCallback", name, currentRequestId, GetInvokingResource() or "unknown", unpack(args))

  nextRequestId = nextRequestId < 65535 and nextRequestId + 1 or 0

  if cbType == "function" then
    return
  end
  return unpack(await(responseCallback) or {})
end

--deprecated function
w.triggerServerCallback = w.callback.triggerServer

RegisterNetEvent("w_lib:triggerCallback", function(name, requestId, fromResource, ...)
  TriggerServerEvent(generateEventName("response", requestId), fromResource, executeCallback(name, ...))
end)

exports("getCallbackAPI", function()
  return w.callback
end)

--- The ox-style synchronous call: `local result = w.callback.await(name, delay, ...)`.
--- `delay` (false | number) is accepted for compatibility and ignored: triggerServer
--- without a function already waits for the answer and returns it.
---@param name string
---@param delay? boolean|number|function
---@return ...
function w.callback.await(name, delay, ...)
  if type(delay) == "function" then
    return w.callback.triggerServer(name, delay, ...)
  end
  return w.callback.triggerServer(name, nil, ...)
end
