--[[ w_lib · essentials (client) — see resource/essentials/shared.lua for every switch. ]]
local E = WEssentials
local KEY_LALT, KEY_SHIFT, KEY_TAB = 0xCF8A4ECA, 0x8FFC75D6, 0xAC4BD4F1   -- w_core/shared/keybinds.lua

local function ped() return cache.ped or PlayerPedId() end
--[[
    ⚠️ NEVER CALL L() / locale() WHILE THIS FILE LOADS.

       The global locale() does not exist yet: imports/locale defines it on the first read of
       lib.locale, and in w_lib's own VM that read is resource/locale/client.lua, which the
       'resource/**/client.lua' glob loads AFTER essentials/. One load-time call threw
       "attempt to call a nil value (global 'locale')" and took down every feature below.
       Threads, handlers and callbacks are fine: they run once every script has loaded.
       (Not `local _ = lib.locale` either: that defines locale() over an empty dictionary.)
]]
local function L(key, ...) return locale('essentials.' .. key, ...) end

--[[
    The host switch (shared.lua header): the server decides and replicates it as
    GlobalState['w_lib:essentials']. This file starts NOTHING until that reads true; nil (not
    arrived yet) and false are off, so a host without w_core (MajestyRP) never gets a keybind,
    a loop, a control block or a relationship change from here.

    Every feature below is a start function, run by start() in file order, never while the
    file loads (see L above). A feature's loops run while live == its run; stop() clears live
    and plays the undo list backwards. Keybinds cannot be unregistered (the key mapping stays):
    each is added once, then disabled / enabled.
]]
local features, undo, binds = {}, {}, {}
local run, live = 0, nil

