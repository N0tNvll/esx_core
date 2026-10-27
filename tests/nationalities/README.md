Run `npm install` and `npm test` here (Node.js 20+). The Lua runner can also use the existing Fengari installation under `tools/node_modules`. Run `node ../identity-modules/run.cjs` for registration and compatibility checks.

Browser smoke: install Playwright separately or set `PLAYWRIGHT_PATH` to its module directory, then run `node browser.cjs <screenshot-directory>`. It serves the built UI on loopback, tests all eight UI locales, mobile layout and the NUI registration payload using Edge. Set `BROWSER_ONLY_MOBILE=1` for only mobile and payload checks.

The countries from PR #1746 are shared between the server and UI through `esx_lib/imports/nationality/countries.json`. Stored values are canonical country names such as `Spain`; visible labels use the selected language. New registrations require a listed country. Existing characters retain NULL when unspecified, with no forced country or registration reset.

API: `xPlayer.getNationality()` returns a country or nil. `xPlayer.setNationality("Spain")` validates and returns true; invalid input returns false without changes. Passing nil clears it. The usual core saves persist the field, and changing it invalidates the unchanged-save fingerprint. There is no per-change SQL write. Client data and the `nationality` state bag are synchronized.

The core SQL startup catalog ensures the nullable column exists before player queries. An independently idempotent `v1.17.1/nationality` migration also checks it; previous version completion markers do not skip it. Fresh installation SQL is updated. Deploy `esx_lib`, `es_extended` and `esx_identity` together and restart the server. No SQL has been run on a live server by these tests.

Lua tests use actual core construction, creation, loading, save queue and schema/catalog code with simulated FiveM/oxmysql. An in-game smoke test against the live database remains necessary.
