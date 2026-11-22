-- ════════════════════════════════════════════════════════════════════════════
-- w_lib — resource/econbridge/server.lua
--   Unified Server Economy/Banking Bridge (Econ*).
--   Exclusively delegates to w_centralbank when started (preventing double
--   charges through w_core), and falls back to Fw* currency exports when
--   w_centralbank is not started.
-- ════════════════════════════════════════════════════════════════════════════
if not IsDuplicityVersion() then return end

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

AddEventHandler('onResourceStop', pruneListeners)

AddEventHandler('w_centralbank:balanceChanged', function(accountId, balance)
    fireListeners(balanceListeners, accountId, balance)
end)

AddEventHandler('w_centralbank:branches', function(banks)
    fireListeners(branchListeners, banks)
end)

-- ───────────────────────── w_centralbank Call Helpers ─────────────────────────

local function callCentralRead(method, ...)
    local packed = table.pack(pcall(function(...)
        return exports.w_centralbank[method](exports.w_centralbank, ...)
    end, ...))
    if not packed[1] then
        return nil
    end
    return table.unpack(packed, 2, packed.n)
end

local function callCentralMutate(method, ...)
    local packed = table.pack(pcall(function(...)
        return exports.w_centralbank[method](exports.w_centralbank, ...)
    end, ...))
    if not packed[1] then
        return nil, 'commit_unknown'
    end
    local ok = packed[2]
    local why = packed[3]
    if ok == true then
        return true, why, packed[4]
    end
    if ok == nil then
        return nil, why or 'commit_unknown'
    end
    return false, why or 'refused'
end

-- ───────────────────────── Framework Fallback Helpers ─────────────────────────

local function isWCoreWithoutCentral()
    -- w_core manages standard server money directly when w_centralbank is not installed.
    return false
end

local function isFwReady()
    local ok, ready = pcall(function() return exports.w_lib:FwReady() end)
    return ok and ready == true
end

local function fwSourceOf(cid)
    local ok, src = pcall(function() return exports.w_lib:FwGetSource(tostring(cid)) end)
    if ok and tonumber(src) then return tonumber(src) end
    return nil
end

local function hasRsgBankAccount(src)
    local okB, backend = pcall(function() return exports.w_lib:FwBackend() end)
    if not okB or (backend ~= 'rsg' and backend ~= 'qbr' and backend ~= 'wcore') then
        return false, nil
    end
    local okU, user = pcall(function() return exports.w_lib:FwGetUser(src) end)
    if not okU or type(user) ~= 'table' then
        return false, nil
    end
    local pd = user.PlayerData
    if type(pd) == 'table' and type(pd.money) == 'table' and pd.money.bank ~= nil and type(user.Functions) == 'table' then
        return true, user
    end
    return false, nil
end

local function fwReadOnlineBalance(src, normKind)
    if normKind == 'gold' then
        local ok, v = pcall(function() return exports.w_lib:FwGetGold(src) end)
        return ok and tonumber(v) or nil
    elseif normKind == 'bank' then
        local hasBank, user = hasRsgBankAccount(src)
        if hasBank then
            return tonumber(user.PlayerData.money.bank) or 0
        end
        local ok, v = pcall(function() return exports.w_lib:FwGetMoney(src) end)
        return ok and tonumber(v) or nil
    else
        local ok, v = pcall(function() return exports.w_lib:FwGetMoney(src) end)
        return ok and tonumber(v) or nil
    end
end

