w.createModule("rawKeys")
w.file.load("raw-keys.vk_qwerty")
w.file.load("raw-keys.vk_azerty")

--[[
    w_lib -- rawKeys

    المفاتيح هنا طريقان لا طريق واحد، ولكلّ منهما معنى مختلف:

      bind()    فعلٌ له اسم → RegisterKeyMapping → يظهر في إعدادات اللاعب ويُعاد ربطه.
      listen()  مراقبة مفتاح خام → RegisterRawKeymap → صامتة، لا أثر لها في القائمة.

    والعطل القديم الذي أُصلح ولا يجوز أن يعود:

    1. RAW KEYMAPS COLLIDE ACROSS RESOURCES, SILENTLY.
       The old implementation named its keymap `w_lib:rawKeys:<vk>` -- one name for
       every resource on the server. The first resource to claim TAB owned it; every
       later one got «already has a keymap bound by another resource», yet listen()
       still returned an id and still marked the key registered. The resource believed
       it was bound and never received a press. Names here are prefixed with the
       consuming resource, so two resources can watch one key without a fight.

    2. A RAW KEY BELONGS TO THE SCRIPT; A KEYMAPPING BELONGS TO THE PLAYER.
       RegisterKeyMapping puts the binding in the player's hands and remembers their
       choice. What a config sets is only a default.

    The public surface is unchanged, so existing callers need no edit.
]]

local nextListenerId = 0

local alias = {
    backspace = "back",
    enter = "return",
    ctrl = "control",
    -- ⚠️ hanja → kanji, not the other way round. Every entry in this table maps a name a
    --    CALLER might write to the name vk_qwerty actually uses, and vk_qwerty has KANJI
    --    (0x19) and no HANJA. Inverted, it turned the one real name into a missing one:
    --    prompt-nui listens to all 174 VKs, normalise(0x19) came back "kanji", the alias
    --    rewrote it to "hanja", getVK found nothing, and every resource drawing a NUI
    --    prompt printed `rawKeys: unknown key  hanja` on load.
    hanja = "kanji",
    esc = "escape",
    pageup = "prior",
    pagedown = "next",
    numpad_multiply = "multiply",
    numpad_add = "add",
    numpad_subtract = "subtract",
    numpad_decimal = "decimal",
    ["l shift"] = "lshift",
    ["r shift"] = "rshift",
    ["l ctrl"] = "lcontrol",
    ["r ctrl"] = "rcontrol",
    ["l alt"] = "lmenu",
    ["r alt"] = "rmenu",
    [";"] = "oem_1",
    ["+"] = "oem_plus",
    [","] = "oem_comma",
    ["-"] = "oem_minus",
    ["/"] = "oem_2",
    ["`"] = "oem_3",
    ["["] = "oem_4",
    ["\\"] = "oem_5",
    ["]"] = "oem_6",
    ["'"] = "oem_7",
}
local reverseAlias = {}
for a, key in pairs(alias) do reverseAlias[key] = a end

local events = {}     -- key name -> { { id = number, callback = fun(pressed) }, ... }
local keymapped = {}  -- key name -> true, one RegisterKeyMapping per key per resource

local keyboard_layout = string.lower(GetConvar("w_lib:keyboard_layout", "qwerty"))

local reverseMap = {}
local reverseMapQwerty = {}

for key, vk in pairs(vk_qwerty) do
    reverseMapQwerty[vk] = key:lower()
end

local function generateReverseMap()
    reverseMap = {}
    local list = table.clone(vk_qwerty)
    if keyboard_layout == "azerty" then
        table.merge(list, vk_azerty)
    end

    for key, vk in pairs(list) do
        reverseMap[vk] = key:lower()
    end
end
generateReverseMap()

AddConvarChangeListener("w_lib:keyboard_layout", function()
    keyboard_layout = string.lower(GetConvar("w_lib:keyboard_layout", "qwerty"))
    generateReverseMap()
end)

--- Normalises anything a caller may pass (name, alias, numeric VK) to one key name.
local function normalise(key)
    if type(key) == "number" then
        key = reverseMapQwerty[key]
        if not key then return nil end
    end
    key = tostring(key):lower()
    return alias[key] or key
end

local function dispatch(key, pressed)
    local list = events[key]
    if not list then return end
    -- Walk backwards: a callback is free to remove itself mid-dispatch.
    for i = #list, 1, -1 do
        local listener = list[i]
        if listener then
            local ok, err = pcall(listener.callback, pressed)
            if not ok then
                eprint(("rawKeys callback error [key %s, listener %d]: %s")
                    :format(key, listener.id, tostring(err)))
            end
        end
    end
end

