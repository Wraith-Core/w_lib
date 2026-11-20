-- ════════════════════════════════════════════════════════════════════════════
-- w_lib — جسر الفريمورك الشامل (fwbridge) — كشف مشترك (خادم/عميل)
--   يوحّد فورب (vorp) و RSGCore، ويكشف مرّة واحدة داخل w_lib، ثم يوفّر:
--     exports.w_lib:FwName() · FwReady() · FwInventory() · FwGetCore()
--   منقول من جسر w_admin المُثبَت ومُعمّم ليكون في المكتبة (شامل كل شي).
--   ملاحظة: يعمل داخل مورد w_lib نفسه (لا وسيط w هنا) — نعتمد النواة مباشرةً.
-- ════════════════════════════════════════════════════════════════════════════

WFW = WFW or { Name = nil, PublicName = nil, Core = nil, Inventory = nil, Ready = false, Host = nil }

-- QBR exposes small functions directly from qbr-core rather than a GetCoreObject
-- table. Build the tiny QB-style shape used by the unified bridge so every Fw*
-- export can keep one implementation for RSG and QBR.
local function getQbrCore()
    local api = exports['qbr-core']
    local okItems, items = pcall(function() return api:GetItems() end)
    local okJobs, jobs = pcall(function() return api:GetJobs() end)
    local okWeapons, weapons = pcall(function() return api:GetWeapons() end)
    local okGangs, gangs = pcall(function() return api:GetGangs() end)
    local okVehicles, vehicles = pcall(function() return api:GetVehicles() end)

    local functions = {
        GetPlayer = function(source)
            local ok, player = pcall(function() return api:GetPlayer(source) end)
            return ok and player or nil
        end,
        GetPlayerData = function()
            local ok, player = pcall(function() return api:GetPlayerData() end)
            return ok and player or nil
        end,
    }

    if IsDuplicityVersion() then
        functions.GetPlayers = function()
            local ok, players = pcall(function() return api:GetPlayers() end)
            return ok and type(players) == 'table' and players or {}
        end
    end

    return {
        Functions = functions,
        Shared = {
            Items = okItems and type(items) == 'table' and items or {},
            Jobs = okJobs and type(jobs) == 'table' and jobs or {},
            Weapons = okWeapons and type(weapons) == 'table' and weapons or {},
            Gangs = okGangs and type(gangs) == 'table' and gangs or {},
            Vehicles = okVehicles and type(vehicles) == 'table' and vehicles or {},
        },
    }
end

-- محاولة كشف صامتة (بلا طباعة) — تُعاد حتى ينجح
-- The module layer already owns the full core catalogue (RedEM, QR, RPX, TPZ, FRP,
-- in addition to the native adapters above). Fw* is the public facade of that SAME
-- catalogue: a core added there must not also require an edit in every w_* resource.
local function tryModuleDetect()
    if type(w) ~= 'table' or type(w.framework) ~= 'table' then return false end
    local ok, detected = pcall(w.framework.getFrameworkDetected, w.framework)
    if not ok or type(detected) ~= 'table' or not detected.id then return false end
    local okCore, core = pcall(w.framework.getCoreObject, w.framework)
    WFW.Name = 'module'
    WFW.PublicName = detected.id
    WFW.Core = okCore and core or {}
    WFW.Inventory = nil -- InvName() remains the single inventory authority
    WFW.Host = detected.folder
    return true
end

local function tryDetect()
    -- Wraith Core first: it `provide`s the vorp_core / rsg-core / qbr-core names, so every
    -- later check below would otherwise match the alias instead of the real core.
    if GetResourceState('w_core') == 'started' then
        local ok, core = pcall(function() return exports['w_core']:GetCoreObject() end)
        if ok and core then
            -- WCore speaks the RSG-Core contract; consumers keyed on FwName() == 'rsgcore' keep working.
            WFW.Name = 'rsgcore'; WFW.PublicName = 'rsgcore'; WFW.Core = core; WFW.Inventory = 'w_inventory'; WFW.Host = 'w_core'
            return true
        end
    end
    if GetResourceState('vorp_core') == 'started' then
        local ok, core = pcall(function() return exports['vorp_core']:GetCore() end)
        if ok and core then
            WFW.Name = 'vorp'; WFW.PublicName = 'vorp'; WFW.Core = core; WFW.Inventory = 'vorp_inventory'
            return true
        end
    end
    if GetResourceState('rsg-core') == 'started' then
        local ok, core = pcall(function() return exports['rsg-core']:GetCoreObject() end)
        if ok and core then
            WFW.Name = 'rsgcore'; WFW.PublicName = 'rsgcore'; WFW.Core = core; WFW.Inventory = 'rsg-inventory'
            return true
        end
    end
    if GetResourceState('qbr-core') == 'started' then
        -- Internally QBR follows the same PlayerData contract as RSG/QB. Publicly
        -- it remains "qbr" so consumers can identify the actual framework.
        WFW.Name = 'rsgcore'
        WFW.PublicName = 'qbr'
        WFW.Core = getQbrCore()
        WFW.Inventory = 'qbr-inventory'
        return true
    end
    return tryModuleDetect()
