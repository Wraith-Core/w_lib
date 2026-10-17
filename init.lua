---@meta
--[[
    https://github.com/overextended/ox_lib

    This file is licensed under LGPL-3.0 or higher <https://www.gnu.org/licenses/lgpl-3.0.en.html>

    Copyright © 2025 Linden <https://github.com/thelindat>
]]

if not _VERSION:find('5.4') then
    error('Lua 5.4 must be enabled in the resource manifest!', 2)
end

local resourceName = GetCurrentResourceName()
local w_lib = 'w_lib'

-- Some people have decided to load this file as part of w_lib's fxmanifest?
if resourceName == w_lib then return end

if lib and lib.name == w_lib then
    error(("Cannot load w_lib more than once.\n\tRemove any duplicate entries from '@%s/fxmanifest.lua'"):format(resourceName))
end

local export = exports[w_lib]

if GetResourceState(w_lib) ~= 'started' then
    error('^1w_lib must be started before this resource.^0', 0)
end

local status = export.hasLoaded()

if status ~= true then error(status, 2) end

-- Ignore invalid types during msgpack.pack (e.g. userdata)
msgpack.setoption('ignore_invalid', true)

-----------------------------------------------------------------------------------------------
-- Module
-----------------------------------------------------------------------------------------------

local LoadResourceFile = LoadResourceFile
local context = IsDuplicityVersion() and 'server' or 'client'

function noop() end

