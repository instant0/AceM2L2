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
