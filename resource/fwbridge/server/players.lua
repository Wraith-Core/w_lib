-- ════════════════════════════════════════════════════════════════════════════
-- w_lib — fwbridge/server/players.lua
--   Online/offline player snapshots, duty, gang, levels, metadata, permissions,
--   commands, and citizen generation helpers across w_core, VORP, RSG, QBR, module.
-- ════════════════════════════════════════════════════════════════════════════
if not IsDuplicityVersion() then return end

WFW = WFW or {}
WFW._Server = WFW._Server or {}
local S = WFW._Server

local function decodeJsonSafe(val, fallback)
    if type(val) == 'table' then return val end
    if type(val) == 'string' and val ~= '' then
        local ok, decoded = pcall(json.decode, val)
        if ok and type(decoded) == 'table' then return decoded end
    end
    return fallback
end

local function cloneTable(tbl)
    if type(tbl) ~= 'table' then return {} end
    local out = {}
    for k, v in pairs(tbl) do
        if type(v) == 'table' then
            out[k] = cloneTable(v)
        elseif type(v) ~= 'function' then
            out[k] = v
        end
    end
    return out
end

local function cleanVorpId(cid)
    local s = tostring(cid or '')
    s = s:gsub('^vorp:', '')
    return tonumber(s)
end

local function isCallable(fn)
    return type(fn) == 'function' or (type(fn) == 'table' and getmetatable(fn) and getmetatable(fn).__call ~= nil)
end

-- ───────────────────────── Online Players & Snapshots ─────────────────────────

local function buildPlayerSnapshot(src)
    src = tonumber(src)
    if not src then return nil end
    local cid = exports.w_lib:FwGetCharacterIdentifier(src)
    if not cid then return nil end
    local char = S.getChar and S.getChar(src) or nil
    local jobInfo = S.buildJobInfo and S.buildJobInfo(src) or exports.w_lib:FwGetJobInfo(src)
    local rawGang = (WFW.Name == 'rsgcore' and type(char) == 'table') and char.gang or nil
    local gangNorm = S.normalizeGang and S.normalizeGang(rawGang) or {
        name = 'none', label = 'No Gang', label_ar = 'بدون عصابة',
        grade = 0, gradeName = '', grade_name_ar = '', isboss = false,
    }
    local rawMeta = exports.w_lib:FwGetMetadata(src)
    local money = {
        cash = tonumber(exports.w_lib:FwGetMoney(src)) or 0,
        gold = tonumber(exports.w_lib:FwGetGold(src)) or 0,
        bank = 0,
    }
    local charinfo = {}
    local license = exports.w_lib:FwGetIdentifier(src)

    if WFW.Name == 'rsgcore' and type(char) == 'table' then
        local ci = type(char.charinfo) == 'table' and char.charinfo or {}
        charinfo = {
            firstname = ci.firstname or '',
            lastname = ci.lastname or '',
            nickname = ci.nickname or '',
            age = ci.age,
            gender = ci.gender,
            birthdate = ci.birthdate,
            account = ci.account,
            phone = ci.phone,
            description = ci.description or '',
        }
        license = char.license or license
        if type(char.money) == 'table' and char.money.bank ~= nil then
            money.bank = tonumber(char.money.bank) or 0
        end
    elseif WFW.Name == 'vorp' and type(char) == 'table' then
        charinfo = {
            firstname = char.firstname or '',
            lastname = char.lastname or '',
            nickname = char.nickname or '',
            age = char.age,
            gender = char.gender,
            description = char.charDescription or '',
        }
        license = char.identifier or license
    else
        charinfo = {
            firstname = exports.w_lib:FwGetFirstName(src) or '',
            lastname = exports.w_lib:FwGetLastName(src) or '',
            nickname = exports.w_lib:FwGetNickname(src) or '',
            age = exports.w_lib:FwGetAge(src),
            description = exports.w_lib:FwGetDescription(src) or '',
        }
    end

    local jobSnapshot = {
        name = jobInfo.name or 'unemployed',
        label = jobInfo.label or jobInfo.name or 'Unemployed',
        label_ar = jobInfo.label_ar or jobInfo.label or 'Unemployed',
        type = jobInfo.type or 'none',
        onduty = jobInfo.onduty == true,
        isboss = jobInfo.isboss == true,
        payment = tonumber(jobInfo.payment) or 0,
        grade = {
            level = tonumber(jobInfo.grade) or 0,
            name = jobInfo.gradeName or '',
            name_ar = jobInfo.grade_name_ar or jobInfo.gradeName or '',
            payment = tonumber(jobInfo.payment) or 0,
            isboss = jobInfo.isboss == true,
        },
    }

    local gangSnapshot = {
        name = gangNorm.name or 'none',
        label = gangNorm.label or 'No Gang',
        label_ar = gangNorm.label_ar or gangNorm.label or 'No Gang',
        isboss = gangNorm.isboss == true,
        grade = {
            level = tonumber(gangNorm.grade) or 0,
            name = gangNorm.gradeName or '',
            name_ar = gangNorm.grade_name_ar or gangNorm.gradeName or '',
            isboss = gangNorm.isboss == true,
        },
    }

    return {
        source = src,
        citizenid = tostring(cid),
        license = license,
        name = exports.w_lib:FwGetCharacterName(src),
        charinfo = charinfo,
        job = jobSnapshot,
        gang = gangSnapshot,
        metadata = cloneTable(rawMeta),
        money = money,
    }
