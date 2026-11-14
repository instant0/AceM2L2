# Storage direction

**Status:** working design direction; not implemented  
**Basis:** Lua 5.1 behavior, WoW SavedVariables/loading rules, current code, and
the existing samples. This is the consolidated answer set for DS-4.

## Answers

| Question | Decision | Confidence |
|---|---|---|
| How to organize data for retrieval without duplicate entries | Canonical per-character aggregate records keyed by stable identity, with in-memory indexes rebuilt at load and derived views for Areas/Levels | High |
| How to optimize and still read correctly | Hot data stays as plain Lua tables with direct lookups; pages query the active/selected zone; cold data is decoded only if a packed archive is adopted | High |
| How to reuse data on another character | Keep raw history per character; share account-wide aggregate leveling knowledge and static metadata; never copy one character's raw history | High |
| Is nested JSON the best representation | No. SavedVariables are Lua tables, not JSON. JSON adds quoting/parsing and does not remove Lua key overhead | High |
| Should data be compressed with Base64 | No for hot data. Base64 expands by about 33% and adds CPU; only use it to wrap a binary cold block if one is justified | High |
| Can entries/zones/mob names be a checksum | No. Checksums are not reversible and can collide. Use `npcID`, `mapID`, `instanceID`, level, or a local numeric ID plus a name dictionary. Checksums are for corruption detection only | High |
| Can kills be stored as 64×64 zone blocks instead of coordinates | Yes for kill heatmaps. Kills already map to one of 4,096 cells. Keep exact coordinates only for deaths and, if approved, Journey | High |
| How to deduplicate to keep SavedVariables small | One canonical mob record, one zone/instance aggregate, derived `areas`/`levels`/`areaLevels`, numeric keys, names stored once, zero/default fields omitted, static metadata kept outside the character save | High |

## Representation rules

### Hot data

- Plain Lua tables with direct key lookup.
- Stable numeric IDs where possible: `npcID`, `mapID`, `instanceID`, level.
- For name-only mobs, allocate a local numeric ID and keep one canonical name.
  Rebuild the normalized-name and NPC-ID indexes in memory at load.
- Store the name once in the canonical record, not in every view or key.
- Sparse numeric maps for counts, levels, and 64×64 cells.
- Do not store an independent copy of totals that can be derived from canonical
  records.
- Do not introduce a per-kill event log. Aggregate at kill time.

### Cold/archive data

- Use plain Lua tables for warm data. A packed block is a later option, not the
  default.
- Adopt packed blocks only if a measured cold-zone sample gives a material size
  win without an unacceptable decode cost.
- If a packed block is adopted: version it, checksum it for corruption, and keep
  a plain fallback.
- Base64 is only an encoding wrapper for a binary cold block. It is not
  compression and is not used for hot tables.

### Names and identity

- `npcID` is the primary identity when available.
- A normalized name plus a local numeric ID is the fallback for name-only mobs.
- Merge a name-only record into its NPC-ID record when the ID becomes known.
- Never use a checksum as the primary key or as the only stored mob name.

### Heatmap

- Store a kill in exactly one 64×64 cell for the current map.
- Do not store per-kill coordinates.
- Keep exact coordinates for deaths and any approved Journey feature only.
- Keep open-world zones, dungeons, raids, PvP, and scenarios/delves as separate
  scene types rather than mixing them into one area total.

## Retrieval rules

- **Tooltip:** resolve the hovered mob through a direct identity index. The
  current NPC-ID path is O(1); the name-only path scans all mobs and needs an
  in-memory name index. Do not scan every mob or zone. If the record is
  unavailable, show the formula/global fallback, never a false zero.
- **Mobs / Areas / Levels:** use the active or selected zone index plus a compact
  global summary. Use the small derived `areas`/`levels`/`areaLevels` caches;
  rebuild them only when a cache is missing or a page plan replaces them.
- **Heatmap:** normalize and render the current or selected zone; release the
  previous zone or keep it in a small bounded cache. Current normalization
  iterates every zone at load, which is the gap to fix.
- **Diagnostics:** use counts and summary indexes, not full deep traversal.
- **Alt/shared knowledge:** query account-wide aggregates, not another
  character's raw records.

## Mobs in multiple zones

A mob can appear in several zones, several instances, or both. This is normal and
must be modeled as many-to-many, not as one zone per mob.

- Keep one global mob record per identity.
- Keep `killsByMap[mapID]`, `killsByAreaLevel[mapID][level]`,
  `killsByInstance[instanceKey]`, and `killsByInstanceLevel[instanceKey][level]`.
- Rebuild `zoneToMobs[mapID] = { [mobKey] = true }` in memory. A mob can belong
  to several zone sets.
- In a zone-filtered list, show and sort by the zone count, not the global mob
  total.
- In the global Mobs list, show the global total once.
- Show all zone/instance breakdowns in mob detail; the current detail shows only
  the top area.
- Deleting a mob removes all of its zone and instance counts.
- `totals.uniqueMobs` is a count of global identities, not the sum of per-zone
  unique counts.

Same-name mobs are not always the same NPC. The current name-only `name:` key is
global and can merge same-name mobs across zones. Prefer `npcID`; keep name-only
ambiguity visible and merge only when an NPC ID confirms it.

