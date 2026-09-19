-- ════════════════════════════════════════════════════════════════════════════
-- w_lib · compat/host_server.lua — the VORP server contract on top of the host core
-- (w_core). Runs inside the host's server VM (see host_shared.lua).
--
--   local Core = exports.vorp_core:GetCore()
--   local User = Core.getUser(src)            -> nil when the player has no character loaded
--   local Character = User.getUsedCharacter   -> identifier, charIdentifier, firstname, lastname,
--                                                money, gold, rol, job, jobGrade, jobLabel, gender,
--                                                age, xp, isdead, playerName, group + setters
--   Core.Callback.Register(name, function(source, cb, ...) cb(result) end)
--   Core.NotifyRightTip(src, text, ms) … (every VORP notify name)
--   TriggerEvent('vorp:addMoney', src, 0, amount) … (legacy money/job/xp events)
--   'vorp:SelectedCharacter' (src, Character) is fired when the core loads a character.
--
-- Limits (see compat/COMPATIBILITY.md): skin/clothes setters (updateSkin, updateComps) are
-- no-ops — appearance is w_creators'; Core.AddWebhook is routed to w_logs when it runs.
-- ════════════════════════════════════════════════════════════════════════════

local Core = WCompat.vorp
local currencyName, isCallable = WCompat.currencyName, WCompat.isCallable

local function player(source)
    local core = WCompat.core()
    if not core or not core.Functions or not core.Functions.GetPlayer then return nil end
    return core.Functions.GetPlayer(tonumber(source))
end

local function money(pd, kind)
    return pd.money and tonumber(pd.money[kind]) or 0
end

--- Build the VORP "Character" table of a loaded player. Fields are a snapshot; the
--- setters act on the live core object.
local function buildCharacter(source, Player)
    local pd = Player.PlayerData
    local job = pd.job or {}
    local grade = type(job.grade) == 'table' and job.grade or { level = tonumber(job.grade) or 0, name = '' }
    local info = pd.charinfo or {}
    local meta = pd.metadata or {}

    local ch = {
        source          = source,
        identifier      = pd.license or (pd.identifiers and pd.identifiers.license) or '',
        charIdentifier  = pd.citizenid,
        citizenid       = pd.citizenid,
        firstname       = info.firstname or '',
        lastname        = info.lastname or '',
        playerName      = pd.name or GetPlayerName(source) or '',
        steamname       = pd.name or '',
        money           = money(pd, 'cash'),
        gold            = money(pd, 'gold'),
        rol             = money(pd, 'rol'),
        bank            = money(pd, 'bank'),
        job             = job.name or 'unemployed',
        jobGrade        = tonumber(grade.level) or 0,
        jobLabel        = job.label or job.name or '',
        gender          = tostring(info.gender or 0),
        age             = tonumber(info.age or info.birthdate) or 0,
        xp              = tonumber(meta.xp) or 0,
        isdead          = meta.isdead == true,
        group           = 'user',
        skinPlayer      = '',
        compPlayer      = '',
    }

    function ch.addCurrency(kind, amount, reason)
        return Player.Functions.AddMoney(currencyName(kind), tonumber(amount) or 0, reason or 'vorp-compat') and true or false
    end
    function ch.removeCurrency(kind, amount, reason)
        return Player.Functions.RemoveMoney(currencyName(kind), tonumber(amount) or 0, reason or 'vorp-compat') and true or false
    end
    function ch.setCurrency(kind, amount, reason)
        return Player.Functions.SetMoney(currencyName(kind), tonumber(amount) or 0, reason or 'vorp-compat') and true or false
    end
    function ch.getCurrency(kind)
        return Player.Functions.GetMoney(currencyName(kind)) or 0
    end
    function ch.setJob(name, gradeLevel)
        return Player.Functions.SetJob(name, tonumber(gradeLevel) or ch.jobGrade) and true or false
    end
    function ch.setJobGrade(gradeLevel)
        return Player.Functions.SetJob(ch.job, tonumber(gradeLevel) or 0) and true or false
    end
    function ch.setJobLabel(label)
        Player.Functions.SetPlayerData('job', { name = ch.job, label = label, grade = grade, onduty = job.onduty, isboss = job.isboss, payment = job.payment })
        return true
    end
    function ch.setGroup(group)
        local core = WCompat.core()
        if core and core.Functions and core.Functions.AddPermission then core.Functions.AddPermission(source, group) end
        return true
    end
    function ch.addXp(amount)
        Player.Functions.SetMetaData('xp', (tonumber(meta.xp) or 0) + (tonumber(amount) or 0))
        return true
    end
    function ch.removeXp(amount)
        Player.Functions.SetMetaData('xp', math.max(0, (tonumber(meta.xp) or 0) - (tonumber(amount) or 0)))
        return true
    end
    function ch.setXp(amount)
        Player.Functions.SetMetaData('xp', tonumber(amount) or 0)
        return true
    end
    function ch.setDead(value)
        Player.Functions.SetMetaData('isdead', value == true)
        return true
    end
    function ch.setFirstname(value) Player.Functions.SetPlayerData('charinfo', { firstname = value, lastname = ch.lastname, gender = info.gender, birthdate = info.birthdate }) end
    function ch.setLastname(value)  Player.Functions.SetPlayerData('charinfo', { firstname = ch.firstname, lastname = value, gender = info.gender, birthdate = info.birthdate }) end
    function ch.updateSkin() return true end
    function ch.updateComps() return true end
    function ch.updateCharUi() return true end
    function ch.getInfo() return ch end

    return ch
end

--- Core.getUser(source) -> User | nil
function Core.getUser(source)
    source = tonumber(source)
    local Player = source and player(source)
    if not Player then return nil end

    local character = buildCharacter(source, Player)
    -- `User.getUsedCharacter` is read as a field by modern scripts and called by old ones.
    local used = setmetatable(character, { __call = function(self) return self end })

    local User = {
        source            = source,
        getUsedCharacter  = used,
        getIdentifier     = character.identifier,
        getPlayerName     = character.playerName,
        getGroup          = character.group,
        numberOfCharacters = 1,
        getUserCharacters = { character },
    }
    function User.setGroup(group) return character.setGroup(group) end
    function User.getUsedCharacterId() return character.charIdentifier end
    return User
end

Core.getUsers = function()
    local users = {}
    local core = WCompat.core()
    if not core then return users end
    for _, src in ipairs(GetPlayers()) do
        local user = Core.getUser(src)
        if user then users[tonumber(src)] = user end
    end
    return users
end

Core.maxCharacters = 5

-- ───────────────────────────── callbacks ─────────────────────────────
-- VORP: Core.Callback.Register(name, function(source, cb, ...) cb(result) end). The
-- library wire is return-value based, so the VORP callback is awaited with a promise.
Core.Callback = {}

function Core.Callback.Register(name, handler)
    if type(name) ~= 'string' or not isCallable(handler) then return end
    w.callback.register(name, function(source, ...)
        local p = promise.new()
        local settled = false
        local function cb(...)
            if settled then return end
            settled = true
            p:resolve(table.pack(...))
        end
        local ok, err = pcall(handler, source, cb, ...)
        if not ok then
            print(('^1[w_lib] vorp callback %s failed: %s^0'):format(name, tostring(err)))
            cb(nil)
        end
        SetTimeout(10000, function() cb(nil) end)
        local result = Citizen.Await(p)
        return table.unpack(result, 1, result.n)
    end)
end
Core.Callback.RegisterCallback = Core.Callback.Register
Core.RegisterServerCallback = Core.Callback.Register

--- Core.Callback.TriggerAsync(source, name, cb, ...) — a client callback from the server.
function Core.Callback.TriggerAsync(source, name, cb, ...)
    return w.callback.triggerClient(name, source, cb, ...)
end
function Core.Callback.TriggerAwait(source, name, ...)
    return w.callback.triggerClient(name, source, nil, ...)
end
Core.Callback.TriggerClientCallback = Core.Callback.TriggerAsync

-- ───────────────────────────── notifications ─────────────────────────────
local function notify(source, data)
    if not source or source == 0 then return end
    w.notify(source, data)
end

local function ms(v) local n = tonumber(v) return n and n > 0 and n or 5000 end

function Core.NotifyRightTip(source, text, duration)        notify(source, { description = text, duration = ms(duration), position = 'right-center' }) end
function Core.NotifyTip(source, text, duration)             notify(source, { description = text, duration = ms(duration) }) end
function Core.NotifyBottomRight(source, text, duration)     notify(source, { description = text, duration = ms(duration), position = 'bottom-right' }) end
function Core.NotifyObjective(source, text, duration)       notify(source, { description = text, duration = ms(duration), position = 'top', type = 'inform' }) end
function Core.NotifyCenter(source, text, duration, color)   notify(source, { description = text, duration = ms(duration), position = 'center-right' }) end
function Core.NotifyLeft(source, title, subtitle, dict, icon, duration, color)
    notify(source, { title = title, description = subtitle, duration = ms(duration), position = 'top-left' })