end

exports('FwGetPlayerData', buildPlayerSnapshot)

local function makeFilterSet(val)
    if type(val) == 'string' and val ~= '' then
        return { [val] = true }
    elseif type(val) == 'table' then
        local set = {}
        for k, v in pairs(val) do
            if type(k) == 'number' and type(v) == 'string' then
                set[v] = true
            elseif type(k) == 'string' and v == true then
                set[k] = true
            end
        end
        if next(set) ~= nil then return set end
    end
    return nil
end

exports('FwGetOnlinePlayers', function(filter)
    local out = {}
    local jobSet = type(filter) == 'table' and makeFilterSet(filter.job) or nil
    local gangSet = type(filter) == 'table' and makeFilterSet(filter.gang) or nil
    local wantDuty = nil
    if type(filter) == 'table' and filter.onduty ~= nil then
        wantDuty = filter.onduty == true
    end

    for _, src in ipairs(exports.w_lib:FwGetLoadedPlayers()) do
        local snap = buildPlayerSnapshot(src)
        if snap then
            local ok = true
            if jobSet and not jobSet[snap.job.name] then ok = false end
            if ok and gangSet and not gangSet[snap.gang.name] then ok = false end
            if ok and wantDuty ~= nil and (snap.job.onduty == true) ~= wantDuty then ok = false end
            if ok then
                out[src] = snap
            end
        end
    end
    return out
end)

exports('FwGetPlayerByCitizenId', function(cid)
    if cid == nil or cid == '' then return nil end
    local target = tostring(cid)
    if WFW.Name == 'rsgcore' and WFW.Core and WFW.Core.Functions and WFW.Core.Functions.GetPlayerByCitizenId then
        local ok, p = pcall(WFW.Core.Functions.GetPlayerByCitizenId, target)
        if ok and type(p) == 'table' and p.PlayerData and p.PlayerData.source then
            return buildPlayerSnapshot(p.PlayerData.source)
        end
    end
    local src = exports.w_lib:FwGetSource(target)
    if src then return buildPlayerSnapshot(src) end
    return nil
end)

-- ───────────────────────── Duty Queries & Mutators ─────────────────────────

