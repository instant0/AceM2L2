# Storage strategy — consolidated

**Status:** authoritative strategy summary; not implemented  
**Inputs:** PLAN addon/API research, DS-1, DS-2, DS-3, DS-4, DS-5,
`docs/DS-17-1-CAPACITY-AND-STRATEGY.md`, HC-5, H64-9, MEM-1  
**Purpose:** keep the prior addon/method research and the resulting storage and
retrieval strategy in one place. This is not a new investigation.

## What was inspected

### Addon patterns

- **AllTheThings:** multiple `SavedVariables` plus
  `SavedVariablesPerCharacter`; large static database under `db/` loaded as Lua;
  account/character/cache/UI roots separate; sparse numeric ID sets. Reference
  figures: old sample 204,987 bytes / 11,433 entries; new sample 2,673,713 bytes
  / ~186,000 entries; ~51 MB loaded, ~65 MB opened, several hundred MB on
  Midnight.
- **Questie / QuestieDB:** static `QuestieDB` as a separate Lua database addon;
  `QuestieConfig` account plus `QuestieConfigCharacter` per character;
  `LoadSavedVariablesFirst: 1`.
- **Carbonite:** one `CarbData` AceDB with `profile`, `global`, and `char`
  scopes; per-character data inside the global saved variable.
- **ForeverLevelingGuide:** static guide data plus per-character progress;
  ~48 MB reference. Do not assume internals.
- **TradeSkillMaster:** nested UI state and long namespaced keys; 234,786 bytes,
  2,237 string keys / 30.8 KB, plus one 166.7 KB item-info string.
- **Blizzard console:** 1,328,130 bytes dominated by 1,295 KB of strings; one
  large blob is cheaper than thousands of tiny records.
- **Current AceM2L2:** 70,661 bytes, 729 tables, 3,366 entries, ~21.6 KB key
  text; 85 mobs / 762 kills / 2 heatmap zones / 193 cells / 1 instance.
  Memory samples: 3.2 MB (389 kills/25 mobs) and 3.85 MB (762 kills/85 mobs,
  heatmap open).

### What already exists in the game

- **Identity:** the client provides NPC IDs, map IDs, instance IDs, levels,
  classes, and names. Saved data should store the IDs/counts, not repeated names.
- **SavedVariables:** account and per-character scopes. Per-character data loads
  only for the active character; account data loads for every character.
- **Loading:** normal SavedVariables load together; only a LoadOnDemand addon can
  defer its own code/data. There are no per-zone SavedVariables files.
- **Lua 5.1:** no native JSON, Base64, compression, or `string.pack`; any packed
  codec is addon code.
- **No built-in database:** addons ship static Lua metadata (QuestieDB/ATT
  pattern), derive from client APIs, or store their own tables.
- **64×64 cells:** an addon data model, not a client feature.
- **Existing addons:** AllTheThings, Questie/QuestieDB, Carbonite,
  TradeSkillMaster, ForeverLevelingGuide, and Blizzard's own saved data provide
  patterns, not code to copy.

### Memory reference

Recorded AceM2L2 samples are **3.2 MB** (389 kills/25 mobs) and **3.85 MB**
(762 kills/85 mobs with the Silverpine heatmap open). Your ~3.7 MB figure is
consistent with that range.

AllTheThings was ~**51 MB loaded / 65 MB opened**, with several hundred MB on
Midnight. That is a different addon with a large static database and different
features. It shows the client can carry large data, not that the current
AceM2L2 caps are sufficient.

### Methods inspected

- nested Lua tables vs JSON-like blobs;
- stable IDs/dictionaries vs checksums;
- packed binary/string blocks and Base64;
- 64×64 zone cells vs exact coordinates;
- dedup by canonical identity and derived views;
- multiple SavedVariables vs LoadOnDemand companion;
- static metadata in Lua/TOC vs saved data;
- account vs per-character roots;
- indexes rebuilt in memory;
- hot/warm/cold retention.

## Decisions already made

