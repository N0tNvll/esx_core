fx_version 'cerulean'

game 'gta5'
description 'The Core resource that provides the functionalities for all other resources.'
lua54 'yes'
version '1.14.1'

shared_scripts {
	'@esx_lib/imports.lua',
	'locale.lua',

	'shared/config/main.lua',
    'shared/config/weapons.lua',
	'shared/config/adjustments.lua',

    'shared/main.lua',
    'shared/functions.lua',
    'shared/modules/math.lua',
    'shared/modules/random.lua',
    'shared/modules/config.lua',
    'shared/modules/weapons.lua',
    'shared/modules/debug.lua',
    'shared/modules/validation.lua',
	'shared/compat.lua'
}

server_scripts {
	'@oxmysql/lib/MySQL.lua',
    'shared/config/logs.lua',

	'server/core.lua',
	'server/functions.lua',
	'server/modules/core/debug.lua',
	'server/modules/core/network.lua',
	'server/modules/player/lookup.lua',
	'server/modules/player/identity.lua',
	'server/modules/player/admin.lua',
	'server/modules/player/save.lua',
	'server/modules/commands/register.lua',
	'server/modules/commands/context.lua',
	'server/modules/logging/discord.lua',
	'server/modules/jobs/registry.lua',
	'server/modules/items/usable.lua',
	'server/modules/items/registry.lua',
	'server/modules/inventory/pickups.lua',
	'server/modules/player/overrides.lua',
	'server/common.lua',
	'server/modules/callback.lua',
	'server/modules/vehicle/types.lua',
	'server/classes/player/context.lua',
	'server/classes/player/base.lua',
	'server/classes/player/accounts.lua',
	'server/classes/player/inventory.lua',
	'server/classes/player/job.lua',
	'server/classes/player/weapons.lua',
	'server/classes/player/notifications.lua',
	'server/classes/player/metadata.lua',
	'server/classes/player.lua',
	'server/classes/player/static.lua',
	'server/classes/vehicle.lua',
	'server/classes/vehicle/state.lua',
	'server/classes/vehicle/create.lua',
	'server/classes/vehicle/getters.lua',
	'server/classes/vehicle/mutators.lua',
	'server/classes/vehicle/delete.lua',
	'server/modules/vehicle/extended.lua',
	'server/classes/overrides/*.lua',
	'server/modules/onesync.lua',
	'server/modules/paycheck.lua',

	'server/main.lua',
	'server/modules/player/session.lua',
	'server/modules/player/session/context.lua',
	'server/modules/player/session/load.lua',
	'server/modules/player/session/create.lua',
	'server/modules/player/session/drop.lua',
	'server/modules/player/session/join.lua',
	'server/modules/player/session/events.lua',
	'server/modules/inventory/events.lua',
	'server/modules/inventory/events/context.lua',
	'server/modules/inventory/events/ammo.lua',
	'server/modules/inventory/events/give.lua',
	'server/modules/inventory/events/remove.lua',
	'server/modules/inventory/events/use.lua',
	'server/modules/inventory/events/pickup.lua',
	'server/modules/callbacks/base.lua',
	'server/modules/system/resource_guard.lua',
	'server/modules/commands.lua',
	'server/modules/commands/admin_core.lua',
	'server/modules/commands/vehicles.lua',
	'server/modules/commands/accounts.lua',
	'server/modules/commands/inventory.lua',
	'server/modules/commands/system.lua',
	'server/modules/commands/admin_actions.lua',

	'server/bridge/**/*.lua',
	'server/modules/npwd.lua',
	'server/modules/createJob.lua',
	'server/migration/**/main.lua',
	'server/migration/main.lua',

	'server/compat.lua'
}

client_scripts {
    'client/main.lua',
	'client/functions.lua',
	'client/modules/core/events.lua',
	'client/modules/player/data.lua',
	'client/modules/player/spawn.lua',
	'client/modules/ui/addons.lua',
	'client/modules/ui/notifications.lua',
	'client/modules/ui/context.lua',
	'client/modules/ui/menu.lua',
	'client/modules/ui/inventory.lua',
	'client/modules/game/utils.lua',
	'client/modules/game/vehicle_types.lua',
	'client/modules/player/join.lua',
	'client/compat.lua',
	'client/modules/wrapper.lua',
	'client/modules/callback.lua',
    'client/modules/adjustments.lua',
	'client/modules/adjustments/hud.lua',
	'client/modules/adjustments/combat.lua',
	'client/modules/adjustments/world.lua',
	'client/modules/adjustments/vehicle.lua',
	'client/modules/adjustments/presence.lua',
	'client/modules/adjustments/load.lua',
	'client/modules/actions.lua',
	'client/modules/player/lifecycle.lua',
	'client/modules/vehicle/properties.lua',
	'client/modules/inventory/events.lua',
	'client/modules/inventory/sync.lua',
	'client/modules/inventory/pickups.lua',
	'client/modules/admin/tpm.lua',
	'client/modules/admin/noclip.lua',
	'client/modules/admin/commands.lua',
	'client/modules/death.lua',
	'client/modules/npwd.lua',
}

ui_page {
	'html/ui.html'
}

files {
	'imports.lua',
	'locales/*.lua',
	'locale.js',
	'html/ui.html',

	'html/css/app.css',

	'html/js/mustache.min.js',
	'html/js/wrapper.js',
	'html/js/app.js',

	'html/fonts/pdown.ttf',
	'html/fonts/bankgothic.ttf',
    "client/imports/*.lua",
}

dependencies {
	'/native:0x6AE51D4B',
    '/native:0xA61C8FC6',
	'oxmysql',
}