end
function Core.NotifySimpleTop(source, title, subtitle, duration)
    notify(source, { title = title, description = subtitle, duration = ms(duration), position = 'top' })
end
function Core.NotifyAvanced(source, text, dict, icon, color, duration)
    notify(source, { description = text, duration = ms(duration), position = 'top-left' })
end
Core.NotifyAdvanced = Core.NotifyAvanced
function Core.NotifyFail(source, text, duration)            notify(source, { description = text, duration = ms(duration), type = 'error' }) end
function Core.NotifyDead(source, text, duration)            notify(source, { description = text, duration = ms(duration), type = 'error', position = 'center-right' }) end
function Core.NotifyUpdate(source, title, text, duration)   notify(source, { title = title, description = text, duration = ms(duration), type = 'inform' }) end
function Core.NotifyWarning(source, title, text, duration)  notify(source, { title = title, description = text, duration = ms(duration), type = 'warning' }) end
function Core.NotifyTopLeft(source, title, text, duration)  notify(source, { title = title, description = text, duration = ms(duration), position = 'top-left' }) end

--- Core.AddWebhook(title, webhook, description, ...) -> w_logs when present, else the console.
function Core.AddWebhook(title, webhook, description, color, name, logo, footerLogo, avatar)
    if GetResourceState('w_logs') == 'started' then
        local ok = pcall(function()
            exports.w_logs:Emit('compat.webhook', { title = tostring(title or ''), description = tostring(description or ''), webhook = webhook, color = color, name = name })
        end)
        if ok then return true end
    end
    print(('^3[w_lib] webhook (%s): %s^0'):format(tostring(title), tostring(description)))
    return true
end

-- ───────────────────────────── legacy events ─────────────────────────────
-- Older VORP scripts drive the core with events instead of the Character setters.
AddEventHandler('vorp:addMoney', function(source, kind, amount)
    local user = Core.getUser(source)
    if user then user.getUsedCharacter.addCurrency(kind, amount) end
end)
AddEventHandler('vorp:removeMoney', function(source, kind, amount)
    local user = Core.getUser(source)
    if user then user.getUsedCharacter.removeCurrency(kind, amount) end
end)
AddEventHandler('vorp:addGold', function(source, amount)
    local user = Core.getUser(source)
    if user then user.getUsedCharacter.addCurrency(1, amount) end
end)
AddEventHandler('vorp:removeGold', function(source, amount)
    local user = Core.getUser(source)
    if user then user.getUsedCharacter.removeCurrency(1, amount) end
end)
AddEventHandler('vorp:setJob', function(source, job, grade)
    local user = Core.getUser(source)
    if user then user.getUsedCharacter.setJob(job, grade) end
end)
AddEventHandler('vorp:setJobGrade', function(source, grade)
    local user = Core.getUser(source)
    if user then user.getUsedCharacter.setJobGrade(grade) end
end)
AddEventHandler('vorp:setGroup', function(source, group)
    local user = Core.getUser(source)
    if user then user.setGroup(group) end
end)
AddEventHandler('vorp:addXp', function(source, amount)
    local user = Core.getUser(source)
    if user then user.getUsedCharacter.addXp(amount) end
end)
AddEventHandler('vorp:removeXp', function(source, amount)
    local user = Core.getUser(source)
    if user then user.getUsedCharacter.removeXp(amount) end
end)
AddEventHandler('vorp:getCharacter', function(source, cb)
    local user = Core.getUser(source)
    if isCallable(cb) then cb(user and user.getUsedCharacter or nil) end
end)
AddEventHandler('vorp:getUser', function(source, cb)
    if isCallable(cb) then cb(Core.getUser(source)) end
end)

-- Lifecycle: the host's loaded / unloaded signals under the VORP names.
AddEventHandler('WCore:Server:PlayerLoaded', function(Player)
    local source = Player and Player.PlayerData and Player.PlayerData.source
    if not source then return end
    local user = Core.getUser(source)
    if not user then return end
    TriggerEvent('vorp:SelectedCharacter', source, user.getUsedCharacter)
    TriggerEvent('vorp_core:Server:OnPlayerReady', source, user.getUsedCharacter)
end)
AddEventHandler('WCore:Server:OnPlayerUnload', function(source)
    TriggerEvent('vorp:PlayerLogout', source)
    TriggerEvent('vorp_core:Server:OnPlayerUnload', source)
end)
