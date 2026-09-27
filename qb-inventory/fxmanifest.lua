fx_version 'cerulean'
game 'gta5'
lua54 'yes'

-- NOTE: the FOLDER/resource name MUST be `qb-inventory` because qb-core and
-- many scripts (qb-radio, etc.) call exports['qb-inventory'] by that exact
-- name. This is the Lior Tools inventory acting as a full drop-in replacement.
name 'qb-inventory'
author 'Lior Tools'
description 'Lior Tools — Inventory (QBCore drop-in). Cinematic monochrome UI, server-authoritative.'
version '1.0.0'
provide 'qb-inventory'

ui_page 'html/index.html'

shared_scripts {
    'config.lua',
    'shared/items.lua'
}

client_scripts {
    'client/main.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua',
    'server/containers.lua'
}

files {
    'html/index.html',
    'html/css/*.css',
    'html/js/*.js',
    'html/fonts/*.woff2',
    'html/assets/*.png',
    'html/assets/*.jpg',
    'html/images/*.png'
}

dependencies {
    'qb-core',
    'oxmysql'
}
