# DS-17.6A — Current data-model validation result

**Status:** executed 2026-11-18  
**Inputs:** A1–A4 audit reports  
**Full suite:** `./tests/run_all.sh` passes  
**Scope:** validation and decision only. No production code changed.

## 1. Executive verdict

Production does **not** implement the DS-17.5 v2 Journey model.

The actual production model is:

- **v1 legacy aggregates** are the canonical per-character store:
  `db.mobs`, `db.areas`, `db.levels`, `db.areaLevels`, `db.instances`,
  `db.quests`, `db.deaths`, `db.respawns`, `db.heatmaps`, `db.levelHistory`;
- **`db.journey` is an additive overlay** containing zone/level XP and time,
  quest anchors, and schema-2 block snapshots;
- `JourneyStorage.lua` declares `storageMode = "additive"`;
- schema-2 blocks are a projection of the legacy tables, not the DS-17.5 model.

So the previous task-board description — that the v2 schema was in production —
was wrong. The codec/storage machinery is real; the v2 **data model** is not.

## 2. What is actually implemented

| Area | Verdict |
|---|---|
| Schema-2 block envelope, base64, checksum | Implemented |
| Dirty-block save, backup/restore, oversize guard | Implemented |
| Lazy selected-block decode, LRU caches | Implemented |
| Zero cold-block decode at login | Implemented by inspection |
| Migration, downgrade guard, reset | Implemented |
| 64×64 sparse heatmap | Implemented |
| Heatmap kill position at commit (G-1B) | Implemented |
| Legacy mob/area/level/quest/death/respawn capture | Implemented |
| Journey zone/level XP and time | Implemented |
| Quest anchors | Implemented |
| Event-driven time, no timer/OnUpdate | Verified |
| No per-kill save | Verified |

## 3. What is not implemented

| Target area | Actual state |
|---|---|
| `journey.mobs` / `journey.instances` / `journey.sessions` / `journey.deaths` / `journey.quests` / `journey.respawns` / `journey.heatmaps` | Missing; legacy roots remain |
| `byPlayerLevel` / `byZone` / `byInstance` / `playerLevels` names | Not applied; legacy names remain |
| Persisted `mobLevelMin/Max/Samples` | Partial; derived only from observation contexts |
| Array contexts + top-8 + `other` | Missing; keyed map capped at 12 |
| `combat` / `xpContexts` split | Missing; one context map does both |
| Death attribution/health/buffs/group/difficulty | Missing; deaths are position-only |
| Per-instance Journey time/deaths/unique mobs | Missing |
| Heatmap cell XP/presence/engaged/lastSeen | Not captured; encoded as zero |
| Stored top-N hotspot summary | Missing; recomputed from a block decode |
| 32/16 cold downsample and archive tier | Missing |
| Adaptive caps beyond mobs/quests | Missing; many fixed caps remain |
| `journey.schema` alignment | Inconsistent: `journey.schema=1` vs `storageSchema=2` |
| Block payload completeness | 8 mob fields + 5 cell fields only |
| Account Knowledge | Explicitly deferred; prototype only |

## 4. Consolidated gaps

### P0 — Data-loss / correctness blockers

| ID | Gap | Source |
|---|---|---|
| P0-1 | Dirty flush rebuilds blocks from legacy and can delete a zone block when the legacy source is empty | A3-G11 |
| P0-2 | Block payload is not v2-complete; retirement would lose level/zone/context/time data | A3-G1 |
| P0-3 | Journey blocks and `blockIndex` are not pruned when legacy heatmaps are cleared/capped; stale zones reappear | A4-G6 |
| P0-4 | `PrintHeatmap` can error on a Journey-only zone because `cells` is nil | A4-G7 |
| P0-5 | `mobZones` is uncapped, so cold fallback can decode many blocks | A3-G6 / A4-G9 |
| P0-6 | `journeyDecodedBlocks` is global, not per-login/per-character; zero-decode proof is unreliable | A3-G7 |
| P0-7 | `journey.schema=1` conflicts with `storageSchema=2` and is not validated | A1 |

### P1 — Model gaps required before Journey can be authoritative

