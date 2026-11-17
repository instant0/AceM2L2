# Storage strategy — consolidated

**Status:** authoritative strategy summary; not implemented  
**Inputs:** PLAN addon/API research, DS-1, DS-2, DS-3, DS-4, DS-5,
`docs/DS-17-1-CAPACITY-AND-STRATEGY.md`, HC-5, H64-9, MEM-1  
**Purpose:** keep the prior addon/method research and the resulting storage and
retrieval strategy in one place. This is not a new investigation.

**Full data-model plan:** `docs/DATA-MODEL-PLAN.md`  
**Model/test record:** `docs/DATA-MODEL-AND-TEST-MATRIX.md`

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

AllTheThings was ~**51 MB loaded / 65 MB opened** in early samples, with a later
**686 MB main-character report**, and several hundred MB on
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
| Static metadata | No shipped all-name list; live account name cache + optional scoped spawn/locality index, outside raw character history |
| Account vs character | Account root: settings + small aggregates; character root: raw active-character history |
| Multiple normal variables | All load together; do not use them expecting deferral |
| LoadOnDemand companion | Only real file-level deferral; timing is a V-2 check |
| Per-zone SavedVariables | Not possible |
| SaveAddOns | Checkpoint, not per-kill durability |
| SAVED_VARIABLES_TOO_LARGE | Out-of-memory load failure; next logout will not save; recovery required |

## Massive-scale verdict

The current capped, hot-only store is **not massive-ready**.

- Current hot caps: adaptive mobs (500/zone, min 2,000, max 12,000), 64 heatmap zones, 100 instances, 12 contexts/mob.
- The actual 2k/40-dense/12-context profile is **8.69 MB compact / 9.94 MB
  client estimate**, with **23 MB stable / 27–37 MB transient Lua heap**.
- That is a **current-cap** profile, not long-term. DS-3C: at 2h/day, 2,000 mobs
  are reached in ~3 months and the 240-rate-sample buffer turns over in 2.4h.
- The old 11–14 MB file estimate was high; the old 18–25 MB 200-zone figure is
  unmeasured and remains only an upper-bound guess.
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
| Capacity validation | DS-3B done: 8.69 MB compact / 9.94 MB client estimate / 23 MB stable / 27–37 MB transient heap for 2k/40/12 |
| Long-term pressure | DS-3C done: 2h/day hit the old 2,000-mob cap in ~3 months; move to cold blocks/adaptive retention before relying on the new 12,000 ceiling |
| Hybrid prototype | DS-4P done: 100k mobs/200 zones/200 instances, 38.5 MB hot / 8.07 MB cold, selected-zone 3.7 ms, no full scan |
| Hot index | DS-4P-F1/F2 done: numeric arrays + scoped name index; 7.73 MB hot + 5.97 MB shared at 100k |
| Packed cold blocks | DS-7/DS-12 done: hybrid sparse/bitset cells, varint/delta, no inline names, per-block base64+checksum; 100k/4ctx 3.90 MB cold, 350k sub-blocks 13.22 MB / 2.55 ms |
| Memory comparison and budget | MEM-1 partial; MEM-2 pending; V-2 live check |
| Game/client static data | DS-6/F1: no shipped all-name list; per-character mob metadata registry (name, fixed level range, ≤4 zone refs); learned live |
| Save/checkpoint/oversize | DS-5 done; DS-14/DS-16 pending |
| Existing addon patterns | Captured here and in PLAN; not copied |

## Target architecture

### 1. Mob metadata registry

- **No shipped all-name list.** Metadata is learned live from captured units.
- **Account-wide stable `npc:<id>` metadata:** one name, one fixed
  `levelMin`/`levelMax`, at most 4 zone/instance refs, optional classification.
  Shared by all characters on the same project/interface.
- **Per-character name-only `name:<lower>` metadata** plus the F2 scoped name
  index. Name-only identity is not merged across characters.
- Raw kills/XP/contexts/counts/heatmaps remain per character. Observed XP is
  not shared; base XP is computed from level/classification.
- Mobs are zone/instance/grid-localized; store per-zone/per-instance blocks,
  not a global all-mob/all-grid matrix.