end

CreateThread(function()
    local attempts = 0
    while not WFW.Ready do
        attempts = attempts + 1
        if tryDetect() then
            WFW.Ready = true
            local ok, activeInventory = pcall(function() return exports.w_lib:InvName() end)
            print(('^2[w_lib] fwbridge -> framework=%s | inventory=%s^7'):format(
                WFW.PublicName or WFW.Name, ok and activeInventory or WFW.Inventory))
            break
        end
        if attempts == 60 then
            print('^1[w_lib] fwbridge: no supported framework detected yet; detection will continue.^7')
        end
        Wait(attempts < 60 and 500 or 2000)
    end
end)

exports('FwName', function() return WFW.PublicName or WFW.Name end)
exports('FwReady', function() return WFW.Ready end)
exports('FwInventory', function()
    -- الحقيبة الفعّالة من جسر الحقيبة (invbridge) لا من الفريمورك — تتّفق مع InvName.
    -- (الاشتقاق من الفريمورك كان يُرجع vorp_inventory دائمًا حتى لو الفعّالة w_inventory.)
    local ok, n = pcall(function() return exports.w_lib:InvName() end)
    return (ok and n) or WFW.Inventory
end)
exports('FwGetCore', function() return WFW.Core end)
exports('FwHost', function() return WFW.Host end)

--- Which core actually answers: 'wcore' (Wraith Core hosting the dialect names), 'vorp',
--- 'rsg' or 'qbr'. w_inventory keys its weapon backend on it (both sides).
exports('FwBackend', function()
    if WFW.Host == 'w_core' or GetResourceState('w_core') == 'started' then return 'wcore' end
    local name = WFW.PublicName or WFW.Name
    if name == 'rsgcore' then return 'rsg' end
    return name
end)

-- A capability list for consumers: never make consumers maintain their own core list.
exports('FwCapabilities', function()
    return {
        ready = WFW.Ready == true,
        framework = WFW.PublicName or WFW.Name,
        backend = exports.w_lib:FwBackend(),
        host = WFW.Host,
        inventory = exports.w_lib:FwInventory(),
        contract = 1,
    }
end)

-- ════════════════════════════════════════════════════════════════════════════
-- Shared Catalogues & Localized Labels (server + client)
-- ════════════════════════════════════════════════════════════════════════════

local function toU32(n)
    if type(n) ~= 'number' then return nil end
    return n & 0xFFFFFFFF
end

local function toS32(n)
    if type(n) ~= 'number' then return nil end
    local u = n & 0xFFFFFFFF
    if u >= 0x80000000 then return u - 0x100000000 end
    return u
end

local function pureJoaat(str)
    str = tostring(str or ''):lower()
    local hash = 0
    for i = 1, #str do
        hash = (hash + str:byte(i)) & 0xFFFFFFFF
        hash = (hash + ((hash << 10) & 0xFFFFFFFF)) & 0xFFFFFFFF
        hash = (hash ~ (hash >> 6)) & 0xFFFFFFFF
    end
    hash = (hash + ((hash << 3) & 0xFFFFFFFF)) & 0xFFFFFFFF
    hash = (hash ~ (hash >> 11)) & 0xFFFFFFFF
    hash = (hash + ((hash << 15) & 0xFFFFFFFF)) & 0xFFFFFFFF
    return toS32(hash)
end

local function hashKey(str)
    if type(str) ~= 'string' or str == '' then return 0 end
    if type(joaat) == 'function' then
        local ok, h = pcall(joaat, str)
        if ok and type(h) == 'number' then return h end
    end
    if type(GetHashKey) == 'function' then
        local ok, h = pcall(GetHashKey, str)
        if ok and type(h) == 'number' and h ~= 0 then return h end
    end
    return pureJoaat(str)
end

local function normalizeLocaleKey(val)
    if type(val) ~= 'string' or val == '' then return nil end
    local lower = val:lower():match('^%s*(.-)%s*$')
    if not lower or lower == '' then return nil end
    local short = lower:match('^([a-z][a-z])')
    return short or lower
end

