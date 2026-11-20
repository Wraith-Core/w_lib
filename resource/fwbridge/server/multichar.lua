-- ════════════════════════════════════════════════════════════════════════════
-- w_lib — fwbridge/server/multichar.lua
--   Multicharacter CRUD across w_core, vorp_core, rsg-core, and qbr-core.
-- ════════════════════════════════════════════════════════════════════════════
if not IsDuplicityVersion() then return end

WFW = WFW or {}
WFW._Server = WFW._Server or {}
local S = WFW._Server

local MAX_NAME_LEN = 25
local SAVE_CONFIRM_MS = 3000

local function decodeJson(val, fallback)
    if type(val) == 'table' then return val end
    if type(val) == 'string' and val ~= '' then
        local ok, decoded = pcall(json.decode, val)
        if ok and type(decoded) == 'table' then return decoded end
    end
    return fallback
end

local function isFinite(n)
    return type(n) == 'number' and n == n and n ~= math.huge and n ~= -math.huge
end

local function sanitizeName(value, fallback)
    if type(value) ~= 'string' then return fallback end
    local v = value:match('^%s*(.-)%s*$')
    if not v or v == '' then return fallback end
    local len = utf8 and utf8.len(v)
    if len and len > MAX_NAME_LEN then
        local cut = utf8.offset(v, MAX_NAME_LEN + 1)
        if cut then v = v:sub(1, cut - 1) end
    elseif not len and #v > MAX_NAME_LEN * 4 then
        v = v:sub(1, MAX_NAME_LEN * 4)
    end
    return v
end

local function birthdateFromAge(age)
    local years = tonumber(age) or 20
    local year = (tonumber(os.date('%Y')) or 1900) - years
    return ('%04d-01-01'):format(year)
end

local function birthdateOf(data)
    local dob = type(data.dob) == 'string' and data.dob:match('^(%d%d%d%d%-%d%d%-%d%d)$') or nil
    return dob or birthdateFromAge(data.age)
end

local function ageOf(data)
    local age = tonumber(data.age)
    if age then return math.floor(age) end
    local y, m, d = tostring(data.dob or ''):match('^(%d%d%d%d)%-(%d%d)%-(%d%d)$')
    if y then
        local now = os.date('*t')
        local computed = now.year - tonumber(y)
        if now.month < tonumber(m) or (now.month == tonumber(m) and now.day < tonumber(d)) then
            computed = computed - 1
        end
        return computed
    end
    return 20
end

local function jsonShape(v)
    if v == nil then return nil end
    local okEnc, enc = pcall(json.encode, v)
    if not okEnc or not enc then return nil end
    local okDec, dec = pcall(json.decode, enc)
    return okDec and dec or nil
end

local function sameValue(a, b)
    if type(a) == 'number' and type(b) == 'number' then
        return math.abs(a - b) <= 1e-6 * math.max(1, math.abs(a), math.abs(b))
    end
    if type(a) ~= 'table' or type(b) ~= 'table' then return a == b end
    for k, v in pairs(a) do if not sameValue(v, b[k]) then return false end end
    for k in pairs(b) do if a[k] == nil then return false end end
    return true
end

