--[[
    https://github.com/overextended/ox_lib

    This file is licensed under LGPL-3.0 or higher <https://www.gnu.org/licenses/lgpl-3.0.en.html>

    Copyright © 2025 Linden <https://github.com/thelindat>
]]

---@class OxCommandParams
---@field name string
---@field help? string
---@field type? 'number' | 'playerId' | 'string' | 'longString'
---@field optional? boolean

---@class OxCommandProperties
---@field help string?
---@field params OxCommandParams[]?
---@field restricted boolean | string | string[]?

---@type OxCommandProperties[]
local registeredCommands = {}
local shouldSendCommands = false

SetTimeout(1000, function()
    shouldSendCommands = true
    TriggerClientEvent('chat:addSuggestions', -1, registeredCommands)
end)

AddEventHandler('playerJoining', function()
    TriggerClientEvent('chat:addSuggestions', source, registeredCommands)
end)

-------------
-- 'playerId' params name a player by his CITIZEN id (players.citizenid), not his server id.
--
-- Why: a server id changes on every connection and, since the citizen id became plain digits,
-- the two collide. '/bring 12' either answered "invalid playerId" to a citizen id or grabbed
-- whoever held server id 12. Staff work with the citizen id only, so this one parser is where
-- every command built on the type learns it:
--   '12', 'omg95204'   the citizen id: the character's current server id when he is in the game
--   '#7'               an explicit server id (any connected player, even one still choosing a
--                      character, so a stuck player can still be reached)
--   'me'               the caller
-- The handler still receives a server id, so those commands keep working unchanged. A citizen who
-- is not connected fails here with the 'offline' reason: a command that can act on an offline
-- character declares the param with NO type (the raw word arrives) and resolves it with
-- w.citizen.resolve. Not 'string': that type refuses anything tonumber reads, so '12' never
-- reaches the handler.
-------------

-- w.citizen runs inside this resource (a module of the w layer). If that layer failed to load
-- here, the same resolver still answers from w_lib's VM through its exports.
local function citizenModule()
    local ok, mod = pcall(function() return w and w.citizen end)
    if ok and type(mod) == 'table' and mod.requireOnline and mod.parse then return mod end
    return nil
end

---@param source number the caller (0 = console)
---@param arg string
---@return number|false value the server id, or false
---@return string|nil reason 'invalid_id' | 'not_found' | 'offline'
---@return table|nil offline the offline character, when the reason is 'offline'
local function parsePlayerId(source, arg)
    local citizen = citizenModule()
    local kind, value

    if citizen then
        kind, value = citizen.parse(arg)
    else
        -- only the two forms that need no lookup are read here; the rest goes to w_lib
        local text = tostring(arg):gsub('^%s+', ''):gsub('%s+$', '')
        local n = text:match('^#%s*(%d+)$')
        if n then
            kind, value = 'server', math.tointeger(tonumber(n))
        elseif text:lower() == 'me' then
            kind = 'self'
        else
            kind, value = 'citizen', text
        end
    end

    if kind == 'self' then
        -- the console is nobody: 'me' from it names no player
        if source and source > 0 and DoesPlayerExist(source--[[@as string]]) then return source end
        return false, 'invalid_id'
    end

    if kind == 'server' then
        if value and DoesPlayerExist(value--[[@as string]]) then return value end
        return false, 'not_found'
    end

    if kind ~= 'citizen' then return false, 'invalid_id' end

    local target, reason, offline
    if citizen then
        target, reason, offline = citizen.requireOnline(value)
    else
        local ok
        ok, target, reason, offline = pcall(function() return exports.w_lib:CitizenRequireOnline(value) end)
        if not ok then target, reason, offline = nil, 'not_found', nil end
    end

    if target and target.source then return target.source end
    return false, reason or 'not_found', offline
end

--- Tells the caller why the player argument was refused. The old parser only traced to the server
--- console, so a staff member typing an id saw nothing happen at all.
---@param source number
---@param reason string
---@param offline table|nil
local function tellCaller(source, reason, offline)
    local citizen = citizenModule()
    local player = source and source > 0 and source or nil
    local text, title = reason, nil

    if citizen then
        text = citizen.reasonText(reason, player)
        if offline then text = ('%s: %s'):format(citizen.label(offline), text) end
        title = citizen.text('label', player)
    end

    if player then
        -- w_lib's own client answers this event, so it shows even for a resource with no client half
        TriggerClientEvent('w_lib:notify', player, title, text, 'error')
    else
        print(('[%s] %s'):format(GetCurrentResourceName(), text))
    end
end

