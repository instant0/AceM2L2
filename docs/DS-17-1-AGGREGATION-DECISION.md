# DS-17.1 — Aggregation and 64×64 decision

**Status:** executed 2026-11-16  
**Task:** `docs/tasks/DS-17-01-AGGREGATION-AND-GRID.md`  
**Inputs:** DS-1 contract, DS-3B synthetic result, DS-3C long-term pressure, H64-9,
DS-5 loading constraints, capacity/strategy.

## Decision

- Keep **64×64 sparse cells** as the durable kill-heatmap unit.
- Keep aggregate counters for mob, level, zone, instance, context, and session.
- Do not add a per-kill event log.
- Do not treat the current 2,000-mob / 40-zone / 100-instance caps as design
  limits. All data is stored in hot/warm/cold units; the hot cache is dynamic.
- Use a compact hot index plus packed cold per-zone/level blocks.
- Rate samples are a rolling calculation buffer; long-term rate history, if
  wanted, is aggregated.
- 96×96/128×128 are not adopted for durable storage. They remain an optional
  display/selected-zone experiment only if the cell inspector proves 64×64
  insufficient.

## Feature-to-data matrix

| Feature | Scope | Required data | Hot/warm/cold unit | Query/index | Fallback |
|---|---|---|---|---|---|
| Tooltip | current mob/zone/level | mob identity, kills, killsAtLevel, solo context, XP summary | hot mob + current zone | NPC ID → mob; normalized-name index | formula/global, never false zero |
| Overview | all-character summary | totals, session, unique mobs, areas, levels, dungeon, quest summary, economy, goal | hot summaries; warm/cold rollups | direct summary fields | zero/none state |
| Mobs list | all-character or selected zone | name, kills, sessionKills, killsAtLevel, xp summary, classification, lastSeen | hot mobs; warm/cold top-N | zone index + sort | empty list |
| Areas | open-world zones | area totals, areaLevels, top mobs | hot summaries; cold zone blocks | map index | no rows |
| Levels | player levels | level totals, top mobs, XP | hot summaries; cold bands | level index | no rows |
| Heatmap | current/selected zone | 64×64 sparse cells, total, lastSeen | hot selected zone; warm 32×32; cold 16×16/packed | map → block | disabled/unloaded state |
| Detail | selected mob/area/level/instance | identity, counts, XP, maps, levels, instances, first/last | hot selected item; warm/cold summary | direct key | empty detail |
| Commands | requested roots | all relevant roots | hot + cold as requested | direct root/query | “no data” |
| Diagnostics | counts/metadata | counts, bytes/estimate, collection state | counts first; no full decode | count indexes | zero/partial label |
| Calibration | current mob/context | context observations, ratios | hot recent contexts; cold collapsed | context key | formula/group prior |
| Deaths | current character | at, mapID, x, y | warm/cold list | recent list | unavailable/no data |
| Respawns | current character | NPC, intervals, first/last | warm/cold list | NPC key | unavailable/no data |
| Rates | rolling rate | at, xp, source, map, level | hot rolling buffer; cold hourly/daily aggregate | recent window | insufficient samples |
| Level history | character | level, start/end, xp, kills, duration | warm/cold records | level/date | none |
| Journey | selected zone/route | zone/instance sequence, cells, deaths | cold route block | selected route/zone | not implemented |
| Cell inspector | selected cell | cell count, top mobs/levels/instances | hot cell aggregate; cold top-N | selected zone/cell | “no cell detail” |
| Unattributed group XP | current character | events, xp, byLevel, byMap, lastSeen | hot summary; cold aggregate | summary only | no fake mob; show aggregate |

## Cardinality by player profile

Planning estimates, not exact content counts:

| Profile | Kills | Unique mobs | Zones | Instances | Contexts | Heatmap cells |
|---|---:|---:|---:|---:|---:|---:|
| Level 1 first character | 0–50 | 0–10 | 1 | 0 | 0–10 | 1 zone, sparse |
| Level 20 leveling | ~5,000 | ~558 | ~5–10 | 0–5 | up to 6.7k | ~5–10 zones, 100–1k each |
| Max Forever | 18k–25k | up to 2,000 | 40 | 30–100 | up to 24k | up to 163,840 at 40×4k |
| First alt, 60 main | alt’s own 0–25k | alt only | alt only | alt only | alt only | alt only |
| 10-year veteran | many alts/archives | active char cap + cold | many cold zones | many cold | archived/collapsed | active hot + cold |
| Midnight max | 25.5k–32.5k | up to 2,000 | up to 200 | up to 200 | up to 24k | up to 819,200 if 200×4k |

The first-alt rule is strict: **the main’s per-character raw history is not
loaded**. Only the alt’s active store and account-wide aggregates are used.

## Hot/warm/cold boundary

The boundary is determined by active use and measured cache limits, not by a
fixed global count:

- **Hot:** current/recent level band, current/selected zone, active mobs,
  current contexts, current session, selected detail.