local function feature(fn) features[#features + 1] = fn end
local function alive(r) return live == r end
local function still(r, ms) Wait(ms) return live == r end   -- Wait, then: is the run still on?
local function onStop(fn) undo[#undo + 1] = fn end

local function keybind(data)
    local bind = binds[data.name]
    if bind then
        bind.onPressed, bind.onReleased = data.onPressed, data.onReleased   -- this run's closures
        bind:disable(false)
    else
        bind = lib.addKeybind(data)
        binds[data.name] = bind
    end
    onStop(function() bind:disable(true) end)
end

local function handler(name, fn)
    local h = AddEventHandler(name, fn)
    onStop(function() RemoveEventHandler(h) end)
end

-- ── hands up (w_policejob checks this very clip before a search / cuffs) ──
if E.handsUp.enabled then
    local dict, clip = 'script_proc@robberies@homestead@lonnies_shack@deception', 'hands_up_loop'
    -- ★ The server cannot see an animation: the player's own client says whether his hands are up
    --   (his own consent to a search), so w_inventory can refuse a search of a man who is not down,
    --   not cuffed and not holding them up -- that check used to live on the searcher's client only.
    feature(function(r)
        CreateThread(function()
            local up = nil
            while alive(r) do
                -- a named BOOL native answers 1 / false here: `== true` alone never saw the hands up (4.1.5)
                local playing = IsEntityPlayingAnim(ped(), dict, clip, 3)
                local now = playing == true or playing == 1
                if now ~= up then
                    up = now
                    LocalPlayer.state:set('handsUp', now, true)
                end
                Wait(500)
            end
            LocalPlayer.state:set('handsUp', false, true)
        end)
    end)
    feature(function() -- the label is a locale string: see L above
        keybind({
            name = 'handsup',
            description = L('keybinds.handsup'),
            defaultKey = E.handsUp.key,
            onPressed = function()
                local p = ped()
                -- a BOOL native may answer 0 / 1: 0 is truthy in Lua, so every check compares with 1 / true (4.1.5)
                local function yes(v) return v == true or v == 1 end
                if yes(IsEntityDead(p)) or yes(IsPedOnMount(p)) or yes(IsPedInAnyVehicle(p, false)) then return end
                -- IsPedLassoed is bound _ri: a free ped answers 0, which is truthy, so X never raised the hands (4.1.5)
                if yes(IsPedLassoed(p)) then return end
                if not yes(IsEntityPlayingAnim(p, dict, clip, 3)) then
                    lib.requestAnimDict(dict)
                    TaskPlayAnim(p, dict, clip, 2.0, -2.0, -1, 67109393, 0.0, false, 1245184, false, 'UpperbodyFixup_filter', false)
                else
                    ClearPedSecondaryTask(p)
                end
            end,
        })
    end)
end

-- ── PVP ──
if E.pvp.enabled then
    feature(function(r)
        local pvp, relation, shown = true, 5, false
        local found   -- the PLAYER relationship before the first change: stop() puts it back
        CreateThread(function()
            while alive(r) do
                local now = GetRelationshipBetweenGroups(`PLAYER`, `PLAYER`)
                -- w_stables' ride-along (2026-11-08): while this player gets on behind another rider or into his
                -- wagon, or sits there, players are respected on this client (the game refuses a hostile rider's
                -- seat); the PvP relation comes back once the flag is false
                if now ~= relation and LocalPlayer.state.wRideAlong ~= true then
                    if found == nil then found = now end
                    NetworkSetFriendlyFireOption(pvp)
                    SetRelationshipBetweenGroups(relation, `PLAYER`, `PLAYER`)
                end
                Wait(1000)
            end
        end)
        onStop(function()
            if relation ~= 5 then Citizen.InvokeNative(0x949B2F9ED2917F5D, ped(), 6) end -- the toggle's flag back
            if shown then lib.hideTextUI() shown = false end
            if found ~= nil then SetRelationshipBetweenGroups(found, `PLAYER`, `PLAYER`) end
        end)
        if E.pvp.toggle then
            local function showOff()
                lib.showTextUI(L('pvp.disabled'), { position = 'top-center', icon = 'skull' })
                shown = true
            end
            keybind({ -- the label is a locale string: see L above
                name = 'togglepvp',
                description = L('keybinds.toggle_pvp'),
                defaultKey = E.pvp.key,
                onReleased = function()
                    pvp = not pvp
                    if relation == 5 then
                        Citizen.InvokeNative(0xB8DE69D9473B7593, ped(), 6) -- no choking
                        relation = 1
                    else
                        Citizen.InvokeNative(0x949B2F9ED2917F5D, ped(), 6)
                        relation = 5
                    end
                    if pvp then if shown then lib.hideTextUI() shown = false end else showOff() end
                end,
            })
            -- Wait(0): the new dictionary is loaded by another 'w_lib:setLocale' handler
            -- (imports/locale), registered after this one; redraw once it has run
            handler('w_lib:setLocale', function() Wait(0) if shown and alive(r) then lib.hideTextUI() showOff() end end)
        end
    end)
end

-- ── controls ──
-- start() runs once every file has loaded, so resource/frame/client.lua (lib.blockControl,
-- loaded after this folder) is there
feature(function(r)
    if E.controls.blockLeftAlt then
        lib.blockControl(KEY_LALT)
        onStop(function() lib.unblockControl(KEY_LALT) end)
    end
    if E.controls.blockWeaponWheel then
        lib.blockControl(KEY_TAB)
        onStop(function() lib.unblockControl(KEY_TAB) end)
    end
    if E.controls.blockSprintWhileAiming then
        CreateThread(function()
            while alive(r) do
                if IsAimCamActive() then -- a named BOOL native answers 1 / false
                    DisableControlAction(0, KEY_SHIFT, true)
                    Wait(0)
                else
                    Wait(150)
                end
            end
        end)
    end
end)

-- ── the game's challenge toasts ──
if E.hideChallengeToasts then
    local hidden = { [`EVENT_CHALLENGE_GOAL_COMPLETE`] = true, [`EVENT_CHALLENGE_REWARD`] = true,
                     [`EVENT_DAILY_CHALLENGE_STREAK_COMPLETED`] = true }
    feature(function(r)
        CreateThread(function()
            while still(r, 0) do
                local count = Citizen.InvokeNative(0x5CE8DE5909565748, 0, Citizen.ResultAsInteger()) or 0
                for i = 0, count - 1 do
                    if hidden[Citizen.InvokeNative(0xA85E614430EFF816, 0, i, Citizen.ResultAsInteger())] then
                        Citizen.InvokeNative(0x6035E8FBCA32AC5E) -- UiFeedClearAllChannels
                        break
                    end
                end
            end
        end)
    end)
end

-- ── scenario blacklist ──
-- stop() ends the loop only: the game's own state of a scenario is not readable, so nothing
-- is switched back on
if next(E.blacklistedScenarios.types) or next(E.blacklistedScenarios.groups) then
    feature(function(r)
        CreateThread(function()
            while alive(r) do
                for _, t in pairs(E.blacklistedScenarios.types) do SetScenarioTypeEnabled(t, false) end
                for _, g in pairs(E.blacklistedScenarios.groups) do SetScenarioGroupEnabled(g, false) end
                Wait(10000)
            end
        end)
    end)
end

-- ── stuck wagons ──
if E.stuckWagons.enabled then
    feature(function(r)
        CreateThread(function()
            while alive(r) do
                for _, veh in ipairs(GetGamePool('CVehicle')) do
                    if not still(r, 10) then return end
                    -- networked only: a local vehicle is a script's own (a stable's preview wagon, a
                    -- cutscene) and has no state bag, Entity(veh).state throws on it (native 0x3BB78F05)
                    if DoesEntityExist(veh) and NetworkGetEntityIsNetworked(veh) and IsVehicleStopped(veh) then
                        local state = Entity(veh).state
                        -- a player's wagon (w_stables) and a housing delivery stand on purpose
                        -- 4.4.3 (2026-11-08): only the game's own traffic is cleaned. A wagon a script made (population
                        -- type 7 / 8 or a mission entity: w_jobs' wagon frozen at its bay while its team idles, a heist
                        -- coach, a mission delivery) stands on purpose; the job wagon vanished within 3 s of spawning.
                        local pop = GetEntityPopulationType(veh)
                        local scripted = pop == 7 or pop == 8 or IsEntityAMissionEntity(veh) or state.w_jobs ~= nil
                        if not scripted and not state.wHousingDelivery and not state.w_stables and not state.wagonUUID then
                            local horse = Citizen.InvokeNative(0xA8BA0BAE0173457B, veh, 0) -- the first draft animal
                            local driver = Citizen.InvokeNative(0x2963B5C1637E8A27, veh)
                            if horse and horse ~= 0 and (IsPedWalking(horse) or IsPedRunning(horse)) and driver ~= ped() then
                                if driver and driver ~= 0 then DeleteEntity(driver) end
                                DeleteEntity(veh)
                            end
                        end
                    end
                end
                Wait(math.max(1, E.stuckWagons.everySeconds) * 1000)
            end
        end)
    end)
