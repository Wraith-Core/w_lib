-- ════════════════════════════════════════════════════════════════════════════
-- w_lib — مساعدات الإطار المركزيّة (خادم)
--   تُغطّي فجوات API الخاصّة بكل نظام (فورب/RSG/QBR/redemrp) التي لا يوحّدها w،
--   فتستدعيها سكربتاتنا عبر exports.w_lib بدل نداء الإطار مباشرةً.
-- ملاحظة: نستخدم w.framework (نواة w_lib فيها w، لا وسيط w المستهلِك).
-- ════════════════════════════════════════════════════════════════════════════

--- مجموعة اللاعب (صلاحية) عبر كل الأنظمة.
--- فورب: مجموعة الحساب (users.group) أولًا — لأن w يكشف مجموعة الشخصيّة فقط
--- (تبقى 'user' غالبًا). ثم redemrp وغيره. fallback: مجموعة الشخصيّة.
---@param source integer
---@return string|nil
local function getPlayerGroup(source)
    local user = w.framework:getUser(source)
    if not user then return nil end

    if user.getGroup then
        local group = user:getGroup()
        if group then return group end
    end

    local framework = w.framework:get()
    local data = user.data
    if not data then return nil end

    if framework == 'vorp' then
        local ok, core = pcall(function() return exports.vorp_core:GetCore() end)
        if ok and core then
            local coreUser = core.getUser(source)
            local accountGroup = coreUser and coreUser.getGroup
            if type(accountGroup) == 'string' and accountGroup ~= '' and accountGroup ~= 'user' then
                return accountGroup
            end
        end
        return data.group
    elseif framework == 'redemrp_2023' then
        if data.GetGroup then return data.GetGroup() end
        return data.group
    elseif framework == 'redemrp_old' and data.getGroup then
        return data.getGroup()
    end

    return nil
end

exports('GetPlayerGroup', getPlayerGroup)

-- ── الصلاحيات (عبر كل الأنظمة) ──────────────────────────────────────────────
-- مجموعات تُعدّ إداريّة (fallback حين لا يوفّر الإطار HasPermission)
local adminGroups = { admin = true, superadmin = true, owner = true, god = true }
-- أطر توفّر دالة HasPermission جاهزة (معرّفات كاشف w)
local permissionCores = { rsg = 'rsg-core', rsg_v2 = 'rsg-core', qr = 'qr-core' }

--- هل يملك اللاعب صلاحية مجموعة معيّنة؟ (يسأل الإطار أولاً ثم يقارن المجموعة)
---@param source integer
---@param group string
---@return boolean
local function hasPermission(source, group)
    local framework = w.framework:get()

    local core = permissionCores[framework]
    if core then
        local ok, res = pcall(function()
            return exports[core]:GetCoreObject().Functions.HasPermission(source, group)
        end)
        return ok and res == true
    end

    if framework == 'qbr' then
        local ok, res = pcall(function() return exports['qbr-core']:HasPermission(source, group) end)
        return ok and res == true
    end

    local playerGroup = getPlayerGroup(source)
    if not playerGroup then return false end
    if playerGroup == group then return true end
    -- الأدمن يغطّي أي مجموعة إداريّة أخرى
    return adminGroups[group] == true and adminGroups[playerGroup] == true
end
exports('HasPermission', hasPermission)

--- هل اللاعب أدمن؟ صلاحية 'admin' في الإطار، أو مبدأ ACE 'command'.
---@param source integer
---@return boolean
local function isAdmin(source)
    if not source then return false end
    if hasPermission(source, 'admin') then return true end
    return IsPlayerAceAllowed(source, 'command') and true or false
end
exports('IsAdmin', isAdmin)
