# DS-17 — Character lifecycle, compression, and cross-character leveling data

**Status:** task document, not implemented  
**Priority:** high — the current caps and schema are not designed for a full 1–60/1–max leveling life plus alts  
**Scope:** storage modes, archival compression, cross-character leveling knowledge  
**Depends on:** DS-1, DS-2, DS-3, DS-4, DS-5, DS-9, DS-11, DS-12, DS-13, DS-14, DS-15, DS-16  
**Related:** H64-9, G-2, SC-1..SC-5, J-1..J-6, M-1..M-6

---

## 0. Aggregate-first rule

**Store aggregates, not kill events.** A leveling life has at least ~12,000
kills (250 × 48 levels is already 12,000; 1–60 at 250/level is 15,000), but the
addon does not need one record per kill while the 64×64 heatmap and the
per-mob/level/zone/instance counters hold.

The design question is therefore **not** “how do we store 12,000 or 350,000
rows?” It is how to organize the data for efficiency, speed, correctness, and
reuse. The size tiers are stress tests, not the objective.

The question is:

- which features need identity beyond a heatmap cell (mob, level, instance,
  context);
- how many unique mobs/zones/instances a real leveling life creates;
- whether a 64×64 cell count is sufficient resolution for heatmap, route, and
  inspector use, including wide/tall/irregular zones and empty cells;
- how much detail must survive in hot, warm, and cold tiers;
- whether one canonical store can feed every view without duplicate copies;
- whether endgame/leveling/shared data can be reused without re-storing it.

No task below may introduce a per-kill log unless DS-17.1 proves the aggregate
model cannot answer a required feature.

## 1. Problem

The current schema is aggregation-first, but it is still sized around a
single active character with a limited number of zones and instances. A full
leveling life is much larger:

- roughly **250 kills per level** from 1–60 = **15,000 kills**; at Midnight
  1–90 the same rate is **22,500 kills**;
- roughly **100 kills per instance**; a leveling route that visits 30–50
  instances adds **3,000–5,000 kills**;
- a completionist route can visit **100+ instances**, adding ~10,000 kills;
- that is **18,000–25,000 kills per character** before alts.

The current store does not keep one record per kill, but the aggregate still
grows through unique mobs, contexts, zones, instances, level history, heatmaps,
deaths, and respawns. The caps are lower than the game's content:

- heatmap zones: **40**;
- instance records: **100**;
- mobs: **2,000**;
- contexts: **12 per mob**.

The result is predictable loss: a character that visits most zones and
instances hits caps, and a level-60 archive is not designed to be compressed,
read-only, or useful to a new character.

This task defines the future database shape rather than another incremental cap
bump.

---

## 2. Content categories and player scenarios

Exact WoW census numbers are **not** required. Midnight content categories are
enough to size the design:

- outdoor zones — roughly 200 unique names;
- dungeons, raids, PvP battlegrounds/arenas, scenarios/delves are separate
  categories and must not be collapsed into one "instance" count;
- `UiMap` dungeon-type rows include variants/difficulties and are not a count of
  unique dungeons;
- AllTheThings is a useful upper-bound reference: its database is about 72 MB
  on disk and is estimated at ~350k entries. We do not need to match it, copy
  it, or count it exactly.

The design requirement is simpler: **handle 100 entries or 100,000 entries
without special-casing the exact content count.**

### Player scenarios

| Scenario | Data state | Storage/retrieval needs |
|---|---|---|
| **Level 1, first character** | little or no history | tiny active store; no archive; optional shared leveling knowledge |
| **Level 4, early leveling** | one current zone, a few mobs, local tooltip | no full-zone/mob decode for tooltip; heatmap current zone only; minimal active memory |
| **Level 20 leveling** | active mobs, zones, heatmap, instances, deaths, rates | hot detail; recent levels/zones; ordinary caps and current 64×64 grid |
| **Max level, endgame** | leveling history complete | leveling archive read-only; current endgame tracking; XP details no longer need hot retention; AceM2L2's visible endgame value is reputation (and non-XP history), not XP |
| **First alt, main already max level** | one full 1–60 archive + one 1–60 heatmap dataset | per-character raw data separate; shared aggregate knowledge for the alt; archive loaded lazily |
| **10-year veteran** | many kills, zones, instances, alts, expansions | multiple archives; retention/compression; lazy load/eviction; endgame reputation/instance history; bounded active memory |
| **Midnight endgame** | no XP model, counts-focused | same lifecycle, but no XP/leveling formula detail to retain; reputation and non-XP history are the endgame value |