local function resolveLocale(srcOrLocale)
    if type(srcOrLocale) == 'string' and srcOrLocale ~= '' then
        return normalizeLocaleKey(srcOrLocale) or 'en'
    end
    local src = tonumber(srcOrLocale)
    if IsDuplicityVersion() and src and src > 0 then
        if type(Player) == 'function' then
            local ok, bagKey = pcall(function()
                local p = Player(src)
                return p and p.state and p.state['w_lib:locale']
            end)
            if ok then
                local norm = normalizeLocaleKey(bagKey)
                if norm then return norm end
            end
        end
        if exports and exports.w_lib then
            local ok, k = pcall(function() return exports.w_lib:getPlayerLocaleKey(src) end)
            if ok then
                local norm = normalizeLocaleKey(k)
                if norm then return norm end
            end
        end
    end
    if type(lib) == 'table' and type(lib.getLocaleKey) == 'function' then
        local ok, k = pcall(lib.getLocaleKey)
        if ok then
            local norm = normalizeLocaleKey(k)
            if norm then return norm end
        end
    end
    if exports and exports.w_lib then
        local ok, k = pcall(function() return exports.w_lib:getLocaleKey() end)
        if ok then
            local norm = normalizeLocaleKey(k)
            if norm then return norm end
        end
    end
    if type(w) == 'table' and type(w.getLocaleKey) == 'function' then
        local ok, k = pcall(w.getLocaleKey)
        if ok then
            local norm = normalizeLocaleKey(k)
            if norm then return norm end
        end
    end
    if type(GetConvar) == 'function' then
        local k = GetConvar('w_lib:locale', GetConvar('w_lib:i18n:locale', 'en'))
        local norm = normalizeLocaleKey(k)
        if norm then return norm end
    end
    return 'en'
end

local function coreSharedTable(field, getterName)
    local core = WFW.Core
    if type(core) ~= 'table' or type(core.Shared) ~= 'table' then return nil end
    local tbl = core.Shared[field]
    if type(tbl) == 'table' and next(tbl) ~= nil then return tbl end
    if getterName and type(core.Shared[getterName]) == 'function' then
        local ok, res = pcall(core.Shared[getterName])
        if ok and type(res) == 'table' and next(res) ~= nil then return res end
    end
    return type(tbl) == 'table' and tbl or nil
end

local function normalizeGrades(rawGrades)
    local grades = {}
    if type(rawGrades) ~= 'table' then return grades end
    for k, g in pairs(rawGrades) do
        if type(g) == 'table' then
            local key = tonumber(k) or k
            grades[key] = {
                name = g.name or g.label or tostring(key),
                name_ar = g.name_ar,
                payment = tonumber(g.payment) or 0,
                isboss = g.isboss == true,
                level = tonumber(k) or tonumber(g.level),
            }
            for extraK, extraV in pairs(g) do
                if grades[key][extraK] == nil then grades[key][extraK] = extraV end
            end
        end
    end
    return grades
end

local function getSharedJobs()
    if WFW.Name == 'vorp' then return {} end
    local raw = coreSharedTable('Jobs', 'GetJobs')
    if type(raw) ~= 'table' then return {} end
    local out = {}
    for name, def in pairs(raw) do
        if type(name) == 'string' and type(def) == 'table' then
            out[name] = {
                name = name,
                label = def.label or name,
                label_ar = def.label_ar,
                defaultDuty = def.defaultDuty == true,
                offDutyPay = def.offDutyPay == true,
                type = def.type or 'none',
                grades = normalizeGrades(def.grades),
            }
            for extraK, extraV in pairs(def) do
                if out[name][extraK] == nil then out[name][extraK] = extraV end
            end
        end
    end
    return out
end

local function getSharedGangs()
    if WFW.Name == 'vorp' then return {} end
    local raw = coreSharedTable('Gangs', 'GetGangs')
    if type(raw) ~= 'table' then return {} end
    local out = {}
    for name, def in pairs(raw) do
        if type(name) == 'string' and type(def) == 'table' then
            out[name] = {
                name = name,
                label = def.label or name,
                label_ar = def.label_ar,
                grades = normalizeGrades(def.grades),
            }
            for extraK, extraV in pairs(def) do
                if out[name][extraK] == nil then out[name][extraK] = extraV end
            end
        end
    end
    return out
end

local function lookupRoleDef(name)
    if type(name) ~= 'string' or name == '' then return nil end
    local jobs = getSharedJobs()
    if jobs[name] then return jobs[name] end
    local gangs = getSharedGangs()
    if gangs[name] then return gangs[name] end
    local lower = name:lower()
    return jobs[lower] or gangs[lower]
