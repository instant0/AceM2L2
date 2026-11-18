# DS-17.7 — Data-model reconciliation and migration plan

**Status:** executed 2026-11-18; decision only.  
**Result:** `docs/DS-17-07-DATA-MODEL-RECONCILIATION-RESULT.md`  
**Depends on:** DS-17.6A, DS-11, DS-17.5, CAP-1, IMP-1A/B, DS-14/15/16  
**Blocks:** P0 safety fixes, V-2 scope, migration implementation, IMP-1B11 retirement  
**Related:** `docs/tasks/V-2-LIVE-VERIFICATION.md`

## Why

DS-17.6A proved that production does **not** implement the DS-17.5 v2 Journey.
The real store is v1 legacy aggregates plus an additive `journey` overlay and
schema-2 block machinery.

The codec/storage work is valid. The data-model migration is not. Before any
more feature work, one task must decide:

- which production fields are canonical;
- which DS-17.5 target fields are adopted;
- which legacy fields become derived caches or are retired;
- how the migration is split into safe implementation slices;
- which fields need V-2 live API/availability checks before implementation.

## Relationship to V-2

V-2 is **live-only residual verification**. It is not a general test phase and
not a data-model implementation gate.

V-2 currently covers:

1. real combat event ordering and killer attribution;
2. health, buffs, group size, and rested values under combat;
3. presence/engaged timing under real event sequences;
4. heatmap cell XP/time capture under real kills;
5. real SavedVariables write/load timing and size;
6. actual `SAVED_VARIABLES_TOO_LARGE` behavior;
7. Midnight secret-value behavior;
8. LoadOnDemand companion timing;
9. visual/frame behavior.

After DS-17.6A, some of those fields are **not implemented in production**.
V-2 cannot validate a field that does not exist.

DS-17.7 must split V-2 into:

- **V-2A — API/field availability probes:** can run after DS-17.7 defines the
  target fields. No implementation dependency.
- **V-2B — implemented-capture validation:** runs after the relevant migration
  slice lands.
- **V-2C — save/load/oversize/companion validation:** runs after storage changes.
- **V-2D — visual/frame checks:** independent.

No full V-2 sign-off until field ownership and migration slices are defined.

## Inputs

- `docs/DS-17-06A-DATA-MODEL-VALIDATION-RESULT.md`
- `docs/audits/DS-17-06A1-FIELD-OWNERSHIP.md`
- `docs/audits/DS-17-06A2-CAPTURE-PATHS.md`
- `docs/audits/DS-17-06A3-STORAGE-RETRIEVAL.md`
- `docs/audits/DS-17-06A4-QUERY-TRUTH.md`
- `docs/DS-11-DECISION-RECORD.md`
- `docs/DS-17-05-SCHEMA-AND-MIGRATION-RESULT.md`
- `docs/CAP-1-JOURNEY-CAPTURE-FIELDS-RESULT.md`
- `docs/tasks/V-2-LIVE-VERIFICATION.md`

## Decisions required

### D1 — Canonical baseline

Choose one:

- **A.** Current production additive model is the baseline; DS-17.5 is re-scoped.
- **B.** DS-17.5 v2 is the target; production migrates to it in slices.
- **C.** Hybrid: legacy roots remain canonical for existing features, but new v2
  fields are added only where required.

The decision must state what “the Journey is the source of truth” means for
current code, because today it is not true.

### D2 — Field ownership

For every duplicated/ambiguous field, name one owner and one derived reader:

- zone kills: `db.areas` vs `journey.zones[].kills` vs `db.levels`;
- player-level kills: `db.levels`, `mob.killsAtLevel`, `journey.levels`;
- area×level: `db.areaLevels` vs `mob.killsByAreaLevel`;
- mob kills/XP: `db.mobs` vs block records;
- heatmap totals/lastSeen: `db.heatmaps` vs `blockIndex`;
- mob→zone refs: `killsByMap` vs `mobZones`;
- level XP: `levelHistory` vs `journey.levels`;
- quests/respawns/deaths: legacy root vs Journey root.

### D3 — Naming and schema

- align `journey.schema` with `storageSchema`/`dataSchema`;
- decide `byPlayerLevel` / `byZone` / `byInstance` / `playerLevels` renames;
- resolve `mob.xp` name collision (statistics table vs scalar XP);
- make player level vs mob level explicit everywhere.

### D4 — P0 safety fixes

DS-17.7 must create separate implementation tasks for these. They are not design
work.

| ID | Fix | Priority |
|---|---|---|
| P0-1 | Dirty flush must not delete a zone block when the legacy source is empty | Before any legacy retirement; before block mutations |
| P0-2 | Block payload must become v2-complete before legacy retirement | Before IMP-1B11 |
| P0-3 | Prune/filter stale block zones after heatmap clear/cap | Before V-2 heatmap/UI sign-off |
| P0-4 | `PrintHeatmap` must handle a Journey-only zone without `cells` | Before command sign-off |
| P0-5 | Cap `mobZones` refs or make fallback current-zone-only | Before cold-tooltip sign-off |
| P0-6 | Reset/track `journeyDecodedBlocks` per login/character | Before zero-decode sign-off |
| P0-7 | Align `journey.schema` with storage/data schema | Before migration |

### D5 — Migration slices

Define ordered slices with dependencies and acceptance. Minimum scope:

1. **P0 safety changes** (separate tasks, before broader migration).
2. Schema/naming alignment and duplicate-owner removal.
3. Mob level persistence independent of observations.
4. Contexts array + top-8 + `other`; `combat`/`xpContexts` split.
5. Journey instance dimension.
6. Death fields (V-2A availability first; implementation later).
7. Quest/respawn/level-history ownership.
8. Heatmap cell XP/time, stored top-N, 32/16 cold tier.
9. Block payload v2 completeness.
10. Caps/retention policy.
11. Legacy retirement (IMP-1B11) last.

Each slice needs:

- input fields;
- output fields;
- canonical owner;
- offline tests;
- V-2 dependency (A/B/C/D);
- stop condition;
- rollback/migration behavior.

### D6 — Stop conditions

- No legacy retirement before block payload is v2-complete.
- No full V-2 sign-off before field ownership is explicit.
- No V-2 validation of unimplemented fields; only availability probes first.
- No account Knowledge/ALT work.
- No new storage-format study.
- No feature work while P0-1/P0-2 remain open.

## Output

- field-owner matrix;
- adopted/rejected target fields;
- V-2A/B/C/D scope;
- ordered migration slice table;
- P0 fix task list with priorities;
- stop conditions and rollback rules;
- next implementation task.

## Acceptance

- One canonical owner per field.
- DS-17.5 is either adopted as target or explicitly re-scoped.
- Every P0 safety risk has a separate fix task.
- Every V-2-only field is classified as availability, validation, save, or visual.
- Migration slices have dependencies, tests, and stop conditions.
- No code changes in DS-17.7.
- No account/ALT/route work.

## Not required

- implementation;
- UI redesign;
- route recommendation;
- account Knowledge;
- live client test;
- new storage-format study.