Endgame does not need the same detail as leveling. Leveling needs route/mob/zone
detail; endgame needs current activity and long-lived reputation/summary history.

## 3. Storage math

### Kills versus records

The addon aggregates by mob, level, map, and context. 15,000 leveling kills do
not automatically create 15,000 records. Growth comes from:

- unique mob identities (target cap 2,000);
- contexts per mob (currently 12);
- `killsAtLevel`, `killsByMap`, and `killsByAreaLevel` maps;
- per-zone heatmaps (up to 4,096 cells each, with wide/tall/irregular zones
  containing many empty cells);
- instance records and per-instance level maps;
- deaths, respawns, rates, quests, level history, and calibration.

### Current rough baseline

- Captured Forever character: **70,661 bytes**, 85 mobs, 2 heatmap zones,
  193 heatmap cells, 1 instance.
- Diagnostics estimate on that store: **82,614 bytes** (conservative, +16.9%).
- Moderate synthetic profile (100 mobs, 5 dense heatmap zones, 100 instances,
  all other caps): **~1.12 MB estimated**, not truncated.
- Extreme profile (2,000 mobs, 40 dense heatmap zones, 100 instances): truncated
  diagnostics estimate of **~2.12 MB**; the true count is larger.

The exact 1–60 estimate is a task deliverable. The planning expectation is:

- a detailed leveling character may exceed **2–5 MB**;
- several alts with detailed histories would exceed a comfortable single-file
  budget;
- dense heatmaps, contexts, and instance records dominate before raw kill count
  does.

---

## 4. Goals

- Define a storage lifecycle that supports a full 1–max leveling history.
- Separate **leveling mode** from **endgame mode**.
- Compress older state instead of deleting it abruptly.
- Keep current/recent data detailed and older data summarized.
- Provide a cross-character **leveling knowledge** view that a level-1
  character can use for planning.
- Keep raw per-character identity data separate from shared aggregates.
- Preserve privacy, migration safety, downgrade behavior, and backups.
- Make caps/quotas explicit and measurable.

## 5. Non-goals

- A per-kill event log.
- Real-time sharing between accounts or a server API.
- Copying third-party leveling data.
- Replacing the current 64×64 heatmap before the grid study.
- Implementing Journey or the cell inspector in this task.
- Live client verification; runtime checks remain in V-2.

---

## 6. Storage modes

### 6.1 Leveling mode

Active from level 1 to max level.

Detailed data:

- current and recent levels: full mob, context, zone, and instance detail;
- current and recent zones: 64×64 heatmap;
- all level bands within the retention window;
- level history, deaths, respawns, and rates;
- per-character raw data.

### 6.2 Endgame mode

Activated at max level, manually or by prompt.

- Leveling history becomes a **read-only archive**.
- Current endgame content remains detailed:
  - current zones and instances;
  - current mobs and contexts;
  - endgame heatmap cells;
  - endgame rates/loot.
- Leveling archive is compressed by tier.
- The character can still add notes/summaries to the archive.

### 6.3 Mode switch

- Detect max level once, record `storageMode = "endgame"` and
  `levelingArchivedAt`.
- Offer a one-time prompt; do not silently delete detail.
- Allow a manual return to leveling mode for a new expansion/level cap, with a
  new archive generation.
- Keep both modes' counters separate so endgame kills do not distort leveling
  route data.

---

## 7. Retention and compression tiers

### Hot (current + recent)

- Current level and previous 5 levels.
- Full mob/context/zone/instance detail.
- 64×64 heatmaps.
- Current session and recent rate samples.