end

local function pickLocalizedField(tbl, baseField, loc, fallbackField)
    if type(tbl) ~= 'table' then return nil end
    if loc and loc ~= 'en' then
        local localized = tbl[baseField .. '_' .. loc]
        if type(localized) == 'string' and localized ~= '' then return localized end
        local arFallback = tbl[baseField .. '_ar']
        if type(arFallback) == 'string' and arFallback ~= '' then return arFallback end
    end
    local primary = tbl[baseField]
    if type(primary) == 'string' and primary ~= '' then return primary end
    if fallbackField then
        local fb = tbl[fallbackField]
        if type(fb) == 'string' and fb ~= '' then return fb end
    end
    return nil
end

local function jobLabel(jobOrGangOrName, srcOrLocale)
    local loc = resolveLocale(srcOrLocale)
    if type(jobOrGangOrName) == 'string' then
        local def = lookupRoleDef(jobOrGangOrName)
        if def then
            return pickLocalizedField(def, 'label', loc, 'name') or jobOrGangOrName
        end
        return jobOrGangOrName
    end
    if type(jobOrGangOrName) ~= 'table' then return '' end
    local entry = jobOrGangOrName
    local def = type(entry.name) == 'string' and lookupRoleDef(entry.name) or nil
    local merged = entry
    if def and (entry.label == nil or entry.label == '' or (loc ~= 'en' and entry['label_' .. loc] == nil and entry.label_ar == nil)) then
        merged = {
            name = entry.name,
            label = (type(entry.label) == 'string' and entry.label ~= '') and entry.label or def.label,
            label_ar = (type(entry.label_ar) == 'string' and entry.label_ar ~= '') and entry.label_ar or def.label_ar,
        }
        if loc ~= 'en' then
            local k = 'label_' .. loc
            merged[k] = (type(entry[k]) == 'string' and entry[k] ~= '') and entry[k] or def[k]
        end
    end
    return pickLocalizedField(merged, 'label', loc, 'name') or ''
end

local function gradeName(jobOrGangOrGrade, gradeOrSrc, srcOrLocale)
    local loc
    local gradeEntry

    if type(jobOrGangOrGrade) == 'string' then
        local def = lookupRoleDef(jobOrGangOrGrade)
        loc = resolveLocale(srcOrLocale)
        local gKey = tonumber(gradeOrSrc) or gradeOrSrc
        if def and type(def.grades) == 'table' and gKey ~= nil then
            gradeEntry = def.grades[gKey] or def.grades[tostring(gKey)]
        end
        if type(gradeEntry) ~= 'table' then
            return gradeOrSrc ~= nil and tostring(gradeOrSrc) or ''
        end
    elseif type(jobOrGangOrGrade) == 'table' then
        local entry = jobOrGangOrGrade
        if type(entry.grades) == 'table' and (type(gradeOrSrc) == 'number' or type(gradeOrSrc) == 'string') and (entry.grades[tonumber(gradeOrSrc)] or entry.grades[tostring(gradeOrSrc)]) then
            loc = resolveLocale(srcOrLocale)
            local gKey = tonumber(gradeOrSrc) or gradeOrSrc
            gradeEntry = entry.grades[gKey] or entry.grades[tostring(gKey)]
        else
            loc = resolveLocale(srcOrLocale ~= nil and srcOrLocale or gradeOrSrc)
            gradeEntry = type(entry.grade) == 'table' and entry.grade or entry
            if type(entry.name) == 'string' and type(gradeEntry) == 'table' then
                local gLevel = tonumber(gradeEntry.level)
                if gLevel then
                    local def = lookupRoleDef(entry.name)
                    local defGrade = def and def.grades and (def.grades[gLevel] or def.grades[tostring(gLevel)])
                    if defGrade and (gradeEntry.name == nil or gradeEntry.name == '' or (loc ~= 'en' and gradeEntry['name_' .. loc] == nil and gradeEntry.name_ar == nil)) then
                        gradeEntry = {
                            name = (type(gradeEntry.name) == 'string' and gradeEntry.name ~= '') and gradeEntry.name or defGrade.name,
                            name_ar = (type(gradeEntry.name_ar) == 'string' and gradeEntry.name_ar ~= '') and gradeEntry.name_ar or defGrade.name_ar,
                        }
                        if loc ~= 'en' then
                            local k = 'name_' .. loc
                            gradeEntry[k] = (type(gradeEntry[k]) == 'string' and gradeEntry[k] ~= '') and gradeEntry[k] or defGrade[k]
                        end
                    end
                end
            end
        end
    else
        return ''
    end

    if type(gradeEntry) ~= 'table' then return '' end
    return pickLocalizedField(gradeEntry, 'name', loc, 'label') or ''
