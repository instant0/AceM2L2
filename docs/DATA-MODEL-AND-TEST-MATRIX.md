# Data model and test matrix — working record

**Status:** documented 2026-11-16 from the latest review  
**Scope:** local SavedVariables only; no uploads or external sharing  
**Purpose:** retain the current data-model decision, what the earlier tests proved,
and what still has to be tested before the model is final.

## 1. Terms

- **Character Journey:** per-character history in `AceM2L2CharDB`.
- **Account Knowledge:** derived, account-wide summaries in `AceM2L2DB` for the
  player's own characters. Not raw history. Not implemented now.
- **Static metadata:** mob/quest/instance facts learned locally. No shipped
  all-name list.
- **Account-wide:** the same player's characters on the same computer only.

There is no upload, network, privacy, or cross-account model.

## 2. Requirements retained from review

- The per-character Journey is the primary asset. Do not shrink it to the
  current 2,000/40/100/12 caps.
- Keep enough detail that a high-level character and later alts have data to
  analyse.
- Define the account-wide target now if useful; implement it later.
- Merge is a future problem. The per-character data is always available in
  SavedVariables, so the merge can read it later.
- Danger tooltip: has this mob killed a player under similar circumstances, or
  do players normally slaughter it?
- Quest state does not alter mob health, buffs, or group state. Do not put quest
  state in the mob combat/XP context.
- Combat context uses health, buffs, group size, player/mob level,
  classification, and instance difficulty.
- Best zone = highest XP/hour at the current level.
- Mobs have one fixed level range and at most 4 zone/instance refs (current
  working assumption).

## 3. Per-character Journey model

```lua
AceM2L2CharDB.xpTooltip.clients[projectID] = {
  schema = ...,
  projectID = ...,
  interface = ...,
  mode = "leveling" | "endgame",
  levelCap = ...,
  character = {
    class = ..., race = ..., faction = ...,
    level = ..., maxLevel = ...,
    createdAt = ..., playtime = ...,
  },

  journey = {
    mobs = {
      ["npc:<id>"] = {
        npcID = ...,
        name = "...",
        levelMin = ..., levelMax = ...,
        classification = ...,
        firstSeen = ..., lastSeen = ...,

        kills = ..., xp = ...,
        sessionKills = ..., sessionXP = ...,

        byLevel = {
          [level] = { kills = ..., xp = ..., deaths = ..., activeSeconds = ... },
        },
        byMap = {
          [mapID] = { kills = ..., xp = ..., deaths = ..., activeSeconds = ... },
        },
        byInstance = {
          [instanceKey] = { kills = ..., xp = ..., deaths = ..., activeSeconds = ... },
        },

        combat = {
          [combatContextKey] = {
            playerLevel = ..., mobLevel = ...,
            healthBand = "0-20" | "21-40" | "41-60" | "61-80" | "81-100",
            buffSignature = "...",
            groupSize = ...,
            classification = ...,
            instanceDifficulty = ...,
            kills = ..., deaths = ...,
            healthLostSum = ..., healthLostSamples = ...,
            timeToKillSum = ..., timeToKillSamples = ...,
            lastSeen = ...,
          },
        },

        xpContexts = {
          [xpContextKey] = {
            playerLevel = ..., mobLevel = ...,
            groupSize = ...,
            rested = true/false,
            buffSignature = "...",
            classification = "...",
            kills = ..., xp = ...,
            samples = ..., lastSeen = ...,
          },
        },

        respawn = {
          samples = ..., min = ..., max = ..., median = ...,
          firstSeen = ..., lastSeen = ...,
        },
      },
    },

    zones = {
      [mapID] = {
        name = ...,
        firstSeen = ..., lastSeen = ...,
        kills = ..., xp = ..., activeSeconds = ...,
        deaths = ..., sessions = ..., uniqueMobs = ...,
        levels = {
          [level] = { kills = ..., xp = ..., activeSeconds = ..., deaths = ... },
        },
      },
    },

    instances = {
      [instanceKey] = {
        name = ..., instanceID = ..., mapID = ..., difficultyID = ...,
        instanceType = ...,
        kills = ..., xp = ..., activeSeconds = ...,
        deaths = ..., sessions = ...,
        levels = { [level] = { kills = ..., xp = ..., activeSeconds = ... } },
      },
    },

    levels = {
      [level] = {
        kills = ..., xp = ..., activeSeconds = ...,
        deaths = ..., startedAt = ..., endedAt = ...,
      },
    },

    sessions = {
      [sessionID] = {
        startedAt = ..., endedAt = ..., activeSeconds = ...,
        levelStart = ..., levelEnd = ...,
        mapID = ..., instanceKey = ...,
        kills = ..., xp = ..., deaths = ...,
      },
    },

    heatmaps = {
      [mapID] = {
        gridSize = 64,
        total = ...,
        lastSeen = ...,
        cells = {
          [cell] = {
            kills = ..., xp = ..., activeSeconds = ..., lastSeen = ...,
          },
        },
      },
    },

    deaths = {
      [deathID] = {
        at = ..., mapID = ..., x = ..., y = ...,
        mobKey = ..., npcID = ..., name = ...,
        playerLevel = ..., mobLevel = ...,
        playerHealth = ..., playerHealthMax = ...,
        healthBand = ...,
        buffSignature = ..., groupSize = ...,
        classification = ..., instanceDifficulty = ...,
        combatContextKey = ...,
      },
    },

    quests = {
      [questID] = {
        name = ..., xp = ..., count = ..., level = ..., mapID = ...,
        firstSeen = ..., lastSeen = ...,
      },
    },
  },
}
```

