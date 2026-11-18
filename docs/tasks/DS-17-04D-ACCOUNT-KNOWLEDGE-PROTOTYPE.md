# DS-17.4D — Account Knowledge derivation prototype

**Status:** executed 2026-11-18; offline prototype.  
**Result:** `docs/DS-17-04D-ACCOUNT-KNOWLEDGE-RESULT.md`  
**Depends on:** DS-17.4A/B/C, DS-17.5, DS-15, DS-17.1  
**Blocks:** ALT feature scheduling; DS-11 addendum if account Knowledge changes the decision

## Why

Per-character Journey is the primary, always-available data. Account-wide
Knowledge is a future **derived** view for alts and cross-character advice.

This task proves that the current schema can produce useful account Knowledge
from character data without copying raw history or source-character fields. It
does not ship the merge.

## Scope

### Sources

- Synthetic 1/3/5-character corpora with overlap, shared mobs/zones, different
  levels/classes/groups/buffs, and missing contexts.
- Optional local real SavedVariables when present (`/mnt/r/AceM2L2.lua`).
- The prototype must run offline and must not use an online source, upload,
  cross-account merge, or write production SavedVariables.
- Source character tables are read-only; clone before deriving.

The local real save may be absent. Synthetic profiles are the required proof;
the real sample is a sanity check only.

Runtime note: per-character SavedVariables are not co-loaded in game. This
prototype reads character data offline. A future runtime account Knowledge store
would need an account-level derived save or companion; that persistence design
is out of scope here.

### Derived output

Prototype shape:

```text
knowledge.schema, projectID, interface, levelCap, mode

knowledge.mobs[key]
  npcID, name, classification
  mobLevelMin, mobLevelMax, mobLevelSamples
  zones, instances
  kills, xp, samples
  byPlayerLevel
  danger contexts
  xp contexts
  respawn aggregates
  firstSeen, lastSeen

knowledge.zones[map]
  kills, killXP, questXP, otherXP, xp
  presenceSeconds, engagedSeconds, deaths, sessions, uniqueMobs
  byPlayerLevel
  heatmap summary

knowledge.instances[key]
  same totals as zones, plus instance identity

knowledge.heatmaps[map]
  sparse cells, total, top-10 summary, lastSeen
  -- no level band until Journey stores per-cell level

knowledge.quests[questID]
  count, xp, samples, lastSeen

knowledge.meta
  sourceCount, rebuiltAt, schema
```

The derived schema does not need source-character names, GUIDs, session
timelines, per-kill timestamps, or raw death coordinates. Those are source-only
fields and stay out of the derived output by design.

### Merge rules

- **Identity:** prefer `npcID`. Name-only records merge only when the name is
  unique across sources. Ambiguous names stay separate or are marked unknown;
  never blind-merge by name.
- **Counts/XP/time:** sum across sources.
- **Rates:** recompute from sums; never average per-character rates.
- **Confidence:** preserve sample counts, active seconds, and `lastSeen`; derive
  Wilson-style bounds on read, not as stored point estimates.
- **Heatmaps:** sum sparse cells by map; recompute the top-10 after merge.
  Account heatmaps stay level-agnostic because source heatmaps are level-agnostic;
  do not invent a level band.
- **Quests:** merge by quest ID; store count/XP/samples. Resolve names
  opportunistically from a character quest ledger; do not copy quest text.
- **Respawns:** merge interval samples into count/min/max/sum aggregates; no
  source-character fields.
- **Levels:** preserve `byPlayerLevel` where available. If the prototype shows
  excessive size, test 5-level bands and report the loss; do not silently band.
- **Separation:** never merge across project, interface, level cap, or mode.
- **Rebuild:** derive from surviving character stores on each run. A missing or
  deleted source must disappear after rebuild. Do not build incremental merge
  state in this task.
- **Source order:** results must not depend on source load order; use
  deterministic ordering for output and identity ties.
- **Missing fields:** omit unavailable fields or mark them unavailable. Do not
  invent active time, danger contexts, per-cell XP/time, or heatmap level bands.

### Idempotence

- Deterministic key ordering and numeric rounding.
- Re-running the same sources must produce byte-identical serialized output.
- No random ordering from `pairs` in stored output.

## Test profiles

- 1, 3, and 5 synthetic characters with shared and unique mobs/zones.
- Same NPC across characters.
- Same name-only mob with and without an NPC ID.
- Conflicting classification/level observations.
- Sparse contexts, full contexts, top-8+other.
- Different player levels and level-cap generations.
- Different projects/interfaces/modes to prove separation.
- Missing/deleted source character.
- Different source load orders; byte-identical output is required.
- Optional local real save.
- Sparse/dense heatmaps and top-10 stability.

## Measure

- serialized Knowledge size and Lua heap;
- derivation time;
- query latency for mob, zone, instance, heatmap, quest;
- confidence/coverage versus per-character data;
- idempotence and rebuild time;
- derived/source-field boundary checks: ensure the derived output contains only
  aggregate fields.

## Acceptance

- Knowledge is derived only from Journey data.
- The derived output contains only aggregate fields; source-character names,
  GUIDs, session timelines, per-kill rows, and raw death coordinates are not
  part of the schema.
- Mob identity merge is deterministic; ambiguous names are not blind-merged.
- Counts/XP/time are additive; rates are recomputed from sums.
- Project/interface/level-cap/mode separation works.
- Source tables are not mutated.
- Rebuild from surviving sources is possible; deleted sources disappear.
- Re-run is byte-idempotent, including different source load orders.
- Size, heap, derivation time, and query latency are reported.
- No production merge or SavedVariables writes; the prototype is read-only.
- Runtime cross-character co-loading is not assumed; the prototype is offline.
- Heatmaps remain level-agnostic; no fake level band is introduced.
- DS-11/ALT scheduling can decide whether account Knowledge is worth shipping.
- Synthetic proof is complete even if the local real save is absent.

## Not required

- production account-wide storage or SavedVariables writes;
- UI;
- route recommendation;
- cross-account merge;
- raw history import;
- live client test;
- grid/schema change.

## Risks

- Name-only/ambiguous mob identity can create false merges.
- Missing V-2 fields (danger contexts, active time, per-cell XP/time) may make
  parts of Knowledge incomplete; mark them unavailable rather than inventing.
- Exact `byPlayerLevel` retention may be large; measure before banding.
- Source heatmaps are level-agnostic, so Account heatmaps cannot be level-banded
  yet.
- Account Knowledge can become stale if sources are not loaded; rebuild
  semantics must be explicit.
- Runtime co-loading of per-character SavedVariables is not available; account
  persistence remains a separate future design.
- The local real sample may be absent or too small to prove distributions.

## Artifacts

- `tests/ds17_4d_knowledge.lua`
- `docs/DS-17-04D-ACCOUNT-KNOWLEDGE-RESULT.md`
- `docs/DATA-MODEL-PLAN.md`
- `docs/tasks/DS-17-04D-ACCOUNT-KNOWLEDGE-PROTOTYPE.md`
