-- ════════════════════════════════════════════════════════════════════════════
-- w_lib — جسر الحقائب المركزيّ (عميل): تسمية العنصر + إغلاق الحقيبة عبر الأنظمة
-- ════════════════════════════════════════════════════════════════════════════

local NAME
local INV_ORDER = { 'w_inventory', 'rsg-inventory', 'qbr-inventory', 'vorp_inventory' }
local ALIASES = {
    w = 'w_inventory',
    ox = 'w_inventory',
    vorp = 'vorp_inventory',
    rsg = 'rsg-inventory',
    qbr = 'qbr-inventory',
}

local function normalize(name)
    name = tostring(name or 'auto'):lower():gsub('%s+', '')
    return ALIASES[name] or name
end

--- الحقيبة الفعّالة — نفس مرجع الخادم: (1) ما بثّه الخادم، (2) تثبيت يدويّ، (3) كشف محلّي بنفس الترتيب.
local function detect()
    local fromServer = GetConvar('w_lib:activeInventory', '')
    if fromServer ~= '' then
        local selected = normalize(fromServer)
        if GetResourceState(selected) == 'started' then
            NAME = selected
            return NAME
        end
    end

    -- w_inventory provides the native bag names. Prefer the actual provider
    -- locally as well, even before the replicated server decision arrives.
    if GetResourceState('w_inventory') == 'started' then
        NAME = 'w_inventory'
        return NAME
    end

    if NAME and GetResourceState(NAME) == 'started' then return NAME end
    NAME = nil

    local forced = normalize(GetConvar('w_lib:inventory', 'auto'))
    if forced ~= 'auto' and GetResourceState(forced) == 'started' then
        NAME = forced
        return NAME
    end
    for _, n in ipairs(INV_ORDER) do
        if GetResourceState(n) == 'started' then NAME = n; return NAME end
    end
    return nil
end

--- اسم الحقيبة الفعّالة (عميل) — يوازي exports.w_lib:InvName الخادميّ
exports('InvName', function() return detect() end)

--- Calls one of the active inventory's own exports by name: exports[<inventory>][fn](...).
--- The consumer names the function and never the resource, so the same line runs on
--- w_inventory, vorp_inventory or rsg-inventory. nil (and false as the second value) when
--- no inventory is up or it has no such export; the export's own return values otherwise.
exports('InvCall', function(fn, ...)
    local n = detect()
    if not n or type(fn) ~= 'string' then return nil, false end
    local target = exports[n]
    local ok, a, b, c, d = pcall(function(...) return target[fn](target, ...) end, ...)
    if not ok then return nil, false end
    return a, b, c, d
end)

--- The inventory's own export only (never the bridge's adapters), by name.
exports('InvNativeCall', function(fn, ...)
    local n = detect()
    if not n or type(fn) ~= 'string' then return nil, false end
    local target = exports[n]
    local ok, a, b, c, d = pcall(function(...) return target[fn](target, ...) end, ...)
    if not ok then return nil, false end
    return a, b, c, d
end)

--- تسمية عنصر للعرض (fallback: الاسم نفسه)
exports('InvItemLabel', function(item)
    if not item then return 'Unknown' end
    if detect() == 'w_inventory' then
        local d = exports.w_inventory:Items(item)
        if d and d.label then return d.label end
    end
    return item
end)

--- إغلاق واجهة الحقيبة (تحرير التركيز/السكرول)
exports('InvClose', function()
    local n = detect()
    if n == 'w_inventory' then
        pcall(function() exports.w_inventory:closeInventory() end)
    elseif n == 'vorp_inventory' then
        pcall(function() TriggerEvent('vorp_inventory:closeInventory') end)
    elseif n == 'rsg-inventory' then
        pcall(function() TriggerEvent('rsg-inventory:client:closeinv') end)
    elseif n == 'qbr-inventory' then
        pcall(function() TriggerEvent('qbr-inventory:client:closeinv') end)
    end
end)
