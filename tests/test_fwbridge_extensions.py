"""Comprehensive lupa unit tests for w_lib M1b Fw* extensions and framework-bridge fixes."""
from pathlib import Path
import json
import unittest
from lupa import lua54

ROOT = Path(__file__).resolve().parents[1]


def _pure_joaat(text: str) -> int:
    h = 0
    for ch in text.lower().encode("utf-8"):
        h = (h + ch) & 0xFFFFFFFF
        h = (h + ((h << 10) & 0xFFFFFFFF)) & 0xFFFFFFFF
        h = (h ^ (h >> 6)) & 0xFFFFFFFF
    h = (h + ((h << 3) & 0xFFFFFFFF)) & 0xFFFFFFFF
    h = (h ^ (h >> 11)) & 0xFFFFFFFF
    h = (h + ((h << 15) & 0xFFFFFFFF)) & 0xFFFFFFFF
    if h >= 0x80000000:
        h -= 0x100000000
    return h


def build_fwbridge_runtime(backend="w_core", is_server=True, locale="ar"):
    lua = lua54.LuaRuntime(unpack_returned_tuples=True)
    lua.globals()._TEST_BACKEND = backend
    lua.globals()._TEST_IS_SERVER = is_server
    lua.globals()._TEST_LOCALE = locale
    lua.globals()._TEST_JSON_ENCODE = json.dumps
    def _dec(s):
        val = json.loads(s)
        if isinstance(val, (dict, list)):
            return lua.table_from(val, recursive=True)
        return val
    lua.globals()._TEST_JSON_DECODE = _dec

    lua.execute(
        """
        local isServer = _TEST_IS_SERVER
        local backend = _TEST_BACKEND

        function IsDuplicityVersion() return isServer end

        json = {
            encode = function(v)
                local function toPy(x)
                    if type(x) ~= 'table' then return x end
                    return x
                end
                local ok, res = pcall(_TEST_JSON_ENCODE, toPy(v))
                if ok then return res end
                -- fallback simple Lua serializer for Lua tables
                local function ser(val)
                    local t = type(val)
                    if t == 'nil' then return 'null'
                    elseif t == 'boolean' then return val and 'true' or 'false'
                    elseif t == 'number' then return tostring(val)
                    elseif t == 'string' then return string.format('%q', val)
                    elseif t == 'table' then
                        local isArr = true
                        local maxN = 0
                        for k in pairs(val) do
                            if type(k) ~= 'number' or k < 1 or math.floor(k) ~= k then isArr = false break end
                            if k > maxN then maxN = k end
                        end
                        if isArr and maxN > 0 then
                            local parts = {}
                            for i = 1, maxN do parts[i] = ser(val[i]) end
                            return '[' .. table.concat(parts, ',') .. ']'
                        end
                        local parts = {}
                        for k, item in pairs(val) do
                            parts[#parts + 1] = string.format('%q:%s', tostring(k), ser(item))
                        end
                        return '{' .. table.concat(parts, ',') .. '}'
                    end
                    return 'null'
                end
                return ser(v)
            end,
            decode = function(s)
                if type(s) ~= 'string' or s == '' then return nil end
                local ok, dec = pcall(_TEST_JSON_DECODE, s)
                if not ok then return nil end
                return dec
            end,
        }

        function joaat(s)
            s = tostring(s or ''):lower()
            local hash = 0
            for i = 1, #s do
                hash = (hash + s:byte(i)) & 0xFFFFFFFF
                hash = (hash + ((hash << 10) & 0xFFFFFFFF)) & 0xFFFFFFFF
                hash = (hash ~ (hash >> 6)) & 0xFFFFFFFF
            end
            hash = (hash + ((hash << 3) & 0xFFFFFFFF)) & 0xFFFFFFFF
            hash = (hash ~ (hash >> 11)) & 0xFFFFFFFF
            hash = (hash + ((hash << 15) & 0xFFFFFFFF)) & 0xFFFFFFFF
            if hash >= 0x80000000 then hash = hash - 0x100000000 end
            return hash
        end
        GetHashKey = joaat

        RESOURCE_STATES = {
            w_lib = 'started',
            w_inventory = (backend == 'w_core') and 'started' or 'missing',
            w_core = (backend == 'w_core') and 'started' or 'missing',
            vorp_core = (backend == 'vorp_core') and 'started' or 'missing',
            ['rsg-core'] = (backend == 'rsg-core') and 'started' or 'missing',
            ['qbr-core'] = (backend == 'qbr-core') and 'started' or 'missing',
            w_centralbank = 'missing',
            w_medic = 'missing',
        }
        function GetResourceState(name) return RESOURCE_STATES[name] or 'missing' end

        INVOKING_RESOURCE = 'consumer_a'
        function GetInvokingResource() return INVOKING_RESOURCE end

        EXPORTS = {}
        exports = setmetatable({}, {
            __call = function(_, name, fn)
                EXPORTS[name] = fn
            end,
            __index = function(_, resName)
                if resName == 'w_lib' then
                    return setmetatable({}, {
                        __index = function(_, fnName)
                            return function(_, ...)
                                local fn = EXPORTS[fnName]
                                if not fn then error('missing w_lib export: ' .. tostring(fnName)) end
                                return fn(...)
                            end
                        end
                    })
                end
                local resTbl = EXPORTS[resName]
                if not resTbl then
                    resTbl = {}
                    EXPORTS[resName] = resTbl
                end
                return setmetatable({}, {
                    __index = function(_, fnName)
                        return function(_, ...)
                            local fn = resTbl[fnName]
                            if not fn then error('missing export ' .. tostring(resName) .. ':' .. tostring(fnName)) end
                            return fn(...)
                        end
                    end
                })
            end
        })

        EVENTS = {}
        NET_EVENTS = {}
        CLIENT_EVENTS = {}
        SERVER_EVENTS = {}
        COMMANDS = {}
        ACES = {}
        TIMERS = {}
        CLOCK = 1000
        WAITS = 0

        function AddEventHandler(name, fn)
            EVENTS[name] = EVENTS[name] or {}
            table.insert(EVENTS[name], fn)
        end
        function RegisterNetEvent(name, fn)
            if fn then
                NET_EVENTS[name] = NET_EVENTS[name] or {}
                table.insert(NET_EVENTS[name], fn)
            end
        end
        function TriggerEvent(name, ...)
            for _, fn in ipairs(EVENTS[name] or {}) do fn(...) end
            for _, fn in ipairs(NET_EVENTS[name] or {}) do fn(...) end
        end
        function TriggerClientEvent(name, target, ...)
            table.insert(CLIENT_EVENTS, { name = name, target = target, args = table.pack(...) })
        end
        function TriggerServerEvent(name, ...)
            table.insert(SERVER_EVENTS, { name = name, args = table.pack(...) })
        end
        function RegisterCommand(name, fn, restricted)
            COMMANDS[name] = { fn = fn, restricted = restricted }
        end
        function IsPlayerAceAllowed(src, ace)
            local p = ACES[tonumber(src)]
            return p and p[ace] == true or false
        end
        function GetGameTimer() return CLOCK end
        function SetTimeout(ms, fn)
            table.insert(TIMERS, { ms = ms, dueAt = CLOCK + ms, fn = fn })
        end
        function runTimers(advanceMs)
            CLOCK = CLOCK + (advanceMs or 0)
            local due = {}
            for _, t in ipairs(TIMERS) do
                if not t.fired and t.dueAt <= CLOCK then
                    t.fired = true
                    table.insert(due, t.fn)
                end
            end
            for _, fn in ipairs(due) do fn() end
        end
        function CreateThread(fn)
            -- run up to first Wait or completion cleanly
            fn()
        end
        function Wait(ms)
            WAITS = WAITS + 1
            CLOCK = CLOCK + (ms or 0)
        end
        function GetConvar(k, default)
            if k == 'w_lib:locale' or k == 'w_lib:i18n:locale' then return _TEST_LOCALE end
            return default
        end

        PLAYER_STATES = {}
        function Player(src)
            src = tonumber(src)
            PLAYER_STATES[src] = PLAYER_STATES[src] or { state = {} }
            return PLAYER_STATES[src]
        end
        LocalPlayer = { state = { isLoggedIn = false, IsInSession = false } }

        CONNECTED_PLAYERS = { '1', '2' }
        PLAYER_NAMES = { [1] = 'SteamOne', [2] = 'SteamTwo' }
        PLAYER_IDENTIFIERS = {
            [1] = { license = 'license:111', steam = 'steam:111' },
            [2] = { license = 'license:222', steam = 'steam:222' },
        }
        function GetPlayers() return CONNECTED_PLAYERS end
        function GetPlayerName(src) return PLAYER_NAMES[tonumber(src)] end
        function GetPlayerIdentifierByType(src, kind)
            local row = PLAYER_IDENTIFIERS[tonumber(src)]
            return row and row[kind] or nil
        end
        function GetPlayerIdentifier(src, idx)
            local row = PLAYER_IDENTIFIERS[tonumber(src)]
            return row and (row.license or row.steam) or nil
        end
        function GetCurrentPedWeapon() return true, joaat('weapon_revolver_cattleman') end
        function PlayerPedId() return 1 end

        lib = {
            getLocaleKey = function() return _TEST_LOCALE end,
            getPlayerLocaleKey = function(src)
                local st = PLAYER_STATES[tonumber(src)]
                if st and st.state['w_lib:locale'] then return st.state['w_lib:locale'] end
                return _TEST_LOCALE
            end,
            addAce = function(principal, ace)
                ADDED_ACES = ADDED_ACES or {}
                table.insert(ADDED_ACES, { principal = principal, ace = ace })
            end,
        }
        EXPORTS['getLocaleKey'] = lib.getLocaleKey
        EXPORTS['getPlayerLocaleKey'] = lib.getPlayerLocaleKey
        EXPORTS['CompatItems'] = function()
            return {
                bread = { name = 'bread', label = 'Bread', label_ar = 'خبز', weight = 100, type = 'item', image = 'bread.png' },
                ammo_revolver = { name = 'ammo_revolver', label = 'Revolver Ammo', label_ar = 'ذخيرة ريفولفر', weight = 50, type = 'item', image = 'ammo_revolver.png' },
                weapon_revolver_cattleman = { name = 'weapon_revolver_cattleman', label = 'Cattleman Revolver', label_ar = 'ريفولفر كاتلمان', weight = 1200, type = 'weapon', image = 'weapon_revolver_cattleman.png', ammoname = 'ammo_revolver' },
            }
        end
        EXPORTS['InvName'] = function()
            if backend == 'w_core' then return 'w_inventory'
            elseif backend == 'vorp_core' then return 'vorp_inventory'
            elseif backend == 'rsg-core' then return 'rsg-inventory'
            elseif backend == 'qbr-core' then return 'qbr-inventory'
            end
            return nil
        end
        EXPORTS['InvItems'] = function() return EXPORTS['CompatItems']() end
        EXPORTS['HasPermission'] = function(src, group)
            local p = ACES[tonumber(src)]
            return p and p['perm:' .. tostring(group)] == true or false
        end
        EXPORTS['IsAdmin'] = function(src)
            return EXPORTS['HasPermission'](src, 'admin') or IsPlayerAceAllowed(src, 'command')
        end

        SQL_LOG = {}
        SQL_ROWS = {}
        SQL_FAIL = false
        MySQL = {
            query = {
                await = function(q, params)
                    table.insert(SQL_LOG, { op = 'query', q = q, params = params })
                    if SQL_FAIL then error('db_down') end
                    if type(SQL_HANDLER) == 'function' then return SQL_HANDLER('query', q, params) end
                    return SQL_ROWS
                end
            },
            single = {
                await = function(q, params)
                    table.insert(SQL_LOG, { op = 'single', q = q, params = params })
                    if SQL_FAIL then error('db_down') end
                    if type(SQL_HANDLER) == 'function' then return SQL_HANDLER('single', q, params) end
                    return SQL_ROWS[1]
                end
            },
            update = {
                await = function(q, params)
                    table.insert(SQL_LOG, { op = 'update', q = q, params = params })
                    if SQL_FAIL then error('db_down') end
                    if type(SQL_HANDLER) == 'function' then return SQL_HANDLER('update', q, params) end
                    return 1
                end
            },
            insert = {
                await = function(q, params)
                    table.insert(SQL_LOG, { op = 'insert', q = q, params = params })
                    if SQL_FAIL then error('db_down') end
                    return 1
                end
            },
        }
        """
    )

    # Configure backend mocks
    if backend in ("w_core", "rsg-core", "qbr-core"):
        lua.execute(
            """
            SHARED_JOBS = {
                police = {
                    label = 'Law Enforcement',
                    label_ar = 'الشرطة',
                    defaultDuty = true,
                    offDutyPay = false,
                    type = 'leo',
                    grades = {
                        [0] = { name = 'Recruit', name_ar = 'مستجد', payment = 50 },
                        [4] = { name = 'Chief', name_ar = 'قائد الشرطة', payment = 150, isboss = true },
                    },
                },
                doctor = {
                    label = 'Medical',
                    label_ar = 'الطب',
                    defaultDuty = false,
                    offDutyPay = false,
                    grades = {
                        [0] = { name = 'Intern', name_ar = 'متدرب', payment = 40 },
                    },
                },
            }
            SHARED_GANGS = {
                none = { label = 'No Gang', label_ar = 'بدون عصابة', grades = { [0] = { name = 'None', name_ar = 'لا شيء' } } },
                odriscoll = {
                    label = "O'Driscoll",
                    label_ar = 'أودريسكول',
                    grades = {
                        [0] = { name = 'Thug', name_ar = 'عضو' },
                        [2] = { name = 'Leader', name_ar = 'زعيم', isboss = true },
                    },
                },
            }
            SHARED_ITEMS = EXPORTS['CompatItems']()
            SHARED_WEAPONS = {
                [joaat('weapon_revolver_cattleman')] = {
                    name = 'weapon_revolver_cattleman',
                    label = 'Cattleman Revolver',
                    label_ar = 'ريفولفر كاتلمان',
                    type = 'weapon',
                    ammotype = 'AMMO_REVOLVER',
                },
                [joaat('weapon_rifle_boltaction')] = {
                    name = 'weapon_rifle_boltaction',
                    label = 'Bolt Action Rifle',
                    label_ar = 'بندقية بولت أكشن',
                    type = 'weapon',
                    ammotype = 'AMMO_RIFLE',
                },
            }
            if _TEST_BACKEND == 'qbr-core' then
                -- QBR stores weapons by string key in some builds
                SHARED_WEAPONS = {
                    weapon_revolver_cattleman = SHARED_WEAPONS[joaat('weapon_revolver_cattleman')],
                }
            end

            MOCK_PLAYERS = {
                [1] = {
                    PlayerData = {
                        id = 101,
                        source = 1,
                        citizenid = 'CID001',
                        license = 'license:111',
                        charinfo = { firstname = 'Arthur', lastname = 'Morgan', nickname = 'Artie', age = 36, gender = 0, account = 'ACC1' },
                        job = { name = 'police', label = 'Law Enforcement', label_ar = 'الشرطة', onduty = true, isboss = true, type = 'leo', payment = 150, grade = { level = 4, name = 'Chief', name_ar = 'قائد الشرطة', isboss = true, payment = 150 } },
                        gang = { name = 'none', label = 'No Gang', label_ar = 'بدون عصابة', isboss = false, grade = { level = 0, name = 'None', name_ar = 'لا شيء' } },
                        metadata = { hunger = 80, thirst = 75, isdead = false, inlaststand = false, ishandcuffed = false, injail = 0, licences = { weapon = true }, levels = { crafting = 2 } },
                        money = { cash = 250, gold = 5, bank = 1000 },
                        position = { x = 10.5, y = 20.5, z = 30.5, heading = 90.0 },
                        permission = 'admin',
                    },
                    Functions = {},
                },
                [2] = {
                    PlayerData = {
                        id = 102,
                        source = 2,
                        citizenid = 'CID002',
                        license = 'license:222',
                        charinfo = { firstname = '', lastname = '' },
                        job = { name = 'doctor', label = 'Medical', label_ar = 'الطب', onduty = false, isboss = false, grade = { level = 0, name = 'Intern', name_ar = 'متدرب' } },
                        gang = { name = 'odriscoll', label = "O'Driscoll", label_ar = 'أودريسكول', isboss = true, grade = { level = 2, name = 'Leader', name_ar = 'زعيم' } },
                        metadata = { hunger = 90, thirst = 90, isdead = false, levels = {} },
                        money = { cash = 50, gold = 1, bank = 0 },
                        position = { x = 0, y = 0, z = 0 },
                    },
                    Functions = {},
                },
            }

            for src, p in pairs(MOCK_PLAYERS) do
                p.Functions.SetJob = function(job, grade)
                    local def = SHARED_JOBS[job]
                    if not def then return false end
                    local g = def.grades[tonumber(grade) or 0]
                    p.PlayerData.job = {
                        name = job, label = def.label, label_ar = def.label_ar,
                        onduty = def.defaultDuty, type = def.type or 'none',
                        isboss = g and g.isboss or false, payment = g and g.payment or 0,
                        grade = { level = tonumber(grade) or 0, name = g and g.name or '', name_ar = g and g.name_ar or '', isboss = g and g.isboss or false, payment = g and g.payment or 0 },
                    }
                    return true
                end
                p.Functions.SetGang = function(gang, grade)
                    local def = SHARED_GANGS[gang]
                    if not def then return false end
                    local g = def.grades[tonumber(grade) or 0]
                    p.PlayerData.gang = {
                        name = gang, label = def.label, label_ar = def.label_ar,
                        isboss = g and g.isboss or false,
                        grade = { level = tonumber(grade) or 0, name = g and g.name or '', name_ar = g and g.name_ar or '' },
                    }
                    return true
                end
                p.Functions.SetJobDuty = function(state)
                    p.PlayerData.job.onduty = state == true
                    TriggerEvent((_TEST_BACKEND == 'w_core' and 'WCore' or 'RSGCore') .. ':Player:SetPlayerData', p.PlayerData)
                end
                p.Functions.SetPlayerData = function(k, v)
                    if k == 'money' or k == 'citizenid' then return false end
                    p.PlayerData[k] = v
                    return true
                end
                p.Functions.SetMetaData = function(k, v)
                    if (k == 'hunger' or k == 'thirst') and tonumber(v) then v = math.min(100, tonumber(v)) end
                    p.PlayerData.metadata[k] = v
                end
                p.Functions.AddLevel = function(k, amt)
                    if not p.PlayerData.metadata.levels[k] then return false end
                    p.PlayerData.metadata.levels[k] = p.PlayerData.metadata.levels[k] + amt
                    return true
                end
                p.Functions.RemoveLevel = function(k, amt)
                    if not p.PlayerData.metadata.levels[k] then return false end
                    p.PlayerData.metadata.levels[k] = math.max(0, p.PlayerData.metadata.levels[k] - amt)
                    return true
                end
                p.Functions.AddMoney = function(kind, amt)
                    p.PlayerData.money[kind] = (p.PlayerData.money[kind] or 0) + amt
                    return true
                end
                p.Functions.RemoveMoney = function(kind, amt)
                    if (p.PlayerData.money[kind] or 0) < amt then return false end
                    p.PlayerData.money[kind] = p.PlayerData.money[kind] - amt
                    return true
                end
                p.Functions.GetMoney = function(kind) return p.PlayerData.money[kind] or 0 end
                p.Functions.Save = function() SAVED_PLAYERS = (SAVED_PLAYERS or 0) + 1; return true end
            end

            CORE_OBJ = {
                Shared = {
                    Jobs = SHARED_JOBS,
                    Gangs = SHARED_GANGS,
                    Items = SHARED_ITEMS,
                    Weapons = SHARED_WEAPONS,
                },
                Functions = {
                    GetPlayer = function(src) return MOCK_PLAYERS[tonumber(src)] end,
                    GetPlayerData = function() return MOCK_PLAYERS[1].PlayerData end,
                    GetPlayerByCitizenId = function(cid)
                        for _, p in pairs(MOCK_PLAYERS) do
                            if p.PlayerData.citizenid == cid then return p end
                        end
                        return nil
                    end,
                    GetPlayers = function() return { 1, 2 } end,
                    GetWPlayers = function() return MOCK_PLAYERS end,
                },
                Player = {
                    GetOfflinePlayer = function(cid)
                        if cid == 'OFF999' then
                            return {
                                PlayerData = {
                                    citizenid = 'OFF999',
                                    license = 'license:999',
                                    charinfo = { firstname = 'John', lastname = 'Marston' },
                                    job = { name = 'unemployed', label = 'Unemployed', grade = { level = 0, name = '' } },
                                    gang = { name = 'none', label = 'No Gang', grade = { level = 0, name = '' } },
                                    metadata = { injail = 0, hunger = 50 },
                                    money = { cash = 10, gold = 0 },
                                },
                                Functions = {
                                    SetMetaData = function(k, v)
                                        OFFLINE_META_SET = OFFLINE_META_SET or {}
                                        OFFLINE_META_SET[k] = v
                                    end,
                                    Save = function() OFFLINE_SAVED = (OFFLINE_SAVED or 0) + 1 end,
                                },
                            }
                        end
                        return nil
                    end,
                    Logout = function(src) LOGOUT_CALLED = src end,
                    Login = function(src, cid, newData)
                        LOGIN_CALLED = { src = src, cid = cid, newData = newData }
                        if cid == false and newData then
                            MOCK_PLAYERS[src] = {
                                PlayerData = { citizenid = 'NEW777', license = 'license:111', charinfo = newData.charinfo, job = {}, gang = {}, metadata = {}, money = {}, position = { x = 10.5, y = 20.5, z = 30.5, heading = 90.0 } },
                                Functions = MOCK_PLAYERS[1].Functions,
                            }
                        end
                        return true
                    end,
                    DeleteCharacter = function(src, cid)
                        DELETE_CALLED = { src = src, cid = cid }
                        if cid == 'LOCKED' then return false, 'assets' end
                        return true
                    end,
                },
            }

            if _TEST_BACKEND == 'w_core' then
                EXPORTS['w_core'] = {
                    GetCoreObject = function() return CORE_OBJ end,
                    GetCharacterBlock = function(cid)
                        if cid == 'CID002' then return { reason = 'banned', blocked_by = 'admin' } end
                        return nil
                    end,
                    WithCitizenGeneration = function(cid, rowId, fn)
                        local invoker = GetInvokingResource()
                        local trusted = { w_heists = true, w_pets = true, w_crafting = true, w_gunsmith = true, w_creators = true }
                        if not trusted[invoker] then return false, 'forbidden' end
                        return fn()
                    end,
                }
            elseif _TEST_BACKEND == 'rsg-core' then
                EXPORTS['rsg-core'] = {
                    GetCoreObject = function() return CORE_OBJ end,
                }
            elseif _TEST_BACKEND == 'qbr-core' then
                EXPORTS['qbr-core'] = {
                    GetItems = function() return SHARED_ITEMS end,
                    GetJobs = function() return SHARED_JOBS end,
                    GetWeapons = function() return SHARED_WEAPONS end,
                    GetGangs = function() return SHARED_GANGS end,
                    GetVehicles = function() return { cart = { name = 'Cart' } } end,
                    GetPlayer = function(src) return MOCK_PLAYERS[tonumber(src)] end,
                    GetPlayerData = function() return MOCK_PLAYERS[1].PlayerData end,
                    GetPlayers = function() return { 1, 2 } end,
                    Login = function(src, cid, newData)
                        LOGIN_CALLED = { src = src, cid = cid, newData = newData }
                        return true
                    end,
                    DeleteCharacter = function(src, cid)
                        DELETE_CALLED = { src = src, cid = cid }
                        return true
                    end,
                }
            end
            """
        )
    elif backend == "vorp_core":
        lua.execute(
            """
            VORP_CHARS = {
                [1] = {
                    charIdentifier = 10,
                    identifier = 'steam:111',
                    firstname = 'Sadie',
                    lastname = 'Adler',
                    nickname = 'Sadie',
                    age = 28,
                    charDescription = 'Bounty hunter',
                    job = 'police',
                    jobLabel = 'Sheriff',
                    jobGrade = 2,
                    money = 500,
                    gold = 12,
                    rol = 3,
                    coords = '{"x":100.0,"y":200.0,"z":50.0,"heading":45.0}',
                    isdead = false,
                },
                [2] = {
                    charIdentifier = 20,
                    identifier = 'steam:222',
                    firstname = '',
                    lastname = '',
                    job = 'unemployed',
                    jobLabel = 'Unemployed',
                    jobGrade = 0,
                    money = 0,
                    gold = 0,
                    rol = 0,
                    coords = '{"x":0,"y":0,"z":0}',
                    isdead = false,
                },
            }
            VORP_USERS = {}
            for src, c in pairs(VORP_CHARS) do
                c.setJob = function(j) c.job = j end
                c.setJobGrade = function(g) c.jobGrade = tonumber(g) or 0 end
                c.setJobLabel = function(l) c.jobLabel = l end
                c.setFirstname = function(v) c.firstname = v end
                c.setLastname = function(v) c.lastname = v end
                c.setNickName = function(v) c.nickname = v end
                c.setAge = function(v) c.age = v end
                c.setCharDescription = function(v) c.charDescription = v end
                c.addCurrency = function(t, amt)
                    if t == 0 then c.money = c.money + amt elseif t == 1 then c.gold = c.gold + amt end
                end
                c.removeCurrency = function(t, amt)
                    if t == 0 then c.money = c.money - amt elseif t == 1 then c.gold = c.gold - amt end
                end
                VORP_USERS[src] = {
                    getUsedCharacter = c,
                    getIdentifier = function() return c.identifier end,
                    setUsedCharacter = function(id) VORP_SET_CHAR = id end,
                    addCharacter = function(data)
                        VORP_ADDED_CHAR = data
                        VORP_NEW_ID_PENDING = true
                    end,
                }
            end
            EXPORTS['vorp_core'] = {
                GetCore = function()
                    return {
                        getUser = function(src) return VORP_USERS[tonumber(src)] end,
                        Player = { Revive = function() end, Heal = function() end, Respawn = function() end },
                    }
                end,
            }
            """
        )
    elif backend == "module":
        lua.execute(
            """
            MODULE_USERS = {
                [1] = {
                    data = { citizenid = 'MOD1', metadata = { custom = 'yes' } },
                    getRPName = function() return 'Module Hero' end,
                    getJob = function() return 'miner' end,
                    getJobGrade = function() return 3 end,
                    getMoney = function(_, k) return k == 1 and 7 or 99 end,
                    setJob = function(_, j, g) MODULE_SET_JOB = { j, g }; return true end,
                    addMoney = function() return true end,
                    removeMoney = function() return true end,
                },
            }
            w = {
                framework = {
                    getFrameworkDetected = function() return { id = 'tpz', folder = 'tpz_core' } end,
                    getCoreObject = function() return { Shared = {} } end,
                    getUserIdentifiers = function(_, src)
                        if tonumber(src) == 1 then return { identifier = 'tpz:1', charid = 'MOD1' } end
                        return nil
                    end,
                    UserClass = {
                        get = function(_, src) return MODULE_USERS[tonumber(src)] end,
                    },
                    onCharacterSelected = function(_, cb)
                        MODULE_ON_CHAR = cb
                    end,
                }
            }
            """
        )

    # Load real Lua files in manifest order
    lua.execute((ROOT / "resource/fwbridge/shared.lua").read_text(encoding="utf-8"))
    lua.execute("WFW.Ready = true")
    if is_server:
        lua.execute((ROOT / "resource/fwbridge/server.lua").read_text(encoding="utf-8"))
        lua.execute((ROOT / "resource/fwbridge/server/events.lua").read_text(encoding="utf-8"))
        lua.execute((ROOT / "resource/fwbridge/server/players.lua").read_text(encoding="utf-8"))
        lua.execute((ROOT / "resource/fwbridge/server/multichar.lua").read_text(encoding="utf-8"))
    else:
        lua.execute((ROOT / "resource/fwbridge/client.lua").read_text(encoding="utf-8"))
        lua.execute((ROOT / "resource/fwbridge/client/events.lua").read_text(encoding="utf-8"))

    return lua


