const fs = require('node:fs');
const path = require('node:path');
const assert = require('node:assert/strict');
let fengari;
try { fengari = require('fengari'); }
catch { fengari = require('../../tools/node_modules/fengari'); }
const { lua, lauxlib, lualib, to_luastring, to_jsstring } = fengari;
const root = path.resolve(__dirname, '../..');
const identity = path.join(root, '[core]/esx_identity');
const manifest = fs.readFileSync(path.join(identity, 'fxmanifest.lua'), 'utf8');
const serverScripts = manifest.match(/server_scripts\s*\{([\s\S]*?)\}/)[1];
const files = [...serverScripts.matchAll(/'(server\/[^']+\.lua)'/g)].map((match) => match[1]);
assert.equal(files[0], 'server/module/registry.lua');
assert.equal(files.at(-1), 'server/main.lua');
assert.equal(files.length, 10);
assert(serverScripts.indexOf('@esx_lib/imports/catalog/bootstrap.lua') < serverScripts.indexOf('server/module/registry.lua'));
const state = lauxlib.luaL_newstate();
lualib.luaL_openlibs(state);
function stringGlobal(name, value) {
  lua.lua_pushstring(state, to_luastring(value));
  lua.lua_setglobal(state, to_luastring(name));
}
lua.lua_newtable(state);
files.forEach((file, index) => {
  const source = fs.readFileSync(path.join(identity, file), 'utf8');
  if (lauxlib.luaL_loadstring(state, to_luastring(source)) !== lua.LUA_OK) {
    throw Error(`${file}: ${to_jsstring(lua.lua_tostring(state, -1))}`);
  }
  lua.lua_pop(state, 1);
  lua.lua_pushstring(state, to_luastring(source));
  lua.lua_seti(state, -2, index + 1);
});
lua.lua_setglobal(state, to_luastring('SOURCES'));
const validation = fs.readFileSync(path.join(root, '[core]/es_extended/shared/modules/validation.lua'), 'utf8')
  .replace('getmetatable(val)?.__call', '(getmetatable(val) and getmetatable(val).__call)');
stringGlobal('CORE_VALIDATION', validation);
const baselineIndex = process.argv.indexOf('--baseline');
if (baselineIndex !== -1) stringGlobal('BASELINE', fs.readFileSync(process.argv[baselineIndex + 1], 'utf8'));
if (lauxlib.luaL_loadfile(state, path.join(__dirname, 'behavior.lua')) !== lua.LUA_OK ||
    lua.lua_pcall(state, 0, 0, 0) !== lua.LUA_OK) {
  throw Error(to_jsstring(lua.lua_tostring(state, -1)));
}
console.log('10 server files parsed; manifest order checked.');