local function fwAdjustPlayer(cid, rawKind, delta, reason)
    if isWCoreWithoutCentral() then
        return false, 'centralbank_unavailable'
    end
    if not isFwReady() then
        return false, 'economy_not_ready'
    end
    local validCid = WECON.validCid(cid)
    if not validCid then
        return false, 'invalid_cid'
    end
    local normKind = WECON.normalizeKind(rawKind)
    if not normKind then
        return false, 'invalid_kind'
    end
    local amount = WECON.isFiniteAmount(delta, true, true)
    if amount == nil then
        return false, 'invalid_amount'
    end
    if amount == 0 then
        return true
    end

    local absAmount = math.abs(amount)
    local isAdd = amount > 0
    local src = fwSourceOf(validCid)

    if src then
        local curBalance = fwReadOnlineBalance(src, normKind)
        if curBalance == nil then
            return false, 'player_not_loaded'
        end
        if not isAdd and curBalance + 0.0001 < absAmount then
            return false, 'insufficient_funds'
        end

        if normKind == 'bank' then
            local hasBank, user = hasRsgBankAccount(src)
            if hasBank then
                local fn = isAdd and user.Functions.AddMoney or user.Functions.RemoveMoney
                if not WECON.isCallable(fn) then
                    return false, 'unsupported_currency'
                end
                local ok, res = pcall(fn, 'bank', absAmount, reason)
                if not ok then return nil, 'commit_unknown' end
                if res == false then return false, isAdd and 'add_failed' or 'insufficient_funds' end
                local newBal = fwReadOnlineBalance(src, 'bank') or (isAdd and (curBalance + absAmount) or math.max(0, curBalance - absAmount))
                fireListeners(balanceListeners, ('player:%s:bank'):format(validCid), newBal)
                return true
            end
        end

        local curType = (normKind == 'gold') and 1 or 0
        local exportName = isAdd and 'FwAddCurrency' or 'FwRemoveCurrency'
        local ok, res = pcall(function()
            return exports.w_lib[exportName](exports.w_lib, src, curType, absAmount)
        end)
        if not ok then
            return nil, 'commit_unknown'
        end
        if res == false then
            return false, isAdd and 'add_failed' or 'insufficient_funds'
        end
        local newBal = fwReadOnlineBalance(src, normKind) or (isAdd and (curBalance + absAmount) or math.max(0, curBalance - absAmount))
        local rawSuffix = (type(rawKind) == 'string' and rawKind:lower() == 'bloodmoney') and 'gold' or normKind
        fireListeners(balanceListeners, ('player:%s:%s'):format(validCid, rawSuffix), newBal)
        return true
    end

    -- Offline fallback
    local curType = (normKind == 'gold') and 1 or 0
    local exportName = isAdd and 'FwAddCurrencyOffline' or 'FwRemoveCurrencyOffline'
    local ok, res, why = pcall(function()
        return exports.w_lib[exportName](exports.w_lib, validCid, curType, absAmount)
    end)
    if not ok then
        return nil, 'commit_unknown'
    end
    if res == true then
        return true
    end
    if res == nil then
        return nil, why or 'commit_unknown'
    end
    return false, why or 'player_offline'
end

local function classifyEndpoint(accountId)
    local cid, kind = WECON.parsePlayerAccount(accountId)
    if cid then
        return { type = 'player', cid = cid, kind = kind, currency = (kind == 'gold') and 'gold' or 'cash' }
    end
    local isRes, resCur = WECON.isReserveAccount(accountId)
    if isRes then
        return { type = 'reserve', id = accountId, currency = resCur }
    end
    return nil
end

local function fwExecuteSingleMove(fromEp, toEp, amount, reason)
    if fromEp.type == 'player' and toEp.type == 'reserve' then
        return fwAdjustPlayer(fromEp.cid, fromEp.kind, -amount, reason)
    elseif fromEp.type == 'reserve' and toEp.type == 'player' then
        return fwAdjustPlayer(toEp.cid, toEp.kind, amount, reason)
    elseif fromEp.type == 'player' and toEp.type == 'player' then
        local okDebit, whyDebit = fwAdjustPlayer(fromEp.cid, fromEp.kind, -amount, reason)
        if okDebit ~= true then
            return okDebit, whyDebit
        end
        local okCredit, whyCredit = fwAdjustPlayer(toEp.cid, toEp.kind, amount, reason)
        if okCredit ~= true then
            -- Roll back debit
            fwAdjustPlayer(fromEp.cid, fromEp.kind, amount, 'rollback:' .. tostring(reason or ''))
            return okCredit, whyCredit
        end
        return true
    end
    return false, 'centralbank_unavailable'
