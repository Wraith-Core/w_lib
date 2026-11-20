-- ════════════════════════════════════════════════════════════════════════════
-- w_lib — resource/econbridge/client.lua
--   Unified Client Economy/Banking Bridge (Econ*).
-- ════════════════════════════════════════════════════════════════════════════
if IsDuplicityVersion() then return end

WECON = WECON or {}

local balanceListeners = {}
local branchListeners = {}

local function currentInvoker()
    if type(GetInvokingResource) == 'function' then
        local inv = GetInvokingResource()
        if type(inv) == 'string' and inv ~= '' then
            return inv
        end
    end
    return 'w_lib'
end

local function addListener(list, cb)
    if not WECON.isCallable(cb) then return false end
    list[#list + 1] = { fn = cb, owner = currentInvoker() }
    return true
end

local function fireListeners(list, ...)
    if #list == 0 then return end
    local snap = {}
    for i = 1, #list do snap[i] = list[i] end
    for i = 1, #snap do
        pcall(snap[i].fn, ...)
    end
end

local function pruneListeners(resName)
    if type(resName) ~= 'string' or resName == '' then return end
    local selfName = type(GetCurrentResourceName) == 'function' and GetCurrentResourceName() or 'w_lib'
    for _, list in ipairs({ balanceListeners, branchListeners }) do
        for i = #list, 1, -1 do
            if resName == selfName or list[i].owner == resName then
                table.remove(list, i)
            end
        end
    end
end

AddEventHandler('onClientResourceStop', pruneListeners)
AddEventHandler('onResourceStop', pruneListeners)

RegisterNetEvent('w_centralbank:balanceChanged', function(accountId, balance)
    fireListeners(balanceListeners, accountId, balance)
end)

RegisterNetEvent('w_centralbank:branches', function(banks)
    fireListeners(branchListeners, banks)
end)

RegisterNetEvent('hud:client:OnMoneyChange', function(kind, amount, isRemove)
    if WECON.isCentralStarted() then return end
    local normKind = WECON.normalizeKind(tostring(kind or 'cash')) or 'cash'
    local cid = 'local'
    local balance = tonumber(amount) or 0
    if exports and exports.w_lib then
        local ok, pd = pcall(function() return exports.w_lib:FwGetPlayerData() end)
        if ok and type(pd) == 'table' then
            if pd.citizenid then cid = tostring(pd.citizenid) end
            if type(pd.money) == 'table' and pd.money[normKind] ~= nil then
                balance = tonumber(pd.money[normKind]) or balance
            end
        end
    end
    fireListeners(balanceListeners, ('player:%s:%s'):format(cid, normKind), balance, isRemove == true)
end)

RegisterNetEvent('vorp:updateUi', function(payload)
    if WECON.isCentralStarted() then return end
    local data = payload
    if type(payload) == 'string' and payload ~= '' and type(json) == 'table' and type(json.decode) == 'function' then
        local ok, decoded = pcall(json.decode, payload)
        if ok and type(decoded) == 'table' then
            data = decoded
        end
    end
    if type(data) ~= 'table' then return end
    local cash = tonumber(data.moneyquanty or data.money)
    local gold = tonumber(data.goldquanty or data.gold)
    if cash ~= nil then
        fireListeners(balanceListeners, 'player:local:cash', cash)
    end
    if gold ~= nil then
        fireListeners(balanceListeners, 'player:local:gold', gold)
    end
end)

exports('EconOpen', function()
    if WECON.isCentralStarted() then
        local ok, res = pcall(function() return exports.w_centralbank:Open() end)
        if not ok then return false, 'centralbank_unavailable' end
        return res ~= false
    end
    return false, 'centralbank_unavailable'
end)

exports('EconOnBalanceChanged', function(cb)
    return addListener(balanceListeners, cb)
end)

exports('EconOnBranchesChanged', function(cb)
    return addListener(branchListeners, cb)
end)