| ID | Gap | Source |
|---|---|---|
| P1-1 | v2 roots not implemented; legacy tables remain canonical | A1/A2/A3/A4 |
| P1-2 | v2 renames not applied; player/mob level ambiguity remains | A1 |
| P1-3 | Mob level range not persisted independently of observations | A1/A2 |
| P1-4 | Contexts are keyed maps, not arrays; no top-8+`other` cold form | A1/A3 |
| P1-5 | No `combat`/`xpContexts` split; danger cannot be computed | A1/A2 |
| P1-6 | Death records are position-only; normalizer drops future fields | A1/A2 |
| P1-7 | No Journey instance dimension; non-attributable instance kills collapse into `journey.zones["0"]` | A1/A2 |
| P1-8 | Quest/respawn/level-history views are legacy-only | A4 |
| P1-9 | Heatmap cell XP/time/top-N/32-16 cold archive missing | A1/A3 |
| P1-10 | Fixed caps remain for deaths, maps, instances, contexts, levels, rates, respawns, links | A3 |

### P2 — V-2-only / deferred

| ID | Gap | Source |
|---|---|---|
| P2-1 | Death killer attribution, health, time-to-kill, death context | A1/A2 |
| P2-2 | Buff/group/rested reliability | A2 |
| P2-3 | Heatmap cell XP/time capture | A2 |
| P2-4 | Mob level at sighting persistence | A2 |
| P2-5 | Quest turn-in timestamp/reward reliability | A2 |
| P2-6 | Per-zone/level durable time on live client | A2 |
| P2-7 | Account Knowledge, ALT features, route advice | Deferred |

## 5. Decision

### 5.1 Baseline

Treat the **current production additive model** as the as-built baseline for now.
Do not claim DS-17.5 v2 is implemented.

Keep **DS-17.5 as the target model**, but re-scope it as an implementation
program, not an already-completed schema.

### 5.2 Order

1. ~~**DS-17.7 — Data-model reconciliation and migration plan.**~~ Done
   2026-11-18. v2 is the target; v1+additive Journey is transitional.
   Result: `docs/DS-17-07-DATA-MODEL-RECONCILIATION-RESULT.md`.
2. **DS-17.8 — P0 safety fixes** before any legacy retirement or V-2 sign-off:
   flush deletion risk, stale blocks, `PrintHeatmap` nil cells, `mobZones` cap,
   decode counter scope, schema alignment.
3. **V-2A** availability probes after the field list; **V-2B/C/D** after the
   relevant slices.
4. **IMP-1B11** only after S8, S9, and V-2.
5. **DS-17.6B / ALT** stays deferred.

### 5.3 Explicitly not doing

- No account Knowledge now.
- No ALT/route features.
- No legacy retirement now.
- No claim that v2 is implemented.
- No new storage-format study.

## 6. Why the previous plan was wrong

The task board treated DS-17.5 as a completed production schema and IMP-1B as if
it had migrated the Journey roots. The audits show:

- IMP-1B built block codec/retrieval/save machinery;
- CAP-1 prototyped richer capture fields but did not wire them into production;
- `db.journey` only contains zone/level time, anchors, and block metadata;
- the actual analytical store is still the legacy aggregate model.

The codec work is valid. The data-model migration was not done.

## 7. Acceptance

- Field ownership audited: **yes**.
- Capture paths audited: **yes**.
- Storage/retrieval/save audited: **yes**.
- Query truth audited: **yes**.
- Consolidated gaps and priorities: **yes**.
- Production code changed: **no**.
- Full offline suite: **passes**.
- Next owner assigned: **DS-17.8 — P0 safety fixes**.

## 8. Artifacts

- `docs/audits/DS-17-06A1-FIELD-OWNERSHIP.md`
- `docs/audits/DS-17-06A2-CAPTURE-PATHS.md`
- `docs/audits/DS-17-06A3-STORAGE-RETRIEVAL.md`
- `docs/audits/DS-17-06A4-QUERY-TRUTH.md`
- `docs/tasks/DS-17-06A-DATA-MODEL-VALIDATION.md`
- `docs/tasks/DS-17-06A5-CONSOLIDATION.md`
- `docs/tasks/DS-17-07-DATA-MODEL-RECONCILIATION.md`
