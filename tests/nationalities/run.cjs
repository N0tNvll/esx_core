const fs = require('node:fs');
const path = require('node:path');
let fengari;
try { fengari = require('fengari'); } catch { fengari = require('../../tools/node_modules/fengari'); }
const { lua, lauxlib, lualib, to_luastring, to_jsstring } = fengari;
const state = lauxlib.luaL_newstate();
lualib.luaL_openlibs(state);
function push(value) {
  if (value == null) lua.lua_pushnil(state);
  else if (typeof value === 'string') lua.lua_pushstring(state, to_luastring(value));
  else if (typeof value === 'number') lua.lua_pushnumber(state, value);
  else if (typeof value === 'boolean') lua.lua_pushboolean(state, value);
  else {
    lua.lua_newtable(state);
    for (const [key, item] of Object.entries(value)) {
      push(item);
      if (Array.isArray(value)) lua.lua_seti(state, -2, Number(key) + 1);
      else lua.lua_setfield(state, -2, to_luastring(key));
    }
  }
}
const root = path.resolve(__dirname, '../..');
const files = {
  nationality: 'esx_lib/imports/nationality/shared.lua',
  base: 'es_extended/server/classes/player/base.lua',
  player: 'es_extended/server/classes/player.lua',
  context: 'es_extended/server/modules/player/session/context.lua',
  create: 'es_extended/server/modules/player/session/runtime/create.lua',
  load: 'es_extended/server/modules/player/session/runtime/load.lua',
  save: 'es_extended/server/modules/player/save.lua',
  schema: 'esx_lib/imports/schema/server.lua',
  migration: 'es_extended/server/migration/v1.17.1/nationality/main.lua',
  catalog: 'esx_lib/imports/catalog/server.lua',
};
const sources = {};
for (const [name, file] of Object.entries(files)) {
  const source = fs.readFileSync(path.join(root, '[core]', file), 'utf8').replace(/\s*<const>/g, '');
  if (lauxlib.luaL_loadstring(state, to_luastring(source)) !== lua.LUA_OK) throw Error(`${file}: ${to_jsstring(lua.lua_tostring(state, -1))}`);
  lua.lua_pop(state, 1);
  sources[name] = source;
}
push(sources); lua.lua_setglobal(state, to_luastring('SOURCES'));
push(JSON.parse(fs.readFileSync(path.join(root, '[core]/esx_lib/imports/nationality/countries.json'))));
lua.lua_setglobal(state, to_luastring('COUNTRIES'));
const catalog = JSON.parse(fs.readFileSync(path.join(root, '[core]/esx_lib/imports/catalog/data.json')));
push(catalog.resources.es_extended.columns.find((column) => column.table === 'users' && column.name === 'nationality'));
lua.lua_setglobal(state, to_luastring('NATIONALITY_COLUMN'));
if (lauxlib.luaL_loadfile(state, path.join(__dirname, 'persistence.lua')) !== lua.LUA_OK || lua.lua_pcall(state, 0, 0, 0) !== lua.LUA_OK) throw Error(to_jsstring(lua.lua_tostring(state, -1)));
console.log(`${Object.keys(files).length} Lua modules parsed.`);
