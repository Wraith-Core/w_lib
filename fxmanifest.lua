fx_version 'cerulean'
use_experimental_fxv2_oal 'yes'
lua54 'yes'
games { 'rdr3', 'gta5' }
rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'

name 'w_lib'
author 'WraithStudio'
version '4.4.9'
-- Includes adaptations from ox_lib and jo_libs; preserve their original notices.
-- See CREDITS.md and LICENSES/ for upstream attribution and license copies.
license 'LGPL-3.0-or-later'
repository ''
description 'discord.gg/stellar | w_lib — one NUI frame for every interface: context, dialogs, notifications, text UI, menus, progress, skill check, prompt, gizmo and minigames, on the w_crafting design. Built on ox_lib and RedM-jo_libs — see CREDITS.md.'

dependencies {
    '/server:14901',
    '/onesync',
}

ui_page 'nui://w_lib/web/build/index.html'

files {
    -- ── w_lib imports / resource core / web NUI / locales ──
    'init.lua',
    'resource/console.lua',
    'resource/settings.lua',
    'imports/**/client.lua',
    'imports/**/shared.lua',
    'web/build/index.html',
    'web/build/**/*',
    'nui/**/*',
    'locales/*.json',
    -- dialect host layer: loaded by init.lua inside the core that provides rsg-core / vorp_core / qbr-core / ox_lib
    'compat/*.lua',

    -- ── modules loaded at runtime by w_init / NUI assets / locales ──
    'w_init.lua',
    'modules/**/*shared.lua',
    'modules/**/*client.lua',
    'modules/component/clothesList.lua',
    'modules/component/horseComponents.lua',
    'modules/component/data/horseComponents.lua',
    'modules/component/data/playerComponents.lua',
    'modules/component/data/tintShopItems.lua',
    'modules/game-events/data.lua',
    'modules/raw-keys/vk_azerty.lua',
    'modules/raw-keys/vk_qwerty.lua',
    'html/dist/**.html',
    'html/dist/**.js',
    'html/dist/**.css',
    'html/dist/**.ttf',
    'html/dist/**.png',
    'html/dist/**.mp3',
    'html/dist/**.gif',
    'locales_modules/**',
}

-- ── Cfx Asset Escrow ──────────────────────────────────────────────
-- The library loads most of its own code at runtime with LoadResourceFile + load():
-- init.lua (read by every consumer), w_init.lua, everything under imports/ and modules/,
-- and resource/settings.lua (read through require 'resource.settings'). LoadResourceFile
-- returns encrypted bytes unchanged, so an encrypted copy of any of those files fails at
-- start with "syntax error near '<\1>'". Only files the manifest lists as client/server/
-- shared scripts are decrypted by the runtime: that is the resource/ tree, which stays
-- encrypted. imports/ and modules/ are LGPL (ox_lib / jo_libs) and must stay readable anyway.
escrow_ignore {
    'init.lua',
    'w_init.lua',
    'compat/*.lua',
    'imports/**/*.lua',
    'modules/**/*.lua',
    'resource/settings.lua',
    'resource/console.lua',
    'locales/*.json',
    'locales_modules/*.json',
    'web/build/**/*',
    'html/dist/**/*',
    'README.md',
}

-- core module auto-load (w_init reads metadata key 'w_module')
w_module {
    'version-checker',
    'i18n',
}

-- ── w_lib core ──
shared_script 'resource/console.lua' -- first: the quiet console in w_lib itself (init.lua loads it into every consumer)
shared_script 'resource/init.lua'

shared_scripts {
    'resource/**/shared.lua',
    'w_init.lua',           -- compatibility module layer loaded after the w_lib core
}

client_scripts {
    'resource/**/client.lua',
    'resource/**/client/*.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'imports/callback/server.lua',
    'imports/hook/shared.lua',
    'imports/registerHook/shared.lua',
    'imports/getFilesInDirectory/server.lua',
    'resource/**/server.lua',
    'resource/**/server/*.lua',
}
