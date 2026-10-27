Run `npm install` and `npm test` here (Node.js 20+). The runner also accepts an existing Fengari installation under `tools/node_modules`.

The suite covers validation, normalization, locale characters, callback replies, asynchronous SQL, connection deferrals, resource restart, multichar registration, commands, deletion and state bags. Server files load in their actual manifest order. FiveM and oxmysql are simulated; an in-game smoke check remains necessary.

To compare observable calls against the pre-refactor monolithic server, run `node run.cjs --baseline <absolute-path-to-original-main.lua>`. Each scenario must produce the same trace for both implementations.

Inspired by https://github.com/esx-framework/esx_core/pull/1766 at 829ca297034d3ea416d28f0ce9e0cec97a9e32c3. Only the server module organization is adopted; local behavior, client/UI, configuration and package files are retained.