-- ══════════════════════════════════════════════════════════════════════════
-- Client script errors -> w_logs (w_logs 1.2.0, w_logs/docs/client-error-hook.md)
--   The runtime catches a client thread's / handler's error itself and only prints it
--   (citizen scheduler.lua: CreateThread / SetTimeout are native, event handlers run in
--   Citizen.CreateThreadNow, NUI callbacks are pcall'd). The function handed to each is wrapped:
--   the error is printed exactly as before, and a short report goes to w_logs (its room
--   'أخطاء-العميل'): the same error once a minute, 5 reports a minute per resource at most.
--   Client only. w_lib's own resource is not covered (this file returns early inside w_lib).
-- ══════════════════════════════════════════════════════════════════════════
if context == 'client' and not rawget(_ENV, 'WErrorHook') then
    local SAME_MS, PER_MINUTE, MAX_TEXT, MAX_TRACE, MAX_FRAMES = 60000, 5, 400, 1200, 12

    WErrorHook = true

    local RESOURCE    = GetCurrentResourceName()
    local SELF_SOURCE = debug.getinfo(1, 'S').source
    local sentAt, sentCount, minuteAt, minuteCount = {}, 0, 0, 0

    local function frames()
        local out = {}
        for level = 2, 60 do
            local info = debug.getinfo(level, 'Sln')
            if not info then break end
            local src = info.source or ''
            if src:sub(1, 1) == '@' and src ~= SELF_SOURCE and src:sub(1, 10) ~= '@citizen:/' then
                out[#out + 1] = ('> %s (%s:%d)'):format(info.name or '[global chunk]', src:sub(2), info.currentline or 0)
                if #out >= MAX_FRAMES then break end
            end
        end
        return table.concat(out, '\n')
    end

    local function report(err)
        pcall(function()
            local text, trace = tostring(err), frames()
            Citizen.Trace(('^1SCRIPT ERROR: %s^7\n%s\n'):format(text, trace))

            if GetResourceState('w_logs') ~= 'started' then return end
            local now, key = GetGameTimer(), text:sub(1, 200)
            if sentAt[key] and now - sentAt[key] < SAME_MS then return end
            if now - minuteAt >= 60000 then minuteAt, minuteCount = now, 0 end
            if minuteCount >= PER_MINUTE then return end
            minuteCount = minuteCount + 1

            if sentCount >= 50 then sentAt, sentCount = {}, 0 end
            if not sentAt[key] then sentCount = sentCount + 1 end
            sentAt[key] = now

            TriggerServerEvent('w_logs:server:clientError', {
                resource = RESOURCE,
                message  = text:sub(1, MAX_TEXT),
                trace    = trace:sub(1, MAX_TRACE),
            })
        end)
        return err
    end

    local function pass(ok, ...)
        if ok then return ... end
    end

    local function guard(fn)
        if type(fn) ~= 'function' then return fn end
        return function(...) return pass(xpcall(fn, report, ...)) end
    end

    local function wrapArg(original, index)
        if type(original) ~= 'function' then return original end
        return function(...)
            local args = table.pack(...)
            args[index] = guard(args[index])
            return original(table.unpack(args, 1, args.n))
        end
    end

    Citizen.CreateThread    = wrapArg(Citizen.CreateThread, 1)
    Citizen.CreateThreadNow = wrapArg(Citizen.CreateThreadNow, 1)
    Citizen.SetTimeout      = wrapArg(Citizen.SetTimeout, 2)
    CreateThread, SetTimeout = Citizen.CreateThread, Citizen.SetTimeout
    RegisterCommand     = wrapArg(RegisterCommand, 2)
    RegisterNUICallback = wrapArg(RegisterNUICallback, 2)
    RegisterNuiCallback = wrapArg(RegisterNuiCallback, 2)
end

local function loadModule(self, module)
    local dir = ('imports/%s'):format(module)
    local chunk = LoadResourceFile(w_lib, ('%s/%s.lua'):format(dir, context))
    local shared = LoadResourceFile(w_lib, ('%s/shared.lua'):format(dir))

    if shared then
        chunk = (chunk and ('%s\n%s'):format(shared, chunk)) or shared
    end

    if chunk then
        local fn, err = load(chunk, ('@@w_lib/imports/%s/%s.lua'):format(module, context))

        if not fn or err then
            if shared then
                lib.print.warn(("An error occurred when importing '@w_lib/imports/%s'.\nThis is likely caused by improperly updating w_lib.\n%s'")
                    :format(module, err))
                fn, err = load(shared, ('@@w_lib/imports/%s/shared.lua'):format(module))
            end

            if not fn or err then
                return error(('\n^1Error importing module (%s): %s^0'):format(dir, err), 3)
            end
        end

        local result = fn()
        self[module] = result or noop
        return self[module]
    end
end

-----------------------------------------------------------------------------------------------
-- API
-----------------------------------------------------------------------------------------------

local function call(self, index, ...)
    local module = rawget(self, index)

    if not module then
        self[index] = noop
        module = loadModule(self, index)

        if not module then
            local function method(...)
                return export[index](nil, ...)
            end

            if not ... then
                self[index] = method
            end

            return method
        end
    end

    return module
end

local lib = setmetatable({
    name = w_lib,
    context = context,
}, {
    __index = call,
    __call = call,
})

local intervals = {}
--- Dream of a world where this PR gets accepted.
---@param callback function | number
---@param interval? number
---@param ... any
function SetInterval(callback, interval, ...)
    interval = interval or 0

    if type(interval) ~= 'number' then
        return error(('Interval must be a number. Received %s'):format(json.encode(interval --[[@as unknown]])))
    end

    local cbType = type(callback)

    if cbType == 'number' and intervals[callback] then
        intervals[callback] = interval or 0
        return
    end

    if cbType ~= 'function' then
        return error(('Callback must be a function. Received %s'):format(cbType))
    end

    local args, id = { ... }

    Citizen.CreateThreadNow(function(ref)
        id = ref
        intervals[id] = interval or 0
        repeat
            interval = intervals[id]
            Wait(interval)

            if interval < 0 then break end
            callback(table.unpack(args))
        until false
        intervals[id] = nil
    end)

    return id
end

---@param id number
function ClearInterval(id)
    if type(id) ~= 'number' then
        return error(('Interval id must be a number. Received %s'):format(json.encode(id --[[@as unknown]])))
    end

    if not intervals[id] then
        return error(('No interval exists with id %s'):format(id))
    end

    intervals[id] = -1
end

--[[
    lua language server doesn't support generics when using @overload
    see https://github.com/LuaLS/lua-language-server/issues/723
    this function stub allows the following to work

    local key = cache('key', function() return 'abc' end) -- fff: 'abc'
    local game = cache.game -- game: string
]]

---@generic T
---@param key string
---@param func fun(...: any): T
---@param timeout? number
---@return T
---Caches the result of a function, optionally clearing it after timeout ms.
function cache(key, func, timeout) end

local cacheEvents = {}

local cache = setmetatable({ game = GetGameName() --[[@as 'fxserver' | 'fivem' | 'redm']], resource = resourceName }, {
    __index = function(self, key)
        cacheEvents[key] = {}

        AddEventHandler(('w_lib:cache:%s'):format(key), function(value)
            local oldValue = self[key]
            local events = cacheEvents[key]

            for i = 1, #events do
                Citizen.CreateThreadNow(function()
                    events[i](value, oldValue)
                end)
            end

            self[key] = value
        end)

        return rawset(self, key, export.cache(nil, key) or false)[key]
    end,

    __call = function(self, key, func, timeout)
        local value = rawget(self, key)

        if value == nil then
            value = func()

            rawset(self, key, value)

            if timeout then SetTimeout(timeout, function() self[key] = nil end) end
        end

        return value
    end,
})

function lib.onCache(key, cb)
    if not cacheEvents[key] then
        getmetatable(cache).__index(cache, key)
    end

    table.insert(cacheEvents[key], cb)
end

_ENV.lib = lib
_ENV.cache = cache
_ENV.require = lib.require

-- ══════════════════════════════════════════════════════════════════════════
-- w_lib — واجهة العلامة الموحّدة `w`
--   w = كل وحدات w_lib (lib) + cache + rawKeys + DataView.
--   نُبقي lib / cache / DataView عالميّة أيضًا للتوافق.
-- ══════════════════════════════════════════════════════════════════════════
lib.cache = cache
if context == 'client' then
    local _rk = lib.rawKeys  -- تحميل مبكر لوحدة raw-keys (client فقط)
end
--- جدول الوحدات (من w_init.lua) يحمل العلامة libLoaded؛ نواة w_lib لا تحملها.
--  نميّز بها بينهما فلا ندوس على جدول الوحدات إن كان محمّلًا مسبقًا (داخل w_lib نفسه).
local function moduleLayerLoaded()
    return type(w) == 'table' and rawget(w, 'libLoaded') ~= nil
end

local _dv = lib.dataview     -- تحميل مبكر يضبط _ENV.DataView العامّ
if not moduleLayerLoaded() then
    _ENV.w = lib
end

-- تحميل امتدادات w_lib العامّة مبكّرًا (قبل طبقة التوافق في نهاية الملفّ)
-- حتى تتوفّر وظائف table/math/string وواجهة locale الموحّدة.
-- تحميلها قبل w يجعل w يفوز عند تعارض الاسم (map/merge/round/clamp/lerp) كما هو مقصود.
pcall(function() return lib.table end)
pcall(function() return lib.string end)
pcall(function() return lib.math end)
pcall(function() return lib.locale end)

local notifyEvent = ('__w_notify_%s'):format(cache.resource)

if context == 'client' then
    RegisterNetEvent(notifyEvent, function(data)
        if locale then
            if data.title then
                data.title = locale(data.title) or data.title
            end

            if data.description then
                data.description = locale(data.description) or data.description
            end
        end

        return export:notify(data)
    end)

    cache.playerId = PlayerId()
    cache.serverId = GetPlayerServerId(cache.playerId)

    -- ══════════════════════════════════════════════════════════════════════
    -- ★ The built app asks ITS OWN resource, not w_lib.
    --
    --   fetchNui() in web/build resolves GetParentResourceName() -- the resource that owns
    --   the frame. Under `ui_page 'nui://w_lib/web/build/index.html'` that resource is the
    --   consumer, so the app's two startup calls never reach w_lib's handlers in
    --   resource/client.lua (getConfig) and resource/locale/client.lua (init). Both 404:
    --       [w_lib] fetchNui('init') on resource 'w_legal': HTTP 404 Not Found
    --   and the frame keeps the defaults it was built with -- ui.* labels empty and dir=ltr,
    --   which is a w.promptNui drawn left-to-right with unlabelled buttons on an Arabic
    --   server. fetchNui returns null rather than throwing, so nothing else reported it.
    --
    --   Registering the same two here answers them inside the consumer's own frame. The
    --   locale file is w_lib's (these are the library's UI strings, not the resource's), and
    --   the key comes from exports.w_lib:getLocaleKey() so this frame follows a /w_lib
    --   language change exactly like w_lib's own.
    --
    -- ⚠️ Scoped to consumers that actually mount the shell. A resource with no ui_page, or
    --    with an interface of its own, gets nothing: otherwise w_lib:setLocale would fire a
    --    SendNUIMessage at a frame that does not exist --
    --        SEND_NUI_MESSAGE: resource X has no UI frame
    --    -- the same noise inverted, and its own 'init' callback would be shadowed by ours.
    -- ══════════════════════════════════════════════════════════════════════
    local uiPage = GetResourceMetadata(cache.resource, 'ui_page', 0)

    if uiPage and uiPage:find('w_lib/web/build', 1, true) then
        RegisterNUICallback('getConfig', function(_, cb)
            cb({
                primaryColor = GetConvar('w_lib:primaryColor', 'wraith'),
                primaryShade = GetConvarInt('w_lib:primaryShade', 1)
            })
        end)

        local function sendUiLocale(key)
            local file = LoadResourceFile(w_lib, ('locales/%s.json'):format(key))
                or LoadResourceFile(w_lib, 'locales/en.json')

            SendNUIMessage({
                action = 'setLocale',
                data = file and json.decode(file) or {}
            })
        end

        RegisterNUICallback('init', function(_, cb)
            cb(1)

            local ok, key = pcall(function() return lib.getLocaleKey() end)
            sendUiLocale(ok and key or 'en')
        end)

        AddEventHandler('w_lib:setLocale', sendUiLocale)
    end
else
    ---`server`\
    ---Trigger a notification on the target playerId from the server.\
    ---If locales are loaded, the title and description will be formatted automatically.\
    ---Note: No support for locale placeholders when using this function.
    ---@param playerId number
    ---@param data NotifyProps
    ---@deprecated
    ---@diagnostic disable-next-line: duplicate-set-field
    function lib.notify(playerId, data)
        TriggerClientEvent(notifyEvent, playerId, data)
    end

    ---@return number[]
    ---Server-side parity for the `GetPlayers` client native.
    function GetActivePlayers()
        local playerNum = GetNumPlayerIndices()
        local players = table.create(playerNum, 0)

        for i = 1, playerNum do
            players[i] = tonumber(GetPlayerFromIndex(i - 1))
        end

        return players
    end
end

-- ★ A module named in the manifest (`w_lib { 'locale' }`) is loaded AND initialised: a module
--   that returns a function (locale returns lib.locale) is called once here, which is what
--   fills the resource's dictionary at boot.
--
-- ⚠️ The early `pcall(function() return lib.locale end)` above already loads the module, so
--    the old `if not rawget(lib, name)` guard skipped this loop for it and lib.locale() was
--    never called: every consumer (w_hud, w_map, w_pausemenu) started with an EMPTY
--    dictionary until the player switched language from /w_lib -- 'COMPASS.E' on the HUD,
--    'ui.back' / 'ui.unknown' on the map. The guard now only avoids loading twice; the call
--    is made regardless.
local function isImport(name)
    return LoadResourceFile(w_lib, ('imports/%s/shared.lua'):format(name)) ~= nil
        or LoadResourceFile(w_lib, ('imports/%s/%s.lua'):format(name, context)) ~= nil
end

for i = 1, GetNumResourceMetadata(cache.resource, 'w_lib') do
    local name = GetResourceMetadata(cache.resource, 'w_lib', i - 1)
    local module = rawget(lib, name)

    if not module or module == noop then
        module = loadModule(lib, name)
    elseif not isImport(name) then
        module = nil -- an export wrapper made by call(), not a module: nothing to initialise
    end

    if type(module) == 'function' then pcall(module) end
end

-- ══════════════════════════════════════════════════════════════════════════
-- w_lib — الطبقة الثانية (w) داخل المستهلك: نبني الغلوبال `w` أيضًا.
--   النواة تُحمَّل داخل مورد w_lib عبر w_init.lua في المانيفست؛ هنا الجانب
--   المستهلِك (وحدات مُصغَّرة + وسطاء إلى exports.w_lib). الحارس `not w` يمنع
--   التهيئة المزدوجة لو كان المستهلك ما زال يحمّل مكتبة قديمة أثناء الانتقال.
-- ══════════════════════════════════════════════════════════════════════════
if not moduleLayerLoaded() then
    local chunk = LoadResourceFile(w_lib, 'w_init.lua')
    if chunk then
        local fn, err = load(chunk, '@@w_lib/w_init.lua')
        if fn then
            local ok, runErr = pcall(fn)
            if not ok then
                print(('^1[w_lib] w layer failed to initialise: %s^0'):format(runErr))
            end
        else
            print(('^1[w_lib] failed to parse w layer: %s^0'):format(err))
        end
    end
end

-- ══════════════════════════════════════════════════════════════════════════
-- w — فضاء الأسماء الموحّد (المكتبة الواحدة): تستخدمه سكربتاتك في كل شيء.
--   • عند وجود وحدة في w تُعاد (تفوز عند التعارض: callback/print/table/... و
--     framework/menu/notif/promptNui/component/rawKeys/dataview).
--   • وإلا نسقط إلى نواة w_lib: notify/showContext/inputDialog/alertDialog/
--     progressBar/textUI/registerContext ...
--   الغلوبال `w` يبقى داخليًّا (كود w يحتاجه) لكن سكربتاتك لا تستخدمه — `w.` فقط.
-- ══════════════════════════════════════════════════════════════════════════
if moduleLayerLoaded() then
    local mt = getmetatable(w)
    local moduleIndex = mt and mt.__index      -- محلّل الوحدات الكسول من w_init.lua

    if type(moduleIndex) == 'function' then
        local resolved = {}
        -- w_notify (مدموج داخل w_lib): الإشعارات والنصوص عبر w.notify / w.drawText* (client)
        local notifyBridge = context == 'client' and {
            notify     = function(data) return exports.w_lib:NotifyRaw(data) end,
            drawText2D = function(...)  return exports.w_lib:DrawText2D(...) end,
            drawText3D = function(...)  return exports.w_lib:DrawText3D(...) end,
        } or {}

        -- نمدّد ميتاجدول جدول الوحدات نفسه بدل بناء جدول ثانٍ فوقه: غلاف يقرأ
        -- w[k] كان سيقرأ نفسه بعد التوحيد (استدعاء ذاتي لا نهائي). فضاء واحد فقط.
        mt.__index = function(t, k)
            local nb = notifyBridge[k]
            if nb ~= nil then return nb end               -- إشعارات w_notify المدمجة لها الأولوية
            local c = resolved[k]
            if c ~= nil then
                if c == false then return nil end         -- false = "غير موجود" مخبّأ (يمنع I/O متكرّرًا)
                return c
            end
            local v = moduleIndex(t, k)                   -- وحدة (تُحمّل كسولًا؛ nil إن لم توجد)
            if v == nil then v = lib[k] end               -- وإلا نواة w_lib
            if v == nil then resolved[k] = false else resolved[k] = v end
            return v
        end
    end

    w.cache = cache
else
    -- تعذّر تحميل طبقة الوحدات: تبقى نواة w_lib وحدها متاحة عبر w.
    _ENV.w = lib
    w.cache = cache
end

-- ══════════════════════════════════════════════════════════════════════════
-- Dialect host (w_core): the core that `provide`s rsg-core / qbr-core / vorp_core /
-- vorp_menu / vorp_inputs / vorp_progressbar / ox_lib gets the public contracts of
-- those names installed into ITS OWN VM here (compat/host_*.lua). A `provide` only
-- aliases the resource name for dependencies and GetResourceState; it does NOT alias
-- exports (exports['rsg-core']:GetCoreObject() looks for the event
-- __cfx_export_rsg-core_GetCoreObject, which only code running inside the providing
-- resource can register). Third-party RSG/VORP/ox scripts therefore run on w_core
-- unchanged. See compat/COMPATIBILITY.md.
-- ══════════════════════════════════════════════════════════════════════════
do
    local dialects = {
        ['rsg-core'] = true, ['qbr-core'] = true, ['vorp_core'] = true, ['ox_lib'] = true,
        ['vorp_inputs'] = true, ['vorp_menu'] = true, ['vorp_progressbar'] = true,
    }
    local provided = {}
    for i = 1, GetNumResourceMetadata(cache.resource, 'provide') do
        local name = GetResourceMetadata(cache.resource, 'provide', i - 1)
        if dialects[name] then provided[#provided + 1] = name end
    end

    if #provided > 0 then
        _ENV.WCompat = { provided = provided, host = cache.resource }
        for _, part in ipairs({ 'shared', context }) do
            local path = ('compat/host_%s.lua'):format(part)
            local chunk = LoadResourceFile(w_lib, path)
            if chunk then
                local fn, err = load(chunk, '@@w_lib/' .. path)
                if fn then
                    local ok, runErr = pcall(fn)
                    if not ok then print(('^1[w_lib] dialect host (%s) failed: %s^0'):format(path, runErr)) end
                else
                    print(('^1[w_lib] dialect host (%s) failed to parse: %s^0'):format(path, err))
                end
            end
        end
    end
end

-- ══════════════════════════════════════════════════════════════════════════
-- jo — اسم مستعار لنفس السطح.
--   w_lib هو jo_libs بعد إعادة التسمية: نفس الوحدات ونفس الواجهة. الموارد
--   المبنيّة على jo_libs تستدعي jo.* ، فبهذا السطر تعمل عليها كما هي بلا
--   تعديل داخلها. jo و w يشيران إلى الجدول نفسه لا نسختين.
-- ══════════════════════════════════════════════════════════════════════════
_ENV.jo = w

-- (لو تعذّر تحميل طبقة التوافق، تبقى نواة w_lib متاحة عبر w = lib.)
