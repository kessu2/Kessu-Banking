fx_version 'cerulean'
game 'gta5'

author 'kessu'
description 'FiveM Banking'

shared_scripts {
	'@ox_lib/init.lua',
	'config.lua',
}

client_script 'client/client.lua'
server_script 'server/server.lua'

ui_page 'html/index.html'

files {
	'html/index.html',
	'html/style.css',
	'locales/fi.lua',
	'locales/en.lua',
}