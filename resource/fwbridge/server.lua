-- ════════════════════════════════════════════════════════════════════════════
-- w_lib — جسر الفريمورك الشامل (fwbridge) — الدوال الخادميّة (منقولة من w_admin)
--   كل عمليّات الفريمورك (هويّة/شخصيّة/وظيفة/مال/أفعال/حقيبة أونلاين وأوفلاين)
--   صارت في المكتبة وتُستدعى عبر exports.w_lib:Fw*  ⇒ لا نداء مباشر لأي نظام بالسكربتات.
--   المنطق مطابق لجسر w_admin المُثبَت (فورب/RSGCore) — إعادة تغليف صرفة.
-- ════════════════════════════════════════════════════════════════════════════
if not IsDuplicityVersion() then return end

local FW = {}

-- ============================ GETTERS ============================

function FW.GetUser(source)
    if WFW.Name == "vorp" then
        return WFW.Core.getUser(source)
    elseif WFW.Name == "rsgcore" then
        return WFW.Core.Functions.GetPlayer(source)
    end
    return nil
end

function FW.GetCharacter(source)
    local user = FW.GetUser(source)
    if not user then return nil end
    if WFW.Name == "vorp" then
        return user.getUsedCharacter
    elseif WFW.Name == "rsgcore" then
        return user.PlayerData
    end
    return nil
end

function FW.GetCharacterIdentifier(source)
    local char = FW.GetCharacter(source)
    if not char then return nil end
    if WFW.Name == "vorp" then
        return char.charIdentifier
    elseif WFW.Name == "rsgcore" then
        return char.citizenid
    end
    return nil
end

function FW.GetCharacterName(source)
    local char = FW.GetCharacter(source)
    if not char then return GetPlayerName(source) end
    if WFW.Name == "vorp" then
        return (char.firstname or "") .. " " .. (char.lastname or "")
    elseif WFW.Name == "rsgcore" then
        local info = char.charinfo or {}
        return (info.firstname or "") .. " " .. (info.lastname or "")
    end
    return GetPlayerName(source)
end

function FW.GetFirstName(source)
    local char = FW.GetCharacter(source)
    if not char then return "" end
    if WFW.Name == "vorp" then
        return char.firstname or ""
    elseif WFW.Name == "rsgcore" then
        return char.charinfo and char.charinfo.firstname or ""
    end
    return ""
end

function FW.GetLastName(source)
    local char = FW.GetCharacter(source)
    if not char then return "" end
    if WFW.Name == "vorp" then
        return char.lastname or ""
    elseif WFW.Name == "rsgcore" then
        return char.charinfo and char.charinfo.lastname or ""
    end
    return ""
end

function FW.GetIdentifier(source)
    local char = FW.GetCharacter(source)
    if not char then return nil end
    if WFW.Name == "vorp" then
        return char.identifier
    elseif WFW.Name == "rsgcore" then
        return char.license or char.citizenid
    end
    return nil
end

function FW.GetJob(source)
    local char = FW.GetCharacter(source)
    if not char then return "unemployed" end
    if WFW.Name == "vorp" then
        return char.job or "unemployed"
    elseif WFW.Name == "rsgcore" then
        return char.job and char.job.name or "unemployed"
    end
    return "unemployed"
end

function FW.GetJobLabel(source)
    local char = FW.GetCharacter(source)
    if not char then return "Unemployed" end
    if WFW.Name == "vorp" then
        return char.jobLabel or char.job or "Unemployed"
    elseif WFW.Name == "rsgcore" then
        return char.job and char.job.label or "Unemployed"
    end
    return "Unemployed"
end

function FW.GetJobGrade(source)
    local char = FW.GetCharacter(source)
    if not char then return 0 end
    if WFW.Name == "vorp" then
        return char.jobGrade or 0
    elseif WFW.Name == "rsgcore" then
        return char.job and char.job.grade and char.job.grade.level or 0
    end
    return 0
end

function FW.GetMoney(source)
    local char = FW.GetCharacter(source)
    if not char then return 0 end
    if WFW.Name == "vorp" then
        return char.money or 0
    elseif WFW.Name == "rsgcore" then
        local player = FW.GetUser(source)
        return player and player.PlayerData.money and player.PlayerData.money.cash or 0
    end
    return 0
end

function FW.GetGold(source)
    local char = FW.GetCharacter(source)
    if not char then return 0 end
    if WFW.Name == "vorp" then
        return char.gold or 0
    elseif WFW.Name == "rsgcore" then
        local player = FW.GetUser(source)
        local money = player and player.PlayerData.money or nil
        return money and (money.gold or money.bloodmoney or 0) or 0
    end
    return 0
end

function FW.GetPlaytime(source)
    local char = FW.GetCharacter(source)
    if not char then return 0 end
    if WFW.Name == "vorp" then
        return char.hours or 0
    elseif WFW.Name == "rsgcore" then
        return char.metadata and char.metadata.playtime or 0
    end
    return 0
end

function FW.GetDescription(source)
    local char = FW.GetCharacter(source)
    if not char then return "" end
    if WFW.Name == "vorp" then
        return char.charDescription or ""
    elseif WFW.Name == "rsgcore" then
        return char.charinfo and char.charinfo.description or ""
    end
    return ""
end

function FW.GetCharacterData(source)
    local char = FW.GetCharacter(source)
    if not char then return nil end
    if WFW.Name == "vorp" then
        return {
            firstname = char.firstname or "",
            lastname = char.lastname or "",
            job = char.job or "unemployed",
            jobLabel = char.jobLabel or "Unemployed",
            jobGrade = char.jobGrade or 0,
            money = char.money or 0,
            gold = char.gold or 0,
            xp = char.xp or 0,
            charIdentifier = char.charIdentifier,
            identifier = char.identifier
        }
    elseif WFW.Name == "rsgcore" then
        local charinfo = char.charinfo or {}
        local job = char.job or {}
        local money = char.money or {}
        return {
            firstname = charinfo.firstname or "",
            lastname = charinfo.lastname or "",
            job = job.name or "unemployed",
            jobLabel = job.label or "Unemployed",
            jobGrade = job.grade and job.grade.level or 0,
            money = money.cash or 0,
            gold = money.bloodmoney or 0,
            xp = char.metadata and char.metadata.xp or 0,
            charIdentifier = char.citizenid,
            identifier = char.license or char.citizenid
        }
    end
    return nil
end

function FW.GetAge(source)
    local char = FW.GetCharacter(source)
    if not char then return nil end
    if WFW.Name == "vorp" then
        return char.age
    elseif WFW.Name == "rsgcore" then
        return char.charinfo and char.charinfo.age
    end
    return nil
end

function FW.GetNickname(source)
    local char = FW.GetCharacter(source)
    if not char then return "" end
    if WFW.Name == "vorp" then
        return char.nickname or ""
    elseif WFW.Name == "rsgcore" then
        return char.charinfo and char.charinfo.nickname or ""
    end
    return ""
end

-- ============================ SETTERS ============================

function FW.SetJob(source, jobName, grade)
    if WFW.Name == "vorp" then
        local user = FW.GetUser(source)
        if user and user.getUsedCharacter then
            local char = user.getUsedCharacter
            char.setJob(jobName, false)
            char.setJobGrade(grade or 0, false)
            return true
        end
    elseif WFW.Name == "rsgcore" then
        local player = FW.GetUser(source)
        if player then
            local sharedJobs = WFW.Core.Shared.Jobs
            if sharedJobs and sharedJobs[jobName] then
                player.Functions.SetJob(jobName, tonumber(grade) or 0)
                return true
            else
                local success = pcall(function()
                    player.Functions.SetJob(jobName, tonumber(grade) or 0)
                end)
                return success
            end
        end
    end
    return false
end