### Context rules

**Combat/danger context**

- player level
- mob level
- health band
- buff signature
- group size
- classification
- instance difficulty

Quest state is excluded.

**XP context**

- player level
- mob level
- group size
- rested
- buff signature
- classification

Quest state is excluded.

### Danger semantics

- `kills`, `deaths`, `healthLostSum`, `timeToKillSum` are aggregated by combat
  context.
- Individual death records keep the exact circumstances.
- Tooltip danger requires killer attribution. If the addon cannot attribute a
  death to a mob, only zone/level danger is possible.

### Best zone semantics

- `zones[mapID].xp` and `zones[mapID].activeSeconds` give XP/hour.
- `zones[mapID].levels[level]` gives XP/hour at a specific level.
- Raw kill count alone is not a best-zone metric.
- Low active time/sample count means low confidence.

### Heatmap semantics

- Cells keep kills, optional XP, and optional active time.
- Best cell is ranked by kills/hour or XP/hour, not raw count alone.
- 64×64 remains the durable grid.

## 4. Account-wide Knowledge target

This is a **derived target**, not an implementation requirement now.

```lua
AceM2L2DB.profile.knowledge = {
  schema = ..., projectID = ..., interface = ...,
  levelCap = ..., mode = ...,

  mobs = {
    ["npc:<id>"] = {
      name = ..., levelMin = ..., levelMax = ...,
      classification = ..., zones = { ... }, -- <=4
      respawn = { samples = ..., median = ..., min = ..., max = ... },
      danger = {
        [combatContextKey] = {
          kills = ..., deaths = ...,
          healthLostSum = ..., healthLostSamples = ...,
          timeToKillSum = ..., timeToKillSamples = ...,
          lastSeen = ...,
        },
      },
      xp = {
        [xpContextKey] = { kills = ..., xp = ..., samples = ... },
      },
    },
  },

  zones = {
    [mapID] = {
      [levelBand] = {
        kills = ..., xp = ..., activeSeconds = ...,
        deaths = ..., sessions = ..., uniqueMobs = ...,
        characters = ..., lastSeen = ..., confidence = ...,
      },
    },
  },

  instances = { ... },

  heatmaps = {
    [mapID] = {
      [levelBand] = {
        gridSize = 64,
        cells = { [cell] = { kills = ..., xp = ..., activeSeconds = ... } },
      },
    },
  },

  quests = { [questID] = { name = ..., xp = ..., count = ..., level = ... } },
}
```

