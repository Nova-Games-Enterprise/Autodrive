fx_version 'cerulean'
game 'gta5'
name 'NGE Autodrive'
author 'Nova Games Enterprise; original implementation by Bacasuoro'
description 'Experimental, regression-tested vehicle assistance foundation for FiveM'
version '2.0.0-dev.1'

shared_scripts { 'config.lua', 'shared/core.lua' }
client_scripts {
    'client/sensors.lua',
    'client/controller.lua',
    'client/hud.lua',
    'client/main.lua'
}
server_script 'server/main.lua'
ui_page 'html/index.html'
files { 'html/index.html', 'html/index.css', 'html/index.js' }