class TestSharedCataloguesAndLabels(unittest.TestCase):
    def test_qbr_core_binds_gangs_vehicles_and_server_players(self):
        lua_srv = build_fwbridge_runtime("qbr-core", is_server=True)
        self.assertEqual(lua_srv.eval("EXPORTS['FwName']()"), "qbr")
        self.assertEqual(lua_srv.eval("EXPORTS['FwBackend']()"), "qbr")
        self.assertEqual(lua_srv.eval("WFW.Core.Shared.Gangs.odriscoll.label_ar"), "أودريسكول")
        self.assertEqual(lua_srv.eval("WFW.Core.Shared.Vehicles.cart.name"), "Cart")
        self.assertEqual(lua_srv.eval("#WFW.Core.Functions.GetPlayers()"), 2)

        lua_cli = build_fwbridge_runtime("qbr-core", is_server=False)
        self.assertIsNone(lua_cli.eval("WFW.Core.Functions.GetPlayers"))
        self.assertEqual(lua_cli.eval("EXPORTS['FwGetSharedGangs']().odriscoll.label"), "O'Driscoll")

    def test_shared_jobs_and_gangs_across_cores(self):
        for core in ("w_core", "rsg-core", "qbr-core"):
            lua = build_fwbridge_runtime(core, is_server=True)
            self.assertEqual(lua.eval("EXPORTS['FwGetSharedJobs']().police.label_ar"), "الشرطة")
            self.assertEqual(lua.eval("EXPORTS['FwGetSharedJobs']().police.type"), "leo")
            self.assertTrue(lua.eval("EXPORTS['FwGetSharedJobs']().police.defaultDuty"))
            self.assertTrue(lua.eval("EXPORTS['FwGetSharedJobs']().police.grades[4].isboss"))
            self.assertEqual(lua.eval("EXPORTS['FwGetSharedGangs']().odriscoll.grades[2].name"), "Leader")

        lua_vorp = build_fwbridge_runtime("vorp_core", is_server=True)
        self.assertEqual(lua_vorp.eval("next(EXPORTS['FwGetSharedJobs']())"), None)
        self.assertEqual(lua_vorp.eval("next(EXPORTS['FwGetSharedGangs']())"), None)

    def test_job_label_and_grade_name_localization(self):
        lua_srv = build_fwbridge_runtime("w_core", is_server=True, locale="ar")
        lua_srv.execute("Player(1).state['w_lib:locale'] = 'ar'; Player(2).state['w_lib:locale'] = 'en'")
        # Table + string name + server source locale
        self.assertEqual(lua_srv.eval("EXPORTS['FwJobLabel'](MOCK_PLAYERS[1].PlayerData.job, 1)"), "الشرطة")
        self.assertEqual(lua_srv.eval("EXPORTS['FwJobLabel'](MOCK_PLAYERS[1].PlayerData.job, 2)"), "Law Enforcement")
        self.assertEqual(lua_srv.eval("EXPORTS['FwJobLabel']('police', 1)"), "الشرطة")
        self.assertEqual(lua_srv.eval("EXPORTS['FwJobLabel']('odriscoll', 1)"), "أودريسكول")
        self.assertEqual(lua_srv.eval("EXPORTS['FwJobLabel']('police', 'en')"), "Law Enforcement")
        # GradeName variants
        self.assertEqual(lua_srv.eval("EXPORTS['FwGradeName'](MOCK_PLAYERS[1].PlayerData.job, 1)"), "قائد الشرطة")
        self.assertEqual(lua_srv.eval("EXPORTS['FwGradeName'](MOCK_PLAYERS[1].PlayerData.job.grade, 2)"), "Chief")
        self.assertEqual(lua_srv.eval("EXPORTS['FwGradeName']('police', 4, 1)"), "قائد الشرطة")
        self.assertEqual(lua_srv.eval("EXPORTS['FwGradeName']('odriscoll', 0, 'ar')"), "عضو")

        lua_cli = build_fwbridge_runtime("w_core", is_server=False, locale="ar")
        self.assertEqual(lua_cli.eval("EXPORTS['FwJobLabel']('police')"), "الشرطة")
        self.assertEqual(lua_cli.eval("EXPORTS['FwGradeName']('police', 4)"), "قائد الشرطة")

    def test_shared_items_and_weapons_client_and_server(self):
        for core in ("w_core", "qbr-core", "vorp_core"):
            for srv in (True, False):
                lua = build_fwbridge_runtime(core, is_server=srv)
                self.assertEqual(lua.eval("EXPORTS['FwGetSharedItem']('bread').label_ar"), "خبز")
                self.assertEqual(lua.eval("EXPORTS['FwGetSharedItem']({'bread', 'ammo_revolver'}).ammo_revolver.label"), "Revolver Ammo")
                self.assertIsNone(lua.eval("EXPORTS['FwGetSharedItem']({'bread', 'does_not_exist'})"))

                h = _pure_joaat("weapon_revolver_cattleman")
                u32 = h & 0xFFFFFFFF
                self.assertEqual(lua.eval(f"EXPORTS['FwGetSharedWeapon']({h}).name"), "weapon_revolver_cattleman")
                self.assertEqual(lua.eval(f"EXPORTS['FwGetSharedWeapon']({u32}).name"), "weapon_revolver_cattleman")
                self.assertEqual(lua.eval("EXPORTS['FwGetSharedWeapon']('WEAPON_REVOLVER_CATTLEMAN').label_ar"), "ريفولفر كاتلمان")
                self.assertEqual(lua.eval(f"EXPORTS['FwGetSharedWeapon']('{h}').name"), "weapon_revolver_cattleman")