Merge requirements, not merge implementation:

- stable keys: project/interface, mode, level cap, map/instance, mob key, context;
- additive counters: kills, XP, active time, deaths, samples;
- min/max/median/percentile inputs;
- no raw character identity or session timeline;
- readable from character SavedVariables later.

## 5. Current schema mapping and gaps

| Area | Current state | Needed for the model |
|---|---|---|
| Mob identity/name | `mobs` with name/npcID/classification | Keep; learn live; no shipped all-name list |
| Mob counts/XP | `mobs.kills`, `xp`, `killsByMap`, `killsByAreaLevel`, `killsByInstanceLevel` | Keep; add explicit active time and deaths |
| Mob context | `contexts` for calibration | Add combat and XP context keys with health/buffs/group/rested |
| Danger outcomes | Not explicit | Add kills/deaths/health lost/time-to-kill by combat context; death records with mob attribution |
| Zone/level/instance | `areas`, `levels`, `instances` | Add `activeSeconds`, `xp`, `deaths`, `sessions`, per-level breakdown |
| Best zone | Not directly computable | XP/hour from zone/level XP and active time |
| Heatmap | `heatmaps` cells with counts | Add optional XP/active time per cell for best-part ranking |
| Deaths | Map/position records | Add mob identity, health, buffs, group, classification, context |
| Respawns | intervals | Keep; aggregate summary and samples |
| Quests | quest XP/count | Keep separate; never put quest state in mob context |
| Sessions/rates | rolling rate samples | Need durable session/zone/level active time |
| Static metadata | per-character mob names/levels/zones | Can be account-wide later; no all-name payload |

## 6. Key prior numbers

These are retained from the earlier result docs; rerun the harness for exact
current values.

| Area | Number |
|---|---|
| Current real store | 70,661 bytes; 85 mobs; 762 kills; 2 heatmap zones; 193 cells; 1 instance |
| Current-cap synthetic | 8.69 MB compact / 9.94 MB client estimate; 23 MB stable / 27–37 MB transient |
| Long-term pressure | 2,000 mobs in ~3 months at 2h/day; rate buffer turns over in 2.4h |
| Hybrid tier C | 100k mobs/200 zones/200 instances: 38.5 MB hot / 8.07 MB cold; selected-zone 3.7 ms; tooltip 0.55 ms/10k |
| Hot index F1 | 100k: 20.67 MB baseline; 7.67 MB hot with static names; 6.83 MB hot without name index |
| Scoped index F2 | 100k: 7.73 MB hot + 5.97 MB shared; 11,001 scoped entries |
| Shipped-name alternative | 10k/100k/350k names: map 1.21/10.67/40.35 MB; packed 0.31/3.51/12.80 MB |
| Cold codec | 100k/4ctx: 3.90 MB cold / 4.03 MB heap; 100k/12ctx: 9.19 MB; 350k sub-blocks: 13.22 MB / 2.55 ms |
| Live name probe | 10k names 0.95 MB; 100k 8.33 MB |
| Local mob sample | 158 mobs; 100 npcID / 58 name-only; 135 one zone/instance, 23 two; level width 0–4 |
| Local account metadata | 100 entries 0.02 MB / 3.8 KB packed |
| Local name-only metadata | 58 entries 0.01 MB / 3.7 KB packed |
| Account metadata scale | 10k: 2.38 MB map / 0.42 MB packed; 100k: 35.97 / 4.16 MB |

## 6. Existing test inventory

