# DS-1 — Feature data contract and consumer inventory

**Status:** executed; contract and quality pass complete  
**Parent:** storage architecture  
**Depends on:** none  
**Blocks:** DS-3, DS-4, DS-17.1  
**Purpose:** define what every feature requires from storage before choosing a
new schema.

## 1. What this document is

A **feature contract**, not a schema and not a content census.

For each consumer it records:

- data scope;
- required fields;
- query/update pattern;
- fallback when data is absent;
- retention tier;
- whether the data is canonical or derived;
- duplication risk.

A field is **canonical** when it is the source of truth. A **derived** field can
be recomputed from canonical data. A **view** is recomputed on demand.

## 2. Scopes

| Scope | Meaning |
|---|---|
| Account | settings/profile, not character history |
| Character/client | per-character, per-project root |
| Current mob | one NPC/name lookup |
| Current zone | zone-scoped subset |
| Current instance | instance-scoped subset |
| All-character summary | counts/lists across the character |
| Hot | current/recent level or zone |
| Warm | recent history, summarized |
| Cold/archive | old levels/zones, compressed/read-only |
| Shared | account-wide aggregate leveling knowledge |

## 3. Feature contracts

### 3.1 Tooltip — mob hover

| Item | Contract |
|---|---|
| Scope | current mob, current zone; current level |
| Required | `mob.kills`, `mob.killsAtLevel[playerLevel]`, `mob.contexts[contextKey]` (solo), `mob.npcID`, `mob.name`, `mob.classification`, `mob.xp` (optional summary) |
| Query | direct `npc:<id>` lookup; name fallback |
| Update | read-only; no write on tooltip |
| Fallback | formula/global estimate if no mob history; never false zero |
| Retention | hot/warm mob entry |
| Canonical | `mob` entry and context observations |
| Risk | name-only scan of all mobs is not acceptable for on-demand loading |

**Loading contract:** current mob must be resolvable without decoding every
zone. A compact `name -> npc/keys` index is acceptable; a full scan is not.

### 3.2 Overview

| Item | Contract |
|---|---|
| Scope | all-character summary |
| Required | `totals.kills`, `session.kills`, `totals.uniqueMobs`, `areas`, `mobs[*].kills/name`, `levels`, `dungeon`, `totals.xp`, quest XP summary, `economy`, `goal` |
| Query | top-N scans/summaries |
| Update | per kill/session/zone change |
| Fallback | zero/none state |
| Retention | persistent summaries; `areas`/`levels` may be derived |
| Risk | storing `areas`/`levels` as duplicate full maps |

### 3.3 Mobs list

| Item | Contract |
|---|---|
| Scope | all-character; current-zone subset when filtering |
| Required | `mob.name`, `kills`, `sessionKills`, `killsAtLevel`, `xp.samples/sumBase`, `classification`, `lastSeen` |
| Query | iterate/filter/sort; could be zone-scoped |
| Update | per kill |
| Fallback | empty list |
| Retention | hot/warm mobs; cold top-N |
| Risk | full mob iteration for every list build |

### 3.4 Areas list and detail

| Item | Contract |
|---|---|
| Scope | open-world zones plus instances |
| Required | `areas[map]`, `areaLevels[map]`, `instances[key]`, `totals.kills`, `mob.killsByMap`/`killsByInstance`, names |
| Query | list + selected detail |
| Update | per kill |
| Fallback | no rows |
| Retention | persistent summaries; detail hot/warm |
| Risk | `areas`/`areaLevels` duplication; instance vs area double count |

### 3.5 Levels list and detail

| Item | Contract |
|---|---|
| Scope | all-character |
| Required | `levels[level]`, `totals.kills`, `mob.killsAtLevel`, `mob.name`, `mob.kills` |
| Query | list + selected detail |
| Update | per kill |
| Fallback | no rows |
| Retention | persistent summary; mob detail hot/warm |
| Risk | `levels` vs `mob.killsAtLevel` duplication |

### 3.6 Heatmap tab

