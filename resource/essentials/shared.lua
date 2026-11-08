--[[
    w_lib · essentials — the small server-wide behaviours that used to live in w_smallresources
    (merged 2026-09-24; that resource is gone). Only what no other resource already owns:

      kept here   hands up (w_policejob reads its clip), PVP, control blocks, the game's challenge
                  toasts, scenario blacklist, stuck-wagon cleanup, recoil, traffic density, teleports,
                  Discord presence, AFK kick, entity blacklist / ambient boats
      NOT here    Discord webhook logs (w_logs owns 'w_log:server:CreateLog'), HUD icons (w_hud
                  Config.Hide*Native), ped / animal density (w_survival sets it per region), the
                  binoculars / 'dual' items (the first did nothing, the second handed out weapons
                  outside the inventory)

    The host switch sits above every switch below: essentials runs only where the host is
    Wraith Core. A VORP host without w_core (MajestyRP) gets none of it.

      set w_lib:essentials "on" | "off"   (server.cfg) wins over the rule below
      not set                             ON when a resource named w_core exists, else OFF

    The server decides at start, again when w_core starts / stops or the convar changes, and
    replicates the answer as GlobalState['w_lib:essentials'] (true / false). A client starts
    nothing until it reads true (nil / false = off); when it turns false, the client ends its
    loops, lifts its control blocks, disables its keybinds and puts the PLAYER relationship
    back. Server side, OFF kicks nobody and cancels no spawn.

    Every switch is below and applies only under ON; a feature set to false does nothing at all.
]]

WEssentials = {
    handsUp = { enabled = true, key = 'x' },   -- rebindable (Settings > Key Bindings)

    -- friendly fire between players; togglePvp adds a rebindable key (default 8) to switch it off
    pvp = { enabled = true, toggle = false, key = '8' },

    controls = {
        blockLeftAlt = true,            -- the standalone game's money / gold bar
        blockSprintWhileAiming = true,  -- SHIFT moves faster while aiming
        blockWeaponWheel = false,       -- TAB (w_wheel replaces the wheel; keep false)
    },

    hideChallengeToasts = true,         -- the game's challenge / daily-streak notifications

    -- scenario type names ('WORLD_HUMAN_SIT_GROUND') and scenario group hashes never started
    blacklistedScenarios = { types = {}, groups = {} },

    -- a stopped wagon whose horses keep walking is stuck (OneSync): deleted every N seconds.
    -- A player's own wagon (w_stables), a w_housing delivery and any wagon a script made (w_jobs, heists) are never touched.
    stuckWagons = { enabled = true, everySeconds = 3 },

    recoil = { enabled = true, amount = 0.7 },   -- camera kick per shot of a gun (0 = none)

    trafficDensity = 0.3,               -- parked / random vehicles; nil = the game's default

    -- pairs of points: the E prompt on one sends the player to the other. label = locale key.
    -- { { coords = vector4(...), label = 'essentials.teleports.enter' }, { coords = ..., label = '...leave' } }
    teleports = {},

    discord = {
        appId = '',                     -- empty = no rich presence
        largeAsset = 'logo_name', smallAsset = 'logo_name', maxPlayers = 64,
        buttons = { { label = 'essentials.discord.button_connect', url = '' } },
    },

    afk = { enabled = true, kickAfterSeconds = 1800 },   -- staff (mod and above) is never kicked

    -- models that may never spawn (server entityCreating), and ambient boats
    blacklistEntities = {
        [`gatling_gun`] = true, [`gatlingMaxim02`] = true, [`breach_cannon`] = true,
        [`hotchkiss_cannon`] = true, [`policeWagongatling01x`] = true,
    },
    blockAmbientBoats = true,
}