### Warm (older but recent)

- Previous 5–20 levels.
- Keep per-level, per-zone, and per-instance counts.
- Keep top N mobs by kills/XP per zone.
- Keep 32×32 heatmap downsample.
- Drop per-mob contexts outside the top sample set.

### Cold / archive

- All older level bands.
- Per-level and per-zone summaries only.
- 16×16 heatmap downsample.
- Top 5–10 mobs per zone.
- No per-kill timestamps or per-context observations.
- Keep enough to answer “what did I kill, where, and how fast?” and to feed the
  shared knowledge view.

### Shared knowledge

- Account-wide aggregates derived from cold archives.
- Never contains raw player names, GUIDs, timestamps, or private session data.
- Rebuildable from per-character archives.
- Stored once per account/client profile, not per character.

### Compression mechanisms

- Packed zone blocks (DS-12): dictionary-encoded mob IDs, varints, delta or
  capped counts.
- Heatmap quantization: 64×64 active, 32×32 warm, 16×16 archive.
- Mob dictionary and zone/instance ID tables.
- Context collapse: merge rare contexts; keep top contexts per mob.
- Level-band summaries: counts/XP/time by band rather than every level.
- String blobs for long text and notes.
- No compression of data that is not yet classified; compress only after the
  archive boundary.

---

## 8. Cross-character leveling knowledge and route recommendations

### Purpose

A level-1 character planning a route can use data from the player's own prior
characters:

- expected XP/kill by level band and zone;
- kills/hour or time-to-level;
- best zones/instances for a level band;
- mob families and counts;
- instance XP and completion time;
- confidence based on sample count and number of source characters.

When enough data exists, the same aggregates should support an **efficient
leveling route recommendation** for a new character. The route is a plan over
level bands, zones, and optional instances — not turn-by-turn navigation. It
must show expected XP/hour or time-to-level, confidence, alternatives, and an
explicit insufficient-data fallback. The detailed research is in
`docs/tasks/DS-17-04-CROSS-CHARACTER-KNOWLEDGE.md`.

### Route recommendation goal

- Inputs: current level, faction/class if available, max level/client, buffs,
  rested, group size, preference (quest/grind/instance), risk, time, travel.
- Output: next zone/instance, expected value, confidence, alternatives, and
  data basis.
- Gate on minimum source characters, samples, time coverage, variance, recency,
  and class/faction coverage.
- Backtest against a held-out character; compare with a simple best-zone-per-band
  baseline.
- If the sample is insufficient, say so and fall back to the character's own
  history or generic guidance.

### Scope and privacy

- Account-wide, local only.
- Aggregate only; no raw per-character kill timeline or player identity.
- Separate `projectID` (Forever/Midnight) and max-level context.
- Store a source-character count, not names.
- Rebuild from archives; if archives are deleted, derived knowledge can be
  recomputed from remaining sources or dropped.

### Schema sketch

Root/scope rules: `docs/STORAGE-DIRECTION.md`. The account root stays small; raw
history stays per-character.

```lua
AceM2L2DB.profile.levelingKnowledge = {
  version = 1,
  projectID = 1,                 -- Midnight; 18 for Forever
  maxLevel = 90,
  updatedAt = 0,
  bands = {
    ["1-10"] = {
      sampleCharacters = 3,
      zones = {
        [mapID] = {
          kills = 0,
          xp = 0,
          samples = 0,
          timeSeconds = 0,
          levelSamples = 0,
          confidence = 0,         -- 0..1
          lastUpdated = 0,
        },
      },
      instances = {
        [instanceKey] = {
          kills = 0,
          xp = 0,
          timeSeconds = 0,
          samples = 0,
          confidence = 0,
        },
      },
      mobs = {
        [npcID or nameKey] = {
          name = "Mob",
          kills = 0,
          xp = 0,
          samples = 0,
        },
      },
    },
  },
}
```

Use level bands (1–10, 11–20, …) for shared data; keep per-level detail only in
the contributor's hot/warm archive.

