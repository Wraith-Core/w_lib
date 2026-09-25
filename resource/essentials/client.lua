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

-- ── hands up (w_policejob checks this very clip before a search / cuffs) ──
if E.handsUp.enabled then
    local dict, clip = 'script_proc@robberies@homestead@lonnies_shack@deception', 'hands_up_loop'
    CreateThread(function() -- the label is a locale string: see L above
        lib.addKeybind({
            name = 'handsup',
            description = L('keybinds.handsup'),
            defaultKey = E.handsUp.key,
            onPressed = function()
                local p = ped()
                if IsEntityDead(p) or IsPedOnMount(p) or IsPedInAnyVehicle(p, false) then return end
                if IsPedLassoed(p) then return end
                if not IsEntityPlayingAnim(p, dict, clip, 3) then
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
    local pvp, relation, shown = true, 5, false
    CreateThread(function()
        while true do
            if GetRelationshipBetweenGroups(`PLAYER`, `PLAYER`) ~= relation then
                NetworkSetFriendlyFireOption(pvp)
                SetRelationshipBetweenGroups(relation, `PLAYER`, `PLAYER`)
            end
            Wait(1000)
        end
    end)
    if E.pvp.toggle then
        local function showOff()
            lib.showTextUI(L('pvp.disabled'), { position = 'top-center', icon = 'skull' })
            shown = true
        end
        CreateThread(function() -- the label is a locale string: see L above
            lib.addKeybind({
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
        end)
        -- Wait(0): the new dictionary is loaded by another 'w_lib:setLocale' handler
        -- (imports/locale), registered after this one; redraw once it has run
        AddEventHandler('w_lib:setLocale', function() Wait(0) if shown then lib.hideTextUI() showOff() end end)
    end
end

-- ── controls ──
-- ⚠️ in a thread: resource/frame/client.lua (lib.blockControl) loads after this folder
CreateThread(function()
    if E.controls.blockLeftAlt then lib.blockControl(KEY_LALT) end
    if E.controls.blockWeaponWheel then lib.blockControl(KEY_TAB) end
end)
if E.controls.blockSprintWhileAiming then
    CreateThread(function()
        while true do
            if IsAimCamActive() then -- a named BOOL native answers 1 / false
                DisableControlAction(0, KEY_SHIFT, true)
                Wait(0)
            else
                Wait(150)
            end
        end
    end)
end

-- ── the game's challenge toasts ──
if E.hideChallengeToasts then
    local hidden = { [`EVENT_CHALLENGE_GOAL_COMPLETE`] = true, [`EVENT_CHALLENGE_REWARD`] = true,
                     [`EVENT_DAILY_CHALLENGE_STREAK_COMPLETED`] = true }
    CreateThread(function()
        while true do
            Wait(0)
            local count = Citizen.InvokeNative(0x5CE8DE5909565748, 0, Citizen.ResultAsInteger()) or 0
            for i = 0, count - 1 do
                if hidden[Citizen.InvokeNative(0xA85E614430EFF816, 0, i, Citizen.ResultAsInteger())] then
                    Citizen.InvokeNative(0x6035E8FBCA32AC5E) -- UiFeedClearAllChannels
                    break
                end
            end
        end
    end)
end

-- ── scenario blacklist ──
if next(E.blacklistedScenarios.types) or next(E.blacklistedScenarios.groups) then
    CreateThread(function()
        while true do
            for _, t in pairs(E.blacklistedScenarios.types) do SetScenarioTypeEnabled(t, false) end
            for _, g in pairs(E.blacklistedScenarios.groups) do SetScenarioGroupEnabled(g, false) end
            Wait(10000)
        end
    end)
end

-- ── stuck wagons ──
if E.stuckWagons.enabled then
    CreateThread(function()
        while true do
            for _, veh in ipairs(GetGamePool('CVehicle')) do
                Wait(10)
                -- networked only: a local vehicle is a script's own (a stable's preview wagon, a
                -- cutscene) and has no state bag, Entity(veh).state throws on it (native 0x3BB78F05)
                if DoesEntityExist(veh) and NetworkGetEntityIsNetworked(veh) and IsVehicleStopped(veh) then
                    local state = Entity(veh).state
                    -- a player's wagon (w_stables) and a housing delivery stand on purpose
                    if not state.wHousingDelivery and not state.w_stables and not state.wagonUUID then
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
end

-- ── recoil: every gun kicks the camera a little ──
if E.recoil.enabled and (E.recoil.amount or 0) > 0 then
    CreateThread(function()
        while true do
            local p = ped()
            if IsPedShooting(p) then
                local _, weapon = GetCurrentPedWeapon(p)
                if weapon and IsWeaponAGun(weapon) then
                    local total = 0
                    repeat
                        Wait(0)
                        SetGameplayCamRelativePitch(GetGameplayCamRelativePitch() + 0.6, 1.2)
                        total = total + 0.6
                    until total >= E.recoil.amount
                end
            end
            Wait(0)
        end
    end)
end

-- ── traffic ──
if E.trafficDensity then
    CreateThread(function()
        while true do
            Citizen.InvokeNative(0xFEDFA97638D61D4A, E.trafficDensity) -- parked vehicles
            Citizen.InvokeNative(0x1F91D44490E1EA0C, E.trafficDensity) -- random vehicles
            Citizen.InvokeNative(0x606374EBFC27B133, E.trafficDensity) -- vehicles
            Wait(0)
        end
    end)
end

-- ── teleports ──
for i, pair in ipairs(E.teleports) do
    for k, point in ipairs(pair) do
        local target = pair[k == 1 and 2 or 1]
        if target then
            local here = vector3(point.coords.x, point.coords.y, point.coords.z)
            local busy = false
            local p = lib.points.new({ coords = here, distance = 1.2 })
            function p:onEnter() lib.showTextUI('[E] ' .. locale(point.label)) end
            function p:onExit() lib.hideTextUI() end
            function p:nearby()
                Citizen.InvokeNative(0x2A32FAA57B937173, 0x6903B113, here.x, here.y, here.z - 0.98, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
                    1.0, 1.0, 0.9, 237, 230, 214, 155, false, false, 2, false, 0, 0, false) -- paper (tokens.css), was yellow
                if not busy and IsControlJustReleased(0, 0xCEFD9220) then -- E
                    busy = true
                    SetEntityCoords(ped(), target.coords.x, target.coords.y, target.coords.z)
                    if target.coords.w then SetEntityHeading(ped(), target.coords.w) end
                    SetTimeout(1000, function() busy = false end)
                end
            end
        else
            lib.print.warn(('essentials: teleport %d point %d has no partner'):format(i, k))
        end
    end
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
    CreateThread(function() while true do apply() Wait(60000) end end)
    AddEventHandler('w_lib:setLocale', function() Wait(0) apply() end) -- Wait(0): see the PVP handler
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
    CreateThread(function()
        local last, left
        while true do
            Wait(1000)
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
end