class TestServerEventsAndPruning(unittest.TestCase):
    def test_server_events_and_on_resource_stop_pruning(self):
        lua = build_fwbridge_runtime("w_core", is_server=True)
        lua.execute(
            """
            GOT = { loaded = {}, unloaded = {}, job = {}, gang = {}, duty = {}, pdata = {}, money = {}, cid = {}, del = {} }
            INVOKING_RESOURCE = 'res_keep'
            EXPORTS['FwOnCharacterLoaded'](function(s, n) table.insert(GOT.loaded, s) end)
            EXPORTS['FwOnCharacterUnloaded'](function(s) table.insert(GOT.unloaded, s) end)
            EXPORTS['FwOnJobUpdate'](function(s, j) table.insert(GOT.job, { s, j.name, j.label_ar }) end)
            EXPORTS['FwOnGangUpdate'](function(s, g) table.insert(GOT.gang, { s, g.name, g.label_ar }) end)
            EXPORTS['FwOnDutyChange'](function(s, d) table.insert(GOT.duty, { s, d }) end)
            EXPORTS['FwOnPlayerData'](function(s, pd) table.insert(GOT.pdata, s) end)
            EXPORTS['FwOnMoneyChange'](function(s, k, a, m, r) table.insert(GOT.money, { s, k, a, m, r }) end)
            EXPORTS['FwOnCitizenIdChanged'](function(o, n) table.insert(GOT.cid, { o, n }) end)
            EXPORTS['FwOnCharacterDeleted'](function(c, t) table.insert(GOT.del, { c, t }) end)

            INVOKING_RESOURCE = 'res_drop'
            EXPORTS['FwOnJobUpdate'](function() DROPPED_CALLED = (DROPPED_CALLED or 0) + 1 end)

            TriggerEvent('WCore:Server:OnJobUpdate', 1, MOCK_PLAYERS[1].PlayerData.job)
            TriggerEvent('WCore:Server:OnGangUpdate', 2, MOCK_PLAYERS[2].PlayerData.gang)
            TriggerEvent('WCore:Player:SetPlayerData', MOCK_PLAYERS[1].PlayerData) -- initializes lastDuty = true
            MOCK_PLAYERS[1].Functions.SetJobDuty(false) -- fires SetPlayerData -> dutyChange(1, false)
            TriggerEvent('WCore:Server:OnMoneyChange', 1, 'cash', 50, 'add', 'test')
            TriggerEvent('w_core:server:citizenIdChanged', 'OLD1', 'NEW1')
            TriggerEvent('w_core:server:characterDeleted', 'DEL1', true)
            TriggerEvent('WCore:Server:OnPlayerUnload', 1)

            -- Now stop res_drop and re-trigger OnJobUpdate
            TriggerEvent('onResourceStop', 'res_drop')
            TriggerEvent('WCore:Server:OnJobUpdate', 1, MOCK_PLAYERS[1].PlayerData.job)
            """
        )
        self.assertEqual(lua.eval("#GOT.job"), 2)
        self.assertEqual(lua.eval("GOT.job[1][2]"), "police")
        self.assertEqual(lua.eval("GOT.job[1][3]"), "الشرطة")
        self.assertEqual(lua.eval("GOT.gang[1][2]"), "odriscoll")
        self.assertEqual(lua.eval("#GOT.duty"), 1)
        self.assertEqual(lua.eval("GOT.duty[1][2]"), False)
        self.assertEqual(lua.eval("GOT.money[1][5]"), "test")
        self.assertEqual(lua.eval("GOT.cid[1][2]"), "NEW1")
        self.assertEqual(lua.eval("GOT.del[1][1]"), "DEL1")
        self.assertEqual(lua.eval("GOT.unloaded[1]"), 1)
        self.assertEqual(lua.eval("DROPPED_CALLED"), 1)

    def test_vorp_deferred_job_change_and_direct_setjob(self):
        lua = build_fwbridge_runtime("vorp_core", is_server=True)
        lua.execute(
            """
            VORP_JOBS = {}
            EXPORTS['FwOnJobUpdate'](function(s, j) table.insert(VORP_JOBS, { s, j.name, j.grade }) end)
            -- VORP fires event before updating char
            TriggerEvent('vorp:playerJobChange', 1, 'marshal', 'police')
            assert(#VORP_JOBS == 0)
            VORP_CHARS[1].job = 'marshal'
            VORP_CHARS[1].jobLabel = 'Marshal'
            runTimers(250)
            -- Direct FwSetJob on VORP emits immediately
            EXPORTS['FwSetJob'](1, 'doctor', 2)
            """
        )
        self.assertEqual(lua.eval("#VORP_JOBS"), 2)
        self.assertEqual(lua.eval("VORP_JOBS[1][2]"), "marshal")
        self.assertEqual(lua.eval("VORP_JOBS[2][2]"), "doctor")
        self.assertEqual(lua.eval("VORP_JOBS[2][3]"), 2)
        self.assertEqual(lua.eval("CLIENT_EVENTS[#CLIENT_EVENTS].name"), "w_lib:fw:client:jobUpdate")