### Query use cases

- “What is a good zone for level 24?”
- “How much XP per kill did I average in this instance?”
- “Which instance should I run at level 40?”
- “How long did 1–60 take on my last character?”
- “Which mobs gave the best XP in this zone?”

### Rules

- Shared knowledge must never be required for current-character tracking.
- If shared data is absent or stale, fall back to the character's own history.
- Do not mix Forever and Midnight knowledge.
- Do not mix max-level-cap generations after a level-cap increase.

---

## 9. Lifecycle and migration

1. Existing characters load in leveling mode.
2. At max level, create a leveling archive snapshot after a confirmation/backup.
3. Compress warm/cold tiers according to the retention policy.
4. Derive/update shared knowledge from the archive.
5. New endgame data goes into separate endgame buckets.
6. A level-cap increase starts a new leveling generation; old generation remains
   read-only.
7. Downgrade behavior: older builds ignore new archive/shared roots and must
   not overwrite them; document this.
8. Any destructive compression requires a pre-compression backup and a
   restore path.

---

## 10. Caps and quotas

Replace “40 zones / 100 instances forever” with mode- and tier-aware budgets:

- hot zones/instances: full detail;
- warm zones/instances: summarized;
- cold archives: bounded count and size, with oldest/lowest-value pruning;
- shared knowledge: one account-wide entry per band/zone/instance, capped by
  official map/instance lists.

Exact numbers must come from DS-2/DS-3/SC-1/SC-2, not guesswork.

---

## 11. Validation

- Count official zones/instances per client (UiMap/MapDifficulty).
- Measure a real 1–60 character when available (V-2).
- Build synthetic 1–60 profiles:
  - 250 kills/level;
  - 30/50/100 instances;
  - sparse/dense heatmaps;
  - 1/3/5 alts.
- Measure bytes, table counts, load/prune/compress time, and UI latency.
- Verify:
  - hot/warm/cold boundaries;
  - heatmap downsampling and total preservation;
  - archive readability;
  - shared knowledge derivation;
  - no cross-client/mode leakage;
  - backup/restore;
  - downgrade safety.

---

## 12. Acceptance criteria

- A 1–60 leveling life has an estimated and measured storage budget.
- Zone/instance counts and cap pressure are documented per client.
- Leveling and endgame modes are explicitly modeled.
- Older state is compressed in defined hot/warm/cold tiers.
- Leveling data remains readable as an archive at max level.
- A level-1 character can query aggregate leveling knowledge from prior
  characters.
- Shared data is account-wide, aggregate-only, and separable by client and
  level-cap generation.
- Migration preserves raw data and is reversible via backup.
- Caps are expressed as budgets, not one global zone/instance number.
- DS-11 has enough evidence to choose a final schema.

---

## 13. Dependencies and sequencing

1. **DS-1** consumer inventory.
2. **DS-2** real-store baseline.
3. **DS-3** synthetic scale matrix.
4. **DS-17** this task: modes, tiers, cross-character model, counts.
5. **DS-4P** optional schema prototype with mode/tier variants; skipped after
   DS-3 passed.
6. **DS-9** retention/migration.
7. **DS-12** packed block codec.
8. **DS-13** companion packaging if the archive is split.
9. **DS-14** oversize guard.
10. **DS-15** lazy retrieval.
11. **DS-16** save/checkpoint policy.
12. **DS-11** decision record.

---

## 14. Open questions

1. Auto-switch to endgame at max level, or prompt once?
2. Should the leveling archive remain per character, or only the shared
   aggregate survives after a retention window?
3. How many alts should share one account-wide knowledge store before
   confidence needs weighting?
4. Do players want route/zone recommendations, or only historical summaries?
5. How should Forever custom instances be identified when they have no stable
   official map ID?
6. Should cold archives stay in the character file, use a separate normal
   SavedVariables file, or use a LoadOnDemand companion? A separate normal file
   does not defer load; only the companion can, and its timing is V-2.