| Item | Contract |
|---|---|
| Scope | current zone or selected zone |
| Required | `heatmaps[mapID].gridSize`, `.cells`, `.total`, `.lastSeen`; `heatmapEnabled` |
| Query | selected zone only; map switch |
| Update | per kill; render on tab |
| Fallback | disabled state / no data |
| Retention | hot 64×64, warm 32×32, cold 16×16 |
| Risk | normalizing every stored zone at login |

**Loading contract:** load current/selected zone; evict old zones unless within
a small LRU. Empty cells are absent, not zero-stored.

### 3.7 Detail panel

| Item | Contract |
|---|---|
| Scope | selected mob/area/level/instance |
| Required | mob fields plus `xp`, `killsByMap`, `killsAtLevel`, `firstSeen/lastSeen`; instance `name`, `kills`, `xp`, `instanceType`, `killsAtLevel`, `lastSeen`; area `areaLevels`; top-mob field |
| Query | selected item only |
| Update | on selection |
| Fallback | empty detail |
| Retention | current + selected item |
| Risk | generic top-mob helper assumes one field/table shape |

### 3.8 Commands

| Item | Contract |
|---|---|
| Scope | varies: kills, deaths, respawns, heatmaps, sessions, dungeon, goal, economy, stats |
| Required | all relevant roots; see commands implementation |
| Query | explicit user request |
| Update | read-only; some commands reset/delete |
| Fallback | "no data" message |
| Retention | full summary; archives may load on demand |
| Risk | commands that iterate all mobs/zones at once |

### 3.9 Data diagnostics

| Item | Contract |
|---|---|
| Scope | metadata/counts across stores |
| Required | readers for mobs, quests, deaths, respawns, heatmaps, instances, levels, rates, contexts, calibration; estimated bytes; collection state |
| Query | counts; bounded traversal |
| Update | on refresh |
| Fallback | zero counts |
| Retention | all stores; should not require full decode |
| Risk | estimator truncation and fixture-only memory confusion |

### 3.10 Calibration

| Item | Contract |
|---|---|
| Scope | current mob/zone/level/context |
| Required | `mob.contexts`, `calibration.zones/levels/groups/classes/mobs` |
| Query | point lookup by context key |
| Update | solo kill observations |
| Fallback | formula/group prior |
| Retention | hot/warm; contexts age out |
| Canonical | context observations; calibration ratios are derived |
| Risk | group observations currently skipped; contexts can dominate storage |

### 3.11 Deaths, respawns, rates, level history

| Store | Required fields | Scope/retention |
|---|---|---|
| `deaths` | `at,mapID,x,y` | last 100; persistence |
| `respawns` | `name,intervals,lastSeen,lastDeath` | 300 NPCs × 20; persistence |
| `rates` | `at,xp,source,mapID,level` | 240 recent; hot/rolling |
| `levelHistory` | level, start/end, xp, kills, duration | 200 records; persistent |
| `economy` | loot/gold/session/money fields | summary; persistent |
| `goal` | target level/XP/created | persistent |
| `session` | startedAt/kills/xp | reset per session |

### 3.12 Future Journey and cell inspector

| Feature | Required data | Scope |
|---|---|---|
| Journey | zone/instance sequence, time/kill path, heat cells | per-zone/selected archive; lazy |
| Cell inspector | per-cell mob/level/instance counts, top mobs | selected zone/cell; not current schema |

These are contract requirements only; they do not authorize implementation
before DS-11.

## 4. Canonical versus derived

| Data | Status | Notes |
|---|---|---|
| `mobs[key]` identity/counts | canonical | source of truth for mob history |
| `mob.killsByMap`, `killsByAreaLevel` | canonical | open-world aggregation |
| `mob.killsByInstance`, `killsByInstanceLevel` | canonical | instance aggregation |
| `areas`, `levels`, `areaLevels` | derived duplicates | candidates for rebuild-on-demand |
| `instances` | canonical | instance identity/summary |
| `dungeon` | derived aggregate | PvE instance totals |
| `heatmaps` | canonical | per-zone cells |
| `mob.contexts` | canonical observations | calibration input |
| `calibration.*` | derived ratios | rebuildable/summary |
| `totals`, `session` | canonical counters | invariant-checked |
| `deaths`/`respawns`/`rates`/`levelHistory` | canonical | separate stores |
| `quests`, `economy`, `goal` | canonical | independent roots |

