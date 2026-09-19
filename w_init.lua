if not _VERSION:find("5.4") then
  error("^1Lua 5.4 must be enabled in the resource manifest!^0", 2)
end

-------------
-- GLOBAL VARIABLES
-------------
CreateThreadNow = Citizen.CreateThreadNow
Await = Citizen.Await
InvokeNative = Citizen.InvokeNative
-------------
-- END GLOBAL VARIABLES
-------------

local resourceName = GetCurrentResourceName()
local w_lib = "w_lib"
local modules = { "table", "print", "file", "math", "trigger-event" }
local function noFunction() end
local LoadResourceFile = LoadResourceFile
local context = IsDuplicityVersion() and "server" or "client"
local moduleInLoading = {}
local moduleLoaded = {}
local globalModuleLoaded = {}

local alias = {
  framework = "framework-bridge",
  pl = "player",
  versionChecker = "version-checker",
  notif = "notification",
  pedTexture = "ped-texture",
  gameEvents = "game-events",
  triggerEvent = "trigger-event",
  promptNui = "prompt-nui"
}

local function getAlias(module)
  if module == "meCoords" or module == "mePlayerId" or module == "meServerId" then return "me" end
  if alias[module] then return module end
  for alia, name in pairs(alias) do
    if name == module then
      return alia
    end
  end
  return module
end