- Local `/mnt/r/AceM2L2.lua` sample: 158 mobs, 100 npcID / 58 name-only;
  135 in one zone/instance, 23 in two; max observed 2 (assume ≤4); fixed level
  range, max width 4.
- Local account part: 100 entries 0.02 MB / 3.8 KB packed; name-only: 58
  entries 0.01 MB / 3.7 KB packed. Account-only 10k: 2.38 MB map / 0.42 MB
  packed; 100k: 35.97 / 4.16 MB.
- Account metadata loads for every character; pack it above a measured
  threshold. It grows with unique stable `npcID`s across the account, not with
  the number of characters. A pre-kill spawn index is deferred; locality is
  learned from kills.
- Do not copy QuestieDB/ATT/Carbonite. Keep Forever and Midnight separate.
- Shipped-name alternative remains rejected: 100k 10.67 MB map / 3.51 MB packed;
  350k 40.35 / 12.80 MB. See `docs/DS-6-F1-MOB-METADATA-REGISTRY-RESULT.md`.

### 2. Account root

- `AceM2L2DB`: settings, UI profile, small bounded aggregate leveling knowledge,
  and the account-wide stable `npc:<id>` metadata registry.
- Loads for every character, so keep it small and pack when large.
- No raw character history or observed XP.

### 3. Per-character hot tier

- `AceM2L2CharDB`: active-character data.
- The current implementation caps at 2,000 mobs, 40 hot zones, and 100 hot
  instances. These are **implementation caps, not the design limit**.
- The design stores all zones/instances in per-zone/level blocks; the hot cache
  is dynamic and evicts by measured memory/retrieval, not a hard-coded 40/100.
- Contexts are a tunable efficiency choice: 4/8/12 based on measured value, not
  an arbitrary target.
- Sparse cells; per-mob links are bounded by value, not a global count.
- Small derived `areas`/`levels`/`areaLevels` caches.
- In-memory name/zone/instance indexes.

There is **no fixed file-size or heap target**. DS-3B measured 8.69 MB compact /
9.94 MB client estimate and 23 MB stable / 27–37 MB transient for the current
2k/40/100 implementation profile. 23 MB stable is acceptable relative to ATT
51–686 MB reference range. Optimize the method, not an arbitrary MB number.

### 4. Packed cold tier

- Per-zone/instance/level-band blocks, numeric IDs, varint/delta counts.
- Hybrid cells: sparse at low density, bitset at higher density (DS-7/DS-12).
- No inline names; names resolve from the per-character metadata registry.
- Target ~256-512 mobs per block; split large zones/level bands.
- Versioned, checksummed, with a plain fallback.
- Per-block base64 in SavedVariables; decode only the selected block; LRU cache.
- Old zones downsampled: 64×64 hot, 32×32/16×16 cold.
- Contexts collapsed/archived; cold keeps 4/collapsed, not 12.
- No per-zone SavedVariables files.

### 5. Optional companion

- No companion is required for names: they are learned live.
- A LoadOnDemand companion is only for optional scoped spawn/locality data or a
  cold-archive package, and only if V-2 proves variable timing and a measured
  size/load win.
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

## Measured capacity

| Scenario | Hot estimate |
|---|---:|
| 2k mobs / 40 dense zones / 4 contexts | not measured; expected lower |
| 2k mobs / 40 dense zones / 8 contexts | not measured; expected lower |
| 2k mobs / 40 dense zones / 12 contexts | **8.69 MB compact / 9.94 MB client estimate; 23 MB stable / 27–37 MB transient heap** |
| 2k mobs / 200 dense zones / 12 contexts | not measured; old 18–25 MB is an upper-bound guess |
| 2k mobs / 200 zones × 1k cells / 12 contexts | not measured; old 12–15 MB is an upper-bound guess |

There is no fixed target. At 12 contexts the measured file is 8.69 MB compact /
9.94 MB client estimate with 23 MB stable / 27–37 MB transient heap. Use 4/8
contexts only if measurement shows a better retrieval/memory trade-off; use
cold/downsampled archives to scale beyond the current hot implementation caps.

## Task map

- **DS-3B:** one actual worst-case synthetic file to validate/correct the
  capacity model before final hot/cold decisions.
- **DS-3C:** long-term 3/6/12-month growth and cap pressure. Current caps are
  too small.
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