end

local function getSharedItems()
    local items = coreSharedTable('Items', 'GetItems')
    if type(items) == 'table' and next(items) ~= nil then return items end
    if exports and exports.w_lib then
        local okCompat, cItems = pcall(function() return exports.w_lib:CompatItems() end)
        if okCompat and type(cItems) == 'table' and next(cItems) ~= nil then return cItems end
        local okInv, iItems = pcall(function() return exports.w_lib:InvItems() end)
        if okInv and type(iItems) == 'table' and next(iItems) ~= nil then return iItems end
    end
    return type(items) == 'table' and items or {}
end

local function findItemInTable(items, name)
    if type(name) ~= 'string' or name == '' then return nil end
    if items[name] ~= nil then return items[name] end
    local lower = name:lower()
    if items[lower] ~= nil then return items[lower] end
    for k, v in pairs(items) do
        if type(k) == 'string' and k:lower() == lower then return v end
        if type(v) == 'table' and type(v.name) == 'string' and v.name:lower() == lower then return v end
    end
    return nil
end

local function getSharedItem(nameOrList)
    local items = getSharedItems()
    if type(nameOrList) == 'string' then
        return findItemInTable(items, nameOrList)
    elseif type(nameOrList) == 'table' then
        local out = {}
        for i = 1, #nameOrList do
            local key = nameOrList[i]
            local found = findItemInTable(items, key)
            if not found then return nil end
            out[key] = found
        end
        return out
    end
    return nil
end