function FW.SetJobLabel(source, label)
    if WFW.Name == "vorp" then
        local user = FW.GetUser(source)
        if user and user.getUsedCharacter then
            user.getUsedCharacter.setJobLabel(label)
            return true
        end
    elseif WFW.Name == "rsgcore" then
        local player = FW.GetUser(source)
        if player then
            local sharedJobs = WFW.Core.Shared.Jobs
            if sharedJobs then
                for jobName, jobData in pairs(sharedJobs) do
                    if jobData.label == label or jobName == label then
                        local currentGrade = player.PlayerData.job and player.PlayerData.job.grade and player.PlayerData.job.grade.level or 0
                        player.Functions.SetJob(jobName, currentGrade)
                        return true
                    end
                end
            end
            local currentGrade = player.PlayerData.job and player.PlayerData.job.grade and player.PlayerData.job.grade.level or 0
            local success = pcall(function()
                player.Functions.SetJob(label, currentGrade)
            end)
            return success
        end
    end
    return false
end

function FW.SetJobGrade(source, grade)
    if WFW.Name == "vorp" then
        local user = FW.GetUser(source)
        if user and user.getUsedCharacter then
            user.getUsedCharacter.setJobGrade(grade, false)
            return true
        end
    elseif WFW.Name == "rsgcore" then
        local player = FW.GetUser(source)
        if player and player.PlayerData.job then
            player.Functions.SetJob(player.PlayerData.job.name, tonumber(grade) or 0)
            return true
        end
    end
    return false
end

-- مساعد RSGCore: تحديث حقل charinfo في الذاكرة + DB
local function rsgUpdateCharInfo(source, field, value)
    local player = FW.GetUser(source)
    if not player then return false end
    local charinfo = player.PlayerData.charinfo or {}
    charinfo[field] = value
    player.PlayerData.charinfo = charinfo
    local citizenid = player.PlayerData.citizenid
    if citizenid then
        MySQL.update("UPDATE players SET charinfo = JSON_SET(charinfo, '$." .. field .. "', ?) WHERE citizenid = ?", { value, citizenid })
    end
    return true
end

function FW.SetFirstName(source, firstName)
    if WFW.Name == "vorp" then
        local user = FW.GetUser(source)
        if user and user.getUsedCharacter then
            user.getUsedCharacter.setFirstname(firstName)
            return true
        end
    elseif WFW.Name == "rsgcore" then
        return rsgUpdateCharInfo(source, "firstname", firstName)
    end
    return false
end

function FW.SetLastName(source, lastName)
    if WFW.Name == "vorp" then
        local user = FW.GetUser(source)
        if user and user.getUsedCharacter then
            user.getUsedCharacter.setLastname(lastName)
            return true
        end
    elseif WFW.Name == "rsgcore" then
        return rsgUpdateCharInfo(source, "lastname", lastName)
    end
    return false
end

function FW.SetNickname(source, nickname)
    if WFW.Name == "vorp" then
        local user = FW.GetUser(source)
        if user and user.getUsedCharacter then
            user.getUsedCharacter.setNickName(nickname)
            return true
        end
    elseif WFW.Name == "rsgcore" then
        return rsgUpdateCharInfo(source, "nickname", nickname)
    end
    return false
end

function FW.SetAge(source, age)
    if WFW.Name == "vorp" then
        local user = FW.GetUser(source)
        if user and user.getUsedCharacter then
            user.getUsedCharacter.setAge(age)
            return true
        end
    elseif WFW.Name == "rsgcore" then
        return rsgUpdateCharInfo(source, "age", age)
    end
    return false
end

function FW.SetDescription(source, description)
    if WFW.Name == "vorp" then
        local user = FW.GetUser(source)
        if user and user.getUsedCharacter then
            user.getUsedCharacter.setCharDescription(description)
            return true
        end
    elseif WFW.Name == "rsgcore" then
        return rsgUpdateCharInfo(source, "description", description)
    end
    return false
end

-- ============================ CURRENCY ============================
-- 0 = cash · 1 = gold(VORP)/bloodmoney(RSG) · 2 = rol(VORP)/blkbank(RSG)
local RSG_MONEY_TYPES = { [0] = "cash", [1] = "bloodmoney", [2] = "blkbank" }

local function qbMoneyType(player, currencyType)
    local balances = player and player.PlayerData and player.PlayerData.money or nil
    if not balances then return nil end

    if currencyType == 0 then return balances.cash ~= nil and 'cash' or nil end
    if currencyType == 1 then
        if balances.gold ~= nil then return 'gold' end
        if balances.bloodmoney ~= nil then return 'bloodmoney' end
        return nil
    end
    if currencyType == 2 then
        if balances.blkbank ~= nil then return 'blkbank' end
        return nil
    end

    return nil
end

function FW.AddCurrency(source, currencyType, amount)
    if WFW.Name == "vorp" then
        local user = FW.GetUser(source)
        if user and user.getUsedCharacter then
            user.getUsedCharacter.addCurrency(currencyType, amount)
            return true
        end
    elseif WFW.Name == "rsgcore" then
        local player = FW.GetUser(source)
        local moneyType = qbMoneyType(player, currencyType) or RSG_MONEY_TYPES[currencyType]
        if not player or not moneyType or not player.PlayerData.money
            or player.PlayerData.money[moneyType] == nil then return false end
        if player and moneyType then
            return player.Functions.AddMoney(moneyType, amount) ~= false
        end
    end
    return false
end

function FW.RemoveCurrency(source, currencyType, amount)
    if WFW.Name == "vorp" then
        local user = FW.GetUser(source)
        if user and user.getUsedCharacter then
            user.getUsedCharacter.removeCurrency(currencyType, amount)
            return true
        end
    elseif WFW.Name == "rsgcore" then
        local player = FW.GetUser(source)
        local moneyType = qbMoneyType(player, currencyType) or RSG_MONEY_TYPES[currencyType]
        if not player or not moneyType or not player.PlayerData.money
            or player.PlayerData.money[moneyType] == nil then return false end
        if player and moneyType then
            return player.Functions.RemoveMoney(moneyType, amount) ~= false
        end
    end
    return false
end

-- ============================ PLAYER ACTIONS ============================
local function applyMetabolism(source)
    -- here
end

function FW.Revive(source)
    if WFW.Name == "vorp" then
        WFW.Core.Player.Revive(source, true)
    elseif WFW.Name == "rsgcore" then
        TriggerClientEvent('rsg-medic:client:adminRevive', source)
    else
        return false
    end
    applyMetabolism(source)
    return true
end

function FW.Heal(source)
    if WFW.Name == "vorp" then
        WFW.Core.Player.Heal(source)
    elseif WFW.Name == "rsgcore" then
        TriggerClientEvent('rsg-medic:client:adminHeal', source)
    else
        return false
    end
    applyMetabolism(source)
    return true
end

function FW.Respawn(source)
    if WFW.Name == "vorp" then
        WFW.Core.Player.Respawn(source, true)
    elseif WFW.Name == "rsgcore" then
        TriggerClientEvent('rsg-medic:client:adminRevive', source)
    else
        return false
    end
    applyMetabolism(source)
    return true
end

function FW.Kill(source)
    if WFW.Name == "vorp" then
        TriggerClientEvent('w_:client:killPlayer', source)
        return true
    elseif WFW.Name == "rsgcore" then
        TriggerClientEvent('rsg-medic:client:KillPlayer', source)
        return true
    end
    return false
end

-- ============================ INVENTORY (ONLINE) ============================

-- الحقيبة الفعّالة (من invbridge) + كاشف اسم سلاح — لتوجيه عمليّات الحقيبة للحقيبة الصحيحة
-- حتى لو الفريمورك vorp لكن الفعّالة w_inventory (تخزّن الأسلحة كعناصر لا في جدول loadout).
local function activeBag()
    local ok, n = pcall(function() return exports.w_lib:InvName() end)
    return (ok and n) or WFW.Inventory