class TestClientEventsAndHud(unittest.TestCase):
    def test_client_events_dedup_duty_diff_hud_and_pruning(self):
        lua = build_fwbridge_runtime("w_core", is_server=False)
        lua.execute(
            """
            CLI = { loaded = 0, unloaded = 0, job = 0, gang = 0, duty = {}, money = {}, pvp = {}, shared = {} }
            INVOKING_RESOURCE = 'ui_mod'
            EXPORTS['FwOnPlayerLoaded'](function() CLI.loaded = CLI.loaded + 1 end)
            EXPORTS['FwOnPlayerUnload'](function() CLI.unloaded = CLI.unloaded + 1 end)
            EXPORTS['FwOnJobUpdate'](function(j) CLI.job = CLI.job + 1; LAST_JOB = j end)
            EXPORTS['FwOnGangUpdate'](function(g) CLI.gang = CLI.gang + 1; LAST_GANG = g end)
            EXPORTS['FwOnDutyChange'](function(d) table.insert(CLI.duty, d) end)
            EXPORTS['FwOnMoneyChange'](function(k, a, r) table.insert(CLI.money, { k, a, r }) end)
            EXPORTS['FwOnPvpChange'](function(v) table.insert(CLI.pvp, v) end)
            EXPORTS['FwOnSharedUpdate'](function(t, k, v) table.insert(CLI.shared, { t, k }) end)

            -- Simulate w_core firing WCore + mirrored RSGCore/vorp events
            TriggerEvent('WCore:Client:OnPlayerLoaded')
            TriggerEvent('RSGCore:Client:OnPlayerLoaded')
            TriggerEvent('vorp:SelectedCharacter')
            assert(EXPORTS['FwIsPlayerLoaded']() == true)
            assert(EXPORTS['FwIsLoggedIn']() == true)

            -- Late listener fires immediately
            EXPORTS['FwOnCharacterLoaded'](function() LATE_FIRED = true end)

            -- Duty diffing via SetPlayerData then WCore:Client:SetDuty (must not double-fire)
            TriggerEvent('WCore:Player:SetPlayerData', { job = { name = 'police', onduty = true } })
            TriggerEvent('WCore:Player:SetPlayerData', { job = { name = 'police', onduty = false } })
            TriggerEvent('WCore:Client:SetDuty', false)

            TriggerEvent('WCore:Client:OnJobUpdate', { name = 'police', onduty = false })
            TriggerEvent('WCore:Client:OnGangUpdate', { name = 'odriscoll' })
            TriggerEvent('hud:client:OnMoneyChange', 'cash', 100, false)
            TriggerEvent('RSGCore:Client:PvpHasToggled', true)
            TriggerEvent('WCore:Client:OnSharedUpdate', 'Items', 'bread', {})

            -- Hide/show HUD + ToggleDuty
            HUD_EVENTS = {}
            for _, ev in ipairs({ 'hud:client:Hideui', 'hud:client:showui', 'hud:client:hideUiWithHoutStement', 'hud:client:showUiWithHoutStement', 'chat:clear' }) do
                AddEventHandler(ev, function() table.insert(HUD_EVENTS, ev) end)
            end
            EXPORTS['FwHideFrameworkHud'](true)
            EXPORTS['FwSetHudVisible'](true)
            EXPORTS['FwToggleDuty']()

            -- Prune on stop
            TriggerEvent('onClientResourceStop', 'ui_mod')
            TriggerEvent('WCore:Client:OnPlayerUnload')
            """
        )
        self.assertEqual(lua.eval("CLI.loaded"), 1)
        self.assertTrue(lua.eval("LATE_FIRED"))
        self.assertEqual(lua.eval("#CLI.duty"), 1)
        self.assertEqual(lua.eval("CLI.duty[1]"), False)
        self.assertEqual(lua.eval("CLI.job"), 1)
        self.assertEqual(lua.eval("LAST_JOB.label_ar"), "الشرطة")
        self.assertEqual(lua.eval("CLI.gang"), 1)
        self.assertEqual(lua.eval("LAST_GANG.label_ar"), "أودريسكول")
        self.assertEqual(lua.eval("CLI.money[1][2]"), 100)
        self.assertEqual(lua.eval("CLI.pvp[1]"), True)
        self.assertEqual(lua.eval("CLI.shared[1][1]"), "Items")
        self.assertEqual(lua.eval("#HUD_EVENTS"), 5)
        self.assertEqual(lua.eval("SERVER_EVENTS[1].name"), "w_lib:fw:server:toggleDuty")
        # Pruned before unload
        self.assertEqual(lua.eval("CLI.unloaded"), 0)
        self.assertFalse(lua.eval("EXPORTS['FwIsPlayerLoaded']()"))

    def test_vorp_client_money_and_imdead_relay(self):
        lua = build_fwbridge_runtime("vorp_core", is_server=False)
        lua.execute(
            """
            MONEY_SNAPS = {}
            EXPORTS['FwOnMoneyChange'](function(k, a, r, snap) table.insert(MONEY_SNAPS, { k, snap }) end)
            TriggerEvent('vorp:updateUi', '{"money":42,"gold":3}')
            TriggerEvent('w_lib:fw:client:vorpMeta', 'isdead', true, true)
            HUD_VORP = {}
            AddEventHandler('vorp:showUi', function(v) table.insert(HUD_VORP, v) end)
            EXPORTS['FwHideFrameworkHud'](true)
            """
        )
        self.assertEqual(lua.eval("MONEY_SNAPS[1][1]"), "vorp")
        self.assertEqual(lua.eval("MONEY_SNAPS[1][2].money"), 42)
        self.assertEqual(lua.eval("SERVER_EVENTS[1].name"), "vorp:ImDead")
        self.assertEqual(lua.eval("SERVER_EVENTS[1].args[1]"), True)
        self.assertEqual(lua.eval("HUD_VORP[1]"), False)


