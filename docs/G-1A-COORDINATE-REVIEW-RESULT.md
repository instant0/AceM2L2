# G-1A — Coordinate source and policy review result

**Status:** executed 2026-11-17  
**Scope:** static review and policy decision. No production code changed.  
**Result:** G-1B authorized as a heatmap-only, replace-only refresh.  
**Task:** `docs/tasks/G-1A-COORDINATE-REVIEW.md`

## 1. Coordinate-source table

| Path | Source | Read time | Map source | Used for |
|---|---|---|---|---|
| `GetPlayerMapPosition` | `C_Map.GetPlayerMapPosition(mapID, "player")`, legacy fallback | call time | `GetMapID()` | shared position |
| `CaptureUnit("target")` | player map position | target-change time | position map, else `GetMapID()` | `lastTarget`, heatmap snapshot |
| `CaptureUnit("mouseover")` | player map position | mouseover-change time | position map, else `GetMapID()` | `lastMouseover`, heatmap snapshot |
| Nameplate sighting | player map position | plate-added time | position map, else `GetMapID()` | respawn sighting only |
| `HandlePlayerDeath` | player map position | player-death time | current map | death record |
| `OnJourneyQuestTurnIn` | player map position | turn-in time | position map | quest anchor |
| `RecordKill` | `info.x` / `info.y` snapshot | kill commit | `info.mapID` | heatmap cell |
| `AddKillXP` | none | late-chat time | none | XP only; no heatmap write |
| Diagnostics | player map position | command time | current map | probe output only |

All positions are normalized player coordinates (`0..1`). The codebase does not
currently read unit position or world position.

### Map resolution

- `GetMapID()` resolves an attributable zone map (`mapType` 3/4).
- Non-attributable maps return `0`.
- `GetPlayerMapPosition()` therefore returns `nil` on non-attributable maps.
- Non-attributable instance maps get no world-map heatmap cell.
- Attributable instance maps (`mapType` 4, such as a real dungeon UI map) keep
  their own heatmap entry. A blanket `inInstance` skip would be wrong.

## 2. Findings

1. **Heatmap kill coordinates are acquisition snapshots.**
   `CaptureUnit` stores the player position; `CopyInfo` carries it through
   pending deaths and chat kills; `RecordKill` passes it to
   `RecordHeatmapKill` without a fresh read.
2. **Staleness is not bounded by the chat window.**
   `FindDeathCandidate` accepts an exact-GUID `lastTarget` regardless of age.
   The dead-target fallback accepts a target up to 10 seconds old. The
   60-second cleanup only runs when a capture fails.
3. **Death coordinates are correct.** `HandlePlayerDeath` reads the position at
   player death.
4. **Quest anchors are correct.** `OnJourneyQuestTurnIn` reads the position at
   turn-in.
5. **Nameplates are not a heatmap path.** They call `CaptureUnit` for respawn
   sightings only.
6. **One heatmap write per kill.** `RecordKill` is the sole accounting point;
   late-chat `add_xp` calls `AddKillXP`, which never touches the heatmap.
7. **Group kills use the local player snapshot.** No group-member position is
   queried.

## 3. Edge-case table

| Case | Current behavior | G-1B behavior |
|---|---|---|
| Nil or secret position | no coordinates; kill still counted; no cell | unchanged |
| Legacy `0,0` | rejected as unknown | unchanged |
| Out-of-range coordinate | rejected | unchanged |
| Map changes before kill commit | snapshot may be from the old map; cell can be written under the kill map with stale coordinates | skip the cell |
| Non-attributable instance | map ID `0`, position nil, no world-map cell; instance attribution preserved | unchanged |
| Attributable instance map | map ID retained; own heatmap entry | unchanged |
| Vehicle | player map position is expected; no separate path | unchanged; live confirmation only if a problem appears |
| Nameplate | respawn sighting only; no heatmap | unchanged |
| Death-commit delay (2.5s) | death-sourced kill reuses the target/mouseover acquisition snapshot | refresh at commit only when the fresh map matches |
| Late-chat `add_xp` | XP only; no second cell | unchanged |
| Group kill | local player position | keep local player position; no group lookup |

## 4. Decisions

| ID | Decision | Answer |
|---|---|---|
| D1 | Heatmap timing | **Kill-time player position.** |
| D2 | Snapshot coverage | **Replace-only.** Do not create cells for kills that had no usable snapshot. |
| D3 | Group kills | **Keep the local player's position.** No group lookup. |
| D4 | Map change before commit | **Skip the cell.** Never write under a different map. |
| D5 | Attribution | **No change.** Heatmap-only refresh. |
| D6 | Instance/vehicle | **Non-attributable instance: no world-map cell. Attributable instance map: keep its own heatmap entry. Vehicle: player map position.** |
| D7 | `UnitPosition` / world position | **Defer.** Revisit only if player position proves insufficient. |

## 5. G-1B authorization

G-1B may now implement one bounded change:

- at the `RecordHeatmapKill` call inside `RecordKill`, read
  `GetPlayerMapPosition()` once;
- refresh only when the candidate snapshot already has valid `x`/`y`;
- require the fresh map ID to equal the already-resolved kill map ID;
- pass fresh coordinates directly to `RecordHeatmapKill`;
- do not mutate `info.mapID`, `info.x`, `info.y`, `db.areas`,
  `mob.killsByMap`, or instance attribution;
- on fresh map mismatch, skip the cell;
- on a nil fresh read, keep the snapshot when it is valid on the same kill map;
- preserve exactly one heatmap write per kill.

### G-1B test plan

- target acquired at A, player moves to B on the same map, kill at B → cell B;
- fresh position nil, snapshot valid → snapshot fallback;
- snapshot absent → no cell even if a fresh position exists;
- map changes before commit → no cross-map cell;
- late-chat `add_xp` → exactly one cell;
- group kill → local player position under the chosen policy;
- non-attributable instance kill → no world-map cell; attributable instance map
  keeps its own cell;
- `db.areas` and `mob.killsByMap` unchanged;
- death and quest-anchor coordinates unchanged;
- coordinates remain within `0..1`;
- no per-kill record or schema field;
- focused test and full offline suite pass.

## 6. Existing coverage gap

The current suite does not catch the defect:

- `heatmap_lazy_zone.lua` writes heatmap cells directly;
- `smoke.lua` covers target changes, deaths, and direct `RecordKill` calls, but
  not movement between acquisition and kill;
- `quest_anchors.lua` covers quest positions;
- `history_view.lua` covers death records.

G-1B must add a focused movement test.

## 7. Limitations

- Static review only; no live client.
- Vehicle and instance behavior are based on the current API guards, not a live
  client trace.
- Group-kill policy is a product choice, not a measured behavior.
- `UnitPosition` / world-position conversion remains unevaluated beyond the
  decision to defer it.

## 8. Next

**G-1B — Heatmap commit-time position refresh** — executed 2026-11-18.
Result: `docs/G-1B-POSITION-REFRESH-RESULT.md`.

## Artifacts

- `docs/tasks/G-1A-COORDINATE-REVIEW.md`
- `docs/tasks/G-1B-POSITION-REFRESH.md`
- `docs/G-1A-COORDINATE-REVIEW-RESULT.md`
- `KillHistory/Util.lua`
- `KillHistory/World.lua`
- `KillHistory/Tracking.lua`
- `KillHistory/Journey.lua`
- `KillHistory/UI/Nameplates.lua`