end

-- ───────────────────────── Export Implementations ─────────────────────────

local function econReady()
    if WECON.isCentralStarted() then
        local ok, r = pcall(function() return exports.w_centralbank:IsReady() end)
        return ok and r == true
    end
    if isWCoreWithoutCentral() then
        return false
    end
    return isFwReady()
end

exports('EconReady', econReady)
exports('EconIsReady', econReady)

exports('EconEnsureAccount', function(id, owner, kind)
    if WECON.isCentralStarted() then
        return callCentralMutate('EnsureAccount', id, owner, kind)
    end
    if isWCoreWithoutCentral() then
        return false, 'centralbank_unavailable'
    end
    local cid = WECON.parsePlayerAccount(id)
    if not cid then
        return false, 'centralbank_unavailable'
    end
    if not isFwReady() then
        return false, 'economy_not_ready'
    end
    return true
end)

exports('EconSetAccountOwner', function(id, owner)
    if WECON.isCentralStarted() then
        local ok, res = pcall(function() return exports.w_centralbank:SetAccountOwner(id, owner) end)
        return ok and res == true
    end
    return false, 'centralbank_unavailable'
end)

exports('EconGetBalance', function(id)
    if WECON.isCentralStarted() then
        local bal = callCentralRead('GetBalance', id)
        return tonumber(bal)
    end
    if isWCoreWithoutCentral() then
        return nil, 'centralbank_unavailable'
    end
    local cid, kind = WECON.parsePlayerAccount(id)
    if not cid then
        return nil, 'centralbank_unavailable'
    end
    if not isFwReady() then
        return nil
    end
    local src = fwSourceOf(cid)
    if not src then
        return nil
    end
    return fwReadOnlineBalance(src, kind)
end)

local function getPlayerBalances(cid)
    local validCid = WECON.validCid(cid)
    if not validCid then return nil end

    if WECON.isCentralStarted() then
        if not econReady() then return nil end
        local cash = callCentralRead('GetBalance', ('player:%s:cash'):format(validCid))
        local bank = callCentralRead('GetBalance', ('player:%s:bank'):format(validCid))
        local gold = callCentralRead('GetBalance', ('player:%s:gold'):format(validCid))
        if cash == nil and bank == nil and gold == nil then
            return nil
        end
        local g = tonumber(gold) or 0
        return {
            cash = tonumber(cash) or 0,
            bank = tonumber(bank) or 0,
            gold = g,
            bloodmoney = g,
        }
    end

    if isWCoreWithoutCentral() or not isFwReady() then
        return nil
    end
    local src = fwSourceOf(validCid)
    if not src then
        return nil
    end
    local cash = fwReadOnlineBalance(src, 'cash')
    local bank = fwReadOnlineBalance(src, 'bank')
    local gold = fwReadOnlineBalance(src, 'gold')
    if cash == nil then return nil end
    local g = tonumber(gold) or 0
    return {
        cash = tonumber(cash) or 0,
        bank = tonumber(bank ~= nil and bank or cash) or 0,
        gold = g,
        bloodmoney = g,
    }
end

exports('EconGetPlayerBalances', getPlayerBalances)

exports('EconHydratePlayer', function(cid, isNew)
    local validCid = WECON.validCid(cid)
    if not validCid then return nil end
    if WECON.isCentralStarted() then
        local res = callCentralRead('HydratePlayer', validCid, isNew == true)
        return type(res) == 'table' and res or nil
    end
    return getPlayerBalances(validCid)
end)

exports('EconAdjustPlayer', function(cid, kind, amount, reason, key)
    if WECON.isCentralStarted() then
        return callCentralMutate('AdjustPlayer', cid, kind, amount, reason, key)
    end
    return fwAdjustPlayer(cid, kind, amount, reason)
end)

