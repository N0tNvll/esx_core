# Vehicle property snapshots

`ESX.Game.GetVehicleProperties` and `ESX.Game.SetVehicleProperties` alias
`xLib.game.getVehicleProperties` and `xLib.game.setVehicleProperties` in
`imports/game/client.lua`. Both APIs therefore use the same extended snapshot.
No database migration is needed for resources which already store the complete
properties table as JSON. Resources which whitelist fields must include the new
fields themselves.

## Additional fields

| Field | Value and behaviour |
| --- | --- |
| `oilLevel` | Oil volume as returned by the Cfx native, including zero. |
| `doorsAngleRatio` | Map of door ID to opening ratio, from 0 (closed) to 1 (open). Includes bonnet 4 and boot 5 even when passenger door IDs are sparse. |
| `tyreBurstComplete` | Map of tyre bone ID to boolean, distinguishing a puncture from a tyre destroyed down to its rim. `tyreBurst` remains the overall burst flag. |
| `wheelHealth` | Map of sequential physical wheel index to health. |
| `wheelsBroken` | Map of sequential physical wheel index to detached-wheel boolean. True entries detach wheels on the receiving vehicle. |
| `paintType1`, `paintType2` | Primary and secondary paint finishes, retained alongside indexed or custom RGB colours. |
| `paintFade` | Paint weathering effect, in the native's 0..1 range. |
| `driftTyres` | Drift tyre toggle on game builds 2372 and newer; omitted and ignored on older builds. |
| `customXenonColorEnabled` | Explicit RGB override flag, allowing a default-colour snapshot to clear an existing override. |
| `wheelSize`, `wheelWidth` | Dimensions of aftermarket wheels. FiveM returns zero for stock wheels, whose dimensions cannot be overridden with these natives. |
| `roofState` | Convertible roof enum. Stable open/closed states are restored instantly; transitions and stuck states settle to their corresponding open/closed position. Only emitted for animated convertibles. |
| `modNitrous`, `modSubwoofer`, `modHydraulics` | Toggle slots 17, 19 and 21. These are installed modification flags, not nitrous quantity or hydraulic suspension motion. |
| `modDoorR` | Modification slot 47. |
| `livery` | Native livery, independent of mod slot 48. |
| `modLiveryIndex` | Exact mod slot 48 index. `modLivery` retains its historical native-livery fallback for existing consumers. |

The existing `modLightbar` field is now applied by the setter, and
`modSmokeEnabled = false` disables tyre smoke instead of enabling it.
Indexed colours clear a previous custom RGB override.

## Indices and compatibility

Snapshot maps use string keys so JSON object round trips preserve index zero.
The setter accepts both string and numeric keys, including explicit zero and
false values. Invalid indices and non-finite values in the new numeric fields
are ignored.

Tyre natives use bone IDs `0..7`, plus `45` and `47` for additional trailer tyres.
Cfx wheel natives use sequential indices `0..GetVehicleNumberOfWheels() - 1`.
They must not be interchanged. All supported tyre IDs are sampled regardless of
wheel count; this includes bikes, trikes and vehicles with more than six wheels.

Old snapshots remain supported. Missing fields leave the corresponding state
alone. A legacy `tyreBurst = true` without `tyreBurstComplete` retains its former
on-rim behaviour. A modern snapshot preserves punctured versus destroyed tyres,
and `tyreBurst = false` repairs that tyre. Legacy `modLivery` still sets both
slot 48 and native livery; new snapshots preserve them independently.

## Limits

This is a snapshot of supported vehicle configuration and damage, not the whole
GTA entity. Position, speed, occupants, attachments, entity ownership, custom
state bags and resource-specific fuel/odometer data are outside this API.

- Existing engine, body and petrol-tank health, broken windows and broken doors
  remain included. Wheel health, missing wheels and tyre burst severity now
  supplement those fields.
- FiveM exposes queries for damaged headlights, detached/bouncing bumpers and
  deformation at individual points, but the documented natives do not provide
  a matching exact setter for each state or a complete mesh snapshot. These are
  not represented as restorable properties. `SetVehicleDamage` applies an impact;
  it does not restore an original deformation vector exactly.
- Detached doors and wheels can be reproduced on a freshly spawned vehicle.
  False entries do not reconstruct parts on an already damaged vehicle. This
  function does not call `SetVehicleFixed`, which would repair unrelated damage.
- Window sampling retains the existing behaviour of rolling windows up before
  checking whether they are intact. Window opening ratios are not persisted.
- Wheel alignment offsets require per-frame overrides according to the Cfx
  native documentation, so they are not added as one-shot snapshot properties.
- Roof animation progress and stuck-roof damage are not reproduced exactly.
  Partially open doors are restored with `SetVehicleDoorControl`; their subsequent
  movement remains subject to game physics.

## Validation

Run from the esx_core repository:

```sh
node tools/test-vehicle-properties.cjs
```

The regression cases execute the actual Lua module with mocked natives, including
JSON round trips, old snapshots, sparse door IDs, 2/3/4/6/8-wheel layouts, punctured
versus destroyed tyres, missing parts, independent liveries, custom paint and
explicit zero/false values. Actual rendering, door physics and network replication
still need an in-game check on the target FiveM artifact and vehicle models.

Sources checked:

- [FiveM vehicle native implementation](https://github.com/citizenfx/fivem/blob/master/code/components/extra-natives-five/src/VehicleExtraNatives.cpp)
- [Official GTA native definitions](https://runtime.fivem.net/doc/natives.json)
- [Official Cfx native definitions](https://runtime.fivem.net/doc/natives_cfx.json)
