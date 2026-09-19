local eventListened = {}
local groupListened = {}
local allEventListened = false
local running = false

w.require("dataview")
w.require("file")
w.file.load("game-events.data")

local function GetEventData(...) return InvokeNative(0x57EC5FA4D4D6AFCA, ...) end

local pump -- defined below, once listenEvents exists

AddEventHandler("w_lib:gameEvents:register", function(eventName)
  if eventName == "all" then
    allEventListened = true
    groupListened[0] = true
    groupListened[1] = true
    groupListened[2] = true
    groupListened[3] = true
  else
    local eventHash = GetHashFromString(eventName)
    local eventData = AllGameEvents[eventHash]
    eventListened[eventHash] = true
    groupListened[eventData.group] = true
  end
  pump()
end)

local function getDataFromEvent(eventHash, index)
  local eventData = AllGameEvents[eventHash]

  local datas = {}
  datas["event_name"] = eventData.name

  local size = eventData.size
  local dataStruct = DataView.ArrayBuffer(8 * size)
  for i = 0, size - 1 do
    local info = eventData.data[i + 1]
    if info.type == "int" then
      dataStruct:SetInt32(8 * i, 0)
    elseif info.type == "float" then
      dataStruct:SetFloat32(8 * i, 0)
    elseif info.type == "bool" then
      dataStruct:SetInt32(8 * i, 0)
    end
  end
  local isDataExist = GetEventData(eventData.group, index, dataStruct:Buffer(), size)
  if not isDataExist then return false end
  for i = 0, size - 1 do
    local info = eventData.data[i + 1]
    if info.type == "int" then
      datas[info.name] = dataStruct:GetInt32(8 * i)
    elseif info.type == "float" then
      datas[info.name] = dataStruct:GetFloat32(8 * i)
    elseif info.type == "bool" then
      datas[info.name] = dataStruct:GetInt32(8 * i)
    end
    datas["value_" .. i] = dataStruct:GetInt32(8 * i)
  end
  return datas
end

local function getEventNameFromHash(eventHash)
  return AllGameEvents[eventHash].name
end

local function processEvent(groupId, index)
  local eventHash = GetEventAtIndex(groupId, index)
  if not eventListened[eventHash] and not allEventListened then return end
  local data = getDataFromEvent(eventHash, index)
  if not data then return false end
  local eventData = AllGameEvents[eventHash]
  if eventListened[eventHash] then
    TriggerEvent("w_lib:gameEvents:" .. eventData.name, data)
  end
  if allEventListened then
    TriggerEvent("w_lib:gameEvents:all", data)
  end
end

local function listenEvents()
  for groupId, _ in pairs(groupListened) do
    local size = GetNumberOfEvents(tonumber(groupId))
    if size > 0 then
      for i = 0, size - 1 do
        processEvent(groupId, i)
      end
    end
  end
end

-- ★ لا حلقةَ إطارٍ قبل أن يسجّل أحد. الحلقة الأبديّة كانت تدور في كلِّ إطار ولو
--   لم يستمع مورد واحد لأيِّ حدث، وهي وحدَها ما يمنع resmon من قراءة 0.00 عند
--   السكون — كما في resource/frame/client.lua. فتبدأ عند أوّل تسجيل لا قبله.
pump = function()
  if running or next(groupListened) == nil then return end
  running = true

  CreateThread(function()
    while next(groupListened) ~= nil do
      listenEvents()
      Wait(0)
    end
    running = false
  end)
end

pump() -- a listener may have registered before this file finished loading