class TestPlayersOpsAndMultichar(unittest.TestCase):
    def test_backward_compat_fixes_and_module_mode(self):
        lua = build_fwbridge_runtime("w_core", is_server=True)
        # Empty charinfo falls back to GetPlayerName (not " ")
        self.assertEqual(lua.eval("EXPORTS['FwGetCharacterName'](2)"), "SteamTwo")
        self.assertEqual(lua.eval("EXPORTS['FwGetCharacterName'](1)"), "Arthur Morgan")
        # Enriched FwGetJobInfo
        self.assertEqual(lua.eval("EXPORTS['FwGetJobInfo'](1).label_ar"), "الشرطة")
        self.assertEqual(lua.eval("EXPORTS['FwGetJobInfo'](1).grade_name_ar"), "قائد الشرطة")
        self.assertEqual(lua.eval("EXPORTS['FwGetJobInfo'](1).type"), "leo")
        self.assertEqual(lua.eval("EXPORTS['FwGetJobInfo'](1).payment"), 150)
        # FwGetMetadata optional key + licences
        self.assertTrue(lua.eval("EXPORTS['FwGetMetadata'](1, 'licences').weapon"))
        self.assertEqual(lua.eval("EXPORTS['FwGetMetadata'](1).hunger"), 80)

        lua_mod = build_fwbridge_runtime("module", is_server=True)
        self.assertEqual(lua_mod.eval("EXPORTS['FwGetJobInfo'](1).name"), "miner")
        self.assertEqual(lua_mod.eval("EXPORTS['FwGetJobInfo'](1).grade"), 3)
        self.assertEqual(lua_mod.eval("EXPORTS['FwGetMetadata'](1, 'custom')"), "yes")
        self.assertEqual(lua54.lua_type(lua_mod.eval("EXPORTS['FwGetMetadata'](1, 'licences')")), "table")

    def test_online_players_duty_gang_levels_meta_perms_cmds(self):
        lua = build_fwbridge_runtime("w_core", is_server=True)
        # Online players + filters + no Functions closures
        self.assertEqual(lua.eval("EXPORTS['FwGetOnlinePlayers']()[1].citizenid"), "CID001")
        self.assertIsNone(lua.eval("EXPORTS['FwGetOnlinePlayers']()[1].Functions"))
        self.assertEqual(lua.eval("EXPORTS['FwGetOnlinePlayers']({ job = 'police', onduty = true })[2]"), None)
        self.assertEqual(lua.eval("EXPORTS['FwGetOnlinePlayers']({ gang = 'odriscoll' })[2].citizenid"), "CID002")
        self.assertEqual(lua.eval("EXPORTS['FwGetPlayerByCitizenId']('CID002').source"), 2)

        # Duty count & toggle
        self.assertEqual(lua.eval("EXPORTS['FwGetDutyCount']('police')"), 1)
        self.assertFalse(lua.eval("EXPORTS['FwToggleDuty'](1)"))
        self.assertEqual(lua.eval("EXPORTS['FwGetDutyCount']('police')"), 0)
        self.assertTrue(lua.eval("EXPORTS['FwSetDuty'](1, true)"))
        self.assertEqual(lua.eval("EXPORTS['FwGetDutyCount']({'police', 'doctor'})"), 1)

        # SetGang & SetMetadata & SetPlayerData & SetCharInfo & Levels
        self.assertTrue(lua.eval("EXPORTS['FwSetGang'](1, 'odriscoll', '2')"))
        self.assertEqual(lua.eval("MOCK_PLAYERS[1].PlayerData.gang.name"), "odriscoll")
        self.assertTrue(lua.eval("EXPORTS['FwSetMetadata'](1, 'hunger', 150)"))
        self.assertEqual(lua.eval("MOCK_PLAYERS[1].PlayerData.metadata.hunger"), 100)
        self.assertFalse(lua.eval("EXPORTS['FwSetPlayerData'](1, 'money', {})"))
        self.assertFalse(lua.eval("EXPORTS['FwSetPlayerData'](1, 'citizenid', 'HACK')"))
        self.assertTrue(lua.eval("EXPORTS['FwSetPlayerData'](1, 'customField', 'ok')"))
        self.assertTrue(lua.eval("EXPORTS['FwSetCharInfo'](1, { firstname = 'John' })"))
        self.assertEqual(lua.eval("MOCK_PLAYERS[1].PlayerData.charinfo.firstname"), "John")
        self.assertTrue(lua.eval("EXPORTS['FwAddLevel'](1, 'mining', 3, true)"))
        self.assertEqual(lua.eval("MOCK_PLAYERS[1].PlayerData.metadata.levels.mining"), 3)
        self.assertTrue(lua.eval("EXPORTS['FwRemoveLevel'](1, 'mining', 1)"))
        self.assertEqual(lua.eval("MOCK_PLAYERS[1].PlayerData.metadata.levels.mining"), 2)

        # Permissions & FwAddCommand
        self.assertTrue(lua.eval("EXPORTS['FwHasPermission'](0, 'god')"))
        self.assertTrue(lua.eval("EXPORTS['FwHasPermission'](1, 'admin')"))
        self.assertFalse(lua.eval("EXPORTS['FwHasPermission'](2, 'god')"))
        lua.execute(
            """
            CMD_LOG = {}
            EXPORTS['FwAddCommand']('setweather', 'Weather', { { name = 'type' } }, true, function(src, args)
                table.insert(CMD_LOG, { src, args[1] })
            end, 'admin')
            COMMANDS.setweather.fn(2, { 'sunny' }, 'setweather sunny') -- denied
            COMMANDS.setweather.fn(1, {}, 'setweather') -- missing arg
            COMMANDS.setweather.fn(1, { 'rain' }, 'setweather rain') -- allowed
            """
        )
        self.assertEqual(lua.eval("#CMD_LOG"), 1)
        self.assertEqual(lua.eval("CMD_LOG[1][2]"), "rain")

        # Offline ops
        self.assertEqual(lua.eval("EXPORTS['FwGetOfflinePlayer']('OFF999').charinfo.firstname"), "John")
        self.assertTrue(lua.eval("EXPORTS['FwSetOfflineMetadata']('OFF999', { injail = 15 })"))
        self.assertEqual(lua.eval("OFFLINE_META_SET.injail"), 15)
        self.assertEqual(lua.eval("OFFLINE_SAVED"), 1)

        lua.execute(
            """
            SQL_HANDLER = function(op, q, params)
                if q:find('citizenid IN') then
                    return { { citizenid = 'OFF1', charinfo = '{"firstname":"Dutch","lastname":"Van"}' } }
                end
                return { charinfo = '{"firstname":"Hosea","lastname":"Matthews"}' }
            end
            """
        )
        self.assertEqual(lua.eval("EXPORTS['FwGetOfflineCharacterName']('OFF2')"), "Hosea Matthews")
        batch = lua.eval("EXPORTS['FwGetOfflineCharacterName']({'CID001', 'OFF1'})")
        self.assertEqual(batch["CID001"], "John Morgan")
        self.assertEqual(batch["OFF1"], "Dutch Van")

        # Generation on w_core: FwWithCitizenGeneration forwards TRUSTED check (returns forbidden when w_lib calls)
        cid, row_id = lua.eval("EXPORTS['FwGetCharacterGeneration'](1)")
        self.assertEqual(cid, "CID001")
        self.assertEqual(row_id, 101)
        ok_gen, err_gen = lua.eval("EXPORTS['FwWithCitizenGeneration']('CID001', 101, function() return true end)")
        self.assertFalse(ok_gen)
        self.assertEqual(err_gen, "forbidden")

    def test_vorp_metadata_duty_offline_and_generation(self):
        lua = build_fwbridge_runtime("vorp_core", is_server=True)
        self.assertEqual(lua.eval("EXPORTS['FwGetCharacterName'](2)"), "SteamTwo")
        self.assertTrue(lua.eval("EXPORTS['FwSetDuty'](1, false)") == False)
        self.assertEqual(lua.eval("EXPORTS['FwGetJobInfo'](1).onduty"), False)
        self.assertEqual(lua.eval("EXPORTS['FwGetDutyCount']('police')"), 0)
        self.assertTrue(lua.eval("EXPORTS['FwToggleDuty'](1)"))
        self.assertEqual(lua.eval("EXPORTS['FwGetDutyCount']('police')"), 1)

        self.assertTrue(lua.eval("EXPORTS['FwSetMetadata'](1, 'isdead', true)"))
        self.assertTrue(lua.eval("EXPORTS['FwGetMetadata'](1, 'isdead')"))
        self.assertEqual(lua.eval("CLIENT_EVENTS[#CLIENT_EVENTS].name"), "w_lib:fw:client:vorpMeta")
        self.assertTrue(lua.eval("EXPORTS['FwSetMetadata'](1, 'licences', { weapon = true })"))
        self.assertTrue(lua.eval("EXPORTS['FwGetMetadata'](1).licences.weapon"))

        # Non-w_core generation runs callback directly
        res = lua.eval("EXPORTS['FwWithCitizenGeneration']('10', nil, function() return 'ran_ok' end)")
        self.assertEqual(res, "ran_ok")

    def test_multichar_crud_wcore_and_vorp(self):
        lua = build_fwbridge_runtime("w_core", is_server=True, locale="ar")
        # DB error returns nil (not {})
        lua.execute("SQL_FAIL = true")
        self.assertIsNone(lua.eval("EXPORTS['FwGetAccountCharacters'](1)"))
        lua.execute("SQL_FAIL = false")

        # Empty list
        lua.execute("SQL_ROWS = {}")
        self.assertEqual(lua.eval("#EXPORTS['FwGetAccountCharacters'](1)"), 0)

        # Populated with Econ ready
        lua.execute(
            """
            EXPORTS['EconIsReady'] = function() return true end
            EXPORTS['EconGetPlayerBalances'] = function(cid)
                return { cash = 333, bank = 444, gold = 5 }
            end
            SQL_HANDLER = function(op, q, params)
                if q:find('FROM players WHERE license') then
                    return {
                        {
                            citizenid = 'CID002',
                            charinfo = '{"firstname":"Micah","lastname":"Bell","birthdate":"1860-01-01","gender":0}',
                            job = '{"name":"police"}',
                            money = '{"cash":1}',
                            position = '{"x":1,"y":2,"z":3,"heading":180}',
                        }
                    }
                elseif q:find('SELECT job, gang, metadata FROM players') then
                    return {
                        {
                            job = json.encode(MOCK_PLAYERS[1].PlayerData.job),
                            gang = json.encode(MOCK_PLAYERS[1].PlayerData.gang),
                            metadata = json.encode(MOCK_PLAYERS[1].PlayerData.metadata),
                        }
                    }
                end
                return {}
            end
            """
        )
        chars = lua.eval("EXPORTS['FwGetAccountCharacters'](1)")
        self.assertEqual(chars[1].charid, "CID002")
        self.assertEqual(chars[1].cash, 333)
        self.assertEqual(chars[1].job, "الشرطة")
        self.assertEqual(chars[1].blocked.reason, "banned")

        # Login confirms save then Logout -> Login
        self.assertTrue(lua.eval("EXPORTS['FwLoginCharacter'](1, 'CID002')"))
        self.assertEqual(lua.eval("LOGOUT_CALLED"), 1)
        self.assertEqual(lua.eval("LOGIN_CALLED.cid"), "CID002")

        # Create & Delete
        self.assertEqual(lua.eval("EXPORTS['FwCreateCharacter'](1, { firstname = 'Charles', lastname = 'Smith', isMale = true })"), "NEW777")
        ok_del, why_del = lua.eval("EXPORTS['FwDeleteCharacter'](1, 'LOCKED')")
        self.assertFalse(ok_del)
        self.assertEqual(why_del, "assets")
        self.assertTrue(lua.eval("EXPORTS['FwDeleteCharacter'](1, 'CID002')"))

        # LastPosition rejects (0,0,0)
        self.assertEqual(lua.eval("EXPORTS['FwGetLastPosition'](1).x"), 10.5)
        self.assertIsNone(lua.eval("EXPORTS['FwGetLastPosition'](2)"))


