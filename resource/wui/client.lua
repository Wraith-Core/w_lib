-- ============================================================
-- w_lib : جسر الواجهة
--
-- المشكلة: وحدة prompt-nui تشترط أن يكون ui_page المورد
-- هو "nui://w_lib/nui/index.html"، والمورد لا يملك إلا ui_page واحداً.
-- فأي سكربت له واجهة مخصصة (React مثلاً) لا يستطيع استخدام البرومبتات.
--
-- الحل: هذا المورد يملك ui_page ويعرض البرومبتات نيابة عن الجميع.
--
-- مبدآن في التصميم:
--   1. مقابض رقمية لا كائنات — الإكسبورت يفقد التوابع عبر حدود الموارد
--   2. أحداث لا استطلاع — الجسر يبث عند الاكتمال ولا يُسأل كل فريم
-- ============================================================

local groups = {}        -- [id] = { group = GroupClass, owner = resource, keys = {}, visible = bool }
local nextId = 0
local visibleId = nil

--- التحقق أن المجموعة موجودة وأن المستدعي يملكها
---@param id integer
---@return table|nil
local function getOwned(id)
    local entry = groups[id]
    if not entry then return nil end

    local invoker = GetInvokingResource()
    -- الاستدعاء الداخلي (من الجسر نفسه) يمر بلا مالك
    if invoker and entry.owner ~= invoker then
        print(('[w_lib] ^1%s tried to control a group owned by %s^0'):format(invoker, entry.owner))
        return nil
    end

    return entry
end

-- ============================================================
-- إنشاء وحذف المجموعات
-- ============================================================

--- إنشاء مجموعة برومبت جديدة
---@param title string عنوان المجموعة
---@param position? string 'bottom-right' افتراضياً
---@return integer id مقبض المجموعة
exports('CreateGroup', function(title, position)
    -- يُلتقط قبل أي Wait، فسياق المورد المستدعي يضيع بعد التعليق
    local owner = GetInvokingResource() or GetCurrentResourceName()

    while not w.libLoaded do Wait(50) end

    nextId = nextId + 1
    groups[nextId] = {
        group = w.promptNui.createGroup(title or '', position or 'bottom-right'),
        owner = owner,
        keys = {},     -- ترتيب المفاتيح للاستطلاع
        prompts = {},  -- [KEY] = PromptClass، نخزّنها بأنفسنا لأن الوحدة تفهرسها بالصفحة
        visible = false,
    }

    return nextId
end)

--- حذف مجموعة وتحرير مفاتيحها
---@param id integer
exports('DeleteGroup', function(id)
    local entry = getOwned(id)
    if not entry then return false end

    if entry.visible then
        -- Release the active group as well as its UI; forceHide is temporary
        -- and leaves promptNui.isDisplayed() true after the group is deleted.
        entry.group:hide()
        if visibleId == id then visibleId = nil end
    end

    groups[id] = nil
    return true
end)

-- ============================================================
-- البرومبتات
-- ============================================================

