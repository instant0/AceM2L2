# DS-17.12 — S2B context shape migration

**Status:** executed 2026-11-18.  
**Result:** `docs/DS-17-12-S2B-CONTEXT-SHAPE-RESULT.md`  
**Depends on:** DS-17.11  
**Blocks:** S3 zone/level ownership, later death/danger work  
**Source:** `docs/DS-17-07-DATA-MODEL-RECONCILIATION-RESULT.md`

## Goal

Move the v2 mob context model from the legacy keyed map to the target shape:

- `journey.mobs.contexts` as a deterministic array/list;
- separate `combat` and `xpContexts` views where the data supports them;
- top-8 + `other` retention for cold/compact use.

Legacy `db.mobs[key].contexts` remains the compatibility source until the reader
switch. No block payload or legacy retirement in this task.

## Context shape contract

`journey.mobs[key]` gets:

```text
contexts = { contextRecord... }       -- full deterministic array
combat = { contextRecord... }         -- combat/danger view
xpContexts = { contextRecord... }     -- XP view
contextsTop8 = { contextRecord... }   -- strongest 8
contextsOther = contextRecord         -- aggregate remainder
```

Each context record keeps:

- `key` (legacy context key);
- `playerLevel`, `mobLevel`, `groupSize`, `mapID`, `instanceKey`;
- `classification`, `buffSig`;
- `samples`, `sumBase`, `sumBuffed`, `sumTotal`;
- `minBase`, `maxBase`, `lastSeen`.

`combat` records carry the same inputs plus `healthKnown = false`; do not invent
deaths or health. `xpContexts` carries the XP fields.

Sorting: `samples` descending, then `key` ascending. Top-8 keeps the first 8;
`contextsOther` sums samples/sums and min/max/lastSeen for the remainder. Totals
must be preserved exactly.

## Sync contract

- `migrateLegacyMob` converts keyed `mob.contexts` into this shape.
- Add `SyncModelMobContextsFromLegacy(mobKey)` that updates only the context
  fields and preserves v2-only fields such as mob-level samples.
- Add a post-observation sync hook in `Calibration.RecordObservation` using
  `info.mobKey`; if absent, skip (no guessed key). Use the context-only sync.
- Merge/delete/prune remain covered by the S2A full sync hooks.
- Bulk load sync rebuilds from final legacy contexts.
- `GetModelMob` exposes `contexts`, `combat`, `xpContexts`, `contextsTop8`, and
  `contextsOther`.

## Test contract

`tests/s2b_context_shape.lua` must cover arrays, combat/xp views, top-8+other
totals, migration, observation sync, merge/delete sync, idempotence, v2-only
reads, and no block/UI changes.

## Scope

- Migrate existing keyed `mob.contexts` into v2 array records.
- Add v2 context record fields already available:
  - `playerLevel`, `mobLevel`, `groupSize`, `mapID`, `instanceKey`,
    `classification`, `buffSig`;
  - `samples`, `sumBase`, `sumBuffed`, `sumTotal`, `minBase`, `maxBase`,
    `lastSeen`.
- Add `combat` and `xpContexts` arrays:
  - `combat` marks health/danger inputs unavailable until V-2;
  - `xpContexts` carries the XP sample fields.
- Keep top-8 + `other` as a deterministic cold summary:
  - sort by sample strength then key;
  - retain 8;
  - aggregate the rest into `other`.
- Sync contexts on observations and mob merge/delete via the S2A hooks.
- Keep legacy keyed contexts readable.
- Do not change block payload, UI readers, death records, or legacy retirement.

## Tests

`tests/s2b_context_shape.lua`:

- keyed legacy contexts migrate to a deterministic array;
- malformed/empty context records are skipped, not invented;
- `combat` and `xpContexts` are v2-shaped;
- top-8 + `other` preserves total samples/XP/min/max/lastSeen;
- context-only sync on observation preserves v2-only mob fields;
- context sync follows merge/delete;
- idempotent migration;
- v2-only context reads with legacy removed;
- no block/UI/retirement changes.

## Acceptance

- v2 contexts are arrays, not keyed maps.
- `combat`/`xpContexts` exist and are populated where data is available.
- Top-8+`other` preserves totals.
- Legacy keyed contexts remain a compatibility view.
- Full suite passes.
- No account Knowledge/ALT work.

## Not required

- real health/danger capture (V-2);
- block payload top-8 packing (S8);
- death/quest/respawn migration;
- legacy retirement;
- live client test.
