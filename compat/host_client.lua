-- ════════════════════════════════════════════════════════════════════════════
-- w_lib · compat/host_client.lua — the VORP client contracts on top of the host core
-- (w_core) and w_lib's interface. Runs inside the host's client VM (see host_shared.lua).
--
--   local Core = exports.vorp_core:GetCore()
--   Core.Callback.TriggerAsync(name, cb, ...) / Core.Callback.TriggerAwait(name, ...)
--   Core.NotifyRightTip(text, ms) … (every VORP notify name)     -> w_lib notifications
--   TriggerEvent('vorp:TipRight', text, ms) …                      -> same
--   exports.vorp_inputs:advancedInput(cb, config)                  -> w_lib input dialog
--   exports.vorp_progressbar:initiate(cb, ms, label)               -> w_lib progress bar
--   exports.vorp_menu:GetMenuData().Open(...)                      -> w_lib context menu
--   'vorp:SelectedCharacter' / 'vorp_core:Client:OnPlayerReady' fire on the core's loaded signal.
-- ════════════════════════════════════════════════════════════════════════════

local Core = WCompat.vorp
local isCallable = WCompat.isCallable
local lib = exports.w_lib

local function ms(v) local n = tonumber(v) return n and n > 0 and n or 5000 end

-- ───────────────────────────── notifications ─────────────────────────────
local function notify(data)
    w.notify(data)
end

function Core.NotifyRightTip(text, duration)        notify({ description = text, duration = ms(duration), position = 'right-center' }) end
function Core.NotifyTip(text, duration)             notify({ description = text, duration = ms(duration) }) end
function Core.NotifyBottomRight(text, duration)     notify({ description = text, duration = ms(duration), position = 'bottom-right' }) end
function Core.NotifyObjective(text, duration)       notify({ description = text, duration = ms(duration), position = 'top', type = 'inform' }) end
function Core.NotifyCenter(text, duration, color)   notify({ description = text, duration = ms(duration), position = 'center-right' }) end
function Core.NotifyLeft(title, subtitle, dict, icon, duration, color)
    notify({ title = title, description = subtitle, duration = ms(duration), position = 'top-left' })
end
function Core.NotifySimpleTop(title, subtitle, duration)
    notify({ title = title, description = subtitle, duration = ms(duration), position = 'top' })
end
function Core.NotifyAvanced(text, dict, icon, color, duration)
    notify({ description = text, duration = ms(duration), position = 'top-left' })
end
Core.NotifyAdvanced = Core.NotifyAvanced
function Core.NotifyFail(text, duration)            notify({ description = text, duration = ms(duration), type = 'error' }) end
function Core.NotifyDead(text, duration)            notify({ description = text, duration = ms(duration), type = 'error', position = 'center-right' }) end
function Core.NotifyUpdate(title, text, duration)   notify({ title = title, description = text, duration = ms(duration), type = 'inform' }) end
function Core.NotifyWarning(title, text, duration)  notify({ title = title, description = text, duration = ms(duration), type = 'warning' }) end
function Core.NotifyTopLeft(title, text, duration)  notify({ title = title, description = text, duration = ms(duration), position = 'top-left' }) end

-- The event names VORP's server-side Notify* helpers send to the client.
local notifyEvents = {
    ['vorp:TipRight']                        = function(text, duration) Core.NotifyRightTip(text, duration) end,
    ['vorp:TipBottom']                       = function(text, duration) Core.NotifyBottomRight(text, duration) end,
    ['vorp:Tip']                             = function(text, duration) Core.NotifyTip(text, duration) end,
    ['vorp:NotifyLeft']                      = function(title, subtitle, dict, icon, duration, color) Core.NotifyLeft(title, subtitle, dict, icon, duration, color) end,
    ['vorp:ShowAdvancedRightNotification']   = function(text, dict, icon, color, duration) Core.NotifyAvanced(text, dict, icon, color, duration) end,
    ['vorp:ShowTopNotification']             = function(title, subtitle, duration) Core.NotifySimpleTop(title, subtitle, duration) end,
    ['vorp:ShowSimpleCenterText']            = function(text, duration, color) Core.NotifyCenter(text, duration, color) end,
    ['vorp:ShowObjective']                   = function(text, duration) Core.NotifyObjective(text, duration) end,
    ['vorp:ShowBottomRight']                 = function(text, duration) Core.NotifyBottomRight(text, duration) end,
    ['vorp:NotifyFail']                      = function(text, duration) Core.NotifyFail(text, duration) end,
    ['vorp:NotifyDead']                      = function(text, duration) Core.NotifyDead(text, duration) end,
    ['vorp:NotifyUpdate']                    = function(title, text, duration) Core.NotifyUpdate(title, text, duration) end,
    ['vorp:NotifyWarning']                   = function(title, text, duration) Core.NotifyWarning(title, text, duration) end,
}
for name, handler in pairs(notifyEvents) do
    RegisterNetEvent(name, handler)