end
local function nativeWStorage()
    if activeBag() ~= 'w_inventory' then return nil end
    local ok, framework = pcall(function() return exports.w_inventory:GetNativeStorage() end)
    return ok and framework or nil
end
local function isWeaponName(n)
    return type(n) == 'string' and n:sub(1, 7):upper() == 'WEAPON_'
end
local function inventoryFlag(value)
    return value == true or value == 1 or value == '1'
end

function FW.GetInventoryItems(source)
    if nativeWStorage() == 'vorp' then return exports.vorp_inventory:getUserInventoryItems(source) end
    local out = {}

    for _, it in ipairs(exports.w_lib:InvGetItems(source) or {}) do
        if it.name and not isWeaponName(it.name) then
            out[#out + 1] = {
                name = it.name,
                count = it.count or it.amount or 1,
                amount = it.count or it.amount or 1,
                label = it.label or it.name,
                weight = it.weight or 0,
                id = it.slot,
                slot = it.slot,
                metadata = it.metadata or {},
                info = it.metadata or {},
            }
        end
    end

    return out
end

function FW.GetInventoryWeapons(source)
    if nativeWStorage() == 'vorp' then return exports.vorp_inventory:getUserInventoryWeapons(source) end
    local out = {}

    for _, it in ipairs(exports.w_lib:InvGetItems(source) or {}) do
        if it.name and isWeaponName(it.name) then
            local md = it.metadata or {}
            local used = inventoryFlag(md.used or it.used)
            out[#out + 1] = {
                name = it.name,
                id = md.weaponId or it.slot,
                slot = it.slot,
                weight = it.weight or 0,
                label = md.label or it.label or it.name,
                custom_label = md.label,
                serial_number = md.serie or md.serial or md.serial_number or "",
                ammo = md.ammo or 0,
                components = md.components or {},
                metadata = md,
                info = md,
                type = 'weapon',
                group = 0,
                propietary = "",
                used = used,
                used2 = used and inventoryFlag(md.used2 or it.used2) or false,
            }
        end
    end

    return out
end

function FW.AddItem(source, itemName, count)
    return exports.w_lib:InvAddItem(source, itemName, count or 1, nil) == true
end

function FW.RemoveItem(source, itemName, count)
    return exports.w_lib:InvRemoveItem(source, itemName, count or 1, nil, nil) == true
end

function FW.AddWeapon(source, weaponName, ammo)
    if nativeWStorage() == 'vorp' then
        return exports.vorp_inventory:createWeapon(source, weaponName, type(ammo) == 'table' and ammo or {}, nil, {}) ~= false
    end
    local metadata = {}

    if activeBag() == 'vorp_inventory' then
        metadata.ammo = type(ammo) == 'table' and ammo or {}
    elseif type(ammo) == 'table' then
        local total = 0
        for _, amount in pairs(ammo) do total = total + (tonumber(amount) or 0) end
        metadata.ammo = math.max(0, math.floor(total))
    else
        metadata.ammo = math.max(0, math.floor(tonumber(ammo) or 0))
    end

    return exports.w_lib:InvAddItem(source, weaponName, 1, metadata) == true
end

function FW.RemoveWeapon(source, weaponId)
    if nativeWStorage() == 'vorp' then return exports.vorp_inventory:subWeapon(source, weaponId) == true end
    local slotData = exports.w_lib:InvGetSlot(source, weaponId)

    if not slotData and activeBag() == 'vorp_inventory' then
        slotData = exports.w_lib:InvGetSlot(source, 'w' .. tostring(weaponId))
    end

    if not slotData then
        for _, item in ipairs(exports.w_lib:InvGetItems(source) or {}) do
            local metadata = item.metadata or {}
            if metadata.weaponId == weaponId or metadata.serial == weaponId
                or metadata.serial_number == weaponId then
                slotData = item
                break
            end
        end
    end

    if not slotData or not slotData.name or not isWeaponName(slotData.name) then return false end

    local metadata = slotData.metadata or {}
    if not metadata.weaponId and activeBag() == 'vorp_inventory' then
        metadata.weaponId = tonumber(weaponId)
    end

    return exports.w_lib:InvRemoveItem(source, slotData.name, 1, metadata,
        slotData.slot or weaponId) == true
end

function FW.CanCarryItem(source, itemName, count)
    return exports.w_lib:InvCanCarry(source, itemName, count or 1) == true
end

function FW.CanCarryWeapon(source, count, weaponName)
    return exports.w_lib:InvCanCarry(source, weaponName, count or 1) == true
end

function FW.ClearInventory(source)
    local items = exports.w_lib:InvGetItems(source) or {}

    for _, item in ipairs(items) do
        if item.name then
            exports.w_lib:InvRemoveItem(source, item.name, item.count or 1,
                item.metadata or {}, item.slot)
        end
    end

    return true
end

-- ============================ INVENTORY (OFFLINE / DB DIRECT) ============================

local function wItemDefinition(name)
    local ok, item = pcall(function() return exports.w_inventory:Items(name) end)
    return ok and item or nil
end

local function loadWInventoryOffline(charId)
    local query, value

    if WFW.Name == 'vorp' then
        query = 'SELECT inventory FROM characters WHERE charidentifier = ?'
        value = tonumber(charId)
    elseif WFW.Name == 'rsgcore' then
        query = 'SELECT inventory FROM players WHERE citizenid = ?'
        value = tostring(charId)
    else
        return nil
    end

    local result = MySQL.query.await(query, { value })
    if not result or not result[1] then return nil end

    local ok, inventory = pcall(json.decode, result[1].inventory or '[]')
    if not ok or type(inventory) ~= 'table' then inventory = {} end

    return inventory, query:match('FROM%s+([%w_]+)'), value
end

local function saveWInventoryOffline(inventory, playerTable, value)
    if not inventory or not playerTable then return false end
    local column = playerTable == 'characters' and 'charidentifier' or 'citizenid'
    local affected = MySQL.update.await(('UPDATE `%s` SET inventory = ? WHERE `%s` = ?')
        :format(playerTable, column), { json.encode(inventory), value })
    return (tonumber(affected) or 0) > 0
end

local function nextWInventorySlot(inventory)
    local used = {}
    for key, item in pairs(inventory) do
        if type(item) == 'table' then used[tonumber(item.slot) or tonumber(key)] = true end
    end
    local slot = 1
    while used[slot] do slot = slot + 1 end
    return slot
end

local function makeWInventoryItem(name, count, metadata, inventory)
    local def = wItemDefinition(name)
    if not def then return nil, 'Item definition not found' end

    count = math.max(1, math.floor(tonumber(count) or 1))
    metadata = type(metadata) == 'table' and metadata or {}

    if def.weapon then
        count = 1
        metadata.durability = tonumber(metadata.durability) or 100
        metadata.ammo = math.max(0, math.floor(tonumber(metadata.ammo) or 0))
        metadata.components = type(metadata.components) == 'table' and metadata.components or {}
        metadata.weaponExpiry = tonumber(metadata.weaponExpiry) or (os.time() + 7 * 24 * 60 * 60)
        metadata.serial = metadata.serial or ('W-%d-%06d'):format(os.time(), math.random(0, 999999))
    elseif def.degrade and not metadata.durability then
        metadata.durability = os.time() + (tonumber(def.degrade) or 0) * 60
        metadata.degrade = tonumber(def.degrade) or 0
    end

    local slot = nextWInventorySlot(inventory)
    return {
        name = name,
        label = def.label or name,
        weight = (tonumber(def.weight) or 0) * count,
        slot = slot,
        count = count,
        description = def.description,
        metadata = metadata,
        stack = def.stack,
        close = def.close,
    }
end