local BUILTIN_RDR3_WEAPONS = {
    { name = 'weapon_revolver_cattleman', label = 'Cattleman Revolver', label_ar = 'ريفولفر كاتلمان' },
    { name = 'weapon_revolver_doubleaction', label = 'Double-Action Revolver', label_ar = 'ريفولفر دبل أكشن' },
    { name = 'weapon_revolver_schofield', label = 'Schofield Revolver', label_ar = 'ريفولفر سكوفيلد' },
    { name = 'weapon_revolver_lemat', label = 'LeMat Revolver', label_ar = 'ريفولفر لومات' },
    { name = 'weapon_revolver_navy', label = 'Navy Revolver', label_ar = 'ريفولفر نيفي' },
    { name = 'weapon_revolver_doubleaction_gambler', label = 'High Roller Revolver', label_ar = 'ريفولفر هاي رولر' },
    { name = 'weapon_revolver_cattleman_john', label = "John's Cattleman Revolver", label_ar = 'ريفولفر جون' },
    { name = 'weapon_revolver_cattleman_mexican', label = "Flaco's Revolver", label_ar = 'ريفولفر فلاكو' },
    { name = 'weapon_revolver_cattleman_pig', label = "Granger's Revolver", label_ar = 'ريفولفر غرانجر' },
    { name = 'weapon_revolver_doubleaction_exotic', label = "Algernon's Revolver", label_ar = 'ريفولفر ألجرنون' },
    { name = 'weapon_revolver_doubleaction_micah', label = "Micah's Revolver", label_ar = 'ريفولفر مايكا' },
    { name = 'weapon_revolver_schofield_calloway', label = "Calloway's Revolver", label_ar = 'ريفولفر كالاواي' },
    { name = 'weapon_revolver_schofield_golden', label = "Otis Miller's Revolver", label_ar = 'ريفولفر أوتيس ميلر' },
    { name = 'weapon_revolver_navy_crossover', label = "Lowry's Revolver", label_ar = 'ريفولفر لاوري' },
    { name = 'weapon_pistol_volcanic', label = 'Volcanic Pistol', label_ar = 'مسدس فولكانيك' },
    { name = 'weapon_pistol_semiauto', label = 'Semi-Automatic Pistol', label_ar = 'مسدس شبه آلي' },
    { name = 'weapon_pistol_mauser', label = 'Mauser Pistol', label_ar = 'مسدس ماوزر' },
    { name = 'weapon_pistol_m1899', label = 'M1899 Pistol', label_ar = 'مسدس إم 1899' },
    { name = 'weapon_pistol_mauser_drunk', label = "Midnight's Pistol", label_ar = 'مسدس ميدنايت' },
    { name = 'weapon_repeater_carbine', label = 'Carbine Repeater', label_ar = 'بندقية كاربين التكرارية' },
    { name = 'weapon_repeater_winchester', label = 'Lancaster Repeater', label_ar = 'بندقية لانكاستر التكرارية' },
    { name = 'weapon_repeater_henry', label = 'Litchfield Repeater', label_ar = 'بندقية ليتشفيلد التكرارية' },
    { name = 'weapon_repeater_evans', label = 'Evans Repeater', label_ar = 'بندقية إيفانز التكرارية' },
    { name = 'weapon_rifle_springfield', label = 'Springfield Rifle', label_ar = 'بندقية سبرينغفيلد' },
    { name = 'weapon_rifle_boltaction', label = 'Bolt Action Rifle', label_ar = 'بندقية بولت أكشن' },
    { name = 'weapon_rifle_varmint', label = 'Varmint Rifle', label_ar = 'بندقية فارمنت' },
    { name = 'weapon_rifle_elephant', label = 'Elephant Rifle', label_ar = 'بندقية الفيل' },
    { name = 'weapon_sniperrifle_rollingblock', label = 'Rolling Block Rifle', label_ar = 'بندقية رولينغ بلوك' },
    { name = 'weapon_sniperrifle_carcano', label = 'Carcano Rifle', label_ar = 'بندقية كاركانو' },
    { name = 'weapon_sniperrifle_rollingblock_exotic', label = 'Rare Rolling Block Rifle', label_ar = 'بندقية رولينغ بلوك النادرة' },
    { name = 'weapon_shotgun_doublebarrel', label = 'Double-Barreled Shotgun', label_ar = 'بندقية خرطوش مزدوجة السبطانة' },
    { name = 'weapon_shotgun_sawedoff', label = 'Sawed-Off Shotgun', label_ar = 'بندقية خرطوش قصيرة' },
    { name = 'weapon_shotgun_pump', label = 'Pump-Action Shotgun', label_ar = 'بندقية خرطوش بالمضخة' },
    { name = 'weapon_shotgun_repeating', label = 'Repeating Shotgun', label_ar = 'بندقية خرطوش تكرارية' },
    { name = 'weapon_shotgun_semiauto', label = 'Semi-Auto Shotgun', label_ar = 'بندقية خرطوش شبه آلية' },
    { name = 'weapon_shotgun_doublebarrel_exotic', label = 'Rare Shotgun', label_ar = 'بندقية خرطوش نادرة' },
    { name = 'weapon_bow', label = 'Bow', label_ar = 'قوس' },
    { name = 'weapon_bow_improved', label = 'Improved Bow', label_ar = 'قوس محسن' },
    { name = 'weapon_melee_knife', label = 'Hunting Knife', label_ar = 'سكين صيد' },
    { name = 'weapon_melee_knife_jawbone', label = 'Jawbone Knife', label_ar = 'سكين عظم الفك' },
    { name = 'weapon_melee_knife_bear', label = 'Antler Knife', label_ar = 'سكين بمقبض قرن' },
    { name = 'weapon_melee_knife_civil_war', label = 'Civil War Knife', label_ar = 'سكين الحرب الأهلية' },
    { name = 'weapon_melee_knife_miner', label = 'Wide-Blade Knife', label_ar = 'سكين ذو نصل عريض' },
    { name = 'weapon_melee_knife_vampire', label = 'Ornate Dagger', label_ar = 'خنجر مزخرف' },
    { name = 'weapon_melee_knife_john', label = "John's Knife", label_ar = 'سكين جون' },
    { name = 'weapon_melee_knife_horror', label = 'Horror Knife', label_ar = 'سكين الرعب' },
    { name = 'weapon_melee_knife_rustic', label = 'Rustic Knife', label_ar = 'سكين ريفي' },
    { name = 'weapon_melee_knife_trader', label = 'Trader Knife', label_ar = 'سكين التاجر' },
    { name = 'weapon_melee_machete', label = 'Machete', label_ar = 'منجل' },
    { name = 'weapon_melee_machete_collector', label = 'Collector Machete', label_ar = 'منجل المقتني' },
    { name = 'weapon_melee_machete_horror', label = 'Horror Machete', label_ar = 'منجل الرعب' },
    { name = 'weapon_melee_broken_sword', label = 'Broken Pirate Sword', label_ar = 'سيف قرصان مكسور' },
    { name = 'weapon_melee_hammer', label = 'Hammer', label_ar = 'مطرقة' },
    { name = 'weapon_melee_hatchet', label = 'Hatchet', label_ar = 'فأس يدوي' },
    { name = 'weapon_melee_cleaver', label = 'Cleaver', label_ar = 'ساطور' },
    { name = 'weapon_melee_ancient_hatchet', label = 'Stone Hatchet', label_ar = 'فأس حجري' },
    { name = 'weapon_melee_hatchet_viking', label = 'Viking Hatchet', label_ar = 'فأس الفايكنغ' },
    { name = 'weapon_melee_hatchet_hewing', label = 'Hewing Hatchet', label_ar = 'فأس نحت الخشب' },
    { name = 'weapon_melee_hatchet_double_bit', label = 'Double Bit Hatchet', label_ar = 'فأس ذو حدين' },
    { name = 'weapon_melee_hatchet_double_bit_rusted', label = 'Rusted Double Bit Hatchet', label_ar = 'فأس صدئ ذو حدين' },
    { name = 'weapon_melee_hatchet_hunter', label = 'Hunter Hatchet', label_ar = 'فأس الصياد' },
    { name = 'weapon_melee_hatchet_hunter_rusted', label = 'Rusted Hunter Hatchet', label_ar = 'فأس صياد صدئ' },
    { name = 'weapon_thrown_throwing_knives', label = 'Throwing Knives', label_ar = 'سكاكين رمي' },
    { name = 'weapon_thrown_tomahawk', label = 'Tomahawk', label_ar = 'فأس توماهوك' },
    { name = 'weapon_thrown_tomahawk_ancient', label = 'Ancient Tomahawk', label_ar = 'توماهوك أثري' },
    { name = 'weapon_thrown_dynamite', label = 'Dynamite', label_ar = 'ديناميت' },
    { name = 'weapon_thrown_molotov', label = 'Fire Bottle', label_ar = 'زجاجة حارقة' },
    { name = 'weapon_thrown_poisonbottle', label = 'Toxic Moonshine Bottle', label_ar = 'زجاجة سامة' },
    { name = 'weapon_thrown_bolas', label = 'Bolas', label_ar = 'بولاس' },
    { name = 'weapon_thrown_bolas_hawkmoth', label = 'Hawkmoth Bolas', label_ar = 'بولاس هوكموث' },
    { name = 'weapon_thrown_bolas_intertwined', label = 'Intertwined Bolas', label_ar = 'بولاس متشابك' },
    { name = 'weapon_thrown_bolas_ironspiked', label = 'Ironspiked Bolas', label_ar = 'بولاس بمسامير حديدية' },
    { name = 'weapon_lasso', label = 'Lasso', label_ar = 'حبل لاسو' },
    { name = 'weapon_lasso_reinforced', label = 'Reinforced Lasso', label_ar = 'حبل لاسو مقوى' },
    { name = 'weapon_melee_davy_lantern', label = 'Davy Lantern', label_ar = 'فانوس ديفي' },
    { name = 'weapon_melee_lantern_electric', label = 'Electric Lantern', label_ar = 'فانوس كهربائي أصلي' },
    { name = 'weapon_melee_lantern_halloween', label = 'Halloween Lantern', label_ar = 'فانوس الهالوين' },
    { name = 'weapon_melee_lantern', label = 'Lantern', label_ar = 'فانوس' },
    { name = 'weapon_melee_torch', label = 'Torch', label_ar = 'شعلة' },
    { name = 'weapon_kit_binoculars', label = 'Binoculars', label_ar = 'منظار' },
    { name = 'weapon_kit_binoculars_improved', label = 'Improved Binoculars', label_ar = 'منظار محسن' },
    { name = 'weapon_kit_camera', label = 'Camera', label_ar = 'كاميرا قديمة' },
    { name = 'weapon_kit_camera_advanced', label = 'Advanced Camera', label_ar = 'كاميرا متقدمة أصلية' },
    { name = 'weapon_kit_metal_detector', label = 'Metal Detector', label_ar = 'كاشف معادن أصلي' },
    { name = 'weapon_fishingrod', label = 'Fishing Rod', label_ar = 'صنارة صيد' },
    { name = 'weapon_moonshinejug_mp', label = 'Moonshine Jug (MP)', label_ar = 'إبريق مونشاين قابل للصب' },
    { name = 'weapon_unarmed', label = 'Unarmed', label_ar = 'أعزل' },
}

