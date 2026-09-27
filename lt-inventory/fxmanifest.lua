fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'lt-inventory'
author 'Lior Tools'
description 'Lior Tools — Inventory (QBCore). Cinematic monochrome UI, server-authoritative.'
version '1.0.0'

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
    'html/images/*.png',
    'html/images/*.jpg',
    'html/images/*.webp'
}

dependencies {
    'qb-core',
    'oxmysql'
}
