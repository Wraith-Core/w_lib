-- ════════════════════════════════════════════════════════════════════════════
-- w_lib — fwbridge/client/events.lua
--   Normalized client lifecycle, job, gang, duty, playerdata, money, pvp, and
--   shared-update subscriptions with invoking-resource cleanup.
-- ════════════════════════════════════════════════════════════════════════════
if IsDuplicityVersion() then return end

WFW = WFW or {}
WFW._Client = WFW._Client or {}

local function isCallable(cb)
    return type(cb) == 'function' or (type(cb) == 'table' and getmetatable(cb) and getmetatable(cb).__call ~= nil)
end

local function isWCore()
    return WFW.Host == 'w_core' or (type(GetResourceState) == 'function' and GetResourceState('w_core') == 'started')
end

local callbacks = {
    loaded = {},
    unloaded = {},
    jobUpdate = {},
    gangUpdate = {},
    dutyChange = {},
    playerData = {},
    moneyChange = {},
    pvpChange = {},
    sharedUpdate = {},
}

local function registerCallback(list, cb)
    if not isCallable(cb) then return false end
    local res = (type(GetInvokingResource) == 'function' and GetInvokingResource()) or 'w_lib'
    list[#list + 1] = { fn = cb, resource = res }
    return true
end

local function fireList(list, ...)
    if #list == 0 then return end
    local snapshot = {}
    for i = 1, #list do snapshot[i] = list[i] end
    for i = 1, #snapshot do
        pcall(snapshot[i].fn, ...)
    end
end

local function pruneResource(resName)
    if type(resName) ~= 'string' or resName == '' then return end
    for _, list in pairs(callbacks) do
        for i = #list, 1, -1 do
            if list[i].resource == resName then
                table.remove(list, i)
            end
        end
    end
end

AddEventHandler('onClientResourceStop', pruneResource)
AddEventHandler('onResourceStop', pruneResource)

local characterLoaded = false
local hasExplicitLoadState = false
local lastDuty = nil

WFW._Client.isLoaded = function()
    return characterLoaded
end

WFW._Client.hasExplicitState = function()
    return hasExplicitLoadState
end

local function normalizeJob(job)
    if type(job) ~= 'table' then return job end
    local name = job.name or 'unemployed'
    local sharedJobs = WFW._Shared and WFW._Shared.getSharedJobs and WFW._Shared.getSharedJobs() or {}
    local def = sharedJobs[name]
    local gradeObj = type(job.grade) == 'table' and job.grade or nil
    local gradeLevel = gradeObj and tonumber(gradeObj.level) or tonumber(job.grade) or 0
    local gDef = def and type(def.grades) == 'table' and (def.grades[gradeLevel] or def.grades[tostring(gradeLevel)]) or nil
    local out = {}
    for k, v in pairs(job) do out[k] = v end
    out.name = name
    out.label = job.label or (def and def.label) or name
    out.label_ar = job.label_ar or (def and def.label_ar) or out.label
    out.onduty = job.onduty == nil and true or (job.onduty == true)
    out.isboss = job.isboss == true or (gradeObj and gradeObj.isboss == true) or (gDef and gDef.isboss == true) or false
    return out
end

local function normalizeGang(gang)
    if type(gang) ~= 'table' then return gang end
    local name = gang.name or 'none'
    local sharedGangs = WFW._Shared and WFW._Shared.getSharedGangs and WFW._Shared.getSharedGangs() or {}
    local def = sharedGangs[name]
    local gradeObj = type(gang.grade) == 'table' and gang.grade or nil
    local gradeLevel = gradeObj and tonumber(gradeObj.level) or tonumber(gang.grade) or 0
    local gDef = def and type(def.grades) == 'table' and (def.grades[gradeLevel] or def.grades[tostring(gradeLevel)]) or nil
    local out = {}
    for k, v in pairs(gang) do out[k] = v end
    out.name = name
    out.label = gang.label or (def and def.label) or name
    out.label_ar = gang.label_ar or (def and def.label_ar) or out.label
    out.isboss = gang.isboss == true or (gradeObj and gradeObj.isboss == true) or (gDef and gDef.isboss == true) or false
    return out
end

local function emitDuty(onDuty)
    local state = onDuty == true
    if lastDuty == state then return end
    lastDuty = state
    fireList(callbacks.dutyChange, state)
end

local function handleLoaded(...)
    if characterLoaded then return end
    characterLoaded = true
    hasExplicitLoadState = true
    local pd = exports.w_lib:FwGetPlayerData()
    if type(pd) == 'table' and type(pd.job) == 'table' and pd.job.onduty ~= nil then
        lastDuty = pd.job.onduty == true
    end
    fireList(callbacks.loaded, ...)
end

local function handleUnloaded()
    hasExplicitLoadState = true
    if not characterLoaded then return end
    characterLoaded = false
    lastDuty = nil
    fireList(callbacks.unloaded)
end

-- Exports
local function onLoaded(cb)
    if not registerCallback(callbacks.loaded, cb) then return false end
    if exports.w_lib:FwIsPlayerLoaded() then
        characterLoaded = true
        if type(CreateThread) == 'function' then
            CreateThread(function() pcall(cb) end)
        else
            pcall(cb)
        end
    end
    return true
end

exports('FwOnCharacterLoaded', onLoaded)
exports('FwOnPlayerLoaded', onLoaded)
exports('FwOnCharacterUnloaded', function(cb) return registerCallback(callbacks.unloaded, cb) end)
exports('FwOnPlayerUnload', function(cb) return registerCallback(callbacks.unloaded, cb) end)
exports('FwOnJobUpdate', function(cb) return registerCallback(callbacks.jobUpdate, cb) end)
exports('FwOnGangUpdate', function(cb) return registerCallback(callbacks.gangUpdate, cb) end)
exports('FwOnDutyChange', function(cb) return registerCallback(callbacks.dutyChange, cb) end)
exports('FwOnPlayerData', function(cb) return registerCallback(callbacks.playerData, cb) end)
exports('FwOnPlayerDataUpdate', function(cb) return registerCallback(callbacks.playerData, cb) end)
exports('FwOnMoneyChange', function(cb) return registerCallback(callbacks.moneyChange, cb) end)
exports('FwOnPvpChange', function(cb) return registerCallback(callbacks.pvpChange, cb) end)
exports('FwOnSharedUpdate', function(cb) return registerCallback(callbacks.sharedUpdate, cb) end)

-- Loaded events
RegisterNetEvent('WCore:Client:OnPlayerLoaded', function(...) handleLoaded(...) end)
for _, ev in ipairs({
    'RSGCore:Client:OnPlayerLoaded',
    'qbr-core:client:OnPlayerLoaded',
    'QBCore:Client:OnPlayerLoaded',
    'QRCore:Client:OnPlayerLoaded',
    'vorp:SelectedCharacter',
    'vorp:selectedCharacter',
    'vorp_core:Client:OnPlayerReady',
    'redemrp:SelectedCharacter',
}) do
    RegisterNetEvent(ev, function(...)
        if isWCore() then return end
        handleLoaded(...)
    end)
end

-- Unloaded events
RegisterNetEvent('WCore:Client:OnPlayerUnload', function() handleUnloaded() end)
for _, ev in ipairs({
    'RSGCore:Client:OnPlayerUnload',
    'qbr-core:client:OnPlayerUnload',
    'QBCore:Client:OnPlayerUnload',
    'vorp:PlayerLogout',
    'vorp:playerUnloaded',
    'vorp_core:Client:OnPlayerUnload',
}) do
    RegisterNetEvent(ev, function()
        if isWCore() then return end
        handleUnloaded()
    end)
end

-- Job updates
local function onJob(job)
    local norm = normalizeJob(job)
    if type(norm) == 'table' and norm.onduty ~= nil then
        if lastDuty ~= nil and lastDuty ~= norm.onduty then
            emitDuty(norm.onduty)
        elseif lastDuty == nil then
            lastDuty = norm.onduty
        end
    end
    fireList(callbacks.jobUpdate, norm)
end

RegisterNetEvent('WCore:Client:OnJobUpdate', onJob)
RegisterNetEvent('w_lib:fw:client:jobUpdate', onJob)
for _, ev in ipairs({ 'RSGCore:Client:OnJobUpdate', 'QBCore:Client:OnJobUpdate', 'qbr-core:client:OnJobUpdate' }) do
    RegisterNetEvent(ev, function(job)
        if not isWCore() then onJob(job) end
    end)
end

-- Gang updates
local function onGang(gang)
    fireList(callbacks.gangUpdate, normalizeGang(gang))
end

RegisterNetEvent('WCore:Client:OnGangUpdate', onGang)
for _, ev in ipairs({ 'RSGCore:Client:OnGangUpdate', 'QBCore:Client:OnGangUpdate', 'qbr-core:client:OnGangUpdate' }) do
    RegisterNetEvent(ev, function(gang)
        if not isWCore() then onGang(gang) end
    end)
end

-- Duty updates
RegisterNetEvent('WCore:Client:SetDuty', function(onDuty) emitDuty(onDuty) end)
RegisterNetEvent('w_lib:fw:client:dutyChanged', function(onDuty) emitDuty(onDuty) end)
for _, ev in ipairs({ 'RSGCore:Client:SetDuty', 'QBCore:Client:SetDuty', 'qbr-core:client:SetDuty' }) do
    RegisterNetEvent(ev, function(onDuty)
        if not isWCore() then emitDuty(onDuty) end
    end)
end

-- PlayerData updates (also catches SetJobDuty transitions!)
local function onPlayerData(pd)
    if type(pd) == 'table' and type(pd.job) == 'table' and pd.job.onduty ~= nil then
        local newDuty = pd.job.onduty == true
        if lastDuty == nil then
            lastDuty = newDuty
        elseif lastDuty ~= newDuty then
            emitDuty(newDuty)
        end
    end
    fireList(callbacks.playerData, pd)
end

RegisterNetEvent('WCore:Player:SetPlayerData', onPlayerData)
for _, ev in ipairs({ 'RSGCore:Player:SetPlayerData', 'QBCore:Player:SetPlayerData', 'qbr-core:player:SetPlayerData' }) do
    RegisterNetEvent(ev, function(pd)
        if not isWCore() then onPlayerData(pd) end
    end)
end

-- Money changes
RegisterNetEvent('hud:client:OnMoneyChange', function(kind, absDelta, isRemove)
    fireList(callbacks.moneyChange, kind, tonumber(absDelta) or 0, isRemove == true)
end)
for _, ev in ipairs({ 'RSGCore:Client:OnMoneyChange', 'QBCore:Client:OnMoneyChange' }) do
    RegisterNetEvent(ev, function(kind, amount, changeType)
        if isWCore() then return end
        local isRemove = (changeType == 'remove' or changeType == true)
        fireList(callbacks.moneyChange, kind, tonumber(amount) or 0, isRemove)
    end)
end
RegisterNetEvent('vorp:updateUi', function(rawJson)
    if isWCore() then return end
    local snap = rawJson
    if type(rawJson) == 'string' and rawJson ~= '' then
        local ok, dec = pcall(json.decode, rawJson)
        if ok and type(dec) == 'table' then snap = dec end
    end
    fireList(callbacks.moneyChange, 'vorp', 0, false, snap)
end)
RegisterNetEvent('vorp_bank:client:updateBalance', function(...)
    if isWCore() then return end
    fireList(callbacks.moneyChange, 'bank', 0, false, ...)
end)

-- PvP toggle
RegisterNetEvent('RSGCore:Client:PvpHasToggled', function(enabled)
    fireList(callbacks.pvpChange, enabled == true)
end)
RegisterNetEvent('vorp:setPVPUi', function(active)
    if isWCore() then return end
    fireList(callbacks.pvpChange, active == true)
end)

-- Shared updates
RegisterNetEvent('WCore:Client:OnSharedUpdate', function(tableName, key, value)
    fireList(callbacks.sharedUpdate, tableName, key, value)
end)
RegisterNetEvent('WCore:Client:OnSharedUpdateMultiple', function(tableName, values)
    fireList(callbacks.sharedUpdate, tableName, nil, values)
end)
RegisterNetEvent('RSGCore:Client:OnSharedUpdate', function(tableName, key, value)
    if not isWCore() then fireList(callbacks.sharedUpdate, tableName, key, value) end
end)
RegisterNetEvent('RSGCore:Client:OnSharedUpdateMultiple', function(tableName, values)
    if not isWCore() then fireList(callbacks.sharedUpdate, tableName, nil, values) end
end)

-- VORP client death metadata relay
RegisterNetEvent('w_lib:fw:client:vorpMeta', function(key, value, down)
    if WFW.Name ~= 'vorp' then return end
    if key == 'isdead' or key == 'inlaststand' then
        if type(TriggerServerEvent) == 'function' then
            TriggerServerEvent('vorp:ImDead', down == true)
        end
    end
end)