local builtinWeaponsMap = nil
local function getBuiltinWeapons()
    if builtinWeaponsMap then return builtinWeaponsMap end
    local items = getSharedItems()
    local map = {}
    for _, wDef in ipairs(BUILTIN_RDR3_WEAPONS) do
        local invItem = findItemInTable(items, wDef.name)
        local h = hashKey(wDef.name)
        map[h] = {
            name = wDef.name,
            label = (invItem and invItem.label) or wDef.label,
            label_ar = (invItem and invItem.label_ar) or wDef.label_ar,
            type = 'weapon',
            image = (invItem and invItem.image) or (wDef.name .. '.png'),
            weight = (invItem and invItem.weight) or 0,
            ammotype = invItem and invItem.ammotype or nil,
            ammoname = invItem and invItem.ammoname or nil,
        }
    end
    for k, v in pairs(items) do
        if type(v) == 'table' and (v.type == 'weapon' or (type(k) == 'string' and k:sub(1, 7):lower() == 'weapon_')) then
            local name = tostring(v.name or k):lower()
            local h = hashKey(name)
            if not map[h] then
                map[h] = {
                    name = name,
                    label = v.label or name,
                    label_ar = v.label_ar,
                    type = 'weapon',
                    image = v.image or (name .. '.png'),
                    weight = tonumber(v.weight) or 0,
                    ammotype = v.ammotype,
                    ammoname = v.ammoname,
                }
            end
        end
    end
    builtinWeaponsMap = map
    return map
