# G-1A — Coordinate source and policy review

**Status:** executed 2026-11-17; review only.  
**Result:** `docs/G-1A-COORDINATE-REVIEW-RESULT.md`  
**Next:** G-1B authorized.  
**Depends on:** G-3, H64-9-F5, SC-1  
**Blocks:** G-1B (now authorized)  
**Follow-up:** V-3 only if G-1B lands

## Why

G-2/G-3 settled the durable 64×64 grid. The remaining accuracy question is not
resolution but **where a coordinate came from and when it was read**.

Initial review found that the heatmap kill path does not read the player
position at kill time. It reuses the position stored when the target or
mouseover was captured. If the player moves between acquiring the target and the
kill, the heatmap cell can be stale.

G-1A decides the policy. G-1B implements it only if the decision calls for a
change.

## Current coordinate paths

| Path | Source | Read time | Used for |
|---|---|---|---|
| `GetPlayerMapPosition` | `C_Map.GetPlayerMapPosition(mapID, "player")`, legacy `GetPlayerMapPosition("player")` | call time | shared position |
| `CaptureUnit("target")` | player map position | target-change time | last target, heatmap kill snapshot |
| `CaptureUnit("mouseover")` | player map position | mouseover-change time | last mouseover, heatmap kill snapshot |
| Nameplate sighting | player map position | plate-added time | respawn sighting only |
| `HandlePlayerDeath` | player map position | player-death time | death record |
| `OnJourneyQuestTurnIn` | player map position | turn-in time | quest anchor |
| `RecordKill` | `info.x` / `info.y` from the candidate snapshot | kill commit | heatmap cell (no fresh read) |

All stored positions are normalized player positions on the current map. There
is no unit position, world position, or map-dimension conversion in the current
path.

`GetMapID()` resolves only attributable zone maps (`mapType` 3/4) and returns
`0` for non-attributable maps. `GetPlayerMapPosition()` therefore returns `nil`
in instances. G-1A must confirm this instead of adding a duplicate instance
filter.

## Findings to confirm

1. **Heatmap coordinates are acquisition snapshots, not kill-time positions.**
   `CaptureUnit` stores `x`/`y`; `CopyInfo` carries them into pending deaths and
   chat kills; `RecordKill` passes them to `RecordHeatmapKill`.
2. **Staleness is not bounded by the chat window.** `FindDeathCandidate`
   accepts an exact-GUID `lastTarget` regardless of age, and the dead-target
   fallback accepts a target up to 10 seconds old. The 60-second `lastTarget`
   cleanup only runs when a capture fails.
3. **Death coordinates are already read at death.** `HandlePlayerDeath` should
   remain authoritative.
4. **Quest anchors are already read at turn-in.** No change is expected.
5. **Nameplates only feed respawn sightings.** They must not become a second
   heatmap write path.
6. **`GetPlayerMapPosition` already guards the dangerous cases:** nil/secret
   position objects, `GetXY`/`.x`/`.y` shapes, legacy `0,0`, non-finite or
   out-of-range coordinates, and missing/non-positive map IDs.
7. **Map transitions and instances are the main edge risk.** A position and a
   map ID must belong together.
8. **Instance heatmaps follow map attribution.** Non-attributable instance maps
   (`mapType` 1/2) return `GetMapID() == 0`, so no world-map cell is written.
   Attributable instance maps (`mapType` 4, such as a real dungeon UI map) keep
   their own heatmap entry. Do not blanket-skip `inInstance`.
9. **`RecordKill` is the only heatmap accounting point.** The late-chat
   `add_xp` path calls `AddKillXP`, not `RecordKill`.
10. **Group-kill policy is undecided.** Either keep the local player position
    or skip heatmap cells for remote group kills; never query group members.

## Existing coverage

| Test | Covers | Gap |
|---|---|---|
| `heatmap_lazy_zone.lua` | direct `RecordHeatmapKill` writes, cache behavior | does not exercise the `RecordKill` path |
| `smoke.lua` | target changes, deaths, direct `RecordKill`, heatmap writes | no “acquire at A, move to B, kill at B” case |
| `quest_anchors.lua` | quest positions and missing-position behavior | not heatmap kill coordinates |
| `history_view.lua` | death records | not heatmap kill coordinates |

G-1B must add a focused movement test; the existing suite would not catch the
stale-snapshot defect.

## Decisions G-1A must make

| ID | Decision | Recommended answer | Why it matters |
|---|---|---|---|
| D1 | Kill-time or engagement-time heatmap? | Kill-time player position. | Changes what the heatmap means. |
| D2 | Replace stale snapshots only, or fill missing positions too? | Replace-only. | Filling missing positions increases coverage and changes test baselines. |
| D3 | Group-kill heatmap policy? | Keep the local player's position; no group lookup. | Remote group kills could otherwise appear at the player's location. |
| D4 | Map changes between capture and commit? | Skip the cell. | Prevents a cell in the wrong zone. |
| D5 | May the refresh change zone/instance attribution? | No. Heatmap-only. | Prevents a display fix from becoming a migration. |
| D6 | Instance/vehicle behavior? | Non-attributable instance: no world-map cell. Attributable instance map: keep its own heatmap entry. Vehicle: keep the player map position; no separate path. | Avoids duplicate filters and preserves real dungeon heatmaps. |
| D7 | Adopt `UnitPosition` / `C_Map.GetMapPosFromWorldPos`? | Not now. | Avoids client-specific world-to-map conversion risk. |

No code should be written until D1–D7 are answered.

## Work items

1. Trace every `x`/`y` write and read:
   - `CaptureUnit`;
   - `CopyInfo`;
   - pending-death and chat-kill paths;
   - `RecordKill`;
   - `RecordHeatmapKill`;
   - death and quest-anchor paths.
2. Confirm map/position pairing at map transitions, instances, and vehicles.
3. Check `HandlePlayerDeath`, `RecordDeath`, and `NormalizeDeaths` for instance
   and nil-map behavior.
4. Check nameplate sightings cannot write heatmap cells.
5. Review `GetPlayerMapPosition` and `ReadPosition` against current and legacy
   client APIs.
6. Confirm `source` (`chat`, `death`, tests) and the `AddKillXP` late-chat path
   cannot produce a second heatmap write.
7. Resolve D1–D7 and write the decision table.
8. Produce the test plan for G-1B. Do not implement it here.

## Output

- completed coordinate-source table;
- edge-case table for nil, `0,0`, out-of-range, map transition, instance,
  vehicle, nameplate, death-commit delay, and late-chat `add_xp`;
- explicit D1–D7 decision table;
- G-1B test plan, or a “no change” decision.

## Acceptance

- Coordinate-source and edge-case tables are complete.
- D1–D7 are explicit.
- Either “no change” is recorded, or G-1B is authorized with a narrow policy.
- No code, grid, schema, UI, or attribution change in G-1A.
- Live comparison remains deferred to V-3.

## Not required

- implementation;
- live client test;
- new map database;
- unit/world-position conversion;
- grid/schema change;
- per-kill coordinate storage;
- account Knowledge.