function FW.GetOfflineInventory(charId)
    if nativeWStorage() then return exports.w_inventory:GetNativeOfflineInventory(charId) end
    local items = {}
    local weapons = {}

    if activeBag() == 'w_inventory' then
        local inventory = loadWInventoryOffline(charId)

        for key, item in pairs(inventory or {}) do
            if type(item) == 'table' and item.name then
                local metadata = item.metadata or item.info or {}
                local slot = tonumber(item.slot) or tonumber(key)
                local def = wItemDefinition(item.name)

                if isWeaponName(item.name) or def and def.weapon then
                    weapons[#weapons + 1] = {
                        name = item.name,
                        count = 1,
                        weight = item.weight or 0,
                        label = metadata.label or item.label or item.name,
                        type = 'weapon',
                        itemId = slot,
                        slot = slot,
                        serial_number = metadata.serial or '',
                        ammo = metadata.ammo or 0,
                        metadata = metadata,
                    }
                else
                    items[#items + 1] = {
                        name = item.name,
                        count = item.count or item.amount or 1,
                        weight = item.weight or 0,
                        label = item.label or item.name,
                        type = 'item',
                        itemId = slot,
                        slot = slot,
                        metadata = metadata,
                    }
                end
            end
        end

        return items, weapons
    end

    if WFW.Name == "vorp" then
        local cid = tonumber(charId)
        local dbItems = MySQL.query.await([[
            SELECT ci.amount, ci.item_name as name, i.label, i.desc as description,
                   ic.id as crafted_id, ci.item_crafted_id
            FROM character_inventories ci
            JOIN items_crafted ic ON ci.item_crafted_id = ic.id
            JOIN items i ON i.item = ci.item_name
            WHERE ci.character_id = ? AND ci.inventory_type = 'default'
        ]], { cid })

        if dbItems then
            for _, item in pairs(dbItems) do
                table.insert(items, {
                    name = item.name,
                    count = item.amount or 1,
                    label = item.label or item.name,
                    type = "item",
                    weight = 0,
                    itemId = item.crafted_id
                })
            end
        end

        local dbWeapons = MySQL.query.await("SELECT * FROM loadout WHERE charidentifier = ?", { cid })
        if dbWeapons then
            for _, weapon in pairs(dbWeapons) do
                local ammoData = {}
                if weapon.ammo and weapon.ammo ~= "" and weapon.ammo ~= "{}" then
                    local ok, decoded = pcall(json.decode, weapon.ammo)
                    if ok and decoded then ammoData = decoded end
                end
                table.insert(weapons, {
                    name = weapon.name,
                    count = 1,
                    weight = 1.0,
                    label = weapon.custom_label or weapon.label or weapon.name,
                    type = "weapon",
                    itemId = weapon.id,
                    serial_number = weapon.serial_number or "",
                    ammo = ammoData,
                    group = weapon.comps or 0,
                    used = weapon.used == 1,
                    used2 = weapon.used2 == 1,
                })
            end
        end

    elseif WFW.Name == "rsgcore" then
        local result = MySQL.query.await("SELECT inventory FROM players WHERE citizenid = ?", { charId })
        if result and result[1] and result[1].inventory then
            local ok, inventory = pcall(json.decode, result[1].inventory)
            if ok and inventory then
                for _, item in pairs(inventory) do
                    if item and item.name and item.name ~= "" then
                        local itemType = item.type or "item"
                        if itemType == "weapon" then
                            table.insert(weapons, {
                                name = item.name,
                                count = 1,
                                weight = item.weight or 1.0,
                                label = item.label or item.name,
                                type = "weapon",
                                itemId = item.slot,
                                serial_number = item.info and item.info.serie or "",
                                ammo = item.info and item.info.ammo or 0,
                            })
                        else
                            table.insert(items, {
                                name = item.name,
                                count = item.amount or item.count or 1,
                                label = item.label or item.name,
                                type = itemType,
                                weight = item.weight or 0,
                                itemId = item.slot
                            })
                        end
                    end
                end
            end
        end
    end

    return items, weapons
end

function FW.AddItemOffline(charId, itemName, count)
    if nativeWStorage() then return exports.w_inventory:MutateNativeOfflineInventory(charId, 'add', itemName, count or 1) end
    if activeBag() == 'w_inventory' then
        local inventory, playerTable, value = loadWInventoryOffline(charId)
        if not inventory then return false, 'Player not found' end

        local def = wItemDefinition(itemName)
        if not def then return false, 'Item definition not found' end

        count = math.max(1, math.floor(tonumber(count) or 1))

        if def.stack ~= false and not def.weapon then
            for _, item in pairs(inventory) do
                if type(item) == 'table' and item.name == itemName then
                    item.count = (tonumber(item.count or item.amount) or 0) + count
                    item.amount = nil
                    item.weight = (tonumber(def.weight) or 0) * item.count
                    return saveWInventoryOffline(inventory, playerTable, value)
                end
            end
        end

        local separate = def.stack == false or def.weapon == true
        local amount = separate and count or 1
        for _ = 1, amount do
            local row, err = makeWInventoryItem(itemName, separate and 1 or count, {}, inventory)
            if not row then return false, err end
            inventory[row.slot] = row
        end

        return saveWInventoryOffline(inventory, playerTable, value)
    end

    if WFW.Name == "vorp" then
        local cid = tonumber(charId)
        local existing = MySQL.query.await([[
            SELECT ci.amount, ci.item_crafted_id
            FROM character_inventories ci
            WHERE ci.character_id = ? AND ci.item_name = ? AND ci.inventory_type = 'default'
        ]], { cid, itemName })

        if existing and #existing > 0 then
            MySQL.update.await([[
                UPDATE character_inventories SET amount = amount + ?
                WHERE character_id = ? AND item_name = ? AND inventory_type = 'default'
            ]], { count, cid, itemName })
            return true
        else
            local itemDef = MySQL.query.await("SELECT id FROM items WHERE item = ?", { itemName })
            if not itemDef or #itemDef == 0 then
                return false, "Item definition not found"
            end
            local itemDefId = itemDef[1].id

            local craftedId = MySQL.insert.await([[
                INSERT INTO items_crafted (character_id, item_id, item_name, metadata)
                VALUES (?, ?, ?, '{}')
            ]], { cid, itemDefId, itemName })

            if not craftedId then
                return false, "Failed to create item instance"
            end

            MySQL.insert.await([[
                INSERT INTO character_inventories (character_id, item_crafted_id, amount, inventory_type, item_name)
                VALUES (?, ?, ?, 'default', ?)
            ]], { cid, craftedId, count, itemName })

            return true
        end

    elseif WFW.Name == "rsgcore" then
        local result = MySQL.query.await("SELECT inventory FROM players WHERE citizenid = ?", { charId })
        if not result or not result[1] then
            return false, "Player not found"
        end

        local ok, inventory = pcall(json.decode, result[1].inventory or "[]")
        if not ok then inventory = {} end

        local found = false
        for _, item in pairs(inventory) do
            if item and item.name == itemName then
                item.amount = (item.amount or 0) + count
                found = true
                break
            end
        end

        if not found then
            local usedSlots = {}
            for _, item in pairs(inventory) do
                if item and item.slot then usedSlots[item.slot] = true end
            end
            local slot = 1
            while usedSlots[slot] do slot = slot + 1 end

            local itemInfo = WFW.Core.Shared.Items[itemName]
            table.insert(inventory, {
                name = itemName,
                amount = count,
                label = itemInfo and itemInfo.label or itemName,
                weight = itemInfo and itemInfo.weight or 0,
                type = itemInfo and itemInfo.type or "item",
                slot = slot,
                info = {},
                unique = itemInfo and itemInfo.unique or false,
                useable = itemInfo and itemInfo.useable or true,
                image = itemInfo and itemInfo.image or (itemName .. ".png"),
                description = itemInfo and itemInfo.description or "",
                created = os.time()
            })
        end

        MySQL.update.await("UPDATE players SET inventory = ? WHERE citizenid = ?", { json.encode(inventory), charId })
        return true
    end

    return false, "Unknown framework"
