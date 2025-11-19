fx_version 'cerulean'
game 'gta5'

name 'AFAS'
author 'Bacasuoro'
description 'Autopilot, ADAS, retrocamera e HUD per veicoli selezionati'
version '1.0.0'

lua54 'yes'

shared_script 'config.lua'

client_scripts {
    'client.lua'
}

server_scripts {
    'server.lua'
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/index.css',
    'html/reset.css',
    'html/index.js'
}
