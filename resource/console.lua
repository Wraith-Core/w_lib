--[[
    w_lib · resource/console.lua -- the quiet console (owner 2026-10-19: no prints, one banner per script)

    Runs first inside w_lib itself (fxmanifest shared_script) and, through init.lua, inside every resource that
    loads '@w_lib/init.lua' -- in that resource's own Lua environment, on the client and on the server.

    * print(): routine lines are dropped. A line that reports a fault still prints: red (^1), or one of the words
      error / fail / warn / blocked / mismatch / exception / traceback. Runtime errors (SCRIPT ERROR ...) never go
      through print() and always show; w_logs' error room and the deploy agent's console watcher keep their lines.
    * The server prints ONE banner per resource when it starts: name, version, description (w_planefly's box).
      A resource that prints its own banner (with wBanner) declares `w_banner 'own'` in its fxmanifest.
    * `setr w_lib:consoleDebug 1` lets every line through again (both sides); `setr <resource>:consoleDebug 1` one
      resource only. Read every 2 s, so it works without a restart.
]]

if wRawPrint then return end -- once per Lua environment

local rawPrint = print
wRawPrint = rawPrint

local resource = GetCurrentResourceName()
local FAULT = { 'error', 'fail', 'warn', 'blocked', 'mismatch', 'exception', 'traceback' }

local debugOn, checkedAt = false, -1
local function debug()
    local now = GetGameTimer()
    if checkedAt < 0 or now - checkedAt > 2000 then
        checkedAt = now
        debugOn = GetConvarInt(resource .. ':consoleDebug', GetConvarInt('w_lib:consoleDebug', 0)) == 1
    end
    return debugOn
end

local function fault(text)
    if text:find('^1', 1, true) then return true end
    local low = text:lower()
    for i = 1, #FAULT do
        if low:find(FAULT[i], 1, true) then return true end
    end
    return false
end

function print(...)
    if debug() then return rawPrint(...) end
    local n = select('#', ...)
    local parts = {}
    for i = 1, n do parts[i] = tostring((select(i, ...))) end
    if fault(table.concat(parts, ' ')) then return rawPrint(...) end
end

--- A start banner in w_planefly's box: lines = { 'text', ... } (colour codes allowed). Always printed.
function wBanner(lines)
    rawPrint('^4┌──────────────────────────────────────────────────────────────┐^7')
    for _, line in ipairs(type(lines) == 'table' and lines or { lines }) do rawPrint('^4│^7 ' .. tostring(line)) end
    rawPrint('^4└──────────────────────────────────────────────────────────────┘^7')
end

if IsDuplicityVersion() and GetResourceMetadata(resource, 'w_banner', 0) ~= 'own' then
    local version = GetResourceMetadata(resource, 'version', 0)
    local line = ('^5%s^7'):format(resource)
    if version and version ~= '' then line = line .. (' ^2v%s^7'):format(version) end
    local desc = GetResourceMetadata(resource, 'description', 0)
    if desc and desc ~= '' then
        desc = desc:gsub('%s+', ' ')
        local len = utf8.len(desc)
        if len and len > 72 then desc = desc:sub(1, utf8.offset(desc, 70) - 1) .. '…' end
        line = line .. '  ·  ' .. desc
    end
    wBanner({ line })
end