end

function FW.RemoveItemOffline(charId, itemName, count)
    if nativeWStorage() then return exports.w_inventory:MutateNativeOfflineInventory(charId, 'remove', itemName, count or 1) end
    if activeBag() == 'w_inventory' then
        local inventory, playerTable, value = loadWInventoryOffline(charId)
        if not inventory then return false, 'Player not found' end

        count = math.max(1, math.floor(tonumber(count) or 1))
        local available = 0

        for _, item in pairs(inventory) do
            if type(item) == 'table' and item.name == itemName then
                available += tonumber(item.count or item.amount) or 0
            end
        end

        if available < count then return false, 'Item not found in inventory' end

        local remaining = count
        local def = wItemDefinition(itemName)

        for key, item in pairs(inventory) do
            if remaining <= 0 then break end
            if type(item) == 'table' and item.name == itemName then
                local itemCount = tonumber(item.count or item.amount) or 0
                local take = math.min(itemCount, remaining)
                itemCount -= take
                remaining -= take

                if itemCount <= 0 then
                    inventory[key] = nil
                else
                    item.count = itemCount
                    item.amount = nil
                    item.weight = (tonumber(def and def.weight) or 0) * itemCount
                end
            end
        end

        return saveWInventoryOffline(inventory, playerTable, value)
    end

    if WFW.Name == "vorp" then
        local cid = tonumber(charId)
        local existing = MySQL.query.await([[
            SELECT ci.amount, ci.item_crafted_id
            FROM character_inventories ci
            WHERE ci.character_id = ? AND ci.item_name = ? AND ci.inventory_type = 'default'
        ]], { cid, itemName })

        if not existing or #existing == 0 then
            return false, "Item not found in inventory"
        end

        local currentAmount = existing[1].amount or 0
        local craftedId = existing[1].item_crafted_id
        local newAmount = currentAmount - count

        if newAmount <= 0 then
            MySQL.update.await([[
                DELETE FROM character_inventories
                WHERE character_id = ? AND item_name = ? AND inventory_type = 'default'
            ]], { cid, itemName })
            MySQL.update.await("DELETE FROM items_crafted WHERE id = ?", { craftedId })
        else
            MySQL.update.await([[
                UPDATE character_inventories SET amount = ?
                WHERE character_id = ? AND item_name = ? AND inventory_type = 'default'
            ]], { newAmount, cid, itemName })
        end

        return true

    elseif WFW.Name == "rsgcore" then
        local result = MySQL.query.await("SELECT inventory FROM players WHERE citizenid = ?", { charId })
        if not result or not result[1] then
            return false, "Player not found"
        end

        local ok, inventory = pcall(json.decode, result[1].inventory or "[]")
        if not ok then return false, "Failed to parse inventory" end

        local newInventory = {}
        local removed = false
        for _, item in pairs(inventory) do
            if item and item.name == itemName and not removed then
                local newAmount = (item.amount or 0) - count
                if newAmount > 0 then
                    item.amount = newAmount
                    table.insert(newInventory, item)
                end
                removed = true
            else
                table.insert(newInventory, item)
            end
        end

        if not removed then
            return false, "Item not found in inventory"
        end

        MySQL.update.await("UPDATE players SET inventory = ? WHERE citizenid = ?", { json.encode(newInventory), charId })
        return true
    end

    return false, "Unknown framework"
end

function FW.AddWeaponOffline(charId, weaponName, ammo)
    if nativeWStorage() then return exports.w_inventory:MutateNativeOfflineInventory(charId, 'add', weaponName, 1, nil, ammo) end
    if activeBag() == 'w_inventory' then
        local inventory, playerTable, value = loadWInventoryOffline(charId)
        if not inventory then return false, 'Player not found' end

        local ammoCount = 0
        if type(ammo) == 'table' then
            for _, amount in pairs(ammo) do ammoCount += tonumber(amount) or 0 end
        else
            ammoCount = tonumber(ammo) or 0
        end

        local row, err = makeWInventoryItem(weaponName, 1, { ammo = ammoCount }, inventory)
        if not row then return false, err end
        inventory[row.slot] = row
        return saveWInventoryOffline(inventory, playerTable, value)
    end

    if WFW.Name == "vorp" then
        local cid = tonumber(charId)
        local charData = MySQL.query.await("SELECT identifier FROM characters WHERE charidentifier = ?", { cid })
        local identifier = charData and charData[1] and charData[1].identifier or ""

        MySQL.insert.await([[
            INSERT INTO loadout (identifier, charidentifier, name, ammo, components, dirtlevel, mudlevel, conditionlevel, used, comps, label)
            VALUES (?, ?, ?, '{}', '[]', 0, 0, 0, 0, '{}', ?)
        ]], { identifier, cid, weaponName, weaponName })
        return true

    elseif WFW.Name == "rsgcore" then
        return FW.AddItemOffline(charId, weaponName, 1)
    end

    return false
end

function FW.RemoveWeaponOffline(charId, weaponId, weaponName)
    if nativeWStorage() then return exports.w_inventory:MutateNativeOfflineInventory(charId, 'remove', weaponName, 1, weaponId) end
    if activeBag() == 'w_inventory' then
        local inventory, playerTable, value = loadWInventoryOffline(charId)
        if not inventory then return false end

        local wantedSlot = tonumber(weaponId) or tonumber(tostring(weaponId or ''):match('^w(%d+)$'))

        for key, item in pairs(inventory) do
            if type(item) == 'table' and item.name and isWeaponName(item.name) then
                local metadata = item.metadata or item.info or {}
                local slot = tonumber(item.slot) or tonumber(key)
                if (wantedSlot and slot == wantedSlot)
                    or (weaponId and (metadata.serial == weaponId or metadata.serial_number == weaponId))
                    or (not weaponId and weaponName and item.name == weaponName) then
                    inventory[key] = nil
                    return saveWInventoryOffline(inventory, playerTable, value)
                end
            end
        end

        return false
    end

    if WFW.Name == "vorp" then
        MySQL.update.await("DELETE FROM loadout WHERE id = ? AND charidentifier = ?", { tonumber(weaponId), tonumber(charId) })
        return true

    elseif WFW.Name == "rsgcore" then
        local result = MySQL.query.await("SELECT inventory FROM players WHERE citizenid = ?", { charId })
        if not result or not result[1] then return false end

        local ok, inventory = pcall(json.decode, result[1].inventory or "[]")
        if not ok then return false end

        local newInventory = {}
        local removed = false
        for _, item in pairs(inventory) do
            if item and item.slot == weaponId and item.type == "weapon" and not removed then
                removed = true
            elseif item and item.name == weaponName and item.type == "weapon" and not removed then
                removed = true
            else
                table.insert(newInventory, item)
            end
        end

        if removed then
            MySQL.update.await("UPDATE players SET inventory = ? WHERE citizenid = ?", { json.encode(newInventory), charId })
        end
        return removed
    end

    return false
end

