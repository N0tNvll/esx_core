const fs = require('node:fs');
const path = require('node:path');
let fengari;
try { fengari = require('fengari'); }
catch { fengari = require('../../tools/node_modules/fengari'); }
const { lua, lauxlib, lualib, to_luastring, to_jsstring } = fengari;
const state = lauxlib.luaL_newstate();
lualib.luaL_openlibs(state);
const modules = { table: 'shared', class: 'shared', grid: 'shared', points: 'client', zones: 'shared' };
lua.lua_newtable(state);
for (const [name, side] of Object.entries(modules)) {
  const file = path.resolve(__dirname, '../../[core]/esx_lib/imports', name, `${side}.lua`);
  const source = fs.readFileSync(file, 'utf8').replace(/(\w+(?:\[[^\]]+\])?(?:\.\w+)*)\s*([+\-\/])=\s*([^\r\n]+)/g, '$1 = $1 $2 $3');
  if (lauxlib.luaL_loadstring(state, to_luastring(source)) !== lua.LUA_OK) {
    throw Error(`${file}: ${to_jsstring(lua.lua_tostring(state, -1))}`);
  }
  lua.lua_pop(state, 1);
  lua.lua_pushstring(state, to_luastring(source));
  lua.lua_setfield(state, -2, to_luastring(name));
}
lua.lua_setglobal(state, to_luastring('SOURCES'));
if (lauxlib.luaL_loadfile(state, path.join(__dirname, 'behavior.lua')) !== lua.LUA_OK ||
    lua.lua_pcall(state, 0, 0, 0) !== lua.LUA_OK) {
  throw Error(to_jsstring(lua.lua_tostring(state, -1)));
}
