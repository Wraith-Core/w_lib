-------------
-- citizen (server) — who a citizen id is, and whether he is in the game right now.
--
--   w.citizen.resolve(input [, opts])   -> target | nil, 'invalid_id' | 'not_found'
--   w.citizen.requireOnline(input [, opts]) -> target | nil, reason [, offlineTarget]
--   w.citizen.fromSource(serverId)      -> target | nil, 'invalid_id' | 'not_found'
--   w.citizen.idOf(serverId)            -> '12' | nil
--
--   target = { citizenid = '12', source = 7 | nil, online = true | false, name = 'John Doe',
--              license = 'license:...', row = <the saved players row, offline only> }
--
-- The answer comes from w_core (exports.w_core:ResolveCitizen, the owner of the id) whenever
-- w_core runs. Without it (another core) the library's framework bridge answers instead: the
-- online players first, then the core's character table.
-------------
local citizen = w.createModule("citizen")

local MAX_SERVER_ID = 65535

local function trim(text)
  return (tostring(text or ""):gsub("^%s+", ""):gsub("%s+$", ""))
end

local function connected(src)
  return src ~= nil and GetPlayerName(src) ~= nil
end

-- A character id as the bridge hands it (a string on RSG / w_core, a number on VORP) in the
-- canonical form; an id outside the known shapes is compared as it is.
local function canonical(id)
  if id == nil then return nil end
  return citizen.normalize(id) or tostring(id)
end

-------------
-- w_core
-------------

-- Inside w_core itself the resolver is called directly: no export round trip, and it already
-- answers while w_core is still 'starting' (its own commands load before the state flips).
-- Returns false when w_core cannot be asked, so the caller falls back to the bridge.
local function askCore(cid)
  local ok, info, reason
  if GetCurrentResourceName() == "w_core" and type(WCore) == "table" and type(WCore.Citizen) == "table"
      and WCore.Citizen.Resolve then
    ok, info, reason = pcall(WCore.Citizen.Resolve, cid)
  elseif GetResourceState("w_core") == "started" then
    ok, info, reason = pcall(function() return exports.w_core:ResolveCitizen(cid) end)
  else
    return false
  end
  -- an older w_core without the export, or a database error: the bridge still knows the answer
  if not ok then return false end
  if type(info) ~= "table" then return nil, reason == "invalid_id" and "invalid_id" or "not_found" end
  local src = tonumber(info.source)
  -- w_core read its player list a moment ago; a player who dropped since is not reachable
  if src and not connected(src) then src = nil end
  return {
    citizenid = tostring(info.citizenid or cid),
    source = src,
    online = src ~= nil,
    name = trim(info.name),
    license = info.license,
    row = info.row,
  }
end

-------------
-- framework bridge (no w_core)
-------------

local function onlineTarget(src, cid)
  local okName, name = pcall(function() return exports.w_lib:FwGetCharacterName(src) end)
  local okLicense, license = pcall(function() return exports.w_lib:FwGetIdentifier(src) end)
  return {
    citizenid = cid,
    source = src,
    online = true,
    name = okName and trim(name) or "",
    license = okLicense and license or nil,
  }
end

local function characterOf(src)
  local ok, id = pcall(function() return exports.w_lib:FwGetCharacterIdentifier(src) end)
  return ok and canonical(id) or nil
end

local function onlineByBridge(cid)
  for _, id in ipairs(GetPlayers()) do
    local src = tonumber(id)
    if src and characterOf(src) == cid then return onlineTarget(src, cid) end
  end
  return nil
end

local function offlineByBridge(cid)
  local ok, rows = pcall(function() return exports.w_lib:FwCharacterRows("citizenid", cid) end)
  local row = ok and type(rows) == "table" and rows[1] or nil
  if type(row) ~= "table" then return nil end
  -- RSG family: names inside the charinfo JSON; VORP: firstname / lastname columns
  local info = row.charinfo
  if type(info) == "string" then
    local okJson, decoded = pcall(json.decode, info)
    info = okJson and decoded or nil
  end
  if type(info) ~= "table" then info = row end
  return {
    citizenid = cid,
    source = nil,
    online = false,
    name = trim(("%s %s"):format(info.firstname or "", info.lastname or "")),
    license = row.license or row.identifier,
    row = row,
  }
end

local function byCitizenId(cid)
  local target, reason = askCore(cid)
  if target ~= false then return target, reason end
  target = onlineByBridge(cid) or offlineByBridge(cid)
  if target then return target end
  return nil, "not_found"
end

-------------
-- API
-------------

--- The character in play on this server id. For an id the caller already knows is a server id
--- (a player picked from a nearby list, the source of an event). Typed input goes through
--- resolve(), where a server id is written '#7'.
---@param serverId integer|string
---@return table|nil target
---@return string|nil reason ('invalid_id' | 'not_found': nobody on that id, or no character in play yet)
function citizen.fromSource(serverId)
  local src = tonumber(serverId)
  if not src or src ~= src or src < 1 or src > MAX_SERVER_ID or src % 1 ~= 0 then return nil, "invalid_id" end
  src = math.tointeger(src)
  if not connected(src) then return nil, "not_found" end
  local cid = characterOf(src)
  if not cid then return nil, "not_found" end
  local target = askCore(cid)
  if target ~= false then
    if target and target.source == src then return target end
    -- the character left play between the two reads
    return nil, "not_found"
  end
  return onlineTarget(src, cid)
end

--- The citizen id of the character in play on this server id ('12'), or nil. What a resource
--- stores for a player: never his server id.
---@param serverId integer|string
---@return string|nil
function citizen.idOf(serverId)
  local src = tonumber(serverId)
  if not src or not connected(src) then return nil end
  return characterOf(src)
end

--- Who this id is. `input` is a citizen id (string or number, any spaces, the old random form,
--- Arabic digits), '#<n>' for an explicit server id, 'me' (only with opts.self), or a target
--- table (asked again: is he still online?).
---@param input any
---@param opts? { self?: integer } (self: the caller's server id, so 'me' can name him)
---@return table|nil target
---@return string|nil reason ('invalid_id' | 'not_found')
function citizen.resolve(input, opts)
  if type(input) == "table" then
    if input.citizenid ~= nil then
      input = tostring(input.citizenid)
    elseif input.source ~= nil then
      return citizen.fromSource(input.source)
    else
      return nil, "invalid_id"
    end
  end
  local kind, value = citizen.parse(input)
  if kind == "server" then return citizen.fromSource(value) end
  if kind == "self" then
    local caller = type(opts) == "table" and opts.self or nil
    if caller then return citizen.fromSource(caller) end
    return nil, "invalid_id"
  end
  if kind ~= "citizen" then return nil, "invalid_id" end
  return byCitizenId(value)
end

--- resolve(), for an action that needs the player in the game (teleport, revive, a chat
--- message). An offline character answers nil, 'offline' and the offline target as a third
--- value, so the message can still name him.
---@param input any
---@param opts? { self?: integer }
---@return table|nil target
---@return string|nil reason ('invalid_id' | 'not_found' | 'offline')
---@return table|nil offlineTarget
function citizen.requireOnline(input, opts)
  local target, reason = citizen.resolve(input, opts)
  if not target then return nil, reason end
  if not target.online then return nil, "offline", target end
  return target
end

return citizen