| Harness / result | What it established | Re-runnable |
|---|---|---|
| `tests/storage_sanity.lua` → `docs/DS-3-STORAGE-SANITY-RESULT.md` | Storage sanity, migration/legacy behavior | Yes |
| `tests/ds3b_massive.lua` → `docs/DS-3B-MASSIVE-SYNTHETIC-RESULT.md` | 23 MB stable / 27–37 MB transient at 2k/40/100/12; current caps too small | Yes |
| `docs/DS-3C-LONG-TERM-GROWTH.md` | 2h/day reaches 2,000 mobs in ~3 months; rate buffer turns over in 2.4h | Calculation; source profile in DS-3B |
| `tests/ds4p_hybrid.lua` → `docs/DS-4P-HYBRID-PROTOTYPE-RESULT.md` | Hybrid hot/cold; 100k/200/200; selected-zone decode; no full scan | Yes |
| `tests/ds4p_f1_hotindex.lua` → `docs/DS-4P-F1-HOT-INDEX-RESULT.md` | Numeric hot arrays + static names; names cost; records/string keys worse | Yes |
| `tests/ds4p_f2_nameindex.lua` → `docs/DS-4P-F2-SCOPED-NAME-INDEX-RESULT.md` | Scoped name index; name-only/ambiguous handling | Yes |
| `tests/ds6_static_metadata.lua` → `docs/DS-6-STATIC-METADATA-RESULT.md` | Shipped-name alternative measured and rejected; packed table sizes | Yes |
| `tests/ds7_codec.lua` → `docs/DS-7-12-PACKED-BLOCK-CODEC-RESULT.md` | Hybrid cells, varint fields, per-block base64, checksums, block sizes | Yes |
| `tests/ds6f1_registry.lua` → `docs/DS-6-F1-MOB-METADATA-REGISTRY-RESULT.md` | Local 158-mob locality/level distribution; account stable metadata vs name-only | Yes (needs `/mnt/r/AceM2L2.lua`) |
| `tests/bench_heatmap.lua` → `docs/H64-9-BENCHMARK-REPORT.md` | Heatmap benchmark/render cost | Yes |
| `tests/measure_diagnostics.lua` → `docs/HC-5-DIAGNOSTICS-BASELINE.md` | Diagnostics estimate vs real data | Yes |
| `tests/smoke.lua` | Current behavior/regression coverage | Yes, in `run_all.sh` |

The result docs retain the summary numbers. Raw harness output is not all
committed; rerun the harness for exact current values. Timings vary; sizes and
counts are deterministic for the same input.

### What remains valid

- Per-zone/instance/level blocks.
- Packed cold codec; hybrid sparse/bitset cells; checksums; base64.
- Selected-block decode and no full scan.
- No shipped all-name list.
- Scoped name index for name-only/ambiguous mobs.
- Current 2,000/40/100 caps are too small.
- Character Journey stays per character.

### What needs revision

- Name/metadata “cache” as the central model.
- Account-wide metadata as a now-implementation rather than a future target.
- Missing Journey vs Knowledge taxonomy.
- Missing danger outcomes and XP/hour active time.
- Retention rules that could drop aggregation dimensions.
- DS-17.1/17.4/17.5 need the new fields and split.

## 6b. DS-17.4A result

Result: `docs/DS-17-04A-JOURNEY-KNOWLEDGE-MODEL-RESULT.md`

| Finding | Number |
|---|---|
| Local mobs / contexts | 158 mobs / 1 context entry |
| Full contexts at 10k mobs × 12 | 70.70 MB; top-8 45.34 MB, 93.8% kills / 92.3% XP; top-4 23.06 MB, 66.7% / 64.3% |
| Metadata schema at 100k | nested 33.75 MB; parallel 26.00 MB; packed 4.45 MB |
| Heatmap 64→32/16 | totals preserved; 428/256 cells; **local occupancy 4.5–4.8%, not saturated** |
| Local gaps | no active time, combat/XP contexts, death attribution/health/buffs/group, heatmap XP/time |

## 6c. DS-17.4B result

Result: `docs/DS-17-04B-DANGER-AND-XP-HOUR-RESULT.md`

| Finding | Result |
|---|---|
| Danger | Wilson bounds + sample confidence; sparse 2 samples = not enough data |
| Best zone | XP/hour, not kills/hour; low-sample high XP/hour flagged low confidence |
| Heatmap local occupancy | 4.83% / 4.54% / 0.02%; top 10 cells ≈23% of kills |
| Heatmap downsample | top-10 overlap 6/10–10/10 in the tiny sample; not general proof |
| Missing data | killer attribution, death health/buffs/group, per-zone active time, cell XP/time |