7. What is the minimum detail that still makes a historical heatmap useful:
   16×16, 32×32, or a top-cell list?
8. Should shared knowledge be optional and clearable independently?
9. What does an “efficient route” optimize: XP/hour, time-to-level, deaths,
   travel, preference, or a weighted combination?
10. What minimum sample size, character count, variance, and recency make a
    route recommendation trustworthy?
11. Do we need travel/downtime/quest-completion observations that are not stored
    today?
12. How do class, faction, gear, rested, buffs, and group size affect the route
    or its confidence?

---

## 15. Review log

### v1 — initial lifecycle and cross-character task

- Added official zone/instance counts for Retail 12.1.5 and Forever 1.60.1.
- Added 1–60 kill math and cap-pressure analysis.
- Defined leveling/endgame modes and mode switching.
- Defined hot/warm/cold retention tiers and compression mechanisms.
- Defined account-wide aggregate leveling knowledge for alts.
- Added schema sketch, lifecycle, validation, and open questions.
- Cross-linked DS-4/DS-9/DS-11/DS-12/DS-13/DS-14/DS-15/DS-16.

### v2 — sub-task decomposition

- Added the aggregate-first rule and the 12,000-kill minimum.
- Split DS-17 into six research/design tasks with explicit prerequisites and
  blocks.
- Kept implementation in DS-4/9/12/13/14/15/16 rather than duplicating it.

## 16. Sub-tasks and prerequisites

| Task | File | Depends on | Blocks |
|---|---|---|---|
| **DS-17.0** overview | `docs/tasks/DS-17-00-OVERVIEW.md` | — | — |
| **DS-17.1** aggregation and 64×64 sufficiency | `docs/tasks/DS-17-01-AGGREGATION-AND-GRID.md` | DS-1, DS-2, DS-3, DS-5 | DS-17.2, DS-17.3, DS-4 |
| **DS-17.2** modes and lifecycle | `docs/tasks/DS-17-02-MODES-AND-LIFECYCLE.md` | DS-17.1 | DS-17.3, DS-9, DS-11 |
| **DS-17.3** retention and compression | `docs/tasks/DS-17-03-RETENTION-AND-COMPRESSION.md` | DS-17.1, DS-17.2, DS-12 design | DS-17.4, DS-17.5, DS-9 |
| **DS-17.4** cross-character knowledge and route recommendations | `docs/tasks/DS-17-04-CROSS-CHARACTER-KNOWLEDGE.md` | DS-17.1, DS-17.2, DS-17.3 | DS-17.5 |
| **DS-17.5** schema and migration | `docs/tasks/DS-17-05-SCHEMA-AND-MIGRATION.md` | DS-17.1..DS-17.4, DS-4, DS-9, DS-11 | DS-11 |
| **DS-17.6** validation and decision | `docs/tasks/DS-17-06-VALIDATION-AND-DECISION.md` | DS-17.1..DS-17.5, SC-1/SC-2 | DS-11 |

Implementation remains assigned to:

- **DS-4** schema prototypes
- **DS-9** retention/migration implementation
- **DS-12** packed block codec
- **DS-13** companion packaging, if archives are split
- **DS-14** oversize guard
- **DS-15** lazy retrieval
- **DS-16** save/checkpoint policy

### v3 — route recommendation goal

- Expanded DS-17.4 from summaries to an explicit efficient-route recommendation
  goal.
- Added route granularity, inputs/outputs, sufficiency gates, explainability,
  and held-out backtesting.
- Added missing-data and confidence questions.
- Cross-referenced the full DS-17.4 task file.

### v4 — simplify to scenarios and capacity tiers

- Removed the exact-content-census dependency.
- Separated outdoor zones, dungeons, raids, PvP, and scenarios/delves.
- Added level-1, level-20, max-level, first-alt, 10-year veteran, and Midnight
  endgame scenarios.
- Replaced exact counts with entry-capacity tiers: 100 / 1,000 / 10,000 /
  100,000 / 350,000 reference entries.
- Kept 64×64 aggregate storage; no per-kill log.