| Question | Decision |
|---|---|
| Hot representation | Plain nested Lua tables with stable IDs, sparse count/cell maps, derived summaries |
| JSON | No for SavedVariables; Lua tables are native |
| Base64 | No for hot data; optional wrapper for a binary cold block |
| Checksums | Corruption detection only; never identity |
| Identity | `npcID` primary; normalized-name/local-ID fallback; `mapID`/`instanceID`/level |
| Heatmap | Sparse 64×64 cells; exact coordinates only for deaths/Journey |
| Per-kill log | No |
| Dedup | One mob record per identity; names once; derived `areas`/`levels`; lazily created optional fields |
| Static metadata | TOC/Lua data, outside the character save |
| Account vs character | Account root: settings + small aggregates; character root: raw active-character history |
| Multiple normal variables | All load together; do not use them expecting deferral |
| LoadOnDemand companion | Only real file-level deferral; timing is a V-2 check |
| Per-zone SavedVariables | Not possible |
| SaveAddOns | Checkpoint, not per-kill durability |
| SAVED_VARIABLES_TOO_LARGE | Out-of-memory load failure; next logout will not save; recovery required |

## Massive-scale verdict

The current capped, hot-only store is **not massive-ready**.

- Current caps: 2,000 mobs, 40 heatmap zones, 100 instances, 12 contexts/mob.
- 15k–32.5k kills with 2,000 mobs and 40 dense zones is roughly **11–14 MB**
  if 12 contexts and full 64×64 grids are kept.
- 200 zones/200 instances at 12 contexts is roughly **18–25 MB** if all hot.
- 200 zones at 4,096 cells each is 819,200 cells; at ~18 bytes/cell that is
  roughly 14–15 MB before mobs/contexts.
- The 2.1 MB HC-5 extreme figure is truncated at the 200,000-entry estimator
  cap. It is a lower bound, not a ceiling.

Raising the global caps without changing the architecture would multiply
contexts, cells, login load, save cost, and all-mob scans. That is not the
solution.

## Player scenarios and loading

| Scenario | Hot state | Cold/archive | Shared |
|---|---|---|---|
| Level 1, first character | account settings + active character; little/no history | none | optional shared leveling aggregates |
| Level 4, early leveling | active character; current zone; tooltip only | none | optional |
| Level 20 leveling | active character; recent levels/zones/instances; selected heatmap | older levels/zones | optional |
| Max level, endgame | active character endgame state; current zones/instances; reputation | leveling history read-only archive; old heatmaps downsampled | aggregate leveling knowledge |
| First alt with level 60 main | only the alt's per-character data; main's raw history is not loaded | main archive lazy; alt's own archive if any | account aggregates only |
| 10-year veteran | one active character's hot set | many per-character archives, cold/downsampled; no other characters loaded | small account aggregates |
| Midnight endgame | counts/reputation/non-XP history; no XP formula detail | leveling archive | aggregate knowledge |

The key rule: **only the active character's raw history loads**. A max-level
main does not make a new alt load the main's data. Shared knowledge is aggregate
only.

## Task coverage

| Concern | Task / status |
|---|---|
| Loading, unloading, eviction, UI release | MEM-2 task; DS-15/DS-16; design after DS-17.3; not implemented |
| Account vs character vs static vs companion split | DS-5 done; root matrix in `docs/STORAGE-DIRECTION.md`; final schema DS-17.5 |
| Level 1 / level 20 / max level / first alt / veteran | DS-1 contract done; DS-17 master; DS-17.1/2/3/4 pending |
| Best storage representation | DS-4 done/revised; capacity doc done; DS-4P hybrid prototype required |
| Retrieval and indexes | DS-1 consumer contract done; DS-1-F2 index is the safe first code task; DS-15 pending |
| Capacity validation | DS-3B next: one actual worst-case synthetic file; model is provisional |
| Packed cold blocks | DS-7/DS-12 pending; required for massive |
| Memory comparison and budget | MEM-1 partial; MEM-2 pending; V-2 live check |
| Game/client static data | DS-6 pending; use IDs and static Lua where feasible |
| Save/checkpoint/oversize | DS-5 done; DS-14/DS-16 pending |
| Existing addon patterns | Captured here and in PLAN; not copied |

## Target architecture

### 1. Static metadata