end

local function getSharedWeapons()
    local weapons = coreSharedTable('Weapons', 'GetWeapons')
    if type(weapons) == 'table' and next(weapons) ~= nil then return weapons end
    return getBuiltinWeapons()
end

local function matchWeaponInTable(weapons, hashOrName)
    if type(weapons) ~= 'table' then return nil end
    if weapons[hashOrName] ~= nil then return weapons[hashOrName] end
    local num = tonumber(hashOrName)
    if num then
        local u = toU32(num)
        local s = toS32(num)
        if weapons[num] ~= nil then return weapons[num] end
        if u and weapons[u] ~= nil then return weapons[u] end
        if s and weapons[s] ~= nil then return weapons[s] end
        for k, v in pairs(weapons) do
            if tonumber(k) and (toU32(tonumber(k)) == u or toS32(tonumber(k)) == s) then return v end
            if type(v) == 'table' and type(v.name) == 'string' then
                local vh = hashKey(v.name:lower())
                if toU32(vh) == u or toS32(vh) == s then return v end
                local ph = pureJoaat(v.name:lower())
                if toU32(ph) == u or toS32(ph) == s then return v end
            end
        end
        return nil
    end
    if type(hashOrName) == 'string' and hashOrName ~= '' then
        local lower = hashOrName:lower()
        if weapons[lower] ~= nil then return weapons[lower] end
        local h = hashKey(lower)
        local u = toU32(h)
        local s = toS32(h)
        if weapons[h] ~= nil then return weapons[h] end
        if u and weapons[u] ~= nil then return weapons[u] end
        if s and weapons[s] ~= nil then return weapons[s] end
        local ph = pureJoaat(lower)
        local pu = toU32(ph)
        local ps = toS32(ph)
        if weapons[ph] ~= nil then return weapons[ph] end
        if pu and weapons[pu] ~= nil then return weapons[pu] end
        if ps and weapons[ps] ~= nil then return weapons[ps] end
        for k, v in pairs(weapons) do
            if type(k) == 'string' and k:lower() == lower then return v end
            if type(v) == 'table' and type(v.name) == 'string' and v.name:lower() == lower then return v end
        end
    end
    return nil
end

local function getSharedWeapon(hashOrName)
    if hashOrName == nil then return nil end
    if type(hashOrName) == 'table' then
        local out = {}
        for i = 1, #hashOrName do
            local key = hashOrName[i]
            local found = getSharedWeapon(key)
            if not found then return nil end
            out[key] = found
        end
        return out
    end
    local weapons = getSharedWeapons()
    local found = matchWeaponInTable(weapons, hashOrName)
    if found then return found end
    local fallback = getBuiltinWeapons()
    if fallback ~= weapons then
        return matchWeaponInTable(fallback, hashOrName)
    end
    return nil
end

WFW._Shared = {
    resolveLocale = resolveLocale,
    pureJoaat = pureJoaat,
    hashKey = hashKey,
    toU32 = toU32,
    toS32 = toS32,
    getSharedJobs = getSharedJobs,
    getSharedGangs = getSharedGangs,
    getSharedItems = getSharedItems,
    getSharedItem = getSharedItem,
    getSharedWeapons = getSharedWeapons,
    getSharedWeapon = getSharedWeapon,
    jobLabel = jobLabel,
    gradeName = gradeName,
}

exports('FwGetSharedJobs', getSharedJobs)
exports('FwGetSharedGangs', getSharedGangs)
exports('FwJobLabel', jobLabel)
exports('FwGradeName', gradeName)
exports('FwGetSharedItems', getSharedItems)
exports('FwGetSharedItem', getSharedItem)
exports('FwGetSharedWeapons', getSharedWeapons)
exports('FwGetSharedWeapon', getSharedWeapon)
