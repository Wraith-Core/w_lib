-- ════════════════════════════════════════════════════════════════════════════
-- w_lib — جسر الفريمورك الشامل (fwbridge) — كشف مشترك (خادم/عميل)
--   يوحّد فورب (vorp) و RSGCore، ويكشف مرّة واحدة داخل w_lib، ثم يوفّر:
--     exports.w_lib:FwName() · FwReady() · FwInventory() · FwGetCore()
--   منقول من جسر w_admin المُثبَت ومُعمّم ليكون في المكتبة (شامل كل شي).
--   ملاحظة: يعمل داخل مورد w_lib نفسه (لا وسيط w هنا) — نعتمد النواة مباشرةً.
-- ════════════════════════════════════════════════════════════════════════════

WFW = WFW or { Name = nil, PublicName = nil, Core = nil, Inventory = nil, Ready = false }

-- QBR exposes small functions directly from qbr-core rather than a GetCoreObject
-- table. Build the tiny QB-style shape used by the unified bridge so every Fw*
-- export can keep one implementation for RSG and QBR.
local function getQbrCore()
    local api = exports['qbr-core']
    local okItems, items = pcall(function() return api:GetItems() end)
    local okJobs, jobs = pcall(function() return api:GetJobs() end)
    local okWeapons, weapons = pcall(function() return api:GetWeapons() end)

    return {
        Functions = {
            GetPlayer = function(source)
                local ok, player = pcall(function() return api:GetPlayer(source) end)
                return ok and player or nil
            end,
            GetPlayerData = function()
                local ok, player = pcall(function() return api:GetPlayerData() end)
                return ok and player or nil
            end,
        },
        Shared = {
            Items = okItems and items or {},
            Jobs = okJobs and jobs or {},
            Weapons = okWeapons and weapons or {},
        },
    }
end

-- محاولة كشف صامتة (بلا طباعة) — تُعاد حتى ينجح
local function tryDetect()
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
    return false
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
            print('^1[w_lib] fwbridge: no framework detected yet (vorp_core/rsg-core/qbr-core); detection will continue.^7')
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
