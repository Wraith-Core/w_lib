-------------
-- FRAMEWORK CLASS — Wraith Core (w_core)
-- WCore shares the RSG-Core PlayerData contract (citizenid, charinfo, job.grade.level,
-- money.cash / money.gold). Items go through the library's inventory bridge (invbridge),
-- which resolves w_inventory / any other bag the server runs.
-------------
local WCore = exports.w_core:GetCoreObject()
w.framework.core = WCore

local inventoriesCreated = {}
local moneyTypes = { [0] = "cash", [1] = "gold", [2] = "rol" }

local function moneyType(kind)
  if type(kind) == "string" then return kind end
  return moneyTypes[tonumber(kind) or 0] or "cash"
end

-------------
-- USER CLASS
-------------

---Init the w.framework.UserClass
---@param source integer Player server ID
---@return any user w.framework.UserClass if the user exists
function w.framework.UserClass:get(source)
  if not tonumber(source) then
    return false, eprint("w.framework.UserClass:get() -> source value is wrong:", GetValue(source, "nil"))
  end

  local data = WCore.Functions.GetPlayer(tonumber(source))
  if not data then
    -- no character loaded yet (character selection / connecting): not an error
    return false
  end

  -- one object per player: the RSG adapter keeps `data` on the class, which makes every
  -- user share the last player fetched
  local user = setmetatable({}, { __index = self })
  user.source = tonumber(source)
  user.data = data
  return user
end

function w.framework.UserClass:getMoney(kind)
  local name = moneyType(kind)
  if name == "rol" then return 0 end
  return self.data.Functions.GetMoney(name) or 0
end

function w.framework.UserClass:removeMoney(amount, kind)
  local name = moneyType(kind)
  if name == "rol" then return false end
  return self.data.Functions.RemoveMoney(name, amount, "w_lib") and true or false
end

function w.framework.UserClass:addMoney(amount, kind)
  local name = moneyType(kind)
  if name == "rol" then return false end
  return self.data.Functions.AddMoney(name, amount, "w_lib") and true or false
end

function w.framework.UserClass:getIdentifiers()
  local pd = self.data.PlayerData
  return {
    identifier = pd.citizenid,
    charid = pd.cid or 0,
    license = pd.license,
  }
end

function w.framework.UserClass:getJob()
  local job = self.data.PlayerData.job
  return job and job.name or "unemployed"
end

---@return number jobGrade
function w.framework.UserClass:getJobGrade()
  local job = self.data.PlayerData.job
  local grade = job and job.grade
  if type(grade) == "table" then return tonumber(grade.level) or 0 end
  return tonumber(grade) or 0
end

function w.framework.UserClass:setJob(job, grade)
  return self.data.Functions.SetJob(job, grade) and true or false
end

function w.framework.UserClass:getRPName()
  local info = self.data.PlayerData.charinfo or {}
  return ("%s %s"):format(info.firstname or "", info.lastname or "")
end

-------------
-- INVENTORY (through the library's inventory bridge)
-------------

function w.framework:canUseItem(source, item, amount, meta, remove)
  amount = tonumber(amount) or 1
  local count = exports.w_lib:InvGetItemCount(source, item, meta) or 0
  if count < amount then return false end
  if remove then
    return exports.w_lib:InvRemoveItem(source, item, amount, meta) == true
  end
  return true
end

function w.framework:getItemCount(source, item, meta)
  return exports.w_lib:InvGetItemCount(source, item, meta) or 0
end

function w.framework:registerUseItem(item, closeAfterUsed, callback)
  if type(closeAfterUsed) == "function" or (type(closeAfterUsed) == "table" and getmetatable(closeAfterUsed)?.__call) then
    callback = closeAfterUsed
    closeAfterUsed = true
  end
  return exports.w_lib:InvRegisterUsableItem(item, closeAfterUsed, function(source, data)
    callback(source, { metadata = data and data.metadata or {}, slot = data and data.slot })
  end)
end

function w.framework:giveItem(source, item, quantity, meta)
  return exports.w_lib:InvAddItem(source, item, tonumber(quantity) or 1, meta) == true
end

function w.framework:createInventory(id, name, invConfig)
  invConfig = invConfig or {}
  inventoriesCreated[id] = {
    id = id,
    name = name,
    config = table.copy(invConfig),
  }
  -- the bag counts grams; jo scripts configure kilograms
  local maxWeight = invConfig.maxWeight and invConfig.maxWeight * 1000 or nil
  exports.w_lib:InvRegisterStash(id, name, invConfig.slots or 50, maxWeight)
end

function w.framework:openInventory(source, id)
  return exports.w_lib:InvOpenStash(source, id)
end

function w.framework:addItemInInventory(source, invId, item, quantity, metadata, needWait)
  return exports.w_lib:InvAddItemToStash(invId, item, tonumber(quantity) or 1, metadata)
end

function w.framework:getItemsFromInventory(invId)
  local ok, rows = pcall(function() return exports.w_lib:InvGetStashContents(invId) end)
  local items = {}
  if not ok or type(rows) ~= "table" then return items end
  for i = 1, #rows do
    local row = rows[i]
    items[i] = { metadata = row.metadata, amount = row.count or row.amount, item = row.name }
  end
  return items
end

-------------
-- SKIN & CLOTHES — w_creators owns the appearance; the bridge reads what the core stores.
-------------

function w.framework:standardizeClothesInternal(clothes)
  return clothes or {}
end

function w.framework:revertClothesInternal(standard)
  return standard or {}
end

function w.framework:standardizeSkinInternal(skin)
  return skin or {}
end

function w.framework:revertSkinInternal(standard)
  return standard or {}
end

local function appearance(source)
  local ok, data = pcall(function() return exports.w_creators:GetAppearance(source) end)
  if ok and type(data) == "table" then return data end
  local player = WCore.Functions.GetPlayer(source)
  local meta = player and player.PlayerData.metadata or {}
  return type(meta.appearance) == "table" and meta.appearance or {}
end

function w.framework:getUserClothesInternal(source)
  local data = appearance(source)
  return data.clothes or data.comps or {}
end

function w.framework:updateUserClothesInternal(source, clothes, overwrite)
  pcall(function() exports.w_creators:SetClothes(source, clothes, overwrite) end)
end

function w.framework:getUserSkinInternal(source)
  local data = appearance(source)
  return data.skin or data
end

function w.framework:updateUserSkinInternal(source, skin, overwrite)
  pcall(function() exports.w_creators:SetSkin(source, skin, overwrite) end)
end

function w.framework:createUser(source, data, spawnCoordinate, isDead)
  data = GetValue(data, {})
  local convertData = {
    source = source,
    charinfo = {
      firstname = GetValue(data.firstname, ""),
      lastname = GetValue(data.lastname, ""),
      gender = data.skin and data.skin.sex == 1 and "0" or "1",
    },
  }
  if WCore.Player and WCore.Player.CheckPlayerData then
    WCore.Player.CheckPlayerData(source, convertData)
  end
end

-------------
-- CHARACTER SELECTION
-------------

local pendingCharacterSelection = {}

AddEventHandler("w_creators:server:characterCreated", function(source)
  pendingCharacterSelection[source] = true
end)

AddEventHandler("WCore:Server:PlayerLoaded", function(Player)
  local source = Player and Player.PlayerData and Player.PlayerData.source
  if not source then return end
  ExecCharacterSelectedCallback(source, pendingCharacterSelection[source] == true)
  pendingCharacterSelection[source] = nil
end)

AddEventHandler("playerDropped", function()
  local source = source
  pendingCharacterSelection[source] = nil
end)