local function saveLoggedIn(player)
    local data = type(player) == 'table' and player.PlayerData or nil
    local citizenid = type(data) == 'table' and data.citizenid or nil
    local save = type(player) == 'table' and type(player.Functions) == 'table' and player.Functions.Save or nil
    if not citizenid or type(save) ~= 'function' then return false, 'the core offers no save' end

    local fields = { 'job', 'gang', 'metadata' }
    if not (S.isWCore and S.isWCore()) then
        fields[#fields + 1] = 'money'
    end
    local expected = {}
    for _, f in ipairs(fields) do
        expected[f] = jsonShape(data[f]) or {}
    end

    local saved, err = pcall(save)
    if not saved then return false, tostring(err) end

    if type(MySQL) ~= 'table' or not MySQL.query or not MySQL.query.await then
        return true
    end

    local sql = ('SELECT %s FROM players WHERE citizenid = ? LIMIT 1'):format(table.concat(fields, ', '))
    local deadline = (type(GetGameTimer) == 'function' and GetGameTimer() or 0) + SAVE_CONFIRM_MS
    repeat
        local ok, rows = pcall(MySQL.query.await, sql, { citizenid })
        local row = ok and type(rows) == 'table' and rows[1] or nil
        if type(row) == 'table' then
            local same = true
            for _, f in ipairs(fields) do
                local stored = row[f]
                if type(stored) == 'string' then stored = decodeJson(stored, {}) end
                if stored == nil then stored = {} end
                if not sameValue(expected[f], stored) then
                    same = false
                    break
                end
            end
            if same then return true end
        end
        if type(Wait) == 'function' then Wait(100) end
    until (type(GetGameTimer) == 'function' and GetGameTimer() or deadline) >= deadline
    return false, 'the save was not confirmed in time'
end

local function getAccountLicense(src)
    src = tonumber(src)
    if not src then return nil end
    if WFW.Name == 'vorp' then
        local user = S.FW and S.FW.GetUser(src)
        if user and type(user.getIdentifier) == 'function' then
            local ok, id = pcall(user.getIdentifier)
            if ok and id and id ~= '' then return id end
        end
        if type(GetPlayerIdentifierByType) == 'function' then
            return GetPlayerIdentifierByType(src, 'steam')
        end
        return nil
    end
    if type(GetPlayerIdentifierByType) == 'function' then
        local lic = GetPlayerIdentifierByType(src, 'license')
        if lic and lic ~= '' then return lic end
    end
    if type(GetPlayerIdentifier) == 'function' then
        return GetPlayerIdentifier(src, 0)
    end
    return nil
end
exports('FwGetAccountLicense', getAccountLicense)

local function getCharacterBlock(cid)
    if cid == nil or cid == '' then return nil end
    if S.isWCore and S.isWCore() then
        local ok, block = pcall(function() return exports.w_core:GetCharacterBlock(tostring(cid)) end)
        if ok then return block end
    end
    return nil
end
exports('FwGetCharacterBlock', getCharacterBlock)

local function parseCoordsTable(raw)
    if raw == nil then return nil end
    if type(raw) == 'string' then
        if raw == '' then return nil end
        raw = decodeJson(raw, nil)
    end
    if type(raw) ~= 'table' then return nil end
    local x, y, z = tonumber(raw.x), tonumber(raw.y), tonumber(raw.z)
    if not isFinite(x) or not isFinite(y) or not isFinite(z) then return nil end
    if x == 0.0 and y == 0.0 and z == 0.0 then return nil end
    return { x = x, y = y, z = z, heading = tonumber(raw.heading) or tonumber(raw.w) or 0.0 }
end

exports('FwGetLastPosition', function(srcOrCid)
    local raw
    local numSrc = tonumber(srcOrCid)
    local onlineChar = numSrc and S.getChar and S.getChar(numSrc) or nil

    if onlineChar then
        if WFW.Name == 'vorp' then
            raw = onlineChar.coords
        elseif WFW.Name == 'rsgcore' then
            raw = onlineChar.position
        end
    end

    if raw == nil and type(MySQL) == 'table' and MySQL.single and MySQL.single.await then
        local cid
        if numSrc and exports.w_lib:FwGetCharacterIdentifier(numSrc) then
            cid = exports.w_lib:FwGetCharacterIdentifier(numSrc)
        elseif not numSrc and srcOrCid ~= nil and srcOrCid ~= '' then
            cid = tostring(srcOrCid)
        end
        if cid then
            if WFW.Name == 'vorp' then
                local id = tonumber((tostring(cid):gsub('^vorp:', '')))
                if id then
                    local ok, row = pcall(MySQL.single.await, 'SELECT coords FROM characters WHERE charidentifier = ? LIMIT 1', { id })
                    if ok and type(row) == 'table' then raw = row.coords end
                end
            elseif WFW.Name == 'rsgcore' then
                local ok, row = pcall(MySQL.single.await, 'SELECT position FROM players WHERE citizenid = ? LIMIT 1', { tostring(cid) })
                if ok and type(row) == 'table' then raw = row.position end
            end
        end
    end

    return parseCoordsTable(raw)
end)

local function accountBalances(citizenid, moneyColumn)
    if exports and exports.w_lib then
        local okReady, ready = pcall(function() return exports.w_lib:EconIsReady() end)
        if okReady and ready == true then
            local okBal, balances = pcall(function() return exports.w_lib:EconGetPlayerBalances(tostring(citizenid)) end)
            if okBal and type(balances) == 'table' then
                return {
                    cash = isFinite(tonumber(balances.cash)) and tonumber(balances.cash) or nil,
                    bank = isFinite(tonumber(balances.bank)) and tonumber(balances.bank) or nil,
                    gold = isFinite(tonumber(balances.gold)) and tonumber(balances.gold) or nil,
                }
            end
        end
    end
    if S.isWCore and S.isWCore() then return {} end
    local money = decodeJson(moneyColumn, {})
    return {
        cash = isFinite(tonumber(money.cash)) and tonumber(money.cash) or nil,
        bank = isFinite(tonumber(money.bank)) and tonumber(money.bank) or nil,
        gold = isFinite(tonumber(money.gold or money.bloodmoney)) and tonumber(money.gold or money.bloodmoney) or nil,
    }
end

local function storedJobLabel(src, rawJob)
    local job = decodeJson(rawJob, nil)
    if type(job) ~= 'table' then return nil end
    local label = exports.w_lib:FwJobLabel(job, src)
    return (type(label) == 'string' and label ~= '') and label or nil
end

local function getAccountCharacters(src)
    src = tonumber(src)
    local license = getAccountLicense(src)
    if not license then return {} end
    if type(MySQL) ~= 'table' or not MySQL.query or not MySQL.query.await then return nil end

    if WFW.Name == 'vorp' then
        local ok, rows = pcall(MySQL.query.await,
            'SELECT charidentifier, firstname, lastname, age, gender, coords, money, gold, job, joblabel FROM characters WHERE identifier = ?',
            { license })
        if not ok or type(rows) ~= 'table' then return nil end

        local bank = {}
        local okBank, bankRows = pcall(MySQL.query.await,
            'SELECT charidentifier, SUM(money) AS money, SUM(gold) AS gold FROM bank_users WHERE identifier = ? GROUP BY charidentifier',
            { license })
        if okBank and type(bankRows) == 'table' then
            for _, r in ipairs(bankRows) do
                bank[tostring(r.charidentifier)] = { money = r.money or 0, gold = r.gold or 0 }
            end
        end

        local list = {}
        for _, r in ipairs(rows) do
            local acc = bank[tostring(r.charidentifier)] or {}
            local cid = 'vorp:' .. tostring(r.charidentifier)
            local name = ((r.firstname or '') .. ' ' .. (r.lastname or '')):gsub('^%s+', ''):gsub('%s+$', '')
            if name == '' then name = cid end
            list[#list + 1] = {
                charid = cid,
                raw = r.charidentifier,
                citizenId = cid,
                name = name,
                firstname = r.firstname or '',
                lastname = r.lastname or '',
                age = r.age,
                sex = r.gender,
                lastLocation = parseCoordsTable(r.coords),
                cash = tonumber(r.money) or 0,
                gold = tonumber(r.gold) or 0,
                bank = tonumber(acc.money) or 0,
                bankGold = tonumber(acc.gold) or 0,
                job = (r.joblabel ~= nil and r.joblabel ~= '') and r.joblabel or r.job,
                blocked = nil,
            }
        end
        return list
    elseif WFW.Name == 'rsgcore' then
        local ok, rows = pcall(MySQL.query.await,
            'SELECT citizenid, charinfo, job, money, position FROM players WHERE license = ?',
            { license })
        if not ok or type(rows) ~= 'table' then return nil end

        local list = {}
        for _, r in ipairs(rows) do
            local info = decodeJson(r.charinfo, {})
            local name = r.citizenid
            if info.firstname then
                local joined = ((info.firstname or '') .. ' ' .. (info.lastname or '')):match('^%s*(.-)%s*$')
                if joined and joined ~= '' then name = joined end
            end
            local balances = accountBalances(r.citizenid, r.money)
            list[#list + 1] = {
                charid = r.citizenid,
                raw = r.citizenid,
                citizenId = r.citizenid,
                name = name,
                firstname = info.firstname or '',
                lastname = info.lastname or '',
                dob = info.birthdate,
                age = info.age,
                sex = info.gender,
                lastLocation = parseCoordsTable(r.position),
                job = storedJobLabel(src, r.job),
                cash = balances.cash,
                bank = balances.bank,
                gold = balances.gold,
                blocked = getCharacterBlock(r.citizenid),
            }
        end
        return list
    end
    return {}
end
exports('FwGetAccountCharacters', getAccountCharacters)

local function loginCharacter(src, cid, newData)
    src = tonumber(src)
    if not src then return false, 'invalid_source' end

    if WFW.Name == 'vorp' then
        local raw = tonumber((tostring(cid or ''):gsub('^vorp:', '')))
        local user = S.FW and S.FW.GetUser(src)
        if user and raw and type(user.setUsedCharacter) == 'function' then
            local ok, err = pcall(user.setUsedCharacter, raw)
            return ok, err
        end
        return false, 'user_not_found'
    elseif WFW.Name == 'rsgcore' then
        local currentPlayer = S.FW and S.FW.GetUser(src)
        if currentPlayer then
            local saved, why = saveLoggedIn(currentPlayer)
            if not saved then
                return false, why or 'save_not_confirmed'
            end
            if WFW.PublicName ~= 'qbr' and WFW.Core and WFW.Core.Player and WFW.Core.Player.Logout then
                pcall(WFW.Core.Player.Logout, src)
                if type(Wait) == 'function' then Wait(250) end
            end
        end

        if WFW.PublicName == 'qbr' then
            local res = exports.w_lib:FwNativeCoreCall('Login', src, cid, newData)
            return res ~= false
        end
        if WFW.Core and WFW.Core.Player and WFW.Core.Player.Login then
            local ok, res, err = pcall(WFW.Core.Player.Login, src, cid, newData)
            if not ok then return false, tostring(res) end
            return res ~= false, err
        end
        return false, 'login_unavailable'
    end
    return false, 'unsupported'
end
exports('FwLoginCharacter', loginCharacter)

exports('FwLogoutCharacter', function(src)
    src = tonumber(src)
    if not src then return false end
    if WFW.Name == 'rsgcore' then
        local currentPlayer = S.FW and S.FW.GetUser(src)
        if currentPlayer then
            local saved, why = saveLoggedIn(currentPlayer)
            if not saved then return false, why or 'save_not_confirmed' end
        end
        if WFW.PublicName == 'qbr' then
            return exports.w_lib:FwNativeCoreCall('Logout', src) ~= false
        end
        if WFW.Core and WFW.Core.Player and WFW.Core.Player.Logout then
            pcall(WFW.Core.Player.Logout, src)
            return true
        end
        return false
    elseif WFW.Name == 'vorp' then
        if S.getChar and S.getChar(src) then
            return false, 'unsupported'
        end
        return true
    end
    return false
end)

local function vorpCharacterIds(license)
    if type(MySQL) ~= 'table' or not MySQL.query or not MySQL.query.await then return nil end
    local ok, rows = pcall(MySQL.query.await, 'SELECT charidentifier FROM characters WHERE identifier = ?', { license })
    if not ok or type(rows) ~= 'table' then return nil end
    local ids = {}
    for _, r in ipairs(rows) do
        local id = tonumber(r.charidentifier)
        if id then ids[id] = true end
    end
    return ids
end

exports('FwCreateCharacter', function(src, data)
    src = tonumber(src)
    data = type(data) == 'table' and data or {}
    if not src then return nil end

    local first = sanitizeName(data.firstname, nil)
    local last = sanitizeName(data.lastname, nil)
    if not first then
        local f, l = tostring(data.name or ''):match('^(%S+)%s*(.*)$')
        first = sanitizeName(f, 'Character')
        last = last or sanitizeName(l, nil)
    end
    if not last then last = '.' end

    if WFW.Name == 'vorp' then
        local user = S.FW and S.FW.GetUser(src)
        if not user or type(user.addCharacter) ~= 'function' then return nil end
        local license = getAccountLicense(src)
        if not license then return nil end
        local existing = vorpCharacterIds(license)
        if not existing then return nil end

        local added = pcall(function()
            user.addCharacter({
                firstname = first,
                lastname = last,
                charDescription = data.charDescription or 'New Character',
                nickname = data.nickname or first,
                age = ageOf(data),
                gender = data.isMale and 'm' or 'f',
                skin = '{}',
                comps = '{}',
            })
        end)
        if not added then return nil end

        local newId
        for _ = 1, 40 do
            for id in pairs(vorpCharacterIds(license) or {}) do
                if not existing[id] and (newId == nil or id > newId) then
                    newId = id
                end
            end
            if newId then break end
            if type(Wait) == 'function' then Wait(100) end
        end
        if not newId then return nil end
        if type(user.setUsedCharacter) == 'function' then
            pcall(user.setUsedCharacter, newId)
        end
        return 'vorp:' .. tostring(newId)
    elseif WFW.Name == 'rsgcore' then
        local listed = getAccountCharacters(src)
        if type(listed) ~= 'table' then return nil end
        local cidNum = #listed + 1
        local newData = {
            cid = cidNum,
            charinfo = {
                firstname = first,
                lastname = last,
                birthdate = birthdateOf(data),
                gender = data.isMale and 0 or 1,
                nationality = data.nationality or 'USA',
            },
        }
        pcall(TriggerEvent, 'w_creators:server:characterCreated', src)
        local ok = loginCharacter(src, false, newData)
        if not ok then return nil end
        if type(Wait) == 'function' then Wait(100) end
        return exports.w_lib:FwGetCharacterIdentifier(src)
    end
    return nil
end)

exports('FwDeleteCharacter', function(src, cid)
    src = tonumber(src)
    local cidStr = tostring(cid or '')
    if not src or cidStr == '' then return false, 'invalid_data' end

    if WFW.Name == 'vorp' then
        local raw = tonumber((cidStr:gsub('^vorp:', '')))
        if not raw or type(MySQL) ~= 'table' or not MySQL.query or not MySQL.query.await then
            return false, 'invalid_data'
        end
        local ok = pcall(MySQL.query.await, 'DELETE FROM characters WHERE charidentifier = ?', { raw })
        return ok == true
    elseif WFW.Name == 'rsgcore' then
        if WFW.PublicName == 'qbr' then
            local ok, res, reason = pcall(function()
                return exports.w_lib:FwNativeCoreCall('DeleteCharacter', src, cidStr)
            end)
            if not ok then return false, 'error' end
            if res == false then return false, reason end
            return true
        end
        if WFW.Core and WFW.Core.Player and WFW.Core.Player.DeleteCharacter then
            local ok, res, reason = pcall(WFW.Core.Player.DeleteCharacter, src, cidStr)
            if not ok then return false, 'error' end
            if res == false then return false, reason end
            return true
        end
    end
    return false, 'unsupported'
end)
