# DS-17.8 — Data-model P0 safety fixes

**Status:** executed 2026-11-18.  
**Result:** `docs/DS-17-08-DATA-MODEL-P0-SAFETY-RESULT.md`  
**Depends on:** DS-17.7  
**Blocks:** S1 migration, V-2 sign-off where noted, IMP-1B11  
**Source:** `docs/DS-17-07-DATA-MODEL-RECONCILIATION-RESULT.md`

## Why

DS-17.6A found data-loss, stale-read, and decode-budget risks in the storage and
query path. These are not feature work. They must be fixed before migration or
legacy retirement.

## Scope

Fix only:

| ID | Fix |
|---|---|
| P0-1 | Dirty flush must not delete a zone block when the legacy source is empty |
| P0-3 | Prune/filter stale block zones after heatmap clear/cap |
| P0-4 | `PrintHeatmap` must handle a Journey-only zone without `cells` |
| P0-5 | Cap `mobZones` refs or restrict fallback to the current zone |
| P0-6 | Scope `journeyDecodedBlocks` per login/character |
| P0-7 | Align `journey.schema` with `storageSchema`/`dataSchema` |

Do **not** implement P0-2 block payload v2 completeness. That is S8 and depends
on the migration slices.

## Required behavior

### P0-1 — Flush safety

- A dirty flush with an empty legacy source must not delete an existing block.
- Either skip deletion or rebuild from the existing block.
- Add a regression test that proves a block survives a legacy-empty flush.

### P0-3 — Stale blocks

- After heatmap clear or legacy heatmap cap, Journey block zones must not
  reappear in the heatmap selector, `GetHeatmapZones`, or commands.
- Choose one rule:
  - prune `blockIndex` with heatmap retention/clear; or
  - filter Journey-only zones to currently retained legacy maps.
- Add a test with a Journey-only block after clear/cap.

### P0-4 — `PrintHeatmap`

- Guard `zone.cells == nil`.
- Use `GetJourneyHeatmapCells` or print a clear “no legacy cells” message.
- Add a command test for a Journey-only zone.

### P0-5 — `mobZones`

- Enforce the DS-17.5 ≤4 zone-ref cap for cold fallback, or make fallback
  current-zone-only.
- Add a multi-zone tooltip decode-budget test.

### P0-6 — Decode counter

- Reset `journeyDecodedBlocks` on login/character switch.
- Keep a per-login counter for the zero-decode assertion.
- Add a test that a previous session/character does not leak counts.

### P0-7 — Schema alignment

- Retire independent `journey.schema`, or validate it against
  `storageSchema`/`dataSchema`.
- No load should accept conflicting schema numbers silently.
- Add a load/migration test.

## Implementation contract

- P0-1: when a dirty flush finds an existing block but the legacy source has no
  records/cells, keep the block and its index. Do not delete it. Deletion is
  explicit reset/compaction only.
- P0-3: `GetJourneyHeatmapZones` must filter to map IDs still present in
  `char.heatmaps`. `ClearHeatmaps` and heatmap-cap removal must zero
  `blockIndex.heatmapKills/lastSeen` and mark that map dirty. If a removed map's
  block has no mob records (`count == 0`), delete the heatmap-only block and
  index entry immediately; if it has mob records, keep the block and let the
  dirty flush strip cells.
- P0-4: `PrintHeatmap` must fall back to `GetJourneyHeatmapCells` for a
  `journeySource` zone and tolerate `cells = nil`. `CountCells` must accept both
  numeric cells and `{kills=...}` cells.
- P0-5: cap `journey.mobZones[mobKey]` to 4 deterministic sorted refs after the
  flush index is built. Current-zone lookup remains first.
- P0-6: `StartSession` resets `journeyDecodedBlocks` and clears the block cache.
- P0-7: `journey.schema` is the data-model revision and must be 2, aligned with
  `storageSchema = 2`; update the Journey test accordingly.

## Test contract

`tests/p0_data_model_safety.lua` must cover:

1. block survives a legacy-empty dirty flush and its index is unchanged;
2. clear/cap hides stale Journey zones and removes heatmap-only blocks while
   preserving mob-bearing blocks;
3. Journey-only `PrintHeatmap` does not error and can read block cells;
4. `mobZones` is capped to 4;
5. `StartSession` resets decode count and cache;
6. `journey.schema == storageSchema == 2`.

## Rollback

Each fix is isolated. No schema migration is required. If a fix regresses, revert
only its code path and keep the regression test as the acceptance target.

## Conflict boundary

- No owner migration (S1/S2), no block payload v2 work, no UI feature work.
- No account Knowledge/ALT.
- Do not edit DS-17.7 result; this task implements only the listed fixes.
- Update `docs/NEXT-TASK.md`, `PLAN.md`, and a P0 result doc only after tests pass.

## Tests

- `tests/p0_data_model_safety.lua` (new), covering P0-1, P0-3, P0-4, P0-5, P0-6,
  P0-7.
- Existing storage/tooltip/heatmap/command tests remain green.
- Full `./tests/run_all.sh`.

## Acceptance

- Block survives a legacy-empty flush.
- Clear/cap does not resurrect stale Journey zones.
- Journey-only heatmap command does not error.
- Cold fallback has a bounded block decode count.
- Decode counter is per-login/character.
- Schema conflict fails safely.
- No feature/UI/account Knowledge changes.
- No legacy retirement.

## Not required

- P0-2 block payload migration;
- S1/S2 owner migration;
- account Knowledge/ALT;
- route/UI feature work;
- live client test.