class TestModuleFrameworkBridgeFixes(unittest.TestCase):
    def test_userclass_get_does_not_mutate_prototype_across_cores(self):
        for core_file, global_setup in [
            ("cores/vorp_core/server.lua", "EXPORTS_TABLE = { vorp_core = { GetCore = function() return { getUser = function(s) return { getUsedCharacter = { charIdentifier = s, money = s * 10 } } end } end } }"),
            ("cores/rsg-core/server.lua", "EXPORTS_TABLE = { ['rsg-core'] = { GetCoreObject = function() return { Functions = { GetPlayer = function(s) return { PlayerData = { citizenid = 'C'..s, job = { name = 'j'..s, grade = { level = s } } } } end } } end } }"),
            ("cores/rsg-core_v2/server.lua", "EXPORTS_TABLE = { ['rsg-core'] = { GetCoreObject = function() return { Functions = { GetPlayer = function(s) return { PlayerData = { citizenid = 'C'..s, job = { name = 'j'..s, grade = { level = s } } } } end } } end } }"),
            ("cores/tpz_core/server.lua", "EXPORTS_TABLE = { tpz_core = { getCoreAPI = function() return { GetPlayer = function(s) return { loaded = function() return true end, getJob = function() return 'job'..s end } end } end } }"),
        ]:
            lua = lua54.LuaRuntime(unpack_returned_tuples=True)
            lua.execute(
                f"""
                {global_setup}
                exports = setmetatable({{}}, {{
                    __index = function(_, name)
                        local tbl = EXPORTS_TABLE[name] or {{}}
                        return setmetatable({{}}, {{
                            __index = function(_, fn) return function(_, ...) return tbl[fn](...) end end
                        }})
                    end
                }})
                w = {{
                    framework = {{ UserClass = {{}} }},
                    component = {{}},
                }}
                function RegisterNetEvent() end
                function AddEventHandler() end
                function GetValue(a, b) if a == nil then return b end return a end
                function eprint() end
                function oprint() end
                function dprint() end
                """
            )
            lua.execute((ROOT / "modules/framework-bridge" / core_file).read_text(encoding="utf-8"))
            lua.execute("u1 = w.framework.UserClass:get(1); u2 = w.framework.UserClass:get(2)")
            self.assertEqual(lua.eval("u1.source"), 1)
            self.assertEqual(lua.eval("u2.source"), 2)
            self.assertIsNone(lua.eval("w.framework.UserClass.source"))
            self.assertIsNone(lua.eval("w.framework.UserClass.data"))
            if "rsg-core" in core_file:
                self.assertEqual(lua.eval("u1:getJobGrade()"), 1)
                self.assertEqual(lua.eval("u2:getJobGrade()"), 2)

    def test_consumer_vm_with_citizen_generation_and_helpers(self):
        lua = lua54.LuaRuntime(unpack_returned_tuples=True)
        lua.execute(
            """
            INVOKING = 'w_heists'
            function GetInvokingResource() return INVOKING end
            function GetResourceState(n) return n == 'w_core' and 'started' or 'missing' end
            function GetCurrentResourceName() return 'w_heists' end
            function AddEventHandler() end
            function CreateThread(fn) fn() end
            function GetPlayers() return {} end
            function GetPlayerName(s) return 'Player' .. tostring(s) end
            function GetValue(a, b) if a == nil then return b end return a end
            exports = setmetatable({}, {
                __index = function(_, res)
                    if res == 'w_core' then
                        return {
                            WithCitizenGeneration = function(_, cid, rowId, fn)
                                local trusted = { w_heists = true, w_pets = true, w_crafting = true, w_gunsmith = true, w_creators = true }
                                if not trusted[INVOKING] then return false, 'forbidden' end
                                return fn()
                            end
                        }
                    elseif res == 'w_lib' then
                        return {
                            FwGetCharacterName = function(_, s) return 'Bridge Name' end,
                            FwOnJobUpdate = function(_, cb) DELEGATED_JOB_CB = cb; return true end,
                        }
                    end
                    return {}
                end
            })
            table.type = function() return 'array' end
            table.copy = function(t) return t end
            table.merge = function(a, b) return a end
            w = {
                resourceName = 'w_heists',
                require = function() end,
                file = { load = function() end, isExist = function() return false end },
                callback = { register = function() end },
                framework = {
                    loadCoreFiles = function() end,
                    loadInventoryFiles = function() end,
                    isWraith = function() return true end,
                    onCharacterSelected = function() end,
                },
            }
            """
        )
        lua.execute((ROOT / "modules/framework-bridge/server.lua").read_text(encoding="utf-8"))
        lua.execute(
            """
            w.framework.UserClass = {
                get = function(_, s)
                    if s == 1 then
                        return { data = { PlayerData = { id = 55, citizenid = 'HEIST1' } }, getRPName = function() return '   ' end }
                    end
                    return false
                end
            }
            """
        )
        cid, row = lua.eval("w.framework:getCharacterGeneration(1)")
        self.assertEqual(cid, "HEIST1")
        self.assertEqual(row, 55)
        self.assertEqual(lua.eval("w.framework:withCitizenGeneration('HEIST1', 55, function() return 'ok_trusted' end)"), "ok_trusted")
        lua.execute("INVOKING = 'untrusted'")
        ok_u, err_u = lua.eval("w.framework:withCitizenGeneration('HEIST1', 55, function() return 'nope' end)")
        self.assertFalse(ok_u)
        self.assertEqual(err_u, "forbidden")
        # Whitespace getRPName falls back to FwGetCharacterName
        self.assertEqual(lua.eval("w.framework:getCharacterName(1)"), "Bridge Name")
        # Event subscription delegates cleanly to exports.w_lib
        self.assertTrue(lua.eval("w.framework:onJobUpdate(function() end)"))
        self.assertIsNotNone(lua.eval("DELEGATED_JOB_CB"))

    def test_currency_strings_and_codes_across_all_five_frameworks(self):
        # RSG / WCore / QBR: string ('cash', 'gold', 'bank') and integer (0, 1) all work
        for core in ("w_core", "rsg-core", "qbr-core"):
            lua = build_fwbridge_runtime(core, is_server=True)
            before_cash = lua.eval("EXPORTS['FwGetCurrency'](1, 'cash')")
            before_bank = lua.eval("EXPORTS['FwGetCurrency'](1, 'bank')")
            self.assertTrue(lua.eval("EXPORTS['FwAddCurrency'](1, 'cash', 25, 'test')"))
            self.assertEqual(lua.eval("EXPORTS['FwGetCurrency'](1, 'cash')"), before_cash + 25)
            self.assertTrue(lua.eval("EXPORTS['FwRemoveCurrency'](1, 'cash', 10, 'test')"))
            self.assertEqual(lua.eval("EXPORTS['FwGetCurrency'](1, 0)"), before_cash + 15)
            self.assertTrue(lua.eval("EXPORTS['FwAddCurrency'](1, 'bank', 50, 'test')"))
            self.assertEqual(lua.eval("EXPORTS['FwGetCurrency'](1, 'bank')"), before_bank + 50)
            self.assertTrue(lua.eval("EXPORTS['FwAddCurrency'](1, 'gold', 3, 'test')"))
            self.assertTrue(lua.eval("EXPORTS['FwRemoveCurrency'](1, 1, 1, 'test')"))

        # VORP: string ('cash', 'gold') maps cleanly to 0 / 1; 'bank' returns false safely
        lua_v = build_fwbridge_runtime("vorp_core", is_server=True)
        before_m = lua_v.eval("EXPORTS['FwGetCurrency'](1, 'cash')")
        before_g = lua_v.eval("EXPORTS['FwGetCurrency'](1, 'gold')")
        self.assertTrue(lua_v.eval("EXPORTS['FwAddCurrency'](1, 'cash', 30)"))
        self.assertEqual(lua_v.eval("EXPORTS['FwGetCurrency'](1, 'cash')"), before_m + 30)
        self.assertTrue(lua_v.eval("EXPORTS['FwRemoveCurrency'](1, 'cash', 5)"))
        self.assertEqual(lua_v.eval("EXPORTS['FwGetCurrency'](1, 0)"), before_m + 25)
        self.assertTrue(lua_v.eval("EXPORTS['FwAddCurrency'](1, 'gold', 4)"))
        self.assertEqual(lua_v.eval("EXPORTS['FwGetCurrency'](1, 'gold')"), before_g + 4)
        self.assertFalse(lua_v.eval("EXPORTS['FwAddCurrency'](1, 'bank', 10)"))

        # Module (TPZ/RedEM/QR/RPX/FRP): string and integer map cleanly to numeric code
        lua_m = build_fwbridge_runtime("module", is_server=True)
        self.assertTrue(lua_m.eval("EXPORTS['FwAddCurrency'](1, 'cash', 15)"))
        self.assertTrue(lua_m.eval("EXPORTS['FwRemoveCurrency'](1, 'gold', 2)"))
        self.assertFalse(lua_m.eval("EXPORTS['FwAddCurrency'](1, 'bank', 10)"))


if __name__ == "__main__":
    unittest.main()