-- ============================ EXPORTS (exports.w_lib:Fw*) ============================
local API = {
    'GetUser', 'GetCharacter', 'GetCharacterIdentifier', 'GetCharacterName', 'GetFirstName',
    'GetLastName', 'GetIdentifier', 'GetJob', 'GetJobLabel', 'GetJobGrade', 'GetMoney', 'GetGold',
    'GetPlaytime', 'GetDescription', 'GetCharacterData', 'GetAge', 'GetNickname',
    'SetJob', 'SetJobLabel', 'SetJobGrade', 'SetFirstName', 'SetLastName', 'SetNickname', 'SetAge', 'SetDescription',
    'AddCurrency', 'RemoveCurrency', 'Revive', 'Heal', 'Respawn', 'Kill',
    'GetInventoryItems', 'GetInventoryWeapons', 'AddItem', 'RemoveItem', 'AddWeapon', 'RemoveWeapon',
    'CanCarryItem', 'CanCarryWeapon', 'ClearInventory',
    'GetOfflineInventory', 'AddItemOffline', 'RemoveItemOffline', 'AddWeaponOffline', 'RemoveWeaponOffline',
}
for _, name in ipairs(API) do
    exports('Fw' .. name, FW[name])
end

-- ════════════════════════════════════════════════════════════════════════════
-- OFFLINE (DB مباشر) — تعديل حقول الشخصيّة/الوظيفة/العملة للاعب غير متصل،
-- + جلب الديسكورد + إحصاءات. منقولة من w_admin ومُوحّدة (فورب characters / RSG players).
-- كل أعمدة الأعمدة المُدمَجة في SQL تأتي من خرائط ثابتة (لا حقن).
-- ════════════════════════════════════════════════════════════════════════════

-- ── العملة أوفلاين ──
local VORP_CUR = { [0] = 'money', [1] = 'gold', [2] = 'rol' }
local RSG_CUR  = { [0] = 'cash', [1] = 'bloodmoney', [2] = 'blkbank' }
local function currencyOffline(identifier, currencyType, amount, action)
    if WFW.Name == 'vorp' then
        local col = VORP_CUR[currencyType]; if not col then return false, 'invalid_data' end
        if action == 'add' then
            MySQL.update.await("UPDATE characters SET " .. col .. " = " .. col .. " + ? WHERE identifier = ?", { amount, identifier })
        else
            MySQL.update.await("UPDATE characters SET " .. col .. " = GREATEST(" .. col .. " - ?, 0) WHERE identifier = ?", { amount, identifier })
        end
        return true
    elseif WFW.Name == 'rsgcore' then
        local key = RSG_CUR[currencyType]; if not key then return false, 'invalid_data' end
        if action == 'add' then
            MySQL.update.await("UPDATE players SET money = JSON_SET(money, '$." .. key .. "', CAST(JSON_EXTRACT(money, '$." .. key .. "') AS SIGNED) + ?) WHERE citizenid = ?", { amount, identifier })
        else
            MySQL.update.await("UPDATE players SET money = JSON_SET(money, '$." .. key .. "', GREATEST(CAST(JSON_EXTRACT(money, '$." .. key .. "') AS SIGNED) - ?, 0)) WHERE citizenid = ?", { amount, identifier })
        end
        return true
    end
    return false, 'unknown_framework'
end
exports('FwAddCurrencyOffline', function(identifier, t, amt) return currencyOffline(identifier, t, amt, 'add') end)
exports('FwRemoveCurrencyOffline', function(identifier, t, amt) return currencyOffline(identifier, t, amt, 'remove') end)

-- ── الوظيفة أوفلاين (بالمُعرّف identifier) ──
exports('FwSetJobFullOffline', function(identifier, jobName, jobGrade)
    if WFW.Name == 'vorp' then
        MySQL.update.await("UPDATE characters SET job = ?, jobGrade = ? WHERE identifier = ?", { jobName, jobGrade, identifier })
        return true
    elseif WFW.Name == 'rsgcore' then
        local result = MySQL.query.await("SELECT job FROM players WHERE citizenid = ?", { identifier })
        if result and result[1] then
            local jobData = type(result[1].job) == 'string' and json.decode(result[1].job) or result[1].job or {}
            jobData.name = jobName; jobData.label = jobName
            if not jobData.grade then jobData.grade = {} end
            jobData.grade.level = tonumber(jobGrade) or 0
            MySQL.update.await("UPDATE players SET job = ? WHERE citizenid = ?", { json.encode(jobData), identifier })
        end
        return true
    end
    return false
end)
exports('FwSetJobLabelOffline', function(identifier, jobLabel)
    if WFW.Name == 'vorp' then
        MySQL.update.await("UPDATE characters SET jobLabel = ? WHERE identifier = ?", { jobLabel, identifier })
    elseif WFW.Name == 'rsgcore' then
        local result = MySQL.query.await("SELECT job FROM players WHERE citizenid = ?", { identifier })
        if result and result[1] then
            local jobData = type(result[1].job) == 'string' and json.decode(result[1].job) or result[1].job or {}
            jobData.label = jobLabel
            MySQL.update.await("UPDATE players SET job = ? WHERE citizenid = ?", { json.encode(jobData), identifier })
        end
    else
        return false
    end
    return true
end)
exports('FwSetJobGradeOffline', function(identifier, jobGrade)
    if WFW.Name == 'vorp' then
        MySQL.update.await("UPDATE characters SET jobGrade = ? WHERE identifier = ?", { jobGrade, identifier })
    elseif WFW.Name == 'rsgcore' then
        local result = MySQL.query.await("SELECT job FROM players WHERE citizenid = ?", { identifier })
        if result and result[1] then
            local jobData = type(result[1].job) == 'string' and json.decode(result[1].job) or result[1].job or {}
            if not jobData.grade then jobData.grade = {} end
            jobData.grade.level = tonumber(jobGrade) or 0
            MySQL.update.await("UPDATE players SET job = ? WHERE citizenid = ?", { json.encode(jobData), identifier })
        end
    else
        return false
    end
    return true
end)

-- ── قراءة الوظيفة أوفلاين (getPlayerJobs) ──
exports('FwGetJobOffline', function(identifier, charId)
    if WFW.Name == 'rsgcore' then
        local result = MySQL.query.await("SELECT job FROM players WHERE citizenid = ?", { identifier })
        if result and result[1] then
            local jobData = type(result[1].job) == 'string' and json.decode(result[1].job) or result[1].job or {}
            return {
                name = jobData.name or 'unemployed',
                label = jobData.label or jobData.name or 'Unemployed',
                grade = jobData.grade and jobData.grade.level or 0,
                gradeName = jobData.grade and jobData.grade.name or '',
            }
        end
    elseif WFW.Name == 'vorp' then
        local result = MySQL.query.await("SELECT job, jobgrade, joblabel FROM characters WHERE charidentifier = ?", { tonumber(charId) })
        if result and result[1] then
            return {
                name = result[1].job or 'unemployed',
                label = result[1].joblabel or result[1].job or 'Unemployed',
                grade = result[1].jobgrade or 0,
            }
        end
    end
    return nil
end)

-- ── ضبط/إزالة وظيفة أوفلاين (setPlayerJob/removePlayerJob) ──
exports('FwSetPlayerJobOffline', function(identifier, charId, jobName, jobGrade, jobLabel)
    if WFW.Name == 'rsgcore' then
        local sharedJobs = (WFW.Core and WFW.Core.Shared and WFW.Core.Shared.Jobs) or {}
        local jobDef = sharedJobs[jobName]
        local gradeData = jobDef and jobDef.grades and jobDef.grades[tostring(jobGrade)]
        local jobObj = {
            name = jobName, label = jobDef and jobDef.label or jobName, onduty = false,
            grade = {
                level = jobGrade, name = gradeData and gradeData.name or 'Unknown',
                payment = gradeData and gradeData.payment or 0, isboss = gradeData and gradeData.isboss or false,
            },
            payment = gradeData and gradeData.payment or 0, isboss = gradeData and gradeData.isboss or false,
        }
        MySQL.update.await("UPDATE players SET job = ? WHERE citizenid = ?", { json.encode(jobObj), identifier })
        return true
    elseif WFW.Name == 'vorp' then
        MySQL.update.await("UPDATE characters SET job = ?, jobgrade = ?, joblabel = ? WHERE charidentifier = ?",
            { jobName, jobGrade, jobLabel, tonumber(charId) })
        return true
    end
    return false
end)
exports('FwRemoveJobOffline', function(charId)
    if WFW.Name == 'vorp' then
        MySQL.update.await("UPDATE characters SET job = 'unemployed', jobgrade = 0, joblabel = 'Unemployed' WHERE charidentifier = ?", { tonumber(charId) })
        return true
    end
    return false -- RSG: تُدار عبر multijob في السكربت
end)