--- إضافة زر إلى مجموعة
---@param id integer
---@param key string المفتاح مثل 'E'
---@param label string النص المعروض
---@param holdTime? number|boolean مدة الضغط المطوّل، أو false
---@param page? integer رقم الصفحة
exports('AddPrompt', function(id, key, label, holdTime, page)
    local entry = getOwned(id)
    if not entry or type(key) ~= 'string' then return false end

    key = key:upper()

    local prompt = entry.group:addPrompt(key, label or '', holdTime or false, page)
    if not prompt then return false end

    if not entry.prompts[key] then
        entry.keys[#entry.keys + 1] = key
    end
    entry.prompts[key] = prompt

    return true
end)

--- تغيير نص زر
exports('SetPromptLabel', function(id, key, label)
    local entry = getOwned(id)
    if not entry then return false end

    local prompt = entry.prompts[key:upper()]
    if not prompt then return false end

    prompt:setLabel(label)
    return true
end)

--- تفعيل أو تعطيل زر
exports('SetPromptEnabled', function(id, key, enabled)
    local entry = getOwned(id)
    if not entry then return false end

    local prompt = entry.prompts[key:upper()]
    if not prompt then return false end

    prompt:setEnabled(enabled)
    return true
end)

--- إظهار أو إخفاء زر (إخفاء كامل، لا تعطيل مرئي)
exports('SetPromptVisible', function(id, key, visible)
    local entry = getOwned(id)
    if not entry then return false end

    local prompt = entry.prompts[key:upper()]
    if not prompt then return false end

    prompt:setVisible(visible)
    return true
end)

--- تغيير عنوان المجموعة
exports('SetTitle', function(id, title)
    local entry = getOwned(id)
    if not entry then return false end

    entry.group:setTitle(title)
    return true
end)

-- ============================================================
-- العرض والإخفاء
-- الوحدة تعرض مجموعة واحدة في آن، فنُخفي السابقة قبل إظهار الجديدة
-- ============================================================

exports('Display', function(id)
    local entry = getOwned(id)
    if not entry then return false end

    if visibleId and visibleId ~= id and groups[visibleId] then
        groups[visibleId].group:hide()
        groups[visibleId].visible = false
    end

    entry.group:display()
    entry.visible = true
    visibleId = id

    return true
end)

exports('Hide', function(id)
    local entry = getOwned(id)
    if not entry then return false end

    entry.group:hide()
    entry.visible = false
    if visibleId == id then visibleId = nil end

    return true
end)

--- هل المجموعة معروضة الآن؟
exports('IsVisible', function(id)
    local entry = groups[id]
    return entry ~= nil and entry.visible == true
end)

--- هل اكتمل ضغط مفتاح في المجموعة الآن؟ (للاستطلاع المباشر بدل حدث promptCompleted)
---@param id integer مقبض المجموعة
---@param key string المفتاح
---@return boolean
exports('IsCompleted', function(id, key)
    local entry = groups[id]
    if not entry or type(key) ~= 'string' then return false end
    return w.promptNui.isCompleted(entry.group.id, key:upper()) == true
end)

--- تعيين مفتاح الانتقال بين صفحات المجموعة (للبرومبتات متعدّدة الصفحات)
---@param id integer
---@param key string
exports('SetNextPageKey', function(id, key)
    local entry = groups[id]
    if not entry then return false end
    entry.group:setNextPageKey(key)
    return true
end)

-- ============================================================
-- Walk-up arbitration (w.prompt.at across resources)
-- Every resource arbitrates its own records; between resources the closest claim wins.
-- A claim is renewed every frame while the owner shows its group and lapses after 250 ms.
-- ============================================================
local walkup = { owner = nil, distance = math.huge, at = 0 }

--- May the calling resource display a walk-up prompt at this distance?
---@param distance number
---@return boolean
exports('WalkupClaim', function(distance)
    local owner = GetInvokingResource() or GetCurrentResourceName()
    local now = GetGameTimer()
    distance = tonumber(distance) or 0.0

    if walkup.owner and walkup.owner ~= owner and (now - walkup.at) < 250 and walkup.distance <= distance then
        return false
    end

    walkup.owner, walkup.distance, walkup.at = owner, distance, now
    return true
end)

exports('WalkupRelease', function()
    local owner = GetInvokingResource() or GetCurrentResourceName()
    if walkup.owner == owner then
        walkup.owner, walkup.distance, walkup.at = nil, math.huge, 0
    end
end)

-- ============================================================
-- حلقة الاستطلاع الداخلية
-- تعمل فقط حين تكون هناك مجموعة معروضة، وتبث حدثاً عند الاكتمال
-- فلا يستطلع أي سكربت خارجي شيئاً
-- ============================================================
-- ★ While one of our groups is on screen the game's own prompts are hidden that frame (the owner,
--   2026-11-11: two prompt boxes at once read as one mess). _UI_PROMPT_DISABLE_PROMPTS_THIS_FRAME, the
--   native the placer already uses (modules/placer/client.lua:115, 842). The cost: a native prompt
--   (another script's horse / wagon interaction) cannot be used while ours shows; it is back the frame
--   ours hides. `setr w_lib:hideNativePrompts false` turns this off.
local DISABLE_NATIVE_PROMPTS = 0xF1622CE88A1946FB
local hideNative = GetConvar('w_lib:hideNativePrompts', 'true') ~= 'false'

CreateThread(function()
    while true do
        local sleep = 250
        local id = visibleId
        local entry = id and groups[id]

        if entry and entry.visible then
            sleep = 0
            if hideNative then Citizen.InvokeNative(DISABLE_NATIVE_PROMPTS) end

            for i = 1, #entry.keys do
                local key = entry.keys[i]
                if w.promptNui.isCompleted(entry.group.id, key) then
                    TriggerEvent('w_lib:promptCompleted', id, key)
                end
            end
        end

        Wait(sleep)
    end
end)

-- ============================================================
-- تنظيف مجموعات أي مورد يتوقف
-- ============================================================
AddEventHandler('onClientResourceStop', function(resourceName)
    for id, entry in pairs(groups) do
        if entry.owner == resourceName then
            if entry.visible then
                entry.group:hide()
                if visibleId == id then visibleId = nil end
            end
            groups[id] = nil
        end
    end
end)


-- ============================================================
-- الإشعارات الموحّدة — RK-text3d
-- كانت الدالة منسوخة في أربعة سكربتات؛ هذه النسخة الوحيدة الآن،
-- والبقية توكِّل إليها عبر exports.
-- ============================================================
local NotifyIcons  = { success = 'tick', error = 'cross', info = 'warning' }
-- ⚠️ Monochrome, matching resource/wnotify/client.lua STYLE_COLOR — both doors must agree or the
--    same news changes colour depending on which export the caller happened to use.
local NotifyColors = { success = '#f2f2f2', error = '#f2f2f2', info = '#f2f2f2' }

--- @param title string
--- @param message string
--- @param style? string 'success' | 'error' | 'info'
--- @param duration? number مللي ثانية (افتراضي 5000)
local function Notify(title, message, style, duration)
    TriggerEvent('RK-text:send', {
        title            = title or '',
        description      = message or '',
        icon             = NotifyIcons[style] or 'warning',
        placement        = 'middle-right',
        duration         = duration or 5000,
        useBackground    = false,
        contentAlignment = 'center',
        isRTL            = true,
        titleColor       = NotifyColors[style] or '#f2f2f2',
        descriptionColor = '#f2f2f2',
    })
end

exports('Notify', Notify)

--- الوجه الشبكي — يستقبله NotifyPlayer الخادمي
RegisterNetEvent('w_lib:notify', function(title, message, style, duration)
    -- two senders share this event: NotifyPlayer(title, message, style, duration) and the
    -- ox-style table { title, description, type, duration } (txadmin.lua and lib.notify callers)
    if type(title) == 'table' then
        local data = title
        Notify(data.title, data.description or data.message, data.type or data.style, data.duration)
        return
    end
    Notify(title, message, style, duration)
end)