## 5. Invariants

For open-world kills:

- `areas[map]` = sum of `mob.killsByMap[map]` across mobs.
- `areaLevels[map][level]` = sum of `mob.killsByAreaLevel[map][level]`.
- `levels[level]` = sum of `mob.killsAtLevel[level]` across mobs.

For instances:

- `instances[key].kills` = sum of `mob.killsByInstance[key]`.
- `instances[key].killsAtLevel[level]` = sum of `mob.killsByInstanceLevel[key][level]`.

Global:

- `totals.kills` = sum of `mob.kills`.
- `totals.uniqueMobs` = count of non-empty mob entries.
- instance kills are not in `areas`.
- per-client roots are separate; no Forever/Midnight mixing.
- cap pruning is deterministic.
- a missing subset has a defined fallback, never a false zero.

## 6. Loading/query contract

| Consumer | Default scope | Must not do |
|---|---|---|
| Tooltip | current mob + current-zone subset | scan/decode every zone |
| Heatmap | current/selected zone | normalize all zones at login |
| Mobs list | all-character or selected zone | rebuild from full per-kill data |
| Areas/Levels | summaries | duplicate canonical detail unnecessarily |
| Detail | selected item | load unrelated zones |
| Commands | requested roots | force full decode for simple counts |
| Diagnostics | counts | materialize all zones |
| Journey/Inspector | selected zone/cell | require global raw history |

## 7. Quality pass

Verified against:

- `KillHistory/Tooltip.lua`
- `KillHistory/UI/Overview.lua`
- `KillHistory/UI/List.lua`
- `KillHistory/UI/Detail.lua`
- `KillHistory/UI/Diagnostics.lua`
- `KillHistory/Commands.lua`
- `KillHistory/Calibration.lua`
- `KillHistory/World.lua`
- `KillHistory/Heatmap.lua`
- `KillHistory/UI/Heatmap.lua`
- `KillHistory/Data.lua`, `Tracking.lua`

Findings:

- Tooltip direct lookup is fine; name-only fallback (`FindNPCKeyByName`) scans all
  mobs and must become an index for on-demand loading.
- `areas`, `levels`, and `areaLevels` duplicate canonical mob data; decide
  whether to keep them as derived caches.
- Instance kills are separate from `areas`; the Areas UI must not double-count.
- Heatmap normalization currently processes all stored zones; zone-scoped
  loading is a valid design goal.
- `mob.contexts` and calibration are the main storage-growth risk.
- `deaths/respawns/rates/levelHistory` are independent and can be capped
  separately.
- Future Journey/inspector require selected-zone subsets; not the current global
  raw table.

### Quality-pass result

- Contract cross-checked against the current tooltip, UI list/detail/overview,
  commands, diagnostics, calibration, world, heatmap, data, and tracking modules.
- `./tests/run_all.sh` passes.
- Open gaps are recorded in section 8 and
  `docs/tasks/DS-1-FOLLOWUP-TASKS.md`.
- No production code changed.

## 8. Open questions

1. Keep `areas`/`levels`/`areaLevels` as derived caches or rebuild on demand?
2. Is `mob.killsByAreaLevel` needed if `areaLevels` is canonical/derived?
3. Should tooltip name fallback use a compact index or NPC ID only?
4. What is the LRU budget for zone subsets?
5. Can the current UI lists query a zone-scoped index without loading all mobs?
6. Should diagnostics count archives without decoding them?
7. What fallback text should appear for an unloaded zone subset?

## 9. Acceptance

- Every current consumer has a field/scope/fallback contract.
- Canonical and derived data are identified.
- Invariants are explicit.
- Zone-scoped tooltip/heatmap requirements are captured.
- DS-3/DS-4/DS-17.1 can use the contract without re-reading every UI file.
- No schema implementation is authorized by this document.