-- ── حقول الشخصيّة أوفلاين (اسم/عمر/وصف) — فورب بـ charId، RSG بـ identifier ──
local CHARFIELD = {
    nickname    = { vorpCol = 'nickname',       rsgKey = 'nickname' },
    firstname   = { vorpCol = 'firstname',      rsgKey = 'firstname' },
    lastname    = { vorpCol = 'lastname',       rsgKey = 'lastname' },
    age         = { vorpCol = 'age',            rsgKey = 'age' },
    description = { vorpCol = 'charDescription', rsgKey = 'description' },
}
local function setCharFieldOffline(field, identifier, charId, value)
    local f = CHARFIELD[field]; if not f then return false end
    if WFW.Name == 'vorp' then
        if not charId then return false, 'character_not_found' end
        MySQL.update.await("UPDATE characters SET " .. f.vorpCol .. " = ? WHERE charidentifier = ?", { value, tonumber(charId) })
        return true
    elseif WFW.Name == 'rsgcore' then
        MySQL.update.await("UPDATE players SET charinfo = JSON_SET(charinfo, '$." .. f.rsgKey .. "', ?) WHERE citizenid = ?", { value, identifier })
        return true
    end
    return false
end
exports('FwSetNicknameOffline',    function(id, charId, v) return setCharFieldOffline('nickname', id, charId, v) end)
exports('FwSetFirstNameOffline',   function(id, charId, v) return setCharFieldOffline('firstname', id, charId, v) end)
exports('FwSetLastNameOffline',    function(id, charId, v) return setCharFieldOffline('lastname', id, charId, v) end)
exports('FwSetAgeOffline',         function(id, charId, v) return setCharFieldOffline('age', id, charId, v) end)
exports('FwSetDescriptionOffline', function(id, charId, v) return setCharFieldOffline('description', id, charId, v) end)

-- ── الديسكورد (فورب: characters.discordid) ──
exports('FwGetDiscordId', function(identifier)
    if WFW.Name ~= 'vorp' then return nil end
    local row = MySQL.single.await(
        "SELECT discordid FROM characters WHERE identifier = ? AND discordid IS NOT NULL AND discordid != '' LIMIT 1",
        { identifier })
    return row and row.discordid or nil
end)

-- ── إحصاءات لوحة القيادة ──
exports('FwGetTotalCash', function()
    if WFW.Name == 'rsgcore' then
        local r = MySQL.query.await("SELECT SUM(JSON_EXTRACT(money, '$.cash')) as total FROM players")
        return r and r[1] and r[1].total or 0
    end
    local r = MySQL.query.await("SELECT SUM(money) as total FROM characters")
    return r and r[1] and r[1].total or 0
end)
exports('FwCountCharacters', function()
    if WFW.Name == 'rsgcore' then
        local r = MySQL.query.await("SELECT COUNT(citizenid) as total FROM players")
        return r and r[1] and r[1].total or 0
    end
    local r = MySQL.query.await("SELECT COUNT(identifier) as total FROM characters")
    return r and r[1] and r[1].total or 0
end)

-- عدد الحسابات الكليّ (فورب: جدول users · RSG: players)
exports('FwCountAllCharacters', function()
    local tbl = (WFW.Name == 'rsgcore') and 'players' or 'users'
    local r = MySQL.query.await("SELECT COUNT(*) as total FROM " .. tbl)
    return r and r[1] and r[1].total or 0
end)

