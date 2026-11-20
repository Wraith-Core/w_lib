-- ════════════════════════════════════════════════════════════════════════════
-- w_lib — resource/econbridge/shared.lua
--   Unified Economy/Banking detection and shared validation helpers.
--   Routes to w_centralbank when started; falls back to framework money (Fw*)
--   when w_centralbank is not started.
-- ════════════════════════════════════════════════════════════════════════════

WECON = WECON or {}

local VALID_KINDS = {
    cash = 'cash',
    money = 'cash',
    bank = 'bank',
    gold = 'gold',
    bloodmoney = 'gold',
}

function WECON.isCentralStarted()
    return type(GetResourceState) == 'function' and GetResourceState('w_centralbank') == 'started'
end

function WECON.provider()
    if WECON.isCentralStarted() then
        return 'w_centralbank'
    end
    return 'framework'
end

function WECON.isCallable(fn)
    if type(fn) == 'function' then return true end
    if type(fn) == 'table' then
        local mt = getmetatable(fn)
        return type(mt) == 'table' and mt.__call ~= nil
    end
    return false
end

function WECON.normalizeKind(kind)
    if type(kind) ~= 'string' then return nil end
    return VALID_KINDS[kind:lower()]
end

function WECON.validCid(cid)
    if type(cid) ~= 'string' and type(cid) ~= 'number' then return nil end
    local s = tostring(cid)
    if s == '' or #s > 64 or s:find(':', 1, true) then return nil end
    return s
end

function WECON.parsePlayerAccount(accountId)
    if type(accountId) ~= 'string' then return nil, nil end
    local cid, rawKind = accountId:match('^player:([^:]+):([^:]+)$')
    if not cid or not rawKind then return nil, nil end
    local validCid = WECON.validCid(cid)
    local normKind = WECON.normalizeKind(rawKind)
    if not validCid or not normKind then return nil, nil end
    return validCid, normKind
end

function WECON.isReserveAccount(accountId)
    if accountId == 'central:reserve' then return true, 'cash' end
    if accountId == 'central:gold' then return true, 'gold' end
    return false, nil
end

function WECON.isFiniteAmount(v, allowZero, allowNegative)
    local n = tonumber(v)
    if type(n) ~= 'number' or n ~= n or n == math.huge or n == -math.huge then
        return nil
    end
    if not allowNegative and n < 0 then
        return nil
    end
    if not allowZero and math.abs(n) < 0.0001 then
        return nil
    end
    if math.abs(n) > 1000000000 then
        return nil
    end
    local cents = math.floor(math.abs(n) * 100 + 0.5)
    if math.abs(math.abs(n) * 100 - cents) > 0.001 then
        return nil
    end
    if not allowZero and cents == 0 then
        return nil
    end
    local sign = n < 0 and -1 or 1
    return sign * (cents / 100.0)
end

exports('EconProvider', function()
    return WECON.provider()
end)

exports('EconName', function()
    return WECON.provider()
end)