end

-- ───────────────────────────── callbacks ─────────────────────────────
Core.Callback = {}

--- Core.Callback.TriggerAsync(name, cb, ...) — result delivered to `cb`.
function Core.Callback.TriggerAsync(name, cb, ...)
    if isCallable(cb) then
        return w.callback.triggerServer(name, cb, ...)
    end
    return w.callback.triggerServer(name, nil, cb, ...)
end

--- Core.Callback.TriggerAwait(name, ...) — blocks the calling thread for the result.
function Core.Callback.TriggerAwait(name, ...)
    return w.callback.triggerServer(name, nil, ...)
end
Core.Callback.TriggerServerCallback = Core.Callback.TriggerAsync
Core.RpcCall = Core.Callback.TriggerAsync
Core.TriggerServerCallback = Core.Callback.TriggerAsync

--- Client callbacks the server can ask for (Core.Callback.TriggerAsync(source, name, ...)).
function Core.Callback.Register(name, handler)
    if type(name) ~= 'string' or not isCallable(handler) then return end
    w.callback.register(name, function(...)
        local p = promise.new()
        local settled = false
        local function cb(...)
            if settled then return end
            settled = true
            p:resolve(table.pack(...))
        end
        local ok, err = pcall(handler, cb, ...)
        if not ok then
            print(('^1[w_lib] vorp client callback %s failed: %s^0'):format(name, tostring(err)))
            cb(nil)
        end
        SetTimeout(10000, function() cb(nil) end)
        local result = Citizen.Await(p)
        return table.unpack(result, 1, result.n)
    end)
end

-- Legacy: TriggerEvent('vorp:TriggerServerCallback', name, cb, ...)
AddEventHandler('vorp:TriggerServerCallback', function(name, cb, ...)
    Core.Callback.TriggerAsync(name, cb, ...)
end)

-- ───────────────────────────── player data ─────────────────────────────
--- The loaded character as VORP clients see it (Core.Player / 'vorp:SelectedCharacter').
local function currentCharacter()
    local core = WCompat.core()
    local pd = core and core.PlayerData
    if type(pd) ~= 'table' or not pd.citizenid then return nil end
    local info, job, money = pd.charinfo or {}, pd.job or {}, pd.money or {}
    local grade = type(job.grade) == 'table' and job.grade or { level = tonumber(job.grade) or 0 }
    return {
        charIdentifier = pd.citizenid,
        identifier     = pd.license or '',
        firstname      = info.firstname or '',
        lastname       = info.lastname or '',
        money          = tonumber(money.cash) or 0,
        gold           = tonumber(money.gold) or 0,
        rol            = tonumber(money.rol) or 0,
        job            = job.name or 'unemployed',
        jobGrade       = tonumber(grade.level) or 0,
        jobLabel       = job.label or '',
        gender         = tostring(info.gender or 0),
        isdead         = pd.metadata and pd.metadata.isdead == true or false,
    }
end

Core.Player = {}
function Core.Player.GetPlayerData() return currentCharacter() end
function Core.getUsedCharacter() return currentCharacter() end

RegisterNetEvent('WCore:Client:OnPlayerLoaded', function()
    local character = currentCharacter()
    TriggerEvent('vorp:SelectedCharacter', character and character.charIdentifier or nil, character)
    TriggerEvent('vorp_core:Client:OnPlayerReady', character)
end)
RegisterNetEvent('WCore:Client:OnPlayerUnload', function()
    TriggerEvent('vorp:PlayerLogout')
    TriggerEvent('vorp_core:Client:OnPlayerUnload')
end)

-- ───────────────────────────── vorp_inputs ─────────────────────────────
-- exports.vorp_inputs:advancedInput(cb, config)  (also the older (cb, title, placeholder, type))
local function inputLabel(config, fallback)
    if type(config) ~= 'table' then return tostring(config or fallback) end
    local attrs = type(config.attributes) == 'table' and config.attributes or {}
    return attrs.inputHeader or attrs.title or config.inputHeader or config.title or config.placeholder or fallback
end

