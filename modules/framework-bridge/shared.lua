w.require("string")
w.require("resource")

---@class FrameworkClass
---@field core table (The link with the framework)
---@field inv table (The link with the inventory)
---@field inventoryItems table (The list of items)
w.createModule("framework")
w.framework.core = {}
w.framework.inv = {}
w.framework.inventoryItems = {}

local supportedCores = w.file.load("framework-bridge.cores.detector_shared")
local supportedInventories = w.file.load("framework-bridge.inventories.detector_shared")
local coresStarted = {}
local inventoriesStarted = {}

local function waitForResources(resources)
  for r = 1, #resources do
    local resource = resources[r]
    if resource:sub(1, 1) ~= "!" then
      resource = resource:extractConvarComparator()
      while GetResourceState(resource) ~= "started" do
        -- bprint("Waiting start of " .. resource)
        Wait(1000)
      end
    end
  end
end


local function isResourcesMatch(resources)
  for i = 1, #resources do
    if not w.resource.isConvarMatching(resources[i]) then
      return false
    end
  end
  return true
end

local function getMatchedEntries(entries)
  local matchedEntries = {}
  for e = 1, #entries do
    local entry = entries[e]
    local isMatch = isResourcesMatch(entry.matchResources)
    if isMatch then
      waitForResources(entry.matchResources)
      matchedEntries[#matchedEntries + 1] = entry
      gprint(("%s detected"):format(entry.name))
      -- an exclusive entry (Wraith Core) provides the other names itself: stop here so the
      -- aliases are not reported as extra cores
      if entry.exclusive then break end
    end
  end
  return matchedEntries
end

local function detectCores()
  if #coresStarted > 0 then return coresStarted end
  coresStarted = getMatchedEntries(supportedCores)

  if #coresStarted == 0 then
    eprint("=====================================")
    eprint("No compatible core found on your server")
    eprint("=====================================")
    return {}
  end

  if #coresStarted > 1 then
    oprint("=====================================")
    oprint("Warning: multiple cores are started on your server")
    oprint("=====================================")
  end
  return coresStarted
end

local function detectInventories()
  if #inventoriesStarted > 0 then return inventoriesStarted end
  inventoriesStarted = getMatchedEntries(supportedInventories)

  if #inventoriesStarted == 0 then
    -- Inventory resources can start after consumers when an entire folder is
    -- ensured. The central _custom adapter resolves w_lib's active inventory
    -- lazily, so an empty result during startup is valid and not an error.
    return {}
  end

  if #inventoriesStarted > 1 then
    oprint("=====================================")
    oprint("Warning: multiple inventories are started on your server")
    oprint("=====================================")
  end
  return inventoriesStarted
end

---@autodoc:config ignore:true
function w.framework:getFrameworkDetected()
  local cores = detectCores()
  if #cores == 0 then return false end
  return cores[1]
end

--- Returns the id of the framework detected (both sides)
---@return string|nil (`"vorp"`, `"redemrp_old"`, `"redemrp_2023"`, `"qbr"`, `"rsg"`, `"rsg_v2"`, `"qr"`, `"rpx"`, `"tpz"`, `"frp"`)
function w.framework:get()
  local detected = self:getFrameworkDetected()
  return detected and detected.id or nil
end

--- Compares the detected framework with a name (case-insensitive).
--- A versioned id matches its family too: `is("rsg")` is true on `rsg_v2`.
---@param name string
---@return boolean
function w.framework:is(name)
  local coreId = self:get()
  if not coreId or type(name) ~= "string" then return false end
  coreId, name = coreId:lower(), name:lower()
  if coreId == name then return true end
  return coreId:gsub("_v%d+$", "") == name
end

--- The framework's core object as the adapter stored it (RSGCore / QBCore / VORP core).
--- nil while nothing has been stored -- VORP keeps no core object on the client.
---@return table|nil
function w.framework:getCore()
  local core = rawget(self, "core")
  if type(core) == "table" and next(core) ~= nil then return core end
  return nil
end

--- The core object fetched from the running framework (both sides), cached in
--- w.framework.core. On Wraith Core it is WCore (exports.w_core:GetCoreObject()), on RSG
--- RSGCore, on QBR the QBR shape w_lib builds, on VORP the VORP core (server only).
--- Consumers assign it at load: `WCore = w.framework:getCoreObject()`.
---@return table|nil
function w.framework:getCoreObject()
  local core = self:getCore()
  if core then return core end

  local detected = self:getFrameworkDetected()
  local folder = detected and detected.folder
  local id = detected and detected.id
  local ok, obj

  if folder == "w_core" or GetResourceState("w_core") == "started" then
    ok, obj = pcall(function() return exports.w_core:GetCoreObject() end)
  elseif id == "rsg" or id == "rsg_v2" then
    ok, obj = pcall(function() return exports["rsg-core"]:GetCoreObject() end)
  elseif id == "qbr" then
    ok, obj = pcall(function() return exports["qbr-core"]:GetCoreObject() end)
    if not ok or type(obj) ~= "table" then
      ok, obj = pcall(function() return exports.w_lib:FwGetCore() end)
    end
  elseif id == "qr" then
    ok, obj = pcall(function() return exports["qr-core"]:GetCoreObject() end)
  elseif id == "vorp" then
    ok, obj = pcall(function() return exports.vorp_core:GetCore() end)
  elseif id == "rpx" then
    ok, obj = pcall(function() return exports["rpx-core"]:GetCoreObject() end)
  elseif id == "tpz" then
    ok, obj = pcall(function() return exports.tpz_core:getCoreAPI() end)
  end

  if ok and type(obj) == "table" then
    rawset(self, "core", obj)
    return obj
  end
  return nil
end

--- Is the running core Wraith Core (w_core hosting the rsg-core / vorp_core / qbr-core names)?
---@return boolean
function w.framework:isWraith()
  local detected = self:getFrameworkDetected()
  return detected and detected.folder == "w_core" or false
end

local function loadFile(...)
  local path = ("framework-bridge.%s.%s.%s"):format(...)
  if w.file.isExist(path) then
    w.file.load(path)
  end
end

local function loadFiles(mainFolder, folders, file)
  if #folders == 0 then return false end
  for f = 1, #folders do
    local folder = folders[f]
    loadFile(mainFolder, folder.folder, file)
  end
  loadFile(mainFolder, "_custom", file)
  return true
end

---@autodoc:config ignore:true
function w.framework:loadCoreFiles(file)
  local cores = detectCores()
  if #cores == 0 then return false end
  return loadFiles("cores", cores, file)
end

function w.framework:loadInventoryFiles(file)
  local inventories = detectInventories()
  if #inventories == 0 then
    loadFile("inventories", "_custom", file)
    return true
  end
  return loadFiles("inventories", inventories, file)
end

detectCores()
detectInventories()

local function refreshInventoryItems()
  if w.resourceName == "w_lib" or GetResourceState("w_lib") ~= "started" then return end

  local ok, items = pcall(function()
    return exports.w_lib:w_framework_getInventoryItems()
  end)

  if ok and type(items) == "table" and not table.isEmpty(items) then
    w.framework.inventoryItems = items
  end
end

if w.resourceName ~= "w_lib" then
  w.ready(function()
    -- A consumer may become ready before w_inventory finishes starting.
    -- Refresh through the guarded helper and retry silently; never let an
    -- optional item catalogue abort the consumer resource during boot.
    for _attempt = 1, 60 do
      refreshInventoryItems()
      if not table.isEmpty(w.framework.inventoryItems) then return end
      Wait(500)
    end
  end)
end

--- A function to get the list of items
---@return table (The list of items)
---@ignore
function w.framework:getItems()
  if table.isEmpty(w.framework.inventoryItems) then refreshInventoryItems() end
  return w.framework.inventoryItems
end

--- A function to get an item data
---@param item string (The name of the item)
---@return table|false (The item data or false if not found)
---@ignore
function w.framework:getItemData(item)
  if table.isEmpty(w.framework.inventoryItems) then refreshInventoryItems() end
  if not w.framework.inventoryItems[item] then
    eprint("Item %s not found", item)
    return
    {
      label = "Not exist"
    }
  end
  return w.framework.inventoryItems[item]
end

local function addItemDataToCost(cost)
  if type(cost) ~= "table" or not cost.item then return cost end

  local itemData = w.framework:getItemData(cost.item) or {}

  for key, value in pairs(itemData) do
    if cost[key] == nil then
      cost[key] = value
    end
  end

  return cost
end

--- A function to add inventory item data to every item cost inside a price
---@param price table (The price to augment)
---@return table (The mutated price)
function w.framework:addItemDataToPrice(price)
  if type(price) ~= "table" then return price end

  if price.item then
    return addItemDataToCost(price)
  end

  if type(price.costs) == "table" then
    for i = 1, #price.costs do
      addItemDataToCost(price.costs[i])
    end
    return price
  end

  if type(price.prices) == "table" then
    for i = 1, #price.prices do
      w.framework:addItemDataToPrice(price.prices[i])
    end
    return price
  end

  for i = 1, #price do
    w.framework:addItemDataToPrice(price[i])
  end

  return price
end

-------------
-- Shortcut
-------------
w.fw = w.framework
