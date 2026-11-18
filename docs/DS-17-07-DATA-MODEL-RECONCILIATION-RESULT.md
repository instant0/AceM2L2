# DS-17.7 — Data-model reconciliation and migration result

**Status:** decided 2026-11-18  
**Scope:** design/decision only. No production code changed.  
**Input:** `docs/DS-17-06A-DATA-MODEL-VALIDATION-RESULT.md`  
**Full suite:** `./tests/run_all.sh` passes.

## 1. Decision

### D1 — Baseline

**DS-17.5 v2 is the target model. The current v1 aggregate + additive Journey is
the transitional as-built baseline.**

That means:

- do not claim v2 is implemented;
- do not retire legacy roots yet;
- migrate one domain at a time with parity/backfill tests;
- each domain gets one final owner and one transitional owner;
- legacy data remains readable until its slice lands.

This is a staged adoption, not a big-bang rewrite.

### D2 — Final field ownership

| Domain | Transitional owner | Final owner | Slice |
|---|---|---|---|
| Mob identity/metadata | `char.mobs` | `journey.mobs` | S2 |
| Mob/player level | `mob.contexts`, `mob.killsAtLevel` | `journey.mobs.mobLevel*`, `byPlayerLevel` | S2 |
| Mob counts/XP | `char.mobs.kills`, `totalXP` | `journey.mobs.kills`, `xp` | S2 |
| Contexts | `mob.contexts` keyed map | `journey.mobs.contexts`, `combat`, `xpContexts` | S2 |
| Zone counts/XP/time | `char.areas` + `journey.zones` | `journey.zones` | S3 |
| Player levels | `char.levels`, `journey.levels`, `levelHistory` | `journey.levels` | S3 |
| Area×level counts | `char.areaLevels`, `mob.killsByAreaLevel` | `journey.zones[].playerLevels` | S3 |
| Instances | `char.instances`, `journey.zones["0"]` | `journey.instances` | S4 |
| Deaths | `char.deaths` | `journey.deaths` | S5 |
| Quests | `char.quests` + `journey.questAnchors` | `journey.quests` + anchors | S6 |
| Respawns | `char.respawns` | `journey.mobs.respawn` / `journey.respawns` | S6 |
| Sessions | `char.session` live bucket | `journey.sessions` | S6 |
| Heatmaps | `char.heatmaps` + block snapshots | `journey.heatmaps` | S7 |
| Blocks | derived snapshot | serialized form of Journey; not an owner | S8 |
| Account Knowledge | none | future derived target | deferred |

### D3 — Schema and naming

- Retire the independent `journey.schema = 1` and use the existing
  `storageSchema`/`dataSchema` gates.
- Adopt `byPlayerLevel`, `byZone`, `byInstance`, `playerLevels` in v2.
- Keep legacy names until their slice; do not rename in place without a parity
  test.
- Resolve `mob.xp` collision: v2 `mob.xp` is scalar total XP; observation
  statistics move to `mob.xpStats` during S2.
- Always label player-level vs mob-level data explicitly.

## 2. P0 safety fixes

These are separate implementation tasks, not part of this design task.

| ID | Fix | Dependency |
|---|---|---|
| P0-1 | Dirty flush must not delete a zone block when the legacy source is empty | Before any retirement/block mutation |
| P0-3 | Prune/filter stale block zones after heatmap clear/cap | Before heatmap/V-2 sign-off |
| P0-4 | `PrintHeatmap` must handle a Journey-only zone without `cells` | Before command sign-off |
| P0-5 | Cap `mobZones` refs or make fallback current-zone-only | Before cold-tooltip sign-off |
| P0-6 | Scope `journeyDecodedBlocks` per login/character | Before zero-decode sign-off |
| P0-7 | Align `journey.schema` with storage/data schema | Before migration |

P0-2 — block payload v2 completeness — is an S8 migration prerequisite, not a
small patch. Legacy retirement is blocked until it lands.

## 3. Migration slices

Each slice must define its input fields, output fields, canonical owner, offline
tests, V-2 dependency, backfill/dual-read behavior, rollback, and stop condition.

| Slice | Scope | Depends | V-2 |
|---|---|---|---|
| **S0** | P0 safety fixes | DS-17.7 | V-2C later |
| **S1** | Schema/naming/ownership scaffolding | S0 | — |
| **S2** | Mobs, levels, counts/XP, contexts, `combat`/`xpContexts` | S1 | V-2A before death/health fields |
| **S3** | Zones, player levels, area×level, perf counters | S2 | — |
| **S4** | Journey instances and non-attributable instance handling | S3 | — |
| **S5** | Death records with attribution/health/buffs/group | S2 + V-2A | V-2A/V-2B |
| **S6** | Quests, respawns, sessions, level history | S3/S4 | V-2B for turn-in/timing |
| **S7** | Heatmap cells XP/time, top-N, 32/16 cold tier | S2 | V-2B for cell XP/time |
| **S8** | Block payload v2 completeness | S2–S7 | V-2C after |
| **S9** | Adaptive caps/retention/archive policy | S8 | V-2C |
| **S10** | Legacy retirement (IMP-1B11) | S8, S9, V-2 | full V-2 |

No slice may switch an owner without a parity/backfill test and a rollback path.

## 4. V-2 scope

V-2 is live-only residual verification, split as:

| Part | Scope | Timing |
|---|---|---|
| **V-2A** | API/field availability probes | After DS-17.7 field list; can run before implementation |
| **V-2B** | Validate implemented capture | After S2/S5/S6/S7 slices |
| **V-2C** | Save/load/oversize/companion validation | After S0/S8/S9 |
| **V-2D** | Visual/frame checks | Independent |

V-2 cannot validate a field that has no writer. No full V-2 sign-off before field
ownership and the relevant slice are complete.

## 5. Stop conditions

- No legacy retirement before S8 and V-2.
- No full V-2 sign-off before field ownership is explicit.
- No V-2 validation of unimplemented fields; only V-2A probes first.
- No owner switch without parity/backfill tests.
- No feature work while P0-1/P0-2 remain open.
- No account Knowledge/ALT/route work.
- No new storage-format study.

## 6. Next tasks

1. **DS-17.8 — Data-model P0 safety fixes** — next.
   Covers P0-1, P0-3, P0-4, P0-5, P0-6, P0-7 with focused tests.
2. **V-2A — field availability probes** — can run in parallel if a live client is
   available, using the field list from this result.
3. **S1/S2 migration** — after DS-17.8.

## 7. What this fixes

- Stops the false claim that v2 is implemented.
- Prevents retiring legacy before blocks are complete.
- Prevents V-2 from validating fields that do not exist.
- Puts P0 data-loss/display bugs ahead of feature work.
- Keeps ALT/account Knowledge deferred.

## 8. Artifacts

- `docs/DS-17-06A-DATA-MODEL-VALIDATION-RESULT.md`
- `docs/tasks/DS-17-07-DATA-MODEL-RECONCILIATION.md`
- `docs/tasks/DS-17-08-DATA-MODEL-P0-SAFETY.md`
- `docs/tasks/V-2-LIVE-VERIFICATION.md`