exports('EconAdjustAccount', function(id, delta, reason, key)
    if WECON.isCentralStarted() then
        return callCentralMutate('AdjustAccount', id, delta, reason, key)
    end
    local cid, kind = WECON.parsePlayerAccount(id)
    if not cid then
        return false, 'centralbank_unavailable'
    end
    return fwAdjustPlayer(cid, kind, delta, reason)
end)

exports('EconSetPlayerBalance', function(cid, kind, amount, reason, key)
    if WECON.isCentralStarted() then
        return callCentralMutate('SetPlayerBalance', cid, kind, amount, reason, key)
    end
    if isWCoreWithoutCentral() then
        return false, 'centralbank_unavailable'
    end
    if not isFwReady() then
        return false, 'economy_not_ready'
    end
    local validCid = WECON.validCid(cid)
    if not validCid then
        return false, 'invalid_cid'
    end
    local normKind = WECON.normalizeKind(kind)
    if not normKind then
        return false, 'invalid_kind'
    end
    local target = WECON.isFiniteAmount(amount, true, false)
    if target == nil then
        return false, 'invalid_amount'
    end
    local src = fwSourceOf(validCid)
    if not src then
        return false, 'player_offline'
    end
    local current = fwReadOnlineBalance(src, normKind)
    if current == nil then
        return false, 'player_not_loaded'
    end
    local delta = target - current
    if math.abs(delta) < 0.0001 then
        return true
    end
    return fwAdjustPlayer(validCid, normKind, delta, reason)
end)

exports('EconTransfer', function(from, to, amount, reason, key)
    if WECON.isCentralStarted() then
        return callCentralMutate('Transfer', from, to, amount, reason, key)
    end
    if isWCoreWithoutCentral() then
        return false, 'centralbank_unavailable'
    end
    if not isFwReady() then
        return false, 'economy_not_ready'
    end
    if type(from) ~= 'string' or type(to) ~= 'string' or from == '' or to == '' or from == to then
        return false, 'invalid_account'
    end
    local amt = WECON.isFiniteAmount(amount, false, false)
    if amt == nil then
        return false, 'invalid_amount'
    end
    local fromEp = classifyEndpoint(from)
    local toEp = classifyEndpoint(to)
    if not fromEp or not toEp or (fromEp.type == 'reserve' and toEp.type == 'reserve') then
        return false, 'centralbank_unavailable'
    end
    if fromEp.currency ~= toEp.currency then
        return false, 'currency_mismatch'
    end
    return fwExecuteSingleMove(fromEp, toEp, amt, reason)
end)