## 6d. DS-17.4C result

Result: `docs/DS-17-04C-RETENTION-MERGE-COMPATIBILITY-RESULT.md`

| Finding | Number |
|---|---|
| Array contexts at 10k×12 | 4.37 MB full; top-8 3.15 MB, 93.8%/92.2% detail; top-8+other 9.79 MB, 100% totals |
| Keyed-map contexts at 10k×12 | 70.70 MB (DS-17.4A) — array/list is required cold |
| Packed contexts | 1.81 MB full; 1.43 MB top-8+other |
| Active totals | zone kills/XP/activeSeconds/deaths preserved |
| Heatmap normal density | 0.5–5%; top hotspot overlap degrades as density rises |
| Aggregation | cold totals rebuild exactly; no merge implemented |

## 6e. DS-17.5 result

Result: `docs/DS-17-05-SCHEMA-AND-MIGRATION-RESULT.md`

| Finding | Result |
|---|---|
| v2 Journey migration | 158 mobs, 1,993 kills, 152,816 XP, 385 cells, 16 deaths, 38 quests, 69 respawns preserved |
| Idempotent | yes |
| Migration cost | 1.2 ms; 0.49 MB v2 heap on local sample |
| Player vs mob level | v1 `killsAtLevel` is player level; v2 renames to `byPlayerLevel`; mob level range separate |
| Missing after migration | active time, combat/XP contexts, death attribution/health/buffs/group, heatmap XP/time, character class/race/faction |
| Account Knowledge | target defined; no merge implemented |
| Downgrade | newer schema rejected |

## 6f. DS-16 result

Result: `docs/DS-16-SAVE-CHECKPOINT-RESULT.md`

| Finding | Result |
|---|---|
| Full encode, 400×10 KB blocks | 795 ms; 5.11 MB base64 |
| Dirty 1 / 10 / 100 blocks | 2.1 / 21.2 / 206.5 ms |
| Save encoded file | 4.2 ms |
| Full reload + base64 decode all | 1,153.6 ms — lazy selected-block decode required |
| Backup/restore | previous block retained and restored |
| Oversize state | normal → oversized → compacting → normal |
| Policy | no per-kill save; account Knowledge writes deferred |

## 6g. DS-15 result

Result: `docs/DS-15-LAZY-RETRIEVAL-CACHE-RESULT.md`

| Finding | Result |
|---|---|
| Login | 8.0 ms load; **0 blocks decoded** |
| Selected block | 1.7 ms decode; 10k selected-zone tooltips 1.2 ms |
| Full decode | 586 ms — must not happen at login |
| Random global cold tooltip | 16.2 s without cache; 5.8 s with 256-block cache (62.3% hit) |
| Best zone / heatmap | summary queries; no block decode; 77.6 ms / 0.34 ms per 10k |
| Missing/corrupt | safe fallback; cache not poisoned |
| Implication | global tooltip must use hot/registry/summary, not arbitrary cold blocks |

## 6h. DS-11 decision record

Result: `docs/DS-11-DECISION-RECORD.md`

Settled: Journey/Knowledge split; no arbitrary caps; per-zone blocks; 64/32/16;
packed codec; no shipped names; player/mob level separation; array contexts;
top-8+other; selected-block lazy decode; dirty-block save; oversize recovery.

Deferred: account Knowledge merge; LoadOnDemand companion; route/UI; V-2 live
checks. Implementation order: DS-14 → CAP-1 → IMP-1 → V-2 → UI.

## 6i. DS-14 result

Result: `docs/DS-14-OVERSIZE-GUARD-RESULT.md`

| Finding | Result |
|---|---|
| Constant budget | 340k constants split into 4 chunks under 100k; max 99,450 |
| Oversized block | rejected, not truncated |
| Save-blocked state | blocked saves do not write; compaction restores normal save |
| Backup/restore | previous generation restored |
| Downgrade | schema 2 accepted; schema 3 read-only/rejected |
| Exact client limit | V-2 check |

