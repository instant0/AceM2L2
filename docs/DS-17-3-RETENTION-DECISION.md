# DS-17.3 — Retention, compression, and hot/warm/cold decision

**Status:** executed 2026-11-16  
**Task:** `docs/tasks/DS-17-03-RETENTION-AND-COMPRESSION.md`  
**Inputs:** DS-17.1 aggregation decision, DS-17.2 lifecycle decision, DS-3C
long-term pressure, DS-3B synthetic result, DS-5 loading constraints.

## Decision

Use dynamic hot/warm/cold movement, not fixed global counts:

- **Hot:** active/recent level band, current/selected zone, active contexts,
  current session, selected detail.
- **Warm:** recent history, top-N mobs, 32×32 heatmaps, recent summaries.
- **Cold:** older generations/zones, 16×16 or summary heatmaps, packed blocks,
  collapsed contexts, aggregated rates.
- **Shared:** account-wide aggregate leveling knowledge only.

The exact boundary is measured by active use, age, and cache cost. The 5/20-level
examples are starting policy, not hard caps. No 2,000/40/100 element stop is
allowed to decide what is retained.

## Downsampling

| Unit | Cells | Relative size | Use |
|---|---:|---:|---|
| 64×64 | 4,096 | 1× | hot/current detail |
| 32×32 | 1,024 | 0.25× | warm/recent cold |
| 16×16 | 256 | 0.0625× | oldest summary only |

At 200 zones:

| Grid | Cells | Approx. sparse cell bytes at ~18 B |
|---|---:|---:|
| 64×64 | 819,200 | ~14.7 MB |
| 32×32 | 204,800 | ~3.7 MB |
| 16×16 | 51,200 | ~0.9 MB |

Decision:

- keep 64×64 for hot/current;
- downsample to 32×32 for warm/cold route data;
- use 16×16 only for oldest/summary data where route detail is no longer needed;
- do not delete the 64×64 source until the archive backup is complete;
- record the chosen tier in the block metadata.

## Contexts

Contexts are high-cardinality observations, not required forever at full detail.

Rules:

- keep contexts for active/recent levels and the current zone;
- keep contexts that measurably improve XP/route estimates;
- collapse stale contexts into mob/zone/class aggregate XP summaries;
- keep sample counts and confidence when collapsing;
- no fixed low cap just to save MB; the choice is measured by retrieval value;
- record the collapse tier and source sample count.

## Rates

Rate samples are a rolling calculation buffer, not long-term history.

- keep the recent rolling window for current XP/hour/time-to-level;
- aggregate older samples into hourly/daily buckets;
- store buckets by zone/level band, not per kill;
- keep sample count/time coverage for confidence;
- do not let 240 samples define the historical record.

## Quests, deaths, respawns, level history

- **Quests:** per-quest lifetime summary (count/XP/first/last); archive old
  entries; no per-quest event log.
- **Deaths:** recent exact map/x/y; older deaths as per-map counts/summaries;
  exact coordinates only for the retained recent list.
- **Respawns:** per-NPC count/average/min/max/last; archive old intervals.
- **Level history:** per-level summary and generation summary; old level records
  can be compressed to counts/duration/XP.
- **Unattributed group XP:** events/XP by map/level; summary only; never a fake
  mob.
- **Economy/goal/session:** small summaries; session resets; lifetime economy
  aggregate.

## Archive format

- per-character, per-generation archive;
- per-zone/per-level packed blocks;
- versioned, checksummed, with a plain fallback;
- block metadata: projectID, generation, zone/band, grid, tier, length/checksum;
- dictionaries: local mob/level/instance IDs;
- no per-zone SavedVariables files;
- optional LoadOnDemand companion only after V-2 timing proof;
- pre-compression backup and previous archive kept.

## Lifecycle movement

At endgame switch (DS-17.2):

- leveling detail → warm/cold archive;
- 64×64 hot → 32×32 warm → 16×16 summary;
- contexts collapse; DS-7/DS-12 measured 4 contexts at 3.90 MB vs 12 at 9.19 MB
  for 100k mobs, so cold blocks keep 4/collapsed, not 12;
- rates aggregate;
- quests/deaths/respawns/levels summarize;
- endgame starts clean and separate.

At a level-cap generation:

- old generation becomes cold/read-only;
- new generation starts hot;
- no overwrite of older generations;
- account aggregates remain generation-separated.

## Test profiles

Use these in DS-4P and DS-7/DS-12:

- 3/6/12 months at 1/2/4/8 h/day;
- 10k/100k mobs;
- 200/200+ zones and instances;
- contexts 4/8/12;
- heatmaps 64/32/16;
- first alt with a level-60 main archive;
- level-cap generation switch;
- endgame-only and leveling-only states.

Measure:

- hot/warm/cold bytes and Lua heap;
- load/normalize/save/reload;
- selected-zone decode;
- tooltip/zone-list retrieval;
- archive/restore/delete behavior;
- no data loss or double count.

## Acceptance

- Hot/warm/cold are dynamic movement rules, not arbitrary global caps.
- 64 hot, 32 warm/cold, 16 summary policy is explicit.
- Context/rate/quest/death/respawn/level retention is explicit.
- Packed block metadata and backup/downgrade requirements are defined.
- 3/6/12-month and beyond-cap profiles are defined.
- DS-4P/DS-7/DS-12/DS-9/DS-17.5 can proceed without guessing.

## Risks

- Downsampling can hide narrow high-activity cells.
- Context collapse can bias XP/route estimates; keep sample counts.
- Archive codec size/CPU is unmeasured until DS-7/DS-12.
- Long-term distribution is modeled, not observed.
- Cold archives in the normal character file still load at login; only a
  companion can defer file load, and its timing is V-2.