--list modules required
for i = 1, GetNumResourceMetadata(resourceName, "w_module") do
  modules[#modules + 1] = getAlias(GetResourceMetadata(resourceName, "w_module", i - 1))
end

-- Duplicate-load guard: only the module layer carries the 'libLoaded' marker.
-- `@w_lib/init.lua` provisionally assigns the w_lib *core* table to `w` before
-- bootstrapping this file, and that core table also carries .name == "w_lib" --
-- testing the name made this guard fire in every consumer. Match the
-- moduleLayerLoaded() convention used by init.lua instead.
if type(w) == "table" and rawget(w, "libLoaded") ~= nil then
  error(("w_lib is already loaded.\n\tRemove any duplicate entries from '@%s/fxmanifest.lua'"):format(resourceName))
end

function GetHashFromString(value)
  if type(value) == "string" then
    local number = tonumber(value)
    if number then return math.toSigned(number) end
    return joaat(value)
  end
  return value
end

function UnJson(value)
  if not value then return {} end
  if value == "null" then return {} end
  if type(value) == "string" then
    return json.decode(value)
  end
  return value
end

---Set a default value if the value is nil
---@param value any your value
---@param default any the default value
---@return any
function GetValue(value, default)
  if default == nil then
    return value
  end
  if default == false then
    return value or false
  end
  return value == nil and default or value
end

local function isModuleLoaded(name, needLocal)
  needLocal = GetValue(needLocal, true)
  if needLocal and not (moduleLoaded[name] == "local") then return false end
  if moduleInLoading[name] then return true end
  if moduleLoaded[name] then return true end
  return false
end

local function loadGlobalModule(module)
  if resourceName == "w_lib" then return end
  while GetResourceState("w_lib") ~= "started" do Wait(0) end
  exports.w_lib:loadGlobalModule(module)
end

local function doesScopedFilesRequired(name)
  if name == "table" then return true end
  return resourceName ~= "w_lib" or table.find(modules, function(_name) return _name == name end)
end

local function readAndLoadFile(path)
  local file = LoadResourceFile("w_lib", path)
  if not file then
    return false
  end

  local fn, err = load(file, ("@@w_lib/%s.lua"):format(path))

  if not fn or err then
    return false, error(("\n^1Error importing module (%s):\n^1%s^0"):format(path, err), 3)
  end

  local success, err = pcall(fn)

  if not success then
    return false, error(("\n^1Error importing module (%s):\n^1%s^0"):format(path, err), 3)
  end
  return success
end

local function addDebugListener(module)
  if w.debugModules[module] ~= nil then return end
  local convarDebugName = resourceName .. ":debug:" .. module
  local globalDebugName = "all:debug:" .. module

  w.debugModules[module] = (GetConvar(globalDebugName, "off") == "on") or (GetConvar(convarDebugName, "off") == "on")

  if w.debugModules[module] then
    oprint(("/!\\ %s module '%s' is in debug mode /!\\"):format(resourceName, module))
    oprint("Don't use this in production!")
  end

  for _, name in ipairs({ convarDebugName, globalDebugName }) do
    AddConvarChangeListener(name, function()
      w.debugModules[module] = GetConvar(name, "off") == "on"
      if w.debugModules[module] then
        oprint(("/!\\ %s module '%s' is in debug mode /!\\"):format(resourceName, module))
        oprint("Don't use this in production!")
      else
        oprint(("/!\\ %s module '%s' debug mode turned OFF /!\\"):format(resourceName, module))
      end
    end)
  end
end

local function loadModule(name, needLocal)
  if needLocal == nil then needLocal = true end
  local folder = alias[name] or name
  local dir = ("modules/%s"):format(folder)

  moduleInLoading[folder] = true
  moduleInLoading[name] = true
  moduleLoaded[folder] = needLocal and "local" or "global"
  moduleLoaded[name] = needLocal and "local" or "global"


  loadGlobalModule(name)

  --load files in the right order
  for _, fileName in ipairs({ "shared", "context" }) do
    --convert the name if it's context
    fileName = fileName == "context" and context or fileName
    local link = ("%s/%s.lua"):format(dir, fileName)
    --load scoped files
    if needLocal or doesScopedFilesRequired(name) then
      readAndLoadFile(link)
    end
    --load global files inside w_lib
    if resourceName == "w_lib" then
      local globalLink = ("%s/%s.lua"):format(dir, "g_" .. fileName)
      if not globalModuleLoaded[globalLink] then
        globalModuleLoaded[globalLink] = true
        readAndLoadFile(globalLink)
      end
    end
  end

  moduleInLoading[name] = nil
  moduleInLoading[folder] = nil

  addDebugListener(folder)

  return true
end

local function call(_, name, ...)
  if not name then return noFunction end
  if type(name) ~= "string" then return noFunction() end
  name = getAlias(name)

  local module = rawget(w, name)

  if not module then
    loadModule(name)
  end

  while moduleInLoading[name] do Wait(0) end

  return rawget(w, name)
end

local w = setmetatable({
  libLoaded = false,
  debug = false,
  debugModules = {},
  name = w_lib,
  resourceName = resourceName,
  context = context,
  cache = {},
  isServerSide = function()
    return context == "server"
  end,
  isClientSide = function()
    return context == "client"
  end
}, {
  __index = call,
  __call = noFunction
})

function w.createModule(name)
  if not rawget(w, name) then
    rawset(w, name, {})
  end
  return rawget(w, name)
end

function w.waitLibLoading()
  while not w.libLoaded do
    Wait(0)
  end
end

function w.isModuleLoaded(name, needLocal)
  name = getAlias(name)
  return isModuleLoaded(name, needLocal)
end

local function onReady(cb)
  w.waitLibLoading()
  Wait(1000)

  return cb and cb() or true
end

function w.ready(cb)
  CreateThreadNow(function() onReady(cb) end)
end

function w.stopped(cb)
  AddEventHandler("onResourceStop", function(resource)
    if resource ~= resourceName then return end
    cb()
  end)
end

-------------
-- ASYNC
-------------
--- Wraps a function to run inside a thread and return a promise
local function asyncWrap(func)
  return function(...)
    local args = { ... }
    local waiter = promise.new()
    CreateThread(function()
      local results = { pcall(func, table.unpack(args)) }
      local ok = results[1]
      if ok then
        -- Pack results to return multiple values
        waiter:resolve({ table.unpack(results, 2) })
      else
        waiter:reject(results[2])
      end
    end)

    -- Wrap the promise to add .next() and .await() methods
    return setmetatable({}, {
      __index = function(_, key)
        if key == "next" then
          return function(_, callback, errorCallback)
            return waiter:next(function(results)
              return callback(table.unpack(results))
            end, errorCallback)
          end
        elseif key == "await" then
          return function()
            local results = Citizen.Await(waiter)
            return table.unpack(results)
          end
        else
          -- Proxy all other methods to the original promise
          return waiter[key]
        end
      end
    })
  end
end

local wrapValue
local createAsyncProxy
--- Creates a lazy async proxy for a table/module
function createAsyncProxy(tbl)
  return setmetatable({}, {
    __index = function(proxy, key)
      local value = rawget(tbl, key)
      if value == nil then
        value = tbl[key]
      end
      return wrapValue(proxy, key, value)
    end
  })
end

--- Wraps values into async proxies (caches wrapped functions/proxies in the parent proxy)
function wrapValue(proxy, key, value)
  if not value then return end

  local valueType = type(value)
  if valueType == "function" then
    local wrapped = asyncWrap(value)
    rawset(proxy, key, wrapped)
    return wrapped
  elseif valueType == "table" then
    local nested = createAsyncProxy(value)
    rawset(proxy, key, nested)
    return nested
  end
end

--- Global w.async namespace (looks up w.* first, then _G.*)
w.async = setmetatable({}, {
  __index = function(proxy, key)
    local value = rawget(w, key)
    if value == nil then
      value = rawget(_G, key)
    end
    return wrapValue(proxy, key, value)
  end
})

_ENV.w = w
-- jo: اسم مستعار للسطح نفسه. موارد مبنيّة على jo_libs (وهي نفس هذه
-- المكتبة باسم آخر) تستدعي jo.* — فتعمل بلا تعديل سطر واحد فيها.
_ENV.jo = w


if GetResourceState(w_lib) ~= "started" and resourceName ~= "w_lib" then
  error("^1w_lib must be started before this resource.^0", 0)
end

-------------
-- DEFAULT MODULES
-------------

function w.require(name, needLocal)
  needLocal = GetValue(needLocal, true)
  name = getAlias(name)
  if isModuleLoaded(name, needLocal) then return end
  return loadModule(name, needLocal)
end

if resourceName == "w_lib" then
  exports("loadGlobalModule", function(name)
    while not w.libLoaded do Wait(0) end
    w.require(name, false)
    return true
  end)
  AddEventHandler("w_lib:loadGlobalModule", function(name, cb)
    w.require(name, false)
    cb()
    return true
  end)
end

w.require("print")

if GetConvar(resourceName .. ":debug", "off") == "on" then
  oprint(("/!\\ %s is in debug mode /!\\"):format(resourceName))
  oprint("Don't use this in production!")
  w.debug = true
end

AddConvarChangeListener(resourceName .. ":debug", function()
  w.debug = GetConvar(resourceName .. ":debug", "off") == "on"
  if w.debug then
    oprint(("/!\\ %s is in debug mode /!\\"):format(resourceName))
    oprint("Don't use this in production!")
  else
    oprint(("/!\\ %s debug mode turned OFF /!\\"):format(resourceName))
  end
end)

-------------
-- EXPORTS (prevent call before initializes)
-------------
local function createExport(name, cb)
  exports(name, function(...)
    w.waitLibLoading()
    return cb(...)
  end)
end

--Sort module by priority
local priorityModules = { table = 1, print = 2, file = 3, math = 4, hook = 5 }
table.sort(modules, function(a, b)
  local prioA = priorityModules[a]
  local prioB = priorityModules[b]
  if prioA and prioB then
    return prioA < prioB
  end
  if prioA then return true end
  if prioB then return false end
  return a < b
end)
-------------
-- SYNC STARTS
-------------
if resourceName == "w_lib" then
  local resourceStarted = {}

  AddEventHandler("w_lib:resourceStarted", function(resource)
    resourceStarted[resource] = true
    TriggerEvent("w_lib:onResourceStart", resource)
  end)

  AddEventHandler("onResourceStop", function(resourceName)
    resourceStarted[resourceName] = nil
  end)

  exports("isResourceStarted", function(resource)
    return resourceStarted[resource] == true
  end)
end

local onReadyActions = {}
function w.onResourceStart(resource, cb)
  w.waitLibLoading()
  onReadyActions[resource] = onReadyActions[resource] or {}
  table.insert(onReadyActions[resource], cb)
  local isStarted = exports.w_lib:isResourceStarted(resource)
  if isStarted then
    CreateThreadNow(cb)
  end
end

AddEventHandler("w_lib:onResourceStart", function(resource)
  if not onReadyActions[resource] then return end
  for i = 1, #onReadyActions[resource] do
    CreateThreadNow(onReadyActions[resource][i])
  end
end)



-------------
-- LOAD REQUIRED MODULES
-------------
for i = 1, #modules do
  local name = modules[i]
  w.require(name)
  if name == "hook" then
    createExport("registerAction", w.hook.registerAction)
    createExport("RegisterAction", w.hook.RegisterAction)
    createExport("registerFilter", w.hook.registerFilter)
    createExport("RegisterFilter", w.hook.RegisterFilter)
  elseif name == "versionChecker" and context == "server" then
    -- createExport("GetScriptVersion", w.versionChecker.GetScriptVersion)
    createExport("StopAddon", w.versionChecker.stopAddon)
  end
end
w.libLoaded = true
w.ready(function()
  TriggerEvent("w_lib:resourceStarted", resourceName)
end)
