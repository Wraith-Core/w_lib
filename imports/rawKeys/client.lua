--[[
    w_lib — rawKeys (lib.rawKeys)

    طريقان لا طريق واحد، ولكلّ معنى:

      lib.addKeybind   فعلٌ له اسم → RegisterKeyMapping → يظهر في إعدادات اللاعب.
      listen()         مراقبة خام → RegisterRawKeymap → صامتة، لا أثر في القائمة.

    وسبب الفصل عمليّ: prompt-nui ينادي listen لكلّ مفتاح في اللوحة ليعرف أيّها ضُغط،
    فتسجيلها كارتباطات كان يملأ شاشة مفاتيح اللاعب بمئة وسبعين سطراً بلا معنى.

    والعطل القديم مُصلَح: كانت الأسماء "w_lib:rawKeys:<vk>" — اسم واحد لكل السيرفر،
    فأوّل ريسورس يحجز المفتاح يملكه والباقي يظنّ أنّه نجح ولا تصله ضغطة. الاسم الآن
    مسبوق باسم المورد.
]]

-- الوحدة محمّلة؟ لا داعي لتطبيق ثانٍ — نفس الجدول يخدم lib.rawKeys و w.rawKeys،
-- وبذلك يستحيل أن يسجّل الاثنان أمرين لنفس المفتاح في ريسورس واحد.
if w and w.rawKeys and type(w.rawKeys.listen) == 'function' then
    return w.rawKeys
end

-- خريطة أسماء المفاتيح → Windows Virtual-Key codes
local VK = {}
do
    -- الحروف A..Z = 0x41..0x5A
    for i = 0, 25 do VK[string.char(65 + i)] = 0x41 + i end
    -- الأرقام 0..9 = 0x30..0x39
    for i = 0, 9 do VK[tostring(i)] = 0x30 + i end
    -- F1..F12 = 0x70..0x7B
    for i = 1, 12 do VK['F' .. i] = 0x6F + i end
    -- مفاتيح خاصّة
    VK.TAB = 0x09; VK.ENTER = 0x0D; VK.RETURN = 0x0D; VK.ESC = 0x1B; VK.ESCAPE = 0x1B
    VK.SPACE = 0x20; VK.BACKSPACE = 0x08; VK.BACK = 0x08
    VK.SHIFT = 0x10; VK.CTRL = 0x11; VK.CONTROL = 0x11; VK.ALT = 0x12
    VK.LEFT = 0x25; VK.UP = 0x26; VK.RIGHT = 0x27; VK.DOWN = 0x28
    VK.DELETE = 0x2E; VK.INSERT = 0x2D; VK.HOME = 0x24; VK['END'] = 0x23
    VK.PAGEUP = 0x21; VK.PAGEDOWN = 0x22; VK.CAPSLOCK = 0x14
    VK.NUMPAD0 = 0x60; VK.NUMPAD1 = 0x61; VK.NUMPAD2 = 0x62; VK.NUMPAD3 = 0x63; VK.NUMPAD4 = 0x64
    VK.NUMPAD5 = 0x65; VK.NUMPAD6 = 0x66; VK.NUMPAD7 = 0x67; VK.NUMPAD8 = 0x68; VK.NUMPAD9 = 0x69
end

-- أسماء يقبلها RegisterKeyMapping. ENTER/PAGEUP ليست منها، فتُترجم.
local keyMappingName = {
    ENTER = 'RETURN', ESC = 'ESCAPE', BACKSPACE = 'BACK',
    PAGEUP = 'PRIOR', PAGEDOWN = 'NEXT', CTRL = 'CONTROL',
}

--- اسم المفتاح من رمزه (للرسائل التشخيصيّة وللأسماء)
local function vkName(vk)
    for name, code in pairs(VK) do
        if code == vk then return name end
    end
    return nil
end

--- أيّ مُدخَل (اسم أو رمز) → اسم مفتاح موحّد بحروف كبيرة
local function resolveName(key)
    if type(key) == 'number' then return vkName(key) end
    local name = tostring(key):upper()
    return VK[name] and name or nil
end

local rawKeys = {}
local events = {}     -- name -> { { id = number, cb = function }, ... }
local keymapped = {}  -- name -> true (أمر مسجَّل لهذا المفتاح)
local nextId = 0

local function dispatch(name, pressed)
    local list = events[name]
    if not list then return end
    for i = #list, 1, -1 do
        local listener = list[i]
        if listener then
            local ok, err = pcall(listener.cb, pressed)
            if not ok and lib and lib.print then
                lib.print.error(('rawKeys cb error [مفتاح %s · مستمع %d]: %s')
                    :format(name, listener.id, tostring(err)))
            end
        end
    end
end

--[[
    ★ خريطة خامة لا ارتباط في إعدادات اللاعب.

    listen() تُنادى لمفاتيح كثيرة دفعةً واحدة (prompt-nui يراقب اللوحة كلّها)،
    فتسجيلها كارتباطات يملأ شاشة المفاتيح بمئات الأسطر التي لا تعني للاعب شيئاً.
    الارتباط للأفعال ذات الأسماء وحدها — وتلك تمرّ بـlib.addKeybind مباشرةً.

    والاسم مسبوق باسم المورد، فلا يحجز موردٌ مفتاحاً على البقيّة.
]]
local function ensureKeymap(name)
    if keymapped[name] then return true end

    local vk = VK[name]
    if not vk then return false end

    RegisterRawKeymap(
        ('%s:rawkey:%s'):format(GetCurrentResourceName(), name:lower()),
        function() dispatch(name, true) end,
        function() dispatch(name, false) end,
        vk, true
    )

    keymapped[name] = true
    return true
end

--- تسجيل مستمع لمفتاح فيزيائيّ. cb تُستدعى بـ true عند الضغط و false عند الإفلات.
--- مراقبة خامة: اللاعب لا يعيد ربطها ولا تظهر في إعداداته. للفعل المسمّى: lib.addKeybind.
---@param key string|number اسم المفتاح ("I", "TAB", "1"...) أو VK رقميّ
---@param callback fun(pressed: boolean)
---@return number? id معرّف المستمع (لإزالته لاحقًا)
function rawKeys.listen(key, callback)
    local name = resolveName(key)
    if not name then
        if lib and lib.print then lib.print.warn(('rawKeys: unknown key "%s"'):format(tostring(key))) end
        return
    end

    if not ensureKeymap(name) then return end

    nextId = nextId + 1
    local id = nextId

    events[name] = events[name] or {}
    events[name][#events[name] + 1] = { id = id, cb = callback }

    return id
end

--- إزالة مستمع بمعرّفه.
---@param id number
---@return boolean
function rawKeys.removeListener(id)
    if not id then return false end
    for _, list in pairs(events) do
        for i = 1, #list do
            if list[i].id == id then
                table.remove(list, i)
                return true
            end
        end
    end
    return false
end

--- VK لاسم مفتاح.
function rawKeys.getVK(key)
    if type(key) == 'number' then return key end
    return VK[tostring(key):upper()]
end

return rawKeys