--[[
    ★ listen() تراقب مفتاحاً خاماً، ولا تصنع ارتباطاً في قائمة إعدادات اللاعب.

      جرّبنا بناءها على RegisterKeyMapping فانفجرت القائمة: modules/prompt-nui/client.lua:103
      ينادي getAllVK() ثمّ listen() لـكُلّ مفتاح في اللوحة — مئة وأربعة وسبعون مفتاحاً —
      ليعرف أيّها ضُغط في برومبت NUI. فظهرت للاعب مئة وسبعون سطراً
      مثل «w_lib: OEM_COMMA» و«w_lib: F17» في إعداداته.

      والسبب معنويّ لا عرضيّ: مراقبة مفتاح ليست «إجراءً يربطه اللاعب». ما يستحقّ
      سطراً في قائمة المفاتيح هو فعلٌ له اسم — «Open weapon wheel» — وذلك عمل bind().

      فالتقسيم النهائيّ: listen() خامٌ صامت، bind() فعلٌ مرئيّ قابل لإعادة الربط.

    وما زال عطل التصادم القديم مُصلَحاً: الاسم مسبوق باسم المورد، فلا يحجز موردٌ
    مفتاحاً على البقيّة كما كان يحدث مع `w_lib:rawKeys:<vk>`.
]]
local function ensureKeymap(key)
    if keymapped[key] then return true end

    local vk = w.rawKeys.getVK(key)
    if not vk then return eprint("rawKeys: unknown key", key) end

    RegisterRawKeymap(
        ("%s:rawkey:%s"):format(w.resourceName, key),
        function() dispatch(key, true) end,
        function() dispatch(key, false) end,
        vk, true
    )

    keymapped[key] = true
    return true
end

--- Registers a listener for a PHYSICAL key. The callback receives `true` on press and
--- `false` on release. This is raw watching: the player cannot rebind it and it does not
--- appear in their key-bindings screen. For a named, rebindable action use bind().
--- @param key string|number key name ("A", "F1", "TAB"), an alias, or a numeric VK code
--- @param callback fun(pressed: boolean)
--- @return integer? id identifier for removeListener
function w.rawKeys.listen(key, callback)
    local name = normalise(key)
    if not name then return eprint("invalid vk key code") end

    if not ensureKeymap(name) then return end

    nextListenerId = nextListenerId + 1
    local id = nextListenerId

    events[name] = events[name] or {}
    table.insert(events[name], { id = id, callback = callback })

    return id
end

--- Removes all listeners for a key.
---@deprecated since v2.9.0. Use w.rawKeys.removeListener instead
--- @param key string|number
function w.rawKeys.remove(key)
    local name = normalise(key)
    if not name then return eprint("invalid vk key code") end
    events[name] = nil
end

--- Removes one listener by its id.
---@param id integer
---@return boolean
function w.rawKeys.removeListener(id)
    if not id then return false end
    for _, listeners in pairs(events) do
        for l = 1, #listeners do
            if listeners[l].id == id then
                table.remove(listeners, l)
                return true
            end
        end
    end
    return false
end

--- Key name for a VK code, honouring the configured keyboard layout.
function w.rawKeys.getKeyFromVK(vk)
    return reverseMap[vk]
end

--- VK code for a key name or alias.
--- Callers reached for this and got nil, because only imports/rawKeys defined it while
--- consumers were calling it on w.rawKeys -- w_hud and w_wheel both bailed out of binding
--- their wheel key because of that. It is defined here now.
---@param key string|number
---@return integer?
function w.rawKeys.getVK(key)
    if type(key) == "number" then return key end
    local name = normalise(key)
    if not name then return nil end
    for k, vk in pairs(vk_qwerty) do
        if k:lower() == name then return vk end
    end
    return nil
end

function w.rawKeys.getAliasFromStandardKey(key)
    key = key:lower()
    return reverseAlias[key] or key
end

local vks
function w.rawKeys.getAllVK()
    if vks then return vks end
    vks = {}
    for _, vk in pairs(vk_qwerty) do
        vks[#vks + 1] = vk
    end
    return vks
end

-----------------------------------------------------------------------------------------------
-- Named bindings
-----------------------------------------------------------------------------------------------
-- listen() is keyed by a KEY and names the command for you. bind() is keyed by a NAME you
-- choose, which is what you want when the entry should read as an action in the player's
-- settings ("Handcraft menu") rather than as a bare letter.

local binds = {}

--- Registers a rebindable key under a name you choose.
---@param data { name: string, description?: string, defaultKey?: string, defaultMapper?: string, onPressed?: fun(self), onReleased?: fun(self), disabled?: boolean, secondaryKey?: string }
---@return table? keybind (see lib.addKeybind -- CKeybind)
function w.rawKeys.bind(data)
    if type(data) ~= "table" or type(data.name) ~= "string" or data.name == "" then
        return eprint("w.rawKeys.bind: data.name (string) is required")
    end

    if binds[data.name] then
        eprint(("w.rawKeys.bind: \"%s\" is already bound in this resource"):format(data.name))
        return binds[data.name]
    end

    if not (lib and lib.addKeybind) then
        return eprint("w.rawKeys.bind: lib.addKeybind is unavailable -- is @w_lib/init.lua loaded first?")
    end

    data.description = data.description or data.name
    data.defaultMapper = data.defaultMapper or "keyboard"

    local keybind = lib.addKeybind(data)
    binds[data.name] = keybind
    return keybind
end

--- The keybind registered under `name` in this resource, if any.
---@param name string
---@return table? keybind
function w.rawKeys.getBind(name)
    return binds[name]
end