WCompat.alias('vorp_inputs', 'advancedInput', function(cb, config, placeholder, inputType)
    CreateThread(function()
        local heading = inputLabel(config, 'Input')
        local attrs = type(config) == 'table' and type(config.attributes) == 'table' and config.attributes or {}
        local kind = (attrs.type == 'number' or inputType == 'number') and 'number' or 'input'
        local rows = { {
            type = kind,
            label = heading,
            placeholder = type(config) == 'table' and config.placeholder or placeholder,
            default = attrs.value,
            required = true,
        } }
        local result = lib:inputDialog(heading, rows)
        local value = result and result[1] or ''
        if isCallable(cb) then cb(value) end
    end)
end)

-- ───────────────────────────── vorp_progressbar ─────────────────────────────
-- exports.vorp_progressbar:initiate(cb, duration, label)
WCompat.alias('vorp_progressbar', 'initiate', function(cb, duration, label)
    CreateThread(function()
        local done = lib:progressBar({ duration = ms(duration), label = label or '', canCancel = false })
        if isCallable(cb) then cb(done ~= false) end
    end)
end)
WCompat.alias('vorp_progressbar', 'pgreset', function() lib:cancelProgress() end)

-- ───────────────────────────── vorp_menu ─────────────────────────────
-- exports.vorp_menu:GetMenuData() -> MenuData.Open(type, namespace, name, data, submit, cancel, change, close)
local MenuData = { opened = {} }
local menuCounter = 0

local function menuId(namespace, name) return ('vorp_menu:%s:%s'):format(tostring(namespace), tostring(name)) end

function MenuData.Open(menuType, namespace, name, data, submit, cancel, change, close)
    data = type(data) == 'table' and data or {}
    local id = menuId(namespace, name)
    menuCounter = menuCounter + 1

    local menu = { type = menuType, namespace = namespace, name = name, data = data, id = id }

    function menu.close()
        MenuData.opened[id] = nil
        lib:hideContext(false)
        if isCallable(close) then pcall(close, data, menu) end
    end
    function menu.setElements(elements) data.elements = elements menu.refresh() end
    function menu.setTitle(title) data.title = title menu.refresh() end
    function menu.setElement(index, key, value)
        if data.elements and data.elements[index] then data.elements[index][key] = value end
    end
    function menu.update(query, newElement)
        for i, element in ipairs(data.elements or {}) do
            local match = true
            for k, v in pairs(query or {}) do if element[k] ~= v then match = false break end end
            if match then for k, v in pairs(newElement or {}) do data.elements[i][k] = v end end
        end
    end

    function menu.refresh()
        local options = {}
        for _, element in ipairs(data.elements or {}) do
            local title = element.label or element.title or tostring(element.value or '')
            if element.type == 'slider' and element.value ~= nil then
                title = ('%s: %s'):format(title, tostring(element.value))
            end
            options[#options + 1] = {
                title = title,
                description = element.desc or element.info or element.description,
                icon = element.icon,
                disabled = element.disabled == true,
                onSelect = function()
                    data.current = element
                    if element.type == 'slider' and isCallable(change) then
                        element.value = (tonumber(element.value) or 0) + 1
                        if element.max and element.value > element.max then element.value = element.min or 0 end
                        pcall(change, data, menu)
                        return menu.refresh()
                    end
                    if isCallable(submit) then pcall(submit, data, menu) end
                end,
            }
        end
        if data.lastmenu or isCallable(cancel) then
            options[#options + 1] = {
                title = data.backLabel or 'Back',
                icon = 'arrow-left',
                onSelect = function()
                    MenuData.opened[id] = nil
                    if isCallable(cancel) then pcall(cancel, data, menu) end
                end,
            }
        end
        lib:registerContext({
            id = id,
            title = data.title or data.subtext or tostring(name),
            canClose = true,
            onExit = function()
                MenuData.opened[id] = nil
                if isCallable(close) then pcall(close, data, menu) end
            end,
            options = options,
        })
        lib:showContext(id)
    end

    MenuData.opened[id] = menu
    menu.refresh()
    return menu
end

function MenuData.Close(menuType, namespace, name)
    local menu = MenuData.opened[menuId(namespace, name)]
    if menu then menu.close() end
end

function MenuData.CloseAll()
    for id, menu in pairs(MenuData.opened) do menu.close() end
    MenuData.opened = {}
end

function MenuData.IsOpen(menuType, namespace, name)
    return MenuData.opened[menuId(namespace, name)] ~= nil
end

function MenuData.GetOpened(menuType, namespace, name)
    return MenuData.opened[menuId(namespace, name)]
end

WCompat.alias('vorp_menu', 'GetMenuData', function() return MenuData end)
WCompat.alias('vorp_menu', 'CloseAll', function() MenuData.CloseAll() end)