## 6j. CAP-1 result

Result: `docs/CAP-1-JOURNEY-CAPTURE-FIELDS-RESULT.md`

| Finding | Result |
|---|---|
| Health bands | 0–20/21–40/41–60/61–80/81–100; missing → unknown |
| Context split | combat = health/buffs/group/levels/class/difficulty; XP = group/rested/buffs/levels/class; quest excluded |
| Mob level | range min/max/samples; unknown must not become player level |
| Time | event-driven only; presenceSeconds + engagedSeconds; no timer/OnUpdate; one logout finalizer; quest turn-in is a sparse anchor |
| Heatmap cell | kills/XP/presenceSeconds/engagedSeconds |
| Death | attribution/health/buffs/group/class/difficulty; no attribution → no mob-level danger |
| Quest turn-in | existing `QUEST_TURNED_IN` anchors presence and separates quest XP; no engaged time; not in mob context |

## 6k. IMP-1 integration slice result

Result: `docs/IMP-1-JOURNEY-SCHEMA-RETRIEVAL-RESULT.md`

| Finding | Result |
|---|---|
| Local integration | 158 mobs, 3 zone blocks, 106 zone mobs; 2.2 KB encoded |
| Login | 0 blocks decoded |
| Selected zone 1424 | 0.32 ms, 44–45 records |
| Event time | presence 160 s, engaged 130 s; no timer |
| Quest anchor | quest XP 1,150; presence anchor; not engaged time |
| Best zone | total XP rank Zone C; kill-only rank Zone B |
| Heatmap | map 1421, 198 cells, top-10 share 23.2% |
| Fallback | missing/corrupt block safe |

## 6l. IMP-1A instrumentation result

Result: `docs/IMP-1A-JOURNEY-INSTRUMENTATION-RESULT.md`

| Finding | Result |
|---|---|
| Production module | `KillHistory/Journey.lua`; additive `self.char.journey` |
| Time | event-driven only; presence 200 s / engaged 140 s in test |
| Quest anchor | questXP 500; no engaged time; lastTurnInAt set |
| Events | existing events + `PLAYER_LOGOUT` only |
| Tests | `tests/journey.lua` and full smoke suite pass |
| Remaining | v2 migration, blocks, save/guard, retrieval, danger/heatmap queries |

## 6m. IMP-1B query API result

Result: `docs/IMP-1B-JOURNEY-QUERY-RESULT.md`

| Finding | Result |
|---|---|
| APIs | zone/level stats, best zones total/kill, heatmap top cells, mob/quest/time summaries |
| Best zone | total XP/hour ranks quest-heavy zone; kill-only ranks kill-heavy zone |
| Confidence | low <1,800s, medium ≥1,800s, high ≥7,200s |
| Legacy | zone kills merge from `db.areas` |
| Tests | `tests/journey_queries.lua`; run_all passes |
| Remaining | migration, blocks, save/guard, UI integration |

## 6n. IMP-1B2 block storage result

Result: `docs/IMP-1B2-JOURNEY-BLOCK-STORAGE-RESULT.md`

| Finding | Result |
|---|---|
| Blocks | per map zone and instance; varint record format |
| Storage | base64 + checksum; dirty-zone flush |
| Login | zero decode |
| Retrieval | selected-block lazy decode; 8-block LRU |
| Test | map/instance blocks, cache, dirty rebuild, corrupt/missing fallback |
| Limitation | blocks built from legacy data; duplication remains; UI/save integration pending |

## 6o. IMP-1B3 block-retrieval result

Result: `docs/IMP-1B3-BLOCK-RETRIEVAL-RESULT.md`

| Finding | Result |
|---|---|
| Mob→block index | `journey.mobZones` rebuilt on flush |
| Block-backed lookup | works with `db.mobs` emptied |
| Query fallback | `GetMobJourneySummary` uses block with `source="block"` |
| Cache | lazy selected-block decode |
| Remaining | legacy retirement, tooltip/UI/save guard integration |