end

-- ── recoil: every gun kicks the camera a little ──
if E.recoil.enabled and (E.recoil.amount or 0) > 0 then
    feature(function(r)
        CreateThread(function()
            while alive(r) do
                local p = ped()
                if IsPedShooting(p) then
                    local _, weapon = GetCurrentPedWeapon(p)
                    if weapon and IsWeaponAGun(weapon) then
                        local total = 0
                        repeat
                            if not still(r, 0) then return end
                            SetGameplayCamRelativePitch(GetGameplayCamRelativePitch() + 0.6, 1.2)
                            total = total + 0.6
                        until total >= E.recoil.amount
                    end
                end
                Wait(0)
            end
        end)
    end)
end

-- ── traffic ── (a per-frame setting: the game's own density is back the frame the loop ends)
if E.trafficDensity then
    feature(function(r)
        CreateThread(function()
            while alive(r) do
                Citizen.InvokeNative(0xFEDFA97638D61D4A, E.trafficDensity) -- parked vehicles
                Citizen.InvokeNative(0x1F91D44490E1EA0C, E.trafficDensity) -- random vehicles
                Citizen.InvokeNative(0x606374EBFC27B133, E.trafficDensity) -- vehicles
                Wait(0)
            end
        end)
    end)
end

-- ── teleports ──
if #E.teleports > 0 then
    feature(function()
        for i, pair in ipairs(E.teleports) do
            for k, point in ipairs(pair) do
                local target = pair[k == 1 and 2 or 1]
                if target then
                    local here = vector3(point.coords.x, point.coords.y, point.coords.z)
                    local busy, inside = false, false
                    local p = lib.points.new({ coords = here, distance = 1.2 })
                    function p:onEnter() inside = true lib.showTextUI('[J] ' .. locale(point.label)) end
                    function p:onExit() inside = false lib.hideTextUI() end
                    function p:nearby()
                        -- 4.1.0 (the owner): the game's glitter instead of DrawMarker, a ring of look 4 (imports/glow)
                        lib.glow.frame(('teleport:%d:%d'):format(i, k), 'circle', vector3(here.x, here.y, here.z - 0.98), 0.5, { look = 4 })
                        if not busy and IsControlJustReleased(0, 0xF3830D8E) then -- J (INPUT_OPEN_JOURNAL)
                            busy = true
                            SetEntityCoords(ped(), target.coords.x, target.coords.y, target.coords.z)
                            if target.coords.w then SetEntityHeading(ped(), target.coords.w) end
                            SetTimeout(1000, function() busy = false end)
                        end
                    end
                    -- remove() does not call onExit: the line is hidden here
                    onStop(function() p:remove() if inside then inside = false lib.hideTextUI() end end)
                else
                    lib.print.warn(('essentials: teleport %d point %d has no partner'):format(i, k))
                end
            end
        end
    end)
end

-- ── Discord presence ──
if E.discord.appId and E.discord.appId ~= '' then
    local function apply()
        SetDiscordAppId(E.discord.appId)
        SetDiscordRichPresenceAsset(E.discord.largeAsset)
        SetDiscordRichPresenceAssetText(L('discord.large_text'))
        SetDiscordRichPresenceAssetSmall(E.discord.smallAsset)
        SetDiscordRichPresenceAssetSmallText(L('discord.small_text'))
        for i = 1, math.min(#E.discord.buttons, 2) do
            local b = E.discord.buttons[i]
            if b.url and b.url ~= '' then SetDiscordRichPresenceAction(i - 1, locale(b.label), b.url) end
        end
        SetRichPresence(L('discord.players', GlobalState['w_lib:playerCount'] or 0, E.discord.maxPlayers))
    end
    feature(function(r)
        CreateThread(function() while alive(r) do apply() Wait(60000) end end)
        handler('w_lib:setLocale', function() Wait(0) if alive(r) then apply() end end) -- Wait(0): see the PVP handler
    end)
end

-- ── AFK kick ──
if E.afk.enabled then
    local warnAt = { [900] = true, [600] = true, [300] = true, [150] = true, [60] = true, [30] = true, [20] = true, [10] = true }
    local function warning(left)
        if left >= 120 then
            local m = math.ceil(left / 60)
            return L(m >= 11 and 'afk.kick_minutes_many' or 'afk.kick_minutes', m)
        elseif left == 60 then return L('afk.kick_minute') end
        return L(left >= 11 and 'afk.kick_seconds_many' or 'afk.kick_seconds', left)
    end
    feature(function(r)
        CreateThread(function()
            local last, left
            while still(r, 1000) do
                if LocalPlayer.state.isLoggedIn and not LocalPlayer.state['w_lib:afkExempt'] then
                    local pos = GetEntityCoords(ped(), true)
                    if last and #(pos - last) < 0.05 then
                        left = (left or E.afk.kickAfterSeconds) - 1
                        if warnAt[left] then lib.notify({ description = warning(left), type = 'error', duration = 10000 }) end
                        if left <= 0 then TriggerServerEvent('w_lib:essentials:afk', L('afk.kicked')) left = nil end
                    else
                        left = nil
                    end
                    last = pos
                else
                    last, left = nil, nil
                end
            end
        end)
    end)
end

-- ── the host switch: start on true, stop on anything else ──
local function start()
    if live then return end
    run = run + 1
    live = run
    for i = 1, #features do
        local ok, err = pcall(features[i], run)   -- one broken feature does not take the others down
        if not ok then lib.print.error(('essentials: a feature failed to start: %s'):format(err)) end
    end
end

local function stop()
    if not live then return end
    live = nil   -- every loop of the run ends at its next wake-up
    for i = #undo, 1, -1 do
        local ok, err = pcall(undo[i])
        if not ok then lib.print.error(('essentials: a feature failed to stop: %s'):format(err)) end
        undo[i] = nil
    end
end

local function follow(value) if value == true then start() else stop() end end

-- the handler runs before GlobalState holds the new value: it uses the value it is given
AddStateBagChangeHandler('w_lib:essentials', 'global', function(_, _, value) follow(value) end)
CreateThread(function() follow(GlobalState['w_lib:essentials']) end) -- after load: see L above