-- قائمة الشخصيّات (لِلوحة اللاعبين) — صفوف مُوحّدة الشكل، بلا أي علم بجدول w_admin (pac).
-- البحث الأصليّ للفريمورك (اسم/مُعرّف/discord) + extraIds اختياريّة (يمرّرها w_admin بعد بحث pac بنفسه).
exports('FwGetOfflineCharacters', function(searchTerm, limit, extraIds)
    limit = tonumber(limit) or 200
    local hasSearch = searchTerm ~= nil and searchTerm ~= ''
    local extra = (type(extraIds) == 'table' and #extraIds > 0) and extraIds or nil
    local out = {}

    if WFW.Name == 'rsgcore' then
        -- p.license = مفتاح كاش الأفاتار في RSG (GetIdentifier يُرجعه للمتصلين)؛ citizenid يبقى مفتاح الأفعال
        local q = "SELECT p.citizenid, p.license, p.charinfo, p.money, p.job, JSON_UNQUOTE(JSON_EXTRACT(p.metadata, '$.lastlogin')) as lastLogin FROM players p"
        local params = {}
        if hasSearch then
            local pat = '%' .. searchTerm .. '%'
            local conds = "p.citizenid LIKE ? OR JSON_UNQUOTE(JSON_EXTRACT(p.charinfo, '$.firstname')) LIKE ? OR JSON_UNQUOTE(JSON_EXTRACT(p.charinfo, '$.lastname')) LIKE ?"
            params = { pat, pat, pat }
            if extra then
                -- extraIds = مفاتيح كاش (license) قادمة من بحث pac في w_admin
                local ph = {}
                for _, id in ipairs(extra) do ph[#ph + 1] = '?'; params[#params + 1] = id end
                conds = conds .. " OR p.license IN (" .. table.concat(ph, ',') .. ")"
            end
            q = q .. " WHERE (" .. conds .. ") LIMIT " .. limit
        else
            q = q .. " LIMIT " .. limit
        end
        local rows = MySQL.query.await(q, params) or {}
        for _, r in ipairs(rows) do
            local charinfo = type(r.charinfo) == 'string' and json.decode(r.charinfo) or r.charinfo or {}
            local money = type(r.money) == 'string' and json.decode(r.money) or r.money or {}
            local job = type(r.job) == 'string' and json.decode(r.job) or r.job or {}
            out[#out + 1] = {
                charId = r.citizenid, identifier = r.citizenid, cacheKey = r.license or r.citizenid,
                firstName = charinfo.firstname or '', lastName = charinfo.lastname or '', nickname = charinfo.nickname or '',
                jobName = job.name or '', jobLabel = job.label or job.name or 'Unemployed', jobGrade = job.grade and job.grade.level or 0,
                cash = money.cash or 0, gold = money.bloodmoney or 0, lastLogin = r.lastLogin, discordid = '',
            }
        end
    elseif WFW.Name == 'vorp' then
        local q = "SELECT c.charIdentifier, c.firstname, c.lastname, c.job, c.jobLabel, c.jobgrade, c.money, c.gold, c.identifier, c.lastLogin, c.discordid FROM characters c"
        local params = {}
        if hasSearch then
            local pat = '%' .. searchTerm .. '%'
            local conds = "c.firstname LIKE ? OR c.lastname LIKE ? OR c.identifier LIKE ? OR c.discordid LIKE ?"
            params = { pat, pat, pat, pat }
            if extra then
                local ph = {}
                for _, id in ipairs(extra) do ph[#ph + 1] = '?'; params[#params + 1] = id end
                conds = conds .. " OR c.identifier IN (" .. table.concat(ph, ',') .. ")"
            end
            q = q .. " WHERE (" .. conds .. ") LIMIT " .. limit
        else
            q = q .. " LIMIT " .. limit
        end
        local rows = MySQL.query.await(q, params) or {}
        for _, r in ipairs(rows) do
            out[#out + 1] = {
                charId = tostring(r.charIdentifier), identifier = r.identifier, cacheKey = r.identifier,
                firstName = r.firstname or '', lastName = r.lastname or '', nickname = '',
                jobName = r.job or '', jobLabel = r.jobLabel or r.job or 'Unemployed', jobGrade = r.jobgrade or 0,
                cash = r.money or 0, gold = r.gold or 0, lastLogin = r.lastLogin, discordid = r.discordid or '',
            }
        end
    end
    return out
end)

-- شخصيّات فورب التي لها discordid (لصيانة كاش الأفاتار في w_admin؛ التصفية ضدّ pac تبقى في w_admin)
exports('FwGetCharactersWithDiscord', function(limit)
    if WFW.Name ~= 'vorp' then return {} end
    limit = tonumber(limit) or 200
    local rows = MySQL.query.await(
        "SELECT DISTINCT identifier, discordid FROM characters WHERE discordid IS NOT NULL AND discordid != '' LIMIT " .. limit) or {}
    return rows
end)

-- بيانات النواة المشتركة (RSG: Core.Shared.*) — تُعاد كجداول بيانات تعبر exports بأمان.
-- بديل عن قراءة Framework.Core.Shared مباشرةً (توابع النواة لا تعبر الحدود، لكن البيانات تعبر).
-- فورب: لا Core.Shared → تُعاد {} (فورب يحمّل العناصر/الأسلحة بمسار آخر).
exports('FwGetSharedItems', function() return (WFW.Core and WFW.Core.Shared and WFW.Core.Shared.Items) or {} end)
exports('FwGetSharedWeapons', function() return (WFW.Core and WFW.Core.Shared and WFW.Core.Shared.Weapons) or {} end)
exports('FwGetSharedJobs', function() return (WFW.Core and WFW.Core.Shared and WFW.Core.Shared.Jobs) or {} end)

-- ════════════════════════════════════════════════════════════════════════════
-- Host / backend, character rows, offline roles, bank accounts, native core calls
-- ════════════════════════════════════════════════════════════════════════════

-- column whitelist of the character table per core (no caller string reaches the SQL)
local ROW_COLUMNS = {
    rsgcore = { citizenid = 'citizenid', license = 'license', name = 'name', job = 'job', gang = 'gang' },
    vorp    = { citizenid = 'charidentifier', charidentifier = 'charidentifier', identifier = 'identifier', job = 'job', firstname = 'firstname', lastname = 'lastname' },
}

--- Character rows of the core's own table. `field` is one of citizenid / license / name /
--- job / gang (RSG-family: job and gang match the JSON column's name) or charidentifier /
--- identifier / job / firstname / lastname on VORP. Returns raw rows ({} when nothing matches).
exports('FwCharacterRows', function(field, value)
    local columns = ROW_COLUMNS[WFW.Name] or {}
    local column = columns[tostring(field or '')]
    if not column or value == nil then return {} end
    if WFW.Name == 'rsgcore' then
        if column == 'job' or column == 'gang' then
            return MySQL.query.await(('SELECT * FROM players WHERE JSON_UNQUOTE(JSON_EXTRACT(%s, "$.name")) = ?'):format(column), { tostring(value) }) or {}
        end
        return MySQL.query.await(('SELECT * FROM players WHERE %s = ?'):format(column), { value }) or {}
    elseif WFW.Name == 'vorp' then
        return MySQL.query.await(('SELECT * FROM characters WHERE %s = ?'):format(column), { value }) or {}
    end
    return {}
end)

--- Write a job / gang onto a character that may be offline. `role` is the full table the
--- core stores ({ name, label, grade = { level, name }, ... }); `expectedCurrent` (optional)
--- must be the character's current role name or nothing is written (a boss fires only his own
--- employees). An online player is updated through the core so his HUD follows.
---@return boolean
exports('FwSetOfflineRole', function(citizenid, kind, role, expectedCurrent)
    if (kind ~= 'job' and kind ~= 'gang') or type(role) ~= 'table' or not citizenid then return false end
    if WFW.Name == 'rsgcore' then
        local core = WFW.Core
        local online = core and core.Functions.GetPlayerByCitizenId and core.Functions.GetPlayerByCitizenId(citizenid)
        if online then
            local current = online.PlayerData[kind] and online.PlayerData[kind].name
            if expectedCurrent and current ~= expectedCurrent then return false end
            local grade = type(role.grade) == 'table' and role.grade.level or role.grade or 0
            if kind == 'job' then return online.Functions.SetJob(role.name, grade) ~= false end
            return online.Functions.SetGang(role.name, grade) ~= false
        end
        local affected
        if expectedCurrent then
            affected = MySQL.update.await(('UPDATE players SET %s = ? WHERE citizenid = ? AND JSON_UNQUOTE(JSON_EXTRACT(%s, "$.name")) = ?'):format(kind, kind),
                { json.encode(role), citizenid, tostring(expectedCurrent) })
        else
            affected = MySQL.update.await(('UPDATE players SET %s = ? WHERE citizenid = ?'):format(kind), { json.encode(role), citizenid })
        end
        return (affected or 0) > 0
    elseif WFW.Name == 'vorp' then
        if kind ~= 'job' then return false end
        local grade = type(role.grade) == 'table' and role.grade.level or role.grade or 0
        local affected
        if expectedCurrent then
            affected = MySQL.update.await('UPDATE characters SET job = ?, joblabel = ?, jobgrade = ? WHERE charidentifier = ? AND job = ?',
                { role.name, role.label or role.name, grade, citizenid, tostring(expectedCurrent) })
        else
            affected = MySQL.update.await('UPDATE characters SET job = ?, joblabel = ?, jobgrade = ? WHERE charidentifier = ?',
                { role.name, role.label or role.name, grade, citizenid })
        end
        return (affected or 0) > 0
    end
    return false
end)

--- The character whose bank account number this is: a player object (online) or an offline
--- player object of the core, plus `true` when it is offline (call receiver.Functions.Save()).
---@return table|nil receiver, boolean offline
exports('FwFindBankAccount', function(accountNumber)
    accountNumber = tostring(accountNumber or ''):gsub('%s', '')
    if accountNumber == '' then return nil end
    if WFW.Name == 'rsgcore' then
        local core = WFW.Core
        if not core then return nil end
        for _, id in ipairs(GetPlayers()) do
            local player = core.Functions.GetPlayer(tonumber(id))
            local info = player and player.PlayerData and player.PlayerData.charinfo
            if info and tostring(info.account or '') == accountNumber then return player, false end
        end
        local row = MySQL.single.await('SELECT citizenid FROM players WHERE JSON_UNQUOTE(JSON_EXTRACT(charinfo, "$.account")) = ?', { accountNumber })
        if row and core.Player and core.Player.GetOfflinePlayer then
            local offline = core.Player.GetOfflinePlayer(row.citizenid)
            if offline then return offline, true end
        end
    end
    return nil
end)

--- Call a function of the running core by name (Core.Functions.<fn>, Core.Player.<fn> or the
--- core resource's export <fn>), whatever the core is. Used for Login / DeleteCharacter /
--- ExploitBan on the RSG-family cores.
exports('FwNativeCoreCall', function(fn, ...)
    local core = WFW.Core
    if type(fn) ~= 'string' or not core then return nil end
    if core.Functions and core.Functions[fn] then return core.Functions[fn](...) end
    if core.Player and core.Player[fn] then return core.Player[fn](...) end
    local host = WFW.Host or (WFW.Name == 'vorp' and 'vorp_core') or (WFW.PublicName == 'qbr' and 'qbr-core') or 'rsg-core'
    local ok, result = pcall(function(...) return exports[host][fn](nil, ...) end, ...)
    if ok then return result end
    print(('^1[w_lib] FwNativeCoreCall: %s is not a function of %s (%s)^0'):format(fn, host, tostring(result)))
    return nil
end)
