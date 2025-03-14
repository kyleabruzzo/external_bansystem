fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'Advanced Ban System'
author 'kyle'
version '1.0.2'
description 'The most advanced ban system you can find out there'

shared_scripts {
    '@ox_lib/init.lua',
    'require.lua',
    'init.lua',
    'shared/*.lua'
}

server_script '@oxmysql/lib/MySQL.lua'

ui_page 'web/index.html'

files {
    'modules/**/shared/*.lua',
    'modules/**/client.lua',
    'web/index.html',
    'web/**/*',
}

server_scripts {
    'shared/secure_config.lua'
}