- **Warm:** recent levels/zones, top-N mobs, 32×32 heatmap, recent summaries.
- **Cold:** older levels/zones, 16×16 or summary heatmaps, packed zone/level
  blocks, collapsed contexts, aggregated rates.
- **Shared:** account-wide aggregate leveling knowledge only.

The current 5/20-level examples are starting policy for testing, not hard caps.
Eviction/cache size is set by measured memory and retrieval cost.

## 64×64 decision

**Accepted for durable kill heatmaps.**

Evidence from H64-9:

- dense 64×64 first render ~9.4 ms offline; rescale ~6.4 ms; incremental ~0.75 ms;
- 40 dense maps normalize ~93 ms;
- wide/tall 1,024-cell profiles use 3,072 empty cells but empty cells cost no
  storage;
- sparse tables make empty cells free.

96×96 and 128×128 are rejected for durable storage:

- 2.25× and 4× the cells;
- roughly 2.25×/4× the dense render/rescale work;
- more cold-block bytes for marginal route/inspector detail;
- no evidence the current feature set needs finer durable resolution.

64×64 remains sufficient for heatmap and zone/route meaning. The future cell
inspector uses the cell aggregate plus additional per-cell top mobs/levels/
instances; that requires new aggregate fields, not a per-kill or subcell log.
If a selected-zone experiment later proves 96/128 is needed, use it as temporary
display detail, not a new global schema.

Live frame-time validation remains V-1. If 64×64 cannot meet a live budget, the
decision can be revisited; the offline benchmark alone is not a live guarantee.

## Required keys

### Hot index

- schema/version, projectID;
- character summary: totals, unique mobs, last save, mode;
- zone index: mapID → block ID/offset/length/checksum, totals;
- mob identity: npcID/local ID → name/classification/count/XP summary;
- normalized-name index (rebuild in memory);
- instance index: instance key → identity/totals/block;
- hot block references and eviction metadata;
- unattributed XP summary (events/xp/byLevel/byMap);
- digests needed by Overview/Areas/Levels.

### Cold block

- block key: projectID, zone/band, grid, version;
- checksum/length;
- dictionary: local mob IDs, level IDs, instance IDs;
- mob counts/XP summaries;
- level/instance counts;
- sparse 64×64 cell counts;
- top-N mobs/levels;
- creation/retention metadata.

### Per-entity fields

- **Mob:** npcID/local ID; account-wide stable metadata for `npc:<id>` (name,
  one fixed levelMin/levelMax, at most 4 zone/instance refs); per-character
  name-only metadata for `name:<lower>`; no inline cold name; classification,
  first/last, kills, session kills, XP samples/sums; per-level/map/instance
  counts.
- **Context:** player level, mob level, group size, map/instance, classification,
  buff signature, samples/sums/min/max, last seen.
- **Instance:** key; name from client/live metadata, type, difficulty, map, kills, XP,
  killsAtLevel, first/last.
- **Heatmap cell:** cell index, count.
- **Unattributed XP:** events, xp, byLevel, byMap, lastSeen; no mob identity.
- **Death:** at, mapID, x, y.
- **Respawn:** NPC, intervals, first/last death/seen.
- **Rate:** rolling at/xp/source/map/level; cold hourly/daily aggregate.
- **Quest:** ID/name, count, XP, first/last.
- **Level history:** level, start/end, XP/kills/duration.
- **Shared:** zone/level band, XP/kills/time, confidence/sample count; no raw
  player identity.

## No-global-cap policy

- All zones/instances/mobs are stored; the hot cache is dynamic.
- Old zones/levels move to packed cold blocks; old contexts/rates aggregate.
- The current 2,000/40/100 caps are implementation caps to be removed as design
  limits, not retention targets.
- Rate samples stay a rolling buffer for current rate; long-term history is
  hourly/daily aggregates, not raw samples.
- No silent data loss: if detail is downsampled, keep a summary and record the
  tier.
- Per-zone/per-block retention is based on age/value, not one global element
  count.

## DS-4P inputs

- Hot index fields above.
- Cold block fields above.
- Dynamic hot/cold split; no 2k/40/100 stop.
- 64×64 durable grid; 32/16 cold downsample.
- Context/rate aggregation rules.
- 3/6/12-month and 10k/100k-mob test profiles.
- Packed-block codec requirements for DS-7/DS-12.

## Acceptance

- Every feature has scope, fields, hot/cold unit, query, fallback, retention.
- 64×64 is explicitly accepted for durable heatmaps; 96/128 rejected for storage.
- No global 2k/40/100 cap is treated as the design limit.
- Hot/warm/cold units are explicit; eviction is measured, not guessed.
- No per-kill log is introduced.
- Required hot/cold keys are defined for DS-4P and DS-17.5.
- DS-17.2/DS-17.3 can proceed.

## Risks

- Long-term profile growth is still modeled, not observed for 3/6/12 months.
- Cold-block codec size/CPU is unmeasured (DS-7/DS-12).
- Cell inspector may expose a need for finer display detail; use selected-zone
  display, not a new global store.
- Shared knowledge confidence/backtesting remains DS-17.4.