---@param source number
---@param args table
---@param raw string
---@param params OxCommandParams[]?
---@return table?
local function parseArguments(source, args, raw, params)
    if not params then return args end

    local paramsNum = #params
    for i = 1, paramsNum do
        local arg, param = args[i], params[i]
        local value, reason, offline

        if param.type == 'number' then
            value = tonumber(arg)
        elseif param.type == 'string' then
            value = not tonumber(arg) and arg
        elseif param.type == 'playerId' then
            value = false

            if arg ~= nil then
                value, reason, offline = parsePlayerId(source, arg)
            end
        elseif param.type == 'longString' and i == paramsNum then
            if arg then
                local start = raw:find(arg, 1, true)
                value = start and raw:sub(start)
            else
                value = nil
            end
        else
            value = arg
        end

        if not value and (not param.optional or param.optional and arg) then
            if reason then tellCaller(source, reason, offline) end
            return Citizen.Trace(("^1command '%s' received an invalid %s for argument %s (%s), received '%s'^0\n"):format(string.strsplit(' ', raw) or raw, param.type, i, param.name, arg))
        end

        arg = value

        args[param.name] = arg
        args[i] = nil
    end

    return args
end

--- The hint shown for a 'playerId' param: what to type (the citizen id, '#' for a server id) in
--- the server's language, instead of the bare type name that told staff to type a server id.
---@return string
local function playerIdHint()
    local citizen = citizenModule()
    local ok, text = pcall(function() return citizen and citizen.text('help') end)
    if ok and type(text) == 'string' and text ~= '' and text ~= 'help' then return text end
    return 'citizen ID, or #server ID'
end

---@param commandName string
---@param properties OxCommandProperties
---@return OxCommandProperties
local function buildSuggestion(commandName, properties)
    local hints

    if properties.params then
        hints = {}

        for i = 1, #properties.params do
            local param = properties.params[i]
            local kind = param.type == 'playerId' and playerIdHint() or param.type and ('type: %s'):format(param.type)
            hints[i] = {
                name = param.name,
                help = kind
                    and (param.help and ('%s (%s)'):format(param.help, kind) or ('(%s)'):format(kind))
                    or param.help,
            }
        end
    end

    return {
        name = ('/%s'):format(commandName),
        help = properties.help,
        params = hints,
    }
end

---@param commandName string | string[]
---@param properties OxCommandProperties | false
---@param cb fun(source: number, args: table, raw: string)
---@param ... any
function lib.addCommand(commandName, properties, cb, ...)
    -- Try to handle backwards-compatibility with the old addCommand syntax (prior to v3.0)
    local restricted, params

    if properties then
        if ... or table.type(properties) ~= 'hash' then
            local _commandName = type(properties) == 'table' and properties[1] or properties
            local info = debug.getinfo(2, 'Sl')

            warn(("command '%s' is using deprecated syntax for lib.addCommand\nupdate the command or use lib.__addCommand to ignore this warning\n> source ^0(^5%s^0:%d)"):format(_commandName, info.short_src, info.currentline))
            ---@diagnostic disable-next-line: deprecated
            return lib.__addCommand(commandName, properties, cb, ...)
        end

        restricted = properties.restricted
        params = properties.params
    end

    local commands = type(commandName) ~= 'table' and { commandName } or commandName
    local numCommands = #commands
    local totalCommands = #registeredCommands

    local function commandHandler(source, args, raw)
        args = parseArguments(source, args, raw, params)

        if not args then return end

        local success, resp = pcall(cb, source, args, raw)

        if not success then
            Citizen.Trace(("^1command '%s' failed to execute!\n%s"):format(string.strsplit(' ', raw) or raw, resp))
        end
    end

    for i = 1, numCommands do
        totalCommands += 1
        commandName = commands[i]

        RegisterCommand(commandName, commandHandler, restricted and true)

        if restricted then
            local ace = ('command.%s'):format(commandName)
            local restrictedType = type(restricted)

            if restrictedType == 'string' and not IsPrincipalAceAllowed(restricted, ace) then
                lib.addAce(restricted, ace)
            elseif restrictedType == 'table' then
                for j = 1, #restricted do
                    if not IsPrincipalAceAllowed(restricted[j], ace) then
                        lib.addAce(restricted[j], ace)
                    end
                end
            end
        end

        if properties then
            local suggestion = buildSuggestion(commandName, properties)
            registeredCommands[totalCommands] = suggestion

            if shouldSendCommands then TriggerClientEvent('chat:addSuggestions', -1, suggestion) end
        end
    end
end

return lib.addCommand
