fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'lt-startscreen'
author 'Lior Tools'
description 'Lior Tools — Cinematic Loading Screen + Multicharacter + Spawn Selector (QBCore)'
version '1.0.0'

-- ┌──────────────────────────────────────────────────────────────┐
-- │  LOADING SCREEN                                               │
-- │  Shown during the connection/loading phase. Manual shutdown   │
-- │  lets us hand off seamlessly into the character selector      │
-- │  with zero black flashes.                                     │
-- └──────────────────────────────────────────────────────────────┘
loadscreen 'loadscreen/index.html'
loadscreen_manual_shutdown 'yes'

-- ┌──────────────────────────────────────────────────────────────┐
-- │  NUI  (Multicharacter + Spawn Selector share one page/router) │
-- └──────────────────────────────────────────────────────────────┘
ui_page 'ui/index.html'

shared_scripts {
    '@ox_lib/init.lua', -- optional, only used if present (see bridge/loader.lua)
    'config.lua'
}

client_scripts {
    'bridge/loader.lua',
    'client/utils.lua',
    'client/main.lua',
    'client/spawn.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'bridge/loader.lua',
    'server/main.lua'
}

files {
    -- Loading screen
    'loadscreen/index.html',
    'loadscreen/css/*.css',
    'loadscreen/js/*.js',
    'loadscreen/fonts/*.woff2',
    'loadscreen/assets/*.png',
    'loadscreen/assets/*.jpg',
    'loadscreen/assets/*.webp',
    'loadscreen/assets/*.mp4',

    -- NUI
    'ui/index.html',
    'ui/css/*.css',
    'ui/js/*.js',
    'ui/fonts/*.woff2',
    'ui/assets/*.png',
    'ui/assets/*.jpg',
    'ui/assets/*.webp',
    'ui/assets/loc/*.jpg',
    'ui/assets/portraits/*.jpg'
}

-- Optional dependencies are soft — the bridge degrades gracefully.
-- Hard requirement: qb-core + oxmysql.
dependencies {
    'qb-core',
    'oxmysql'
}
