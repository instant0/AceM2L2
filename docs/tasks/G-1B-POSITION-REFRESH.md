# G-1B — Heatmap commit-time position refresh

**Status:** executed 2026-11-18.  
**Result:** `docs/G-1B-POSITION-REFRESH-RESULT.md`  
**Depends on:** G-1A  
**Blocks:** V-3 (live confirmation)  
**Scope:** one bounded heatmap-only coordinate fix. No grid, schema, UI, or
attribution change.

## Authorization

G-1A authorized this task on 2026-11-17:

- D1 kill-time position;
- D2 replace-only coverage;
- D3 local player position for group kills;
- D4 skip the cell on a map change;
- D5 no attribution change;
- D6 non-attributable instance: no world-map cell; attributable instance map:
  keep its own heatmap entry; vehicle: player map position;
- D7 unit/world-position APIs deferred.

Result: `docs/G-1A-COORDINATE-REVIEW-RESULT.md`.

## Default policy

Unless G-1A decides otherwise:

- at the `RecordHeatmapKill` call inside `RecordKill`, read
  `GetPlayerMapPosition()` once;
- refresh **only when the candidate snapshot already has valid `x`/`y`**;
- use the fresh position only when its map ID equals the already-resolved kill
  map ID;
- pass fresh values directly to `RecordHeatmapKill`;
- do **not** mutate `info.mapID`, `info.x`, `info.y`, `db.areas`,
  `mob.killsByMap`, or instance attribution;
- if the fresh map differs from the kill map, skip the cell;
- if the fresh read is nil, keep the existing snapshot when it is valid on the
  same kill map;
- never create a cell for a kill that had no usable snapshot;
- keep exactly one heatmap write per kill; `add_xp` never writes.

This makes the heatmap mean “where the player was when the kill committed,”
while preserving existing coverage and attribution.

## Work items

1. Add the fresh read at the existing heatmap accounting point.
2. Keep the change local; do not refactor the kill pipeline.
3. Add a focused test file covering the policy below.
4. Update the relevant result/task docs.
5. Run the focused test and the full offline suite.

## Tests

- target acquired at A, player moves to B on the same map, kill at B → cell B;
- fresh position nil, snapshot valid → snapshot fallback;
- snapshot absent → no cell, even if a fresh position exists (replace-only);
- map changes between capture and commit → no cross-map cell;
- late-chat `add_xp` → still exactly one cell;
- group kill follows the G-1A policy, never a group member's position;
- non-attributable instance kill creates no world-map cell;
- attributable instance map keeps its own heatmap entry;
- `db.areas` and `mob.killsByMap` are unchanged;
- death and quest-anchor coordinates are unchanged;
- coordinates remain within `0..1`;
- no new per-kill record or schema field.

## Acceptance

- Only the selected policy is implemented.
- Movement within one map updates the heatmap cell.
- Cross-map and stale-map writes are impossible.
- Attribution is byte-for-byte unchanged.
- Focused test and full offline suite pass.
- No grid/schema/UI change.

## Rollback

Remove the fresh read and return to the candidate snapshot. No data migration is
needed because the stored representation does not change.

## Not required

- live client test;
- grid/schema change;
- unit/world-position conversion;
- per-kill coordinate storage;
- account Knowledge;
- death/quest-anchor changes.