## 6p. IMP-1B4 save/guard result

Result: `docs/IMP-1B4-SAVE-GUARD-RESULT.md`

| Finding | Result |
|---|---|
| Block backup | previous block/index retained per dirty zone |
| Restore | `RestoreJourneyBlocks()` restores and clears cache |
| Oversize | `SAVED_VARIABLES_TOO_LARGE` sets `saveBlocked` |
| Filtering | foreign add-on events ignored |
| Blocked write | flush refuses; previous block intact |
| Recovery | explicit reset resumes saving |
| Tests | `tests/journey_save_guard.lua`; run_all passes |

## 7. Required tests

### Tier 1 — model and schema (offline, now)

1. **Journey field inventory** from the local save: which fields exist, which
   dimensions are missing, and which are needed for danger/XP/hour/heatmap.
2. **Context cardinality:** count combat and XP context keys per mob. Measure
   full vs top-N vs collapsed context storage, lookup, and information loss.
3. **Danger model:** simulate kills/deaths under contexts; compute death rate,
   confidence, sparse-data behavior, and “player slaughter” outcome.
4. **Best-zone XP/hour:** synthetic zones/levels/sessions with varied active
   time, group, rested, buffs, and deaths; verify ranking and confidence.
5. **Heatmap best-cell:** per-cell kills/XP/active time; top-N ranking and
   downsampling effect.
6. **Retention compatibility:** cold archive must preserve byLevel/byMap/
   combat/xp/context/time fields needed for future aggregation.
7. **Schema shape comparison:** current nested records vs normalized parallel
   arrays vs packed blocks; measure size, update cost, query cost, and
   migration safety.

### Tier 2 — account-wide derived model (future, prototype only)

8. **Character → account aggregation prototype:** read a character save, build
   account Knowledge, and verify additive counts/time/samples.
9. **Multiple-character merge:** overlapping mobs/zones, idempotence,
   project/interface/level-cap separation.
10. **Account size/load/save:** map vs packed, login/checkpoint cost.
11. **Rebuild/deletion:** Knowledge can be rebuilt from surviving character
    data; no raw history copied.

### Tier 3 — live/API availability (V-2; permission required)

12. **Killer attribution:** can a player death be tied to the killing mob?
13. **Health/outcome capture:** player health before/after, time-to-kill,
    damage taken.
14. **Buff/group/rested capture:** available and stable on Forever/Midnight.
15. **Per-zone/level active time:** can it be measured without a per-kill log?
16. **XP events:** actual XP, group/rested/buff context, unattributed group XP.
17. **SavedVariables size/parse/save and migration/backup.**

### Tier 4 — retrieval and recommendation quality (later)

18. Tooltip latency with danger/XP contexts.
19. Best-zone query latency and confidence.
20. Heatmap best-cell latency and downsampling.
21. Recommendation backtesting with held-out characters.

## 8. Success criteria

- Per-character Journey supports tooltip, danger, best zone, heatmap, quests,
  respawns, and future analysis without a per-kill event log.
- No small global cap is treated as the design.
- Account Knowledge can be derived later from Journey data.
- Danger and best-zone answers show sample/confidence and do not invent data.
- Storage remains within measured size/load/save budgets.

## 9. Task impact

| Task | Revision |
|---|---|
| DS-17.1 | Add Journey/Knowledge split, active time, danger/XP contexts, death attribution |
| DS-17.4 | Define account Knowledge target; defer merge implementation |
| DS-17.5 | Schema/migration: field ownership, versions, contexts, active time |
| DS-15 | Retrieval: tooltip, danger, best zone, heatmap |
| DS-16 | Save policy for richer Journey; account knowledge later |
| DS-9 | Retention must preserve aggregation dimensions |
| DS-6 / F1 | Static metadata learned locally; Journey remains primary |
| DS-7 / DS-12 | Codec remains valid for Journey and future Knowledge blocks |
| DS-11 | Decision record must include this model and test results |
| V-2 | Verify killer/health/time/buff/group/active-time/API availability |
