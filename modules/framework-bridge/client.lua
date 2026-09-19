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

-------------
-- Inventories
-------------
w.framework:loadInventoryFiles("client")
