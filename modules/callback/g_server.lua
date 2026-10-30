local nextRequestId = 0
-- 4.1.4: pending client replies are bounded and settled exactly once.
local pendingClient = {}
local requestBudgets = {}
-- Startup may initialize several dozen resources together; allow that bounded burst.
local CALLBACK_BURST = math.max(30, math.min(240, GetConvarInt('w_lib:callbackBurst', 120)))
local CALLBACK_RATE = math.max(10, math.min(120, GetConvarInt('w_lib:callbackRate', 60)))
local CALLBACK_IN_FLIGHT = math.max(8, math.min(64, GetConvarInt('w_lib:callbackInFlight', 32)))

local function requestBudget(player)
  local now = GetGameTimer()
  local budget = requestBudgets[player]
  if not budget then
    budget = { tokens = CALLBACK_BURST, at = now, active = 0, requests = {} }
    requestBudgets[player] = budget
  end
  budget.tokens = math.min(CALLBACK_BURST, budget.tokens + math.max(0, now - budget.at) * CALLBACK_RATE / 1000)
  budget.at = now
  if budget.tokens < 1 then return nil end
  budget.tokens = budget.tokens - 1
  return budget
end

local function validRequest(name, requestId, resource)
  return type(name) == 'string' and #name > 0 and #name <= 192 and not name:find('%c')
    and type(requestId) == 'number' and requestId >= 0 and requestId <= 65535 and requestId % 1 == 0
    and type(resource) == 'string' and #resource > 0 and #resource <= 128
    and resource:match('^[%w_%.%-]+$') ~= nil
end
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
  if not validRequest(name, requestId, fromRessource) or select('#', ...) > 64 then return end
  local budget = requestBudget(source)
  if not budget then return end
  if budget.requests[requestId] then return end
  if budget.active >= CALLBACK_IN_FLIGHT or not doesCallbackExist(name) then
    TriggerClientEvent(generateEventName("response", requestId), source, fromRessource, nil)
    return
  end

  local trigger = registeredCallback[name].latent and w.emit.triggerClient.latent or TriggerClientEvent
  budget.requests[requestId], budget.active = true, budget.active + 1
  local result = pack(pcall(executeCallback, name, source, ...))
  budget.requests[requestId], budget.active = nil, budget.active - 1
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
  while pendingClient[currentRequestId] do
    currentRequestId = (currentRequestId + 1) % 65536
    if currentRequestId == nextRequestId then return nil end
  end
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
  local finished = false
  local resource = GetInvokingResource() or "unknown"
  local function finish(...)
    if finished then return end
    finished = true
    pendingClient[currentRequestId] = nil
    if handler then RemoveEventHandler(handler) end
    if isAFunction(responseCallback) then
      local ok, err = pcall(responseCallback, ...)
      if not ok then print(('^1[w_lib]^7 Client callback response failed: %s'):format(tostring(err))) end
    else
      responseCallback:resolve(pack(...))
    end
  end
  pendingClient[currentRequestId] = { target = target, resource = resource, finish = finish }
  handler = RegisterNetEvent(generateEventName("response", currentRequestId), function(fromResource, ...)
    if tonumber(_G.source) ~= target then return end
    dprint("Response received for request ID: %d from resource: %s", currentRequestId, fromResource)
    finish(...)
  end)
  SetTimeout(math.min(120000, math.max(1000, GetConvarInt('w_lib:clientCallbackTimeout', 5000))), function()
    if not finished then finish(nil) end
  end)

  nextRequestId = (currentRequestId + 1) % 65536
  TriggerClientEvent("w_lib:triggerCallback", source, name, currentRequestId, resource, unpack(args))
  if cbType == "function" then
    return
  end
  return unpack(Await(responseCallback) or {})
end

AddEventHandler('playerDropped', function()
  local player = tonumber(source)
  requestBudgets[source] = nil
  requestBudgets[player] = nil
  local settling = {}
  for _, pending in pairs(pendingClient) do
    if pending.target == player then settling[#settling + 1] = pending end
  end
  -- A consumer callback may create another request. Never mutate this iteration via user code.
  for _, pending in ipairs(settling) do pending.finish(nil) end
end)

AddEventHandler('onResourceStop', function(resource)
  local settling = {}
  for _, pending in pairs(pendingClient) do
    if pending.resource == resource then settling[#settling + 1] = pending end
  end
  for _, pending in ipairs(settling) do pending.finish(nil) end
end)

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