The extra storage is one numeric entry per zone/instance actually visited, so it
is not a major size problem. The important work is correct per-zone display and
name-only identity, not duplicating mob records.

## WoW loading reality

This distinction matters:

- AceM2L2 currently uses `AceM2L2CharDB` for per-character history and
  `AceM2L2DB` for account settings.
- A `SavedVariablesPerCharacter` variable is loaded for the active character,
  not every alt.
- A normal `SavedVariables` table is loaded as a whole. Lua/WoW cannot lazily
  load one field of that table.
- Therefore "on demand" here means: do not normalize, decode, index, or build UI
  for every zone at login. It does not mean the per-character table is partly
  absent from memory.
- Multiple normal SavedVariables files split scope but do not defer load. True
  deferral requires a LoadOnDemand companion, and its variable timing is a V-2
  check. There are no per-zone SavedVariables files. See
  `docs/DS-5-SAVEDVARIABLES-LOADING-MATRIX.md`.

## Root and scope matrix

This is the known high-level split. DS-17.5 still owns the final field-level
ownership table, schema version, migration, and companion decision.

| Data | Root / scope | Loaded | Rule |
|---|---|---|---|
| Account settings, UI profile, theme, minimap state | `AceM2L2DB` account SavedVariables | Every character | Keep tiny. No per-character history. |
| Account-wide aggregate leveling knowledge | `AceM2L2DB`, namespaced by client/project | Every character | Aggregate only: zones/bands, XP/time, confidence, sample counts. No raw kills, names, GUIDs, or timestamps. |
| Active-character raw history | `AceM2L2CharDB` per-character SavedVariables | Active character only | Mobs, kills, maps, instances, heatmaps, deaths, respawns, quests, rates, session, calibration observations, per-character archives/endgame. |
| Other characters' raw history | Their own `AceM2L2CharDB` | Not loaded | Never copy into the account root. Share only derived aggregates. |
| Static metadata: NPC/zone names, IDs, levels, classification | TOC/Lua data, not SavedVariables | Shared code/data load | Keep outside the character save; feasibility and licensing are DS-6. |
| Hot name/zone/instance indexes | Memory only | Rebuilt at load | Never save; derive from canonical records. |
| Cold archives | Per-character root first; optional LoadOnDemand companion later | Active character or on demand | Only if measured. No per-zone SavedVariables files. Companion timing is V-2. |
| Transient caches and UI objects | Memory only | Not saved | Release on tab/window close or eviction. |

Rules:

- **Match scope to lifetime.** Account-shared data belongs in the account root;
  character-specific detail belongs in the per-character root.
- **Keep the account root small.** It loads for every character.
- **Keep raw history per character.** Cross-character use is aggregate-only.
- **Do not duplicate a fact in both roots.** Link by stable IDs or derive it.
- **Do not split normal SavedVariables for organization alone.** Normal files
  still load together; only a LoadOnDemand companion defers.
- **Namespace by client/project.** Never mix Forever and Midnight data.
- **Version each root and define migration/backup.** Finalized in DS-17.5.

## Deduplication rules

1. One canonical mob record per identity.
2. Store the name once; no repeated name in every view/key.
3. Keep `areas`, `levels`, and `areaLevels` as small derived caches, updated on
   every write/delete/merge/prune. Do not delete them just because they can be
   rebuilt; delete only if a page-query plan replaces them.
4. Keep only totals that cannot be reconstructed cheaply.
5. Omit zero, `false`, and default fields, and create optional sub-tables lazily.
6. Use numeric IDs and count/cell keys where practical. Do not force a migration
   of current stringified numeric keys just for size.
7. Keep static metadata shared and outside the character save.
8. Share account-wide aggregate knowledge, not raw history.
9. Keep per-kill data aggregated; exact coordinates are not per-kill data.

## Checks still worth running

Only one check is needed now:

1. Derived `areas`/`levels`/`areaLevels` versus canonical mob sums on the real
   762-kill sample, including delete/merge/prune/migration.

Deferred until the relevant implementation exists:

2. One packed cold-zone block versus plain Lua tables, only if a cold archive is
   selected.
3. One endgame archive plus one alt shared-knowledge lookup.
4. The tooltip and heatmap query paths after any index change.

No checks are needed for Lua table semantics, SavedVariables being Lua, JSON
cost, Base64 expansion, checksum collision risk, or 64×64 cell mapping. Those
are already established.

## Evidence

- Current code: `KillHistory/Data.lua`, `KillHistory/Tracking.lua`,
  `KillHistory/Tooltip.lua`, `KillHistory/Heatmap.lua`.
- Current per-character save: 70,661 bytes, 85 mobs, 762 kills, 2 heatmap zones,
  193 cells, 1 instance (`docs/HC-5-DIAGNOSTICS-BASELINE.md`).
- Heatmap: 64×64, sparse cell map, measured in `docs/H64-9-BENCHMARK-REPORT.md`.
- Reference shape: AllTheThings 2.7 MB / ~186k entries, dominated by sparse
  numeric ID sets. Reference only; do not copy its content.

## Scope

This document does not change the production schema. Final schema, migration,
and lifecycle decisions remain in DS-17.5 and DS-11.