exports('EconTransferMany', function(moves, reason, key)
    if WECON.isCentralStarted() then
        return callCentralMutate('TransferMany', moves, reason, key)
    end
    if isWCoreWithoutCentral() then
        return false, 'centralbank_unavailable'
    end
    if not isFwReady() then
        return false, 'economy_not_ready'
    end
    if type(moves) ~= 'table' or #moves == 0 then
        return false, 'invalid_moves'
    end

    local parsed = {}
    local netDebits = {}

    for i = 1, #moves do
        local m = moves[i]
        if type(m) ~= 'table' or type(m.from) ~= 'string' or type(m.to) ~= 'string' or m.from == m.to then
            return false, 'invalid_account'
        end
        local amt = WECON.isFiniteAmount(m.amount, false, false)
        if amt == nil then
            return false, 'invalid_amount'
        end
        local fromEp = classifyEndpoint(m.from)
        local toEp = classifyEndpoint(m.to)
        if not fromEp or not toEp or (fromEp.type == 'reserve' and toEp.type == 'reserve') then
            return false, 'centralbank_unavailable'
        end
        if fromEp.currency ~= toEp.currency then
            return false, 'currency_mismatch'
        end
        if fromEp.type == 'player' then
            local k = fromEp.cid .. ':' .. fromEp.kind
            netDebits[k] = { cid = fromEp.cid, kind = fromEp.kind, total = (netDebits[k] and netDebits[k].total or 0) + amt }
        end
        parsed[i] = { fromEp = fromEp, toEp = toEp, amount = amt }
    end

    -- Pre-check online balances for all player debits before executing any move
    for _, req in pairs(netDebits) do
        local src = fwSourceOf(req.cid)
        if src then
            local bal = fwReadOnlineBalance(src, req.kind)
            if bal == nil then return false, 'player_not_loaded' end
            if bal + 0.0001 < req.total then
                return false, 'insufficient_funds'
            end
        end
    end

    local done = {}
    for i = 1, #parsed do
        local step = parsed[i]
        local ok, why = fwExecuteSingleMove(step.fromEp, step.toEp, step.amount, reason)
        if ok ~= true then
            for j = #done, 1, -1 do
                local prev = done[j]
                fwExecuteSingleMove(prev.toEp, prev.fromEp, prev.amount, 'rollback:' .. tostring(reason or ''))
            end
            return ok, why
        end
        done[#done + 1] = step
    end
    return true
end)

exports('EconGetBanks', function()
    if WECON.isCentralStarted() then
        local banks = callCentralRead('GetBanks')
        return type(banks) == 'table' and banks or {}
    end
    return {}
end)

exports('EconTaxRate', function(branch)
    if WECON.isCentralStarted() then
        local rate = callCentralRead('TaxRate', branch)
        return tonumber(rate) or 0
    end
    return 0
end)

exports('EconBankTransfer', function(src, branch, from, to, amount, reason, key)
    if WECON.isCentralStarted() then
        local ok, why, tax = callCentralMutate('BankTransfer', src, branch, from, to, amount, reason, key)
        return ok, why, tax
    end
    local ok, why = exports.w_lib:EconTransfer(from, to, amount, reason, key)
    return ok, why, 0
end)

exports('EconPlayerOutflows', function(cid, limit, beforeId)
    if WECON.isCentralStarted() then
        local res, err = callCentralRead('PlayerOutflows', cid, limit, beforeId)
        return res, err
    end
    return nil, 'centralbank_unavailable'
end)

exports('EconRefundOutflow', function(cid, id, idx, by)
    if WECON.isCentralStarted() then
        return callCentralMutate('RefundOutflow', cid, id, idx, by)
    end
    return false, 'centralbank_unavailable'
end)

exports('EconListDebtAssets', function(cid)
    if WECON.isCentralStarted() then
        local res, err = callCentralRead('ListDebtAssets', cid)
        if type(res) == 'table' then return res, err end
        return {}, err or 'centralbank_unavailable'
    end
    return {}, 'centralbank_unavailable'
end)

exports('EconSeizeDebtAsset', function(cid, assetId, caseId)
    if WECON.isCentralStarted() then
        return callCentralMutate('SeizeDebtAsset', cid, assetId, caseId)
    end
    return false, 'centralbank_unavailable'
end)

exports('EconOnBalanceChanged', function(cb)
    return addListener(balanceListeners, cb)
end)

exports('EconOnBranchesChanged', function(cb)
    return addListener(branchListeners, cb)
end)

exports('EconGetExternalBank', function(provider, identifier, charid)
    if provider == 'vorp_banking' and type(GetResourceState) == 'function' and GetResourceState('vorp_banking') == 'started' then
        local ok, balance = pcall(function()
            return exports.vorp_banking:getAccountMoney(identifier, charid)
        end)
        return ok and tonumber(balance) or 0
    end
    return 0
end)

exports('EconRemoveExternalBank', function(provider, identifier, charid, amount)
    if provider == 'vorp_banking' and type(GetResourceState) == 'function' and GetResourceState('vorp_banking') == 'started' then
        local ok = pcall(function()
            exports.vorp_banking:removeMoneyFromAccount(identifier, charid, amount)
        end)
        return ok == true
    end
    return false
end)