local function getPlayersOnDuty(jobOrList)
    local jobSet = makeFilterSet(jobOrList)
    local out = {}
    local loaded = exports.w_lib:FwGetLoadedPlayers()
    for _, src in ipairs(loaded) do
        local info = S.buildJobInfo and S.buildJobInfo(src) or exports.w_lib:FwGetJobInfo(src)
        if info and info.onduty == true and (not jobSet or jobSet[info.name]) then
            out[#out + 1] = src
        end
    end
    if #loaded == 0 and WFW.Name == 'rsgcore' and type(jobOrList) == 'string'
        and WFW.Core and WFW.Core.Functions and WFW.Core.Functions.GetPlayersOnDuty then
        local ok, list = pcall(WFW.Core.Functions.GetPlayersOnDuty, jobOrList)
        if ok and type(list) == 'table' then
            return list, #list
        end
    end
    return out, #out
end

exports('FwGetPlayersOnDuty', getPlayersOnDuty)
exports('FwGetDutyCount', function(jobOrList)
    if WFW.Name == 'rsgcore' and type(jobOrList) == 'string'
        and #(exports.w_lib:FwGetLoadedPlayers()) == 0
        and WFW.Core and WFW.Core.Functions and WFW.Core.Functions.GetDutyCount then
        local ok, count = pcall(WFW.Core.Functions.GetDutyCount, jobOrList)
        if ok and tonumber(count) then return tonumber(count) end
    end
    local _, count = getPlayersOnDuty(jobOrList)
    return count
end)

local function setDuty(src, onDuty)
    src = tonumber(src)
    if not src then return nil end
    local state = onDuty == true
    if WFW.Name == 'rsgcore' then
        local player = S.FW and S.FW.GetUser(src)
        if not player or not player.PlayerData then return nil end
        if player.Functions and player.Functions.SetJobDuty then
            player.Functions.SetJobDuty(state)
        elseif type(player.PlayerData.job) == 'table' then
            player.PlayerData.job.onduty = state
        end
        if type(TriggerClientEvent) == 'function' then
            pcall(TriggerClientEvent, 'WCore:Client:SetDuty', src, state)
            if not (S.isWCore and S.isWCore()) then
                pcall(TriggerClientEvent, 'RSGCore:Client:SetDuty', src, state)
            end
            pcall(TriggerClientEvent, 'w_lib:fw:client:dutyChanged', src, state)
        end
        if S.emitDutyChange then S.emitDutyChange(src, state) end
        return state
    elseif WFW.Name == 'vorp' or WFW.Name == 'module' then
        local char = S.getChar and S.getChar(src)
        if not char then return nil end
        S.vorpDuty[src] = state
        if type(TriggerClientEvent) == 'function' then
            pcall(TriggerClientEvent, 'w_lib:fw:client:dutyChanged', src, state)
            local jobInfo = S.buildJobInfo and S.buildJobInfo(src)
            if jobInfo then
                pcall(TriggerClientEvent, 'w_lib:fw:client:jobUpdate', src, jobInfo)
            end
        end
        if S.emitDutyChange then S.emitDutyChange(src, state) end
        return state
    end
    return nil
end

exports('FwSetDuty', setDuty)
exports('FwToggleDuty', function(src)
    src = tonumber(src)
    if not src then return nil end
    local cid = exports.w_lib:FwGetCharacterIdentifier(src)
    if not cid then return nil end
    local info = S.buildJobInfo and S.buildJobInfo(src) or exports.w_lib:FwGetJobInfo(src)
    return setDuty(src, not (info and info.onduty == true))
end)

RegisterNetEvent('w_lib:fw:server:toggleDuty', function()
    local src = tonumber(source)
    if not src then return end
    exports.w_lib:FwToggleDuty(src)
end)

-- ───────────────────────── Offline Players & Metadata ─────────────────────────

local function loadVorpOfflineMeta(cidKey)
    local out = {}
    if not S.ensureVorpMetaTable or not S.ensureVorpMetaTable() then return out end
    local ok, rows = pcall(MySQL.query.await, 'SELECT meta_key, meta_val FROM w_fw_metadata WHERE charid = ?', { tostring(cidKey) })
    if ok and type(rows) == 'table' then
        for _, row in ipairs(rows) do
            if type(row.meta_key) == 'string' then
                local val = row.meta_val
                if type(val) == 'string' then
                    local dok, decoded = pcall(json.decode, val)
                    if dok then val = decoded end
                end
                out[row.meta_key] = val
            end
        end
    end
    return out
end

local function normalizeOfflineRsgRow(pd)
    local charinfo = decodeJsonSafe(pd.charinfo, {})
    local job = decodeJsonSafe(pd.job, { name = 'unemployed', label = 'Unemployed', grade = { level = 0, name = '' } })
    local gang = decodeJsonSafe(pd.gang, { name = 'none', label = 'No Gang', grade = { level = 0, name = '' } })
    local metadata = decodeJsonSafe(pd.metadata, {})
    local money = decodeJsonSafe(pd.money, {})
    local position = decodeJsonSafe(pd.position, nil)
    return {
        citizenid = pd.citizenid,
        license = pd.license,
        charinfo = charinfo,
        job = job,
        gang = gang,
        metadata = metadata,
        money = money,
        position = position,
    }
end

exports('FwGetOfflinePlayer', function(cid)
    if cid == nil or cid == '' then return nil end
    local cidStr = tostring(cid)
    local onlineSrc = exports.w_lib:FwGetSource(cidStr)
    if onlineSrc then
        return buildPlayerSnapshot(onlineSrc)
    end

    if WFW.Name == 'rsgcore' then
        if WFW.Core and WFW.Core.Player and WFW.Core.Player.GetOfflinePlayer then
            local ok, offline = pcall(WFW.Core.Player.GetOfflinePlayer, cidStr)
            if ok and type(offline) == 'table' and type(offline.PlayerData) == 'table' then
                return normalizeOfflineRsgRow(offline.PlayerData)
            end
        end
        if type(MySQL) == 'table' and MySQL.single and MySQL.single.await then
            local row = MySQL.single.await('SELECT * FROM players WHERE citizenid = ? LIMIT 1', { cidStr })
            if type(row) == 'table' then
                return normalizeOfflineRsgRow(row)
            end
        end
    elseif WFW.Name == 'vorp' then
        local numId = cleanVorpId(cidStr)
        if not numId or type(MySQL) ~= 'table' or not MySQL.single or not MySQL.single.await then return nil end
        local row = MySQL.single.await(
            'SELECT charidentifier, identifier, firstname, lastname, age, gender, job, jobgrade, joblabel, money, gold, rol, coords, isdead FROM characters WHERE charidentifier = ? LIMIT 1',
            { numId }
        )
        if type(row) ~= 'table' then return nil end
        local meta = loadVorpOfflineMeta(numId)
        if meta.isdead == nil and row.isdead ~= nil then
            meta.isdead = (row.isdead == 1 or row.isdead == true)
        end
        if meta.licences == nil then
            meta.licences = type(meta.licenses) == 'table' and meta.licenses or {}
        end
        local coords = decodeJsonSafe(row.coords, nil)
        return {
            citizenid = tostring(row.charidentifier),
            license = row.identifier,
            charinfo = {
                firstname = row.firstname or '',
                lastname = row.lastname or '',
                age = row.age,
                gender = row.gender,
            },
            job = {
                name = row.job or 'unemployed',
                label = row.joblabel or row.job or 'Unemployed',
                grade = { level = tonumber(row.jobgrade) or 0, name = '' },
                onduty = true,
                isboss = false,
            },
            gang = {
                name = 'none',
                label = 'No Gang',
                grade = { level = 0, name = '' },
                isboss = false,
            },
            metadata = meta,
            money = {
                cash = tonumber(row.money) or 0,
                gold = tonumber(row.gold) or 0,
                rol = tonumber(row.rol) or 0,
            },
            position = coords,
        }
    end
    return nil
end)

exports('FwSetOfflineMetadata', function(cid, values)
    if cid == nil or cid == '' or type(values) ~= 'table' then return false end
    local cidStr = tostring(cid)
    local onlineSrc = exports.w_lib:FwGetSource(cidStr)
    if onlineSrc then
        local ok = true
        for k, v in pairs(values) do
            if not exports.w_lib:FwSetMetadata(onlineSrc, k, v) then ok = false end
        end
        exports.w_lib:FwSavePlayer(onlineSrc)
        return ok
    end

    if WFW.Name == 'rsgcore' then
        if WFW.Core and WFW.Core.Player and WFW.Core.Player.GetOfflinePlayer then
            local ok, offline = pcall(WFW.Core.Player.GetOfflinePlayer, cidStr)
            if ok and type(offline) == 'table' and type(offline.Functions) == 'table' then
                for k, v in pairs(values) do
                    local val = v
                    if (k == 'hunger' or k == 'thirst') and tonumber(val) then
                        val = math.min(100, tonumber(val))
                    end
                    if offline.Functions.SetMetaData then
                        offline.Functions.SetMetaData(k, val)
                    elseif type(offline.PlayerData) == 'table' then
                        offline.PlayerData.metadata = offline.PlayerData.metadata or {}
                        offline.PlayerData.metadata[k] = val
                    end
                end
                if offline.Functions.Save then
                    offline.Functions.Save()
                end
                return true
            end
        end
        if type(MySQL) == 'table' and MySQL.single and MySQL.single.await then
            local row = MySQL.single.await('SELECT metadata FROM players WHERE citizenid = ? LIMIT 1', { cidStr })
            if not row then return false end
            local meta = decodeJsonSafe(row.metadata, {})
            for k, v in pairs(values) do
                local val = v
                if (k == 'hunger' or k == 'thirst') and tonumber(val) then
                    val = math.min(100, tonumber(val))
                end
                meta[k] = val
            end
            local affected = MySQL.update.await('UPDATE players SET metadata = ? WHERE citizenid = ?', { json.encode(meta), cidStr })
            return (tonumber(affected) or 0) > 0
        end
    elseif WFW.Name == 'vorp' then
        local numId = cleanVorpId(cidStr)
        if not numId then return false end
        local any = false
        if S.ensureVorpMetaTable and S.ensureVorpMetaTable() then
            for k, v in pairs(values) do
                if type(k) == 'string' and k ~= '' then
                    pcall(MySQL.update.await,
                        'INSERT INTO w_fw_metadata (charid, meta_key, meta_val) VALUES (?, ?, ?) ON DUPLICATE KEY UPDATE meta_val = VALUES(meta_val)',
                        { tostring(numId), k, json.encode(v) })
                    any = true
                end
            end
        end
        if values.isdead ~= nil and type(MySQL) == 'table' and MySQL.update and MySQL.update.await then
            pcall(MySQL.update.await, 'UPDATE characters SET isdead = ? WHERE charidentifier = ?',
                { values.isdead == true and 1 or 0, numId })
            any = true
        end
        return any
    end
    return false
end)

local function formatNamePair(first, last)
    local joined = ((first or '') .. ' ' .. (last or '')):match('^%s*(.-)%s*$')
    return (joined and joined ~= '') and joined or nil
end

exports('FwGetOfflineCharacterName', function(cidOrList)
    if type(cidOrList) == 'table' then
        local out = {}
        local pending = {}
        local pendingLookup = {}
        for _, rawCid in ipairs(cidOrList) do
            local key = tostring(rawCid or '')
            if key ~= '' then
                local src = exports.w_lib:FwGetSource(key)
                if src then
                    out[key] = exports.w_lib:FwGetCharacterName(src)
                else
                    pending[#pending + 1] = key
                end
            end
        end
        if #pending == 0 or type(MySQL) ~= 'table' or not MySQL.query or not MySQL.query.await then
            return out
        end
        if WFW.Name == 'rsgcore' then
            local ph, params = {}, {}
            for i = 1, #pending do
                ph[i] = '?'
                params[i] = pending[i]
            end
            local ok, rows = pcall(MySQL.query.await,
                ('SELECT citizenid, charinfo FROM players WHERE citizenid IN (%s)'):format(table.concat(ph, ',')),
                params)
            if ok and type(rows) == 'table' then
                for _, r in ipairs(rows) do
                    local ci = decodeJsonSafe(r.charinfo, {})
                    local name = formatNamePair(ci.firstname, ci.lastname)
                    if name then out[tostring(r.citizenid)] = name end
                end
            end
        elseif WFW.Name == 'vorp' then
            local ph, params = {}, {}
            for i = 1, #pending do
                local numId = cleanVorpId(pending[i])
                if numId then
                    ph[#ph + 1] = '?'
                    params[#params + 1] = numId
                    pendingLookup[tostring(numId)] = pending[i]
                end
            end
            if #params > 0 then
                local ok, rows = pcall(MySQL.query.await,
                    ('SELECT charidentifier, firstname, lastname FROM characters WHERE charidentifier IN (%s)'):format(table.concat(ph, ',')),
                    params)
                if ok and type(rows) == 'table' then
                    for _, r in ipairs(rows) do
                        local name = formatNamePair(r.firstname, r.lastname)
                        local origKey = pendingLookup[tostring(r.charidentifier)] or tostring(r.charidentifier)
                        if name then out[origKey] = name end
                    end
                end
            end
        end
        return out
    end

    if cidOrList == nil or cidOrList == '' then return nil end
    local cidStr = tostring(cidOrList)
    local src = exports.w_lib:FwGetSource(cidStr)
    if src then return exports.w_lib:FwGetCharacterName(src) end
    if type(MySQL) ~= 'table' or not MySQL.single or not MySQL.single.await then return nil end

    if WFW.Name == 'rsgcore' then
        local ok, row = pcall(MySQL.single.await, 'SELECT charinfo FROM players WHERE citizenid = ? LIMIT 1', { cidStr })
        if ok and type(row) == 'table' then
            local ci = decodeJsonSafe(row.charinfo, {})
            return formatNamePair(ci.firstname, ci.lastname)
        end
    elseif WFW.Name == 'vorp' then
        local numId = cleanVorpId(cidStr)
        if not numId then return nil end
        local ok, row = pcall(MySQL.single.await, 'SELECT firstname, lastname FROM characters WHERE charidentifier = ? LIMIT 1', { numId })
        if ok and type(row) == 'table' then
            return formatNamePair(row.firstname, row.lastname)
        end
    end
    return nil
end)

-- ───────────────────────── Online Mutators (Meta / Data / CharInfo / Save) ─────────────────────────

exports('FwSetMetadata', function(src, key, val)
    src = tonumber(src)
    if not src or type(key) ~= 'string' or key == '' then return false end

    if WFW.Name == 'rsgcore' then
        local player = S.FW and S.FW.GetUser(src)
        if not player or not player.PlayerData then return false end
        if (key == 'hunger' or key == 'thirst') and tonumber(val) then
            val = math.min(100, tonumber(val))
        end
        if player.Functions and player.Functions.SetMetaData then
            player.Functions.SetMetaData(key, val)
            return true
        end
        player.PlayerData.metadata = player.PlayerData.metadata or {}
        player.PlayerData.metadata[key] = val
        return true
    elseif WFW.Name == 'vorp' or WFW.Name == 'module' then
        local cid = exports.w_lib:FwGetCharacterIdentifier(src)
        if not cid then return false end
        S.vorpMeta[src] = S.vorpMeta[src] or {}
        S.vorpMeta[src][key] = val
        if S.ensureVorpMetaTable and S.ensureVorpMetaTable() then
            pcall(MySQL.update.await,
                'INSERT INTO w_fw_metadata (charid, meta_key, meta_val) VALUES (?, ?, ?) ON DUPLICATE KEY UPDATE meta_val = VALUES(meta_val)',
                { tostring(cid), key, json.encode(val) })
        end
        if key == 'isdead' or key == 'inlaststand' then
            local down = (S.vorpMeta[src].isdead == true or S.vorpMeta[src].inlaststand == true)
            if WFW.Name == 'vorp' and key == 'isdead' and type(MySQL) == 'table' and MySQL.update and MySQL.update.await then
                local numId = cleanVorpId(cid)
                if numId then
                    pcall(MySQL.update.await, 'UPDATE characters SET isdead = ? WHERE charidentifier = ?', { val == true and 1 or 0, numId })
                end
            end
            if type(TriggerClientEvent) == 'function' then
                pcall(TriggerClientEvent, 'w_lib:fw:client:vorpMeta', src, key, val, down)
            end
        end
        return true
    end
    return false
end)

exports('FwSetPlayerData', function(src, key, val)
    src = tonumber(src)
    if not src or type(key) ~= 'string' or key == '' then return false end
    if key == 'money' or key == 'citizenid' then return false end

    if WFW.Name == 'rsgcore' then
        local player = S.FW and S.FW.GetUser(src)
        if not player or not player.PlayerData then return false end
        if player.Functions and player.Functions.SetPlayerData then
            local res = player.Functions.SetPlayerData(key, val)
            return res ~= false
        end
        player.PlayerData[key] = val
        return true
    elseif WFW.Name == 'vorp' and key == 'charinfo' and type(val) == 'table' then
        return exports.w_lib:FwSetCharInfo(src, val)
    end
    return false
end)

exports('FwSetCharInfo', function(src, patch)
    src = tonumber(src)
    if not src or type(patch) ~= 'table' then return false end
    if WFW.Name == 'rsgcore' then
        local player = S.FW and S.FW.GetUser(src)
        if not player or not player.PlayerData then return false end
        local info = cloneTable(player.PlayerData.charinfo or {})
        for k, v in pairs(patch) do
            info[k] = v
        end
        if player.Functions and player.Functions.SetPlayerData then
            player.Functions.SetPlayerData('charinfo', info)
        else
            player.PlayerData.charinfo = info
        end
        if player.Functions and player.Functions.Save then
            pcall(player.Functions.Save)
        end
        return true
    elseif WFW.Name == 'vorp' then
        local user = S.FW and S.FW.GetUser(src)
        local char = user and user.getUsedCharacter
        if not char then return false end
        if patch.firstname ~= nil and char.setFirstname then char.setFirstname(patch.firstname) end
        if patch.lastname ~= nil and char.setLastname then char.setLastname(patch.lastname) end
        if patch.nickname ~= nil and char.setNickName then char.setNickName(patch.nickname) end
        if patch.age ~= nil and char.setAge then char.setAge(patch.age) end
        if patch.description ~= nil and char.setCharDescription then char.setCharDescription(patch.description) end
        return true
    end
    return false
end)

exports('FwSavePlayer', function(src)
    src = tonumber(src)
    if not src then return false end
    if WFW.Name == 'rsgcore' then
        local player = S.FW and S.FW.GetUser(src)
        if not player then return false end
        if player.Functions and player.Functions.Save then
            local ok = pcall(player.Functions.Save)
            return ok
        end
        if WFW.Core and WFW.Core.Player and WFW.Core.Player.Save then
            local ok = pcall(WFW.Core.Player.Save, src)
            return ok
        end
        return false
    elseif WFW.Name == 'vorp' then
        local cid = exports.w_lib:FwGetCharacterIdentifier(src)
        if not cid then return false end
        local meta = S.vorpMeta[src]
        if type(meta) == 'table' then
            if S.ensureVorpMetaTable and S.ensureVorpMetaTable() then
                for k, v in pairs(meta) do
                    pcall(MySQL.update.await,
                        'INSERT INTO w_fw_metadata (charid, meta_key, meta_val) VALUES (?, ?, ?) ON DUPLICATE KEY UPDATE meta_val = VALUES(meta_val)',
                        { tostring(cid), k, json.encode(v) })
                end
            end
            if meta.isdead ~= nil and type(MySQL) == 'table' and MySQL.update and MySQL.update.await then
                local numId = cleanVorpId(cid)
                if numId then
                    pcall(MySQL.update.await, 'UPDATE characters SET isdead = ? WHERE charidentifier = ?', { meta.isdead == true and 1 or 0, numId })
                end
            end
        end
        return true
    end
    return false
end)

-- ───────────────────────── Gang & Levels ─────────────────────────

exports('FwSetGang', function(src, gang, grade)
    src = tonumber(src)
    if not src or type(gang) ~= 'string' or gang == '' then return false end
    if WFW.Name ~= 'rsgcore' then return false end
    local player = S.FW and S.FW.GetUser(src)
    if not player or not player.Functions or not player.Functions.SetGang then return false end
    local ok, res = pcall(player.Functions.SetGang, gang:lower(), tonumber(grade) or 0)
    return ok and res ~= false
end)

exports('FwSetGangOffline', function(cid, gang, grade)
    if cid == nil or cid == '' or type(gang) ~= 'string' or gang == '' then return false end
    if WFW.Name ~= 'rsgcore' then return false end
    local gangName = gang:lower()
    local gradeNum = tonumber(grade) or 0
    local sharedGangs = WFW._Shared and WFW._Shared.getSharedGangs and WFW._Shared.getSharedGangs() or {}
    local gangDef = sharedGangs[gangName]
    local gradeDef = gangDef and type(gangDef.grades) == 'table' and (gangDef.grades[gradeNum] or gangDef.grades[tostring(gradeNum)]) or nil
    if not gangDef and gangName ~= 'none' then return false end
    local role = {
        name = gangName,
        label = (gangDef and gangDef.label) or gangName,
        label_ar = (gangDef and gangDef.label_ar) or (gangDef and gangDef.label) or gangName,
        grade = {
            level = gradeNum,
            name = (gradeDef and gradeDef.name) or tostring(gradeNum),
            name_ar = (gradeDef and gradeDef.name_ar) or (gradeDef and gradeDef.name) or tostring(gradeNum),
        },
        isboss = (gradeDef and gradeDef.isboss == true) or false,
    }
    return exports.w_lib:FwSetOfflineRole(tostring(cid), 'gang', role) == true
end)

local function adjustLevel(src, key, amount, createIfMissing, isRemove)
    src = tonumber(src)
    key = type(key) == 'string' and key:lower() or ''
    amount = tonumber(amount)
    if not src or key == '' or not amount or amount ~= amount or amount <= 0 or amount == math.huge then
        return false, 'invalid_amount'
    end
    if WFW.Name ~= 'rsgcore' then
        return false, 'unsupported'
    end
    local player = S.FW and S.FW.GetUser(src)
    if not player or not player.PlayerData then return false, 'player_not_found' end

    local meta = player.PlayerData.metadata or {}
    local levels = type(meta.levels) == 'table' and meta.levels or {}
    if levels[key] == nil then
        if createIfMissing == false then return false, 'unknown_level' end
        local copy = cloneTable(levels)
        copy[key] = 0
        exports.w_lib:FwSetMetadata(src, 'levels', copy)
    end

    local fnName = isRemove and 'RemoveLevel' or 'AddLevel'
    if player.Functions and type(player.Functions[fnName]) == 'function' then
        local ok, res = pcall(player.Functions[fnName], key, amount)
        return ok and res == true
    end

    local currentLevels = (player.PlayerData.metadata and player.PlayerData.metadata.levels) or {}
    local copy = cloneTable(currentLevels)
    local cur = tonumber(copy[key]) or 0
    copy[key] = isRemove and math.max(0, cur - amount) or (cur + amount)
    return exports.w_lib:FwSetMetadata(src, 'levels', copy)
end

exports('FwAddLevel', function(src, key, amount, createIfMissing)
    return adjustLevel(src, key, amount, createIfMissing, false)
end)

exports('FwRemoveLevel', function(src, key, amount)
    return adjustLevel(src, key, amount, false, true)
end)

-- ───────────────────────── Permissions & Commands ─────────────────────────

local PERM_RANK = { user = 0, vip = 1, mod = 2, admin = 3, god = 4, superadmin = 4, owner = 4 }

local function hasPermission(src, perm)
    src = tonumber(src)
    if src == 0 then return true end
    if not src or src < 1 then return false end
    local p = tostring(perm or ''):lower()
    if p == '' or p == 'user' then return true end

    if type(IsPlayerAceAllowed) == 'function' then
        if IsPlayerAceAllowed(src, 'command') then return true end
        if IsPlayerAceAllowed(src, p) then return true end
        if IsPlayerAceAllowed(src, 'wcore.' .. p) then return true end
        if IsPlayerAceAllowed(src, 'group.' .. p) then return true end
    end

    local char = S.getChar and S.getChar(src)
    if type(char) == 'table' and type(char.permission) == 'string' then
        local cp = char.permission:lower()
        if cp == p then return true end
        if PERM_RANK[cp] and PERM_RANK[p] and PERM_RANK[cp] >= PERM_RANK[p] then return true end
    end

    if exports and exports.w_lib then
        local okPerm, resPerm = pcall(function() return exports.w_lib:HasPermission(src, p) end)
        if okPerm and resPerm == true then return true end
        if p == 'admin' or p == 'god' or p == 'mod' then
            local okAdm, resAdm = pcall(function() return exports.w_lib:IsAdmin(src) end)
            if okAdm and resAdm == true then return true end
        end
    end
    return false
end

exports('FwHasPermission', hasPermission)

exports('FwAddCommand', function(name, help, params, argsRequired, cb, perm)
    if not isCallable(cb) then return false end
    local names = type(name) == 'table' and name or { tostring(name) }
    local restrictedPerm = (type(perm) == 'string' and perm ~= '' and perm ~= 'user') and perm:lower() or nil

    for i = 1, #names do
        local cmdName = tostring(names[i])
        if restrictedPerm and type(lib) == 'table' and type(lib.addAce) == 'function' then
            local ace = 'command.' .. cmdName
            pcall(lib.addAce, 'wcore.' .. restrictedPerm, ace)
            pcall(lib.addAce, 'group.' .. restrictedPerm, ace)
        end

        RegisterCommand(cmdName, function(src, args, raw)
            src = tonumber(src) or 0
            if restrictedPerm then
                local allowed = hasPermission(src, restrictedPerm)
                    or (type(IsPlayerAceAllowed) == 'function' and IsPlayerAceAllowed(src, 'command.' .. cmdName))
                if not allowed then
                    if src > 0 and type(TriggerClientEvent) == 'function' then
                        pcall(TriggerClientEvent, 'w_lib:notify', src, nil, 'No permission', 'error')
                    end
                    return
                end
            end
            args = type(args) == 'table' and args or {}
            if argsRequired and type(params) == 'table' and #args < #params then
                if src > 0 and type(TriggerClientEvent) == 'function' then
                    pcall(TriggerClientEvent, 'w_lib:notify', src, nil, 'Missing arguments', 'error')
                end
                return
            end
            pcall(cb, src, args, raw)
        end, false)

        if type(TriggerClientEvent) == 'function' then
            pcall(TriggerClientEvent, 'chat:addSuggestions', -1, {
                { name = '/' .. cmdName, help = help, params = params },
            })
        end
    end
    return true
end)

-- ───────────────────────── Citizen Generation ─────────────────────────

exports('FwGetCharacterGeneration', function(srcOrCid)
    local srcNum = tonumber(srcOrCid)
    if srcNum and exports.w_lib:FwGetCharacterIdentifier(srcNum) then
        local cid = tostring(exports.w_lib:FwGetCharacterIdentifier(srcNum))
        local char = S.getChar and S.getChar(srcNum)
        local rowId = type(char) == 'table' and tonumber(char.id) or nil
        if not rowId and S.isWCore and S.isWCore() and type(MySQL) == 'table' and MySQL.single and MySQL.single.await then
            local ok, row = pcall(MySQL.single.await, 'SELECT id FROM players WHERE citizenid = ? LIMIT 1', { cid })
            if ok and type(row) == 'table' then rowId = tonumber(row.id) end
        end
        return cid, rowId
    end
    local cid = srcOrCid ~= nil and tostring(srcOrCid) or nil
    if not cid or cid == '' then return nil, nil end
    local onlineSrc = exports.w_lib:FwGetSource(cid)
    if onlineSrc then
        local char = S.getChar and S.getChar(onlineSrc)
        local rowId = type(char) == 'table' and tonumber(char.id) or nil
        if rowId then return cid, rowId end
    end
    if S.isWCore and S.isWCore() and type(MySQL) == 'table' and MySQL.single and MySQL.single.await then
        local ok, row = pcall(MySQL.single.await, 'SELECT id FROM players WHERE citizenid = ? LIMIT 1', { cid })
        if ok and type(row) == 'table' then return cid, tonumber(row.id) end
    end
    return cid, nil
end)

exports('FwWithCitizenGeneration', function(cid, rowId, fn)
    if not isCallable(fn) then return false, 'invalid_generation' end
    if S.isWCore and S.isWCore() then
        local packed = table.pack(pcall(function()
            return exports.w_core:WithCitizenGeneration(cid, rowId, fn)
        end))
        if not packed[1] then return false, 'generation_unavailable' end
        if packed.n <= 1 then return false, 'generation_unavailable' end
        return table.unpack(packed, 2, packed.n)
    end
    local packed = table.pack(pcall(fn))
    if not packed[1] then return false, 'generation_callback_failed' end
    if packed.n <= 1 then return true end
    return table.unpack(packed, 2, packed.n)
end)

exports('FwIsVorpHudDisabled', function()
    if type(GetResourceState) ~= 'function' or GetResourceState('vorp_core') == 'missing' then
        return false
    end
    if type(LoadResourceFile) ~= 'function' then return false end
    local raw = LoadResourceFile('vorp_core', 'config/config.lua')
    if type(raw) ~= 'string' then return false end
    for line in raw:gmatch('[^\n]+') do
        local v = line:match('^%s*HideUi%s*=%s*(%a+)')
        if v then return v == 'true' end
    end
    return false
end)