- NPC/zone/class/instance names and IDs in TOC/Lua, not SavedVariables.
- Shared by every character; versioned with the addon.
- Feasibility/licensing: DS-6.

### 2. Account root

- `AceM2L2DB`: settings, UI profile, small bounded aggregate leveling knowledge.
- Loads for every character, so keep it small.
- No raw character history.

### 3. Per-character hot tier

- `AceM2L2CharDB`: active-character data.
- Bounded hot set: 2,000 mobs, 40 hot zones, 100 hot instances.
- 4 contexts/mob default, 8 recent, 12 only for the current band if measured.
- Sparse cells; capped per-mob zone/instance links.
- Small derived `areas`/`levels`/`areaLevels` caches.
- In-memory name/zone/instance indexes.

Target: roughly **6–8 MB hot per active character**.

### 4. Packed cold tier

- Zone/level blocks, numeric IDs, varint/delta counts, optional bit-packed cells.
- Versioned, checksummed, with a plain fallback.
- Decode only the selected block; LRU cache.
- Old zones downsampled: 64×64 hot, 32×32/16×16 cold.
- Contexts collapsed/archived.
- No per-zone SavedVariables files.

### 5. Optional companion

- LoadOnDemand addon only if V-2 proves variable timing and measured size/load
  win.
- Load from `PLAYER_LOGIN` or a user action, not from `ADDON_LOADED`.
- Missing-companion fallback required.

### 6. Retrieval

- Tooltip: direct NPC/name index; no all-mob scan.
- Mobs/Areas/Levels: selected-zone index + compact global summary; no global
  scan.
- Heatmap: normalize/render selected zone only.
- Diagnostics: counts and summary indexes, no full decode.
- Alt/shared knowledge: account aggregates only.

### 7. Retention instead of global caps

- Remove the 2,000/40/100 global caps as the massive limit.
- Replace with per-zone/per-block retention and cold archives.
- Keep total live data bounded; let cold storage grow.
- Leveling vs endgame modes; archive old level bands.
- PvP, arenas, scenarios, and delves separate from open-world areas.

## Capacity targets

| Scenario | Hot estimate |
|---|---:|
| 2k mobs / 40 dense zones / 4 contexts | ~6–8 MB |
| 2k mobs / 40 dense zones / 8 contexts | ~9–11 MB |
| 2k mobs / 40 dense zones / 12 contexts | ~11–14 MB |
| 2k mobs / 200 dense zones / 12 contexts | ~18–25 MB all hot |
| 2k mobs / 200 zones × 1k cells / 12 contexts | ~12–15 MB all hot |

The 6–8 MB target comes from 4 contexts, 40 hot zones, 100 hot instances, and
cold/downsampled archives.

## Task map

- **DS-3B:** one actual worst-case synthetic file to validate/correct the
  capacity model before final hot/cold decisions.
- **DS-17.1:** feature-to-data matrix, cardinality, hot/warm/cold boundary,
  no-global-cap policy, 64×64 decision, required keys.
- **DS-17.2:** leveling/endgame modes and archive generations.
- **DS-17.3:** context collapse, heatmap downsampling, retention.
- **DS-4P:** hybrid hot/cold prototype. Required.
- **DS-7/DS-12:** packed cold-block format and codec. Required.
- **DS-13:** optional LoadOnDemand companion.
- **DS-15:** lazy retrieval and indexes.
- **DS-16:** save/checkpoint policy.
- **DS-9:** retention/migration.
- **DS-17.5:** final schema and migration.
- **DS-11:** decision record.

## What is still open

- exact hot/warm/cold boundaries;
- exact codec and packed-block envelope;
- exact per-zone/per-block retention caps;
- what 64×64 loses versus 96/128 for routes/cell inspector;
- companion timing/persistence in V-2;
- migration/backup/downgrade details;
- whether account-wide aggregates need confidence weighting.

## Bottom line

The prior research is not lost. It supports a clear decision:

- keep the compact hot Lua index;
- stop treating the global caps as the design;
- add a packed cold tier and per-zone retention;
- use static metadata and in-memory indexes;
- keep account data small and per-character data active-only;
- prototype the hybrid before changing production.

No production code changed.
