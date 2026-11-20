-- ════════════════════════════════════════════════════════════════════════════
-- w_lib — fwbridge/server/events.lua
--   Normalized server lifecycle, job, gang, duty, playerdata, money, citizenId,
--   and character-deletion event subscriptions with invoking-resource cleanup.
-- ════════════════════════════════════════════════════════════════════════════
if not IsDuplicityVersion() then return end

WFW = WFW or {}
WFW._Server = WFW._Server or {}
local S = WFW._Server

local function isCallable(cb)
    return type(cb) == 'function' or (type(cb) == 'table' and getmetatable(cb) and getmetatable(cb).__call ~= nil)
end

local function isWCore()
    return WFW.Host == 'w_core' or (type(GetResourceState) == 'function' and GetResourceState('w_core') == 'started')
end
S.isWCore = isWCore

local callbacks = {
    loaded = {},
    unloaded = {},
    jobUpdate = {},
    gangUpdate = {},
    dutyChange = {},
    playerData = {},
    moneyChange = {},
    citizenIdChanged = {},
    characterDeleted = {},
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

AddEventHandler('onResourceStop', function(resName)
    if type(resName) ~= 'string' or resName == '' then return end
    for _, list in pairs(callbacks) do
        for i = #list, 1, -1 do
            if list[i].resource == resName then
                table.remove(list, i)
            end
        end
    end
end)

local lastDuty = {}
S.lastDuty = lastDuty

local function normalizeGang(rawGang)
    if type(rawGang) ~= 'table' then
        return {
            name = 'none',
            label = 'No Gang',
            label_ar = 'بدون عصابة',
            grade = 0,
            gradeName = '',
            grade_name_ar = '',
            isboss = false,
        }
    end
    local gName = rawGang.name or 'none'
    local sharedGangs = WFW._Shared and WFW._Shared.getSharedGangs and WFW._Shared.getSharedGangs() or {}
    local gangDef = sharedGangs[gName]
    local gradeTable = type(rawGang.grade) == 'table' and rawGang.grade or nil
    local gradeLevel = gradeTable and tonumber(gradeTable.level) or tonumber(rawGang.grade) or 0
    local gradeDef = gangDef and type(gangDef.grades) == 'table'
        and (gangDef.grades[gradeLevel] or gangDef.grades[tostring(gradeLevel)]) or nil
    local label = rawGang.label or (gangDef and gangDef.label) or gName
    local labelAr = rawGang.label_ar or (gangDef and gangDef.label_ar) or label
    local gLabel = (gradeTable and gradeTable.name) or (gradeDef and gradeDef.name) or ''
    local gLabelAr = (gradeTable and gradeTable.name_ar) or (gradeDef and gradeDef.name_ar) or gLabel
    local isboss = rawGang.isboss == true or (gradeTable and gradeTable.isboss == true) or (gradeDef and gradeDef.isboss == true) or false
    return {
        name = gName,
        label = label,
        label_ar = labelAr,
        grade = gradeLevel,
        gradeName = gLabel,
        grade_name_ar = gLabelAr,
        isboss = isboss,
    }
end
S.normalizeGang = normalizeGang

local function emitDutyChange(src, onDuty)
    src = tonumber(src)
    if not src then return end
    local state = onDuty == true
    if lastDuty[src] == state then return end
    lastDuty[src] = state
    fireList(callbacks.dutyChange, src, state)
end
S.emitDutyChange = emitDutyChange

local function emitJobUpdate(src, rawJob)
    src = tonumber(src)
    if not src then return end
    local jobInfo = S.buildJobInfo and S.buildJobInfo(src) or nil
    if type(rawJob) == 'table' and jobInfo then
        if rawJob.name and rawJob.name ~= '' and jobInfo.name == 'unemployed' and rawJob.name ~= 'unemployed' then
            jobInfo.name = rawJob.name
            jobInfo.label = rawJob.label or rawJob.name
        end
        if rawJob.onduty ~= nil then
            jobInfo.onduty = rawJob.onduty == true
        end
    end
    fireList(callbacks.jobUpdate, src, jobInfo)
    if (WFW.Name == 'vorp' or WFW.Name == 'module') and type(TriggerClientEvent) == 'function' then
        pcall(TriggerClientEvent, 'w_lib:fw:client:jobUpdate', src, jobInfo)
    end
    if jobInfo and jobInfo.onduty ~= nil then
        if lastDuty[src] ~= nil and lastDuty[src] ~= (jobInfo.onduty == true) then
            emitDutyChange(src, jobInfo.onduty == true)
        elseif lastDuty[src] == nil then
            lastDuty[src] = jobInfo.onduty == true
        end
    end
end
S.emitJobUpdate = emitJobUpdate

local function onLoaded(src, isNew)
    src = tonumber(src)
    if not src then return end
    if S.clearVorpState then S.clearVorpState(src) end
    if (WFW.Name == 'vorp' or WFW.Name == 'module') and S.loadVorpMeta then
        pcall(S.loadVorpMeta, src, true)
    end
    if S.buildJobInfo then
        local ok, info = pcall(S.buildJobInfo, src)
        if ok and type(info) == 'table' and info.onduty ~= nil then
            lastDuty[src] = info.onduty == true
        end
    end
    fireList(callbacks.loaded, src, isNew == true)
end

local function onUnloaded(src)
    src = tonumber(src)
    if not src then return end
    lastDuty[src] = nil
    if S.clearVorpState then S.clearVorpState(src) end
    fireList(callbacks.unloaded, src)
end

-- Exports: lifecycle
exports('FwOnCharacterLoaded', function(cb) return registerCallback(callbacks.loaded, cb) end)
exports('FwOnPlayerLoaded', function(cb) return registerCallback(callbacks.loaded, cb) end)
exports('FwOnCharacterUnloaded', function(cb) return registerCallback(callbacks.unloaded, cb) end)
exports('FwOnPlayerUnload', function(cb) return registerCallback(callbacks.unloaded, cb) end)

-- Exports: job / gang / duty / data / money / citizen
exports('FwOnJobUpdate', function(cb) return registerCallback(callbacks.jobUpdate, cb) end)
exports('FwOnGangUpdate', function(cb) return registerCallback(callbacks.gangUpdate, cb) end)
exports('FwOnDutyChange', function(cb) return registerCallback(callbacks.dutyChange, cb) end)
exports('FwOnPlayerData', function(cb) return registerCallback(callbacks.playerData, cb) end)
exports('FwOnPlayerDataUpdate', function(cb) return registerCallback(callbacks.playerData, cb) end)
exports('FwOnMoneyChange', function(cb) return registerCallback(callbacks.moneyChange, cb) end)
exports('FwOnCitizenIdChanged', function(cb) return registerCallback(callbacks.citizenIdChanged, cb) end)
exports('FwOnCharacterDeleted', function(cb) return registerCallback(callbacks.characterDeleted, cb) end)

-- Loaded wiring
if type(w) == 'table' and type(w.framework) == 'table' and type(w.framework.onCharacterSelected) == 'function' then
    w.framework:onCharacterSelected(function(src, isNew) onLoaded(src, isNew) end)
else
    AddEventHandler('WCore:Server:PlayerLoaded', function(player)
        local src = type(player) == 'table' and player.PlayerData and player.PlayerData.source or player
        onLoaded(src, false)
    end)
    AddEventHandler('RSGCore:Server:OnPlayerLoaded', function(player)
        if isWCore() then return end
        local src = type(player) == 'table' and player.PlayerData and player.PlayerData.source or player or source
        onLoaded(src, false)
    end)
    AddEventHandler('vorp:SelectedCharacter', function(src)
        if isWCore() then return end
        onLoaded(src, false)
    end)
end

-- Unloaded wiring
AddEventHandler('WCore:Server:OnPlayerUnload', function(src) onUnloaded(src) end)
AddEventHandler('RSGCore:Server:OnPlayerUnload', function(src)
    if not isWCore() then onUnloaded(src) end
end)
AddEventHandler('QBCore:Server:OnPlayerUnload', function(src)
    if not isWCore() then onUnloaded(src) end
end)
AddEventHandler('qbr-core:server:OnPlayerUnload', function(src)
    if not isWCore() then onUnloaded(src) end
end)
AddEventHandler('vorp:PlayerLogout', function(src)
    if not isWCore() then onUnloaded(src) end
end)
AddEventHandler('vorp_core:Server:OnPlayerUnload', function(src)
    if not isWCore() then onUnloaded(src) end
end)
AddEventHandler('playerDropped', function() onUnloaded(source) end)

-- Job update wiring
AddEventHandler('WCore:Server:OnJobUpdate', function(src, job) emitJobUpdate(src, job) end)
AddEventHandler('RSGCore:Server:OnJobUpdate', function(src, job)
    if not isWCore() then emitJobUpdate(src, job) end
end)
AddEventHandler('QBCore:Server:OnJobUpdate', function(src, job)
    if not isWCore() then emitJobUpdate(src, job) end
end)
AddEventHandler('qbr-core:server:OnJobUpdate', function(src, job)
    if not isWCore() then emitJobUpdate(src, job) end
end)

local function handleVorpJobChange(src, newJob, newGrade)
    if isWCore() then return end
    src = tonumber(src)
    if not src then return end
    local function dispatch()
        local jobInfo = S.buildJobInfo and S.buildJobInfo(src) or { name = 'unemployed', grade = 0, onduty = true, isboss = false }
        if type(newJob) == 'string' and newJob ~= '' and (jobInfo.name == 'unemployed' or jobInfo.name == nil) and newJob ~= 'unemployed' then
            jobInfo.name = newJob
            jobInfo.label = newJob
            jobInfo.label_ar = newJob
        end
        if newGrade ~= nil and tonumber(newGrade) and jobInfo.grade == 0 and tonumber(newGrade) ~= 0 then
            jobInfo.grade = tonumber(newGrade)
        end
        fireList(callbacks.jobUpdate, src, jobInfo)
        if type(TriggerClientEvent) == 'function' then
            pcall(TriggerClientEvent, 'w_lib:fw:client:jobUpdate', src, jobInfo)
        end
    end
    if type(SetTimeout) == 'function' then
        SetTimeout(250, dispatch)
    else
        dispatch()
    end
end

AddEventHandler('vorp:playerJobChange', function(src, newJob)
    handleVorpJobChange(src, newJob, nil)
end)
AddEventHandler('vorp:playerJobGradeChange', function(src, newGrade)
    handleVorpJobChange(src, nil, newGrade)
end)

-- Gang update wiring
AddEventHandler('WCore:Server:OnGangUpdate', function(src, gang)
    fireList(callbacks.gangUpdate, tonumber(src), normalizeGang(gang))
end)
AddEventHandler('RSGCore:Server:OnGangUpdate', function(src, gang)
    if not isWCore() then fireList(callbacks.gangUpdate, tonumber(src), normalizeGang(gang)) end
end)
AddEventHandler('QBCore:Server:OnGangUpdate', function(src, gang)
    if not isWCore() then fireList(callbacks.gangUpdate, tonumber(src), normalizeGang(gang)) end
end)

-- PlayerData update + duty transition diffing
local function handlePlayerData(a, b)
    local src, pd
    if type(a) == 'table' then
        pd = a
        src = tonumber(a.source)
    else
        src = tonumber(a)
        pd = b
    end
    if not src or type(pd) ~= 'table' then return end
    if type(pd.job) == 'table' and pd.job.onduty ~= nil then
        local newDuty = pd.job.onduty == true
        if lastDuty[src] == nil then
            lastDuty[src] = newDuty
        elseif lastDuty[src] ~= newDuty then
            emitDutyChange(src, newDuty)
        end
    end
    fireList(callbacks.playerData, src, pd)
end

AddEventHandler('WCore:Player:SetPlayerData', handlePlayerData)
AddEventHandler('RSGCore:Player:SetPlayerData', function(a, b)
    if not isWCore() then handlePlayerData(a, b) end
end)
AddEventHandler('QBCore:Player:SetPlayerData', function(a, b)
    if not isWCore() then handlePlayerData(a, b) end
end)
AddEventHandler('qbr-core:player:SetPlayerData', function(a, b)
    if not isWCore() then handlePlayerData(a, b) end
end)

-- Duty change direct listeners (when core doesn't go through SetPlayerData)
AddEventHandler('WCore:ToggleDuty', function()
    local src = tonumber(source)
    if not src then return end
    local before = lastDuty[src]
    if type(SetTimeout) == 'function' then
        SetTimeout(0, function()
            if lastDuty[src] ~= before then return end
            local info = S.buildJobInfo and S.buildJobInfo(src)
            if info and info.onduty ~= nil and lastDuty[src] ~= (info.onduty == true) then
                emitDutyChange(src, info.onduty == true)
            end
        end)
    end
end)

AddEventHandler('RSGCore:Server:SetDuty', function(a, b)
    if isWCore() then return end
    local src, onDuty
    if b ~= nil then
        src = tonumber(a)
        onDuty = b == true
    else
        src = tonumber(source)
        onDuty = a == true
    end
    if src then emitDutyChange(src, onDuty) end
end)

-- Money change wiring
AddEventHandler('WCore:Server:OnMoneyChange', function(src, kind, amount, mode, reason)
    fireList(callbacks.moneyChange, tonumber(src), kind, amount, mode, reason)
end)
AddEventHandler('RSGCore:Server:OnMoneyChange', function(src, kind, amount, mode, reason)
    if not isWCore() then
        fireList(callbacks.moneyChange, tonumber(src), kind, amount, mode, reason)
    end
end)
AddEventHandler('QBCore:Server:OnMoneyChange', function(src, kind, amount, mode, reason)
    if not isWCore() then
        fireList(callbacks.moneyChange, tonumber(src), kind, amount, mode, reason)
    end
end)

-- Citizen ID & character deletion wiring (w_core)
AddEventHandler('w_core:server:citizenIdChanged', function(oldCid, newCid)
    fireList(callbacks.citizenIdChanged, oldCid, newCid)
end)
AddEventHandler('w_core:server:characterDeleted', function(cid, tombstone)
    fireList(callbacks.characterDeleted, cid, tombstone)
end)
