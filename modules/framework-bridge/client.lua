-------------
-- VARIABLES
-------------
local myIdentifiers = {}

-------------
-- CORE
-------------
w.framework:loadCoreFiles("client")

--- A function to get the user identifiers
function w.framework:getMyIdentifiers()
  if table.isEmpty(myIdentifiers) then
    myIdentifiers = w.callback.triggerServer(w.resourceName .. ":server:framework:getPlayerIdentifiers")
  end
  return myIdentifiers
end

-------------
-- CHARACTER SELECTION (client mirror of the server's onCharacterSelected)
-- Fires once per character load on the core's own "loaded" signal, whatever the core:
-- Wraith Core / RSG / QBR announce the player object, VORP the character table.
-------------
local charSelectedCallbacks = {}
local characterLoaded = false

local function fireCharacterSelected(...)
  characterLoaded = true
  local args = table.pack(...)
  for i = 1, #charSelectedCallbacks do
    local cb = charSelectedCallbacks[i]
    CreateThread(function() cb(table.unpack(args, 1, args.n)) end)
  end
end

for _, event in ipairs({
  "WCore:Client:OnPlayerLoaded",
  "RSGCore:Client:OnPlayerLoaded",
  "qbr-core:client:OnPlayerLoaded",
  "QBCore:Client:OnPlayerLoaded",
  "QRCore:Client:OnPlayerLoaded",
  "vorp:SelectedCharacter",
  "vorp_core:Client:OnPlayerReady",
  "redemrp:SelectedCharacter",
}) do
  RegisterNetEvent(event, function(...)
    fireCharacterSelected(...)
  end)
end

for _, event in ipairs({
  "WCore:Client:OnPlayerUnload", "RSGCore:Client:OnPlayerUnload", "qbr-core:client:OnPlayerUnload",
  "vorp:PlayerLogout", "vorp_core:Client:OnPlayerUnload",
}) do
  RegisterNetEvent(event, function() characterLoaded = false end)
end

--- Callback when the local player's character is loaded (the client side of the server's
--- onCharacterSelected). Called at once when a character is already loaded.
--- @param cb function (The callback function; receives what the core's loaded event carried)
function w.framework:onCharacterSelected(cb)
  if type(cb) ~= "function" and not (type(cb) == "table" and getmetatable(cb) and getmetatable(cb).__call) then return end
  table.insert(charSelectedCallbacks, cb)
  if characterLoaded then CreateThread(cb) end
end

--- Is a character loaded on this client (as far as the core's events told us)?
---@return boolean
function w.framework:isCharacterLoaded()
  return characterLoaded
end

local function isCallable(cb)
  return type(cb) == "function" or (type(cb) == "table" and getmetatable(cb) and getmetatable(cb).__call ~= nil)
end

local function delegateClientExport(exportName, cb)
  if w.resourceName ~= "w_lib" and type(exports) == "table" and exports.w_lib then
    local ok, registered = pcall(function()
      return exports.w_lib[exportName](exports.w_lib, cb)
    end)
    if ok and registered == true then
      return true
    end
  end
  return false
end

local unloadedCallbacks = {}
local jobUpdateCallbacks = {}
local gangUpdateCallbacks = {}
local dutyChangeCallbacks = {}
local playerDataCallbacks = {}
local moneyChangeCallbacks = {}

local function fireLocal(list, ...)
  for i = 1, #list do
    pcall(list[i], ...)
  end
end

for _, event in ipairs({
  "WCore:Client:OnPlayerUnload", "RSGCore:Client:OnPlayerUnload", "qbr-core:client:OnPlayerUnload",
  "QBCore:Client:OnPlayerUnload", "vorp:PlayerLogout", "vorp:playerUnloaded", "vorp_core:Client:OnPlayerUnload",
}) do
  RegisterNetEvent(event, function()
    fireLocal(unloadedCallbacks)
  end)
end

for _, event in ipairs({
  "WCore:Client:OnJobUpdate", "RSGCore:Client:OnJobUpdate", "QBCore:Client:OnJobUpdate",
  "qbr-core:client:OnJobUpdate", "w_lib:fw:client:jobUpdate",
}) do
  RegisterNetEvent(event, function(job)
    fireLocal(jobUpdateCallbacks, job)
  end)
end

for _, event in ipairs({
  "WCore:Client:OnGangUpdate", "RSGCore:Client:OnGangUpdate", "QBCore:Client:OnGangUpdate",
  "qbr-core:client:OnGangUpdate",
}) do
  RegisterNetEvent(event, function(gang)
    fireLocal(gangUpdateCallbacks, gang)
  end)
end

for _, event in ipairs({
  "WCore:Client:SetDuty", "RSGCore:Client:SetDuty", "QBCore:Client:SetDuty",
  "qbr-core:client:SetDuty", "w_lib:fw:client:dutyChanged",
}) do
  RegisterNetEvent(event, function(onDuty)
    fireLocal(dutyChangeCallbacks, onDuty == true)
  end)
end

for _, event in ipairs({
  "WCore:Player:SetPlayerData", "RSGCore:Player:SetPlayerData", "QBCore:Player:SetPlayerData",
  "qbr-core:player:SetPlayerData",
}) do
  RegisterNetEvent(event, function(pd)
    fireLocal(playerDataCallbacks, pd)
  end)
end

RegisterNetEvent("hud:client:OnMoneyChange", function(kind, absDelta, isRemove)
  fireLocal(moneyChangeCallbacks, kind, tonumber(absDelta) or 0, isRemove == true)
end)
RegisterNetEvent("RSGCore:Client:OnMoneyChange", function(kind, amount, changeType)
  fireLocal(moneyChangeCallbacks, kind, tonumber(amount) or 0, changeType == "remove" or changeType == true)
end)
RegisterNetEvent("vorp:updateUi", function(rawJson)
  fireLocal(moneyChangeCallbacks, "vorp", 0, false, rawJson)
end)

function w.framework:onCharacterUnloaded(cb)
  if not isCallable(cb) then return false end
  if delegateClientExport("FwOnCharacterUnloaded", cb) then return true end
  table.insert(unloadedCallbacks, cb)
  return true
end

function w.framework:onJobUpdate(cb)
  if not isCallable(cb) then return false end
  if delegateClientExport("FwOnJobUpdate", cb) then return true end
  table.insert(jobUpdateCallbacks, cb)
  return true
end

function w.framework:onGangUpdate(cb)
  if not isCallable(cb) then return false end
  if delegateClientExport("FwOnGangUpdate", cb) then return true end
  table.insert(gangUpdateCallbacks, cb)
  return true
end

function w.framework:onDutyChange(cb)
  if not isCallable(cb) then return false end
  if delegateClientExport("FwOnDutyChange", cb) then return true end
  table.insert(dutyChangeCallbacks, cb)
  return true
end

function w.framework:onPlayerData(cb)
  if not isCallable(cb) then return false end
  if delegateClientExport("FwOnPlayerData", cb) then return true end
  table.insert(playerDataCallbacks, cb)
  return true
end

function w.framework:onMoneyChange(cb)
  if not isCallable(cb) then return false end
  if delegateClientExport("FwOnMoneyChange", cb) then return true end
  table.insert(moneyChangeCallbacks, cb)
  return true
end

-------------
-- Inventories
-------------
w.framework:loadInventoryFiles("client")
