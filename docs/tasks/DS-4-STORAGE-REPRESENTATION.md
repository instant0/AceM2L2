# DS-4 — Storage representation and retrieval design

**Status:** reviewed 2026-11-14; working answers complete; no new representation
check required  
**Consolidated summary:** `docs/STORAGE-DIRECTION.md`  
**Purpose:** decide representation and retrieval principles from Lua/WoW
behavior, prior research, and current code. This is not the final schema.

## Decision

Keep the current hot representation: nested Lua tables with stable IDs and
sparse count/cell maps. Add compact in-memory indexes for name, zone, and
instance lookup. Do not adopt JSON, Base64, checksum identity, or a per-kill
event log. Keep 64×64 sparse heatmap cells. Keep `areas`, `levels`, and
`areaLevels` as small derived caches. Use packing/Base64 only for a measured
cold archive. Reuse only account-wide aggregates and static metadata on alts.

No production schema change is authorized by this task.

## Why this is the default

- **SavedVariables are Lua tables, not JSON.** The client serializes Lua values.
  JSON would add quoting and parsing without removing Lua key overhead.
- **Lua 5.1 has no native JSON, Base64, or `string.pack`.** Any packed codec is
  our code and must be versioned and tested.
- **The current store is already aggregated.** There is no per-kill event log.
  Kills go to mob counts, level/map/instance counters, and 64×64 cells.
- **The real store is small.** The 762-kill / 85-mob sample is 70,661 bytes
  (`docs/HC-5-DIAGNOSTICS-BASELINE.md`). The HC-5 extreme synthetic profile is
  estimated at about 2.1 MB with 2,000 mobs, 24,000 contexts, and 163,840
  heatmap cells.
- **The AllTheThings sample is a shape reference only.** 2.7 MB / ~186k entries,
  dominated by sparse numeric ID sets. It is not copied or used as a target.
- **Direct lookup works.** Tooltip NPC lookup is already
  `self.char.mobs[mobKey]`; the gaps are name-only lookup, zone lists, and
  heatmap normalization, not the table shape itself.

## Answers

| # | Question | Decision |
|---|---|---|
| 1 | How to organize data for easy retrieval without excessive duplication | One canonical mob record per identity, even when the mob spans zones; stable IDs; sparse numeric count/cell maps; small derived summaries for pages; indexes rebuilt in memory, not saved |
| 2 | How to optimize while reading correctly in Mobs, Areas, Levels, Heatmap, tooltip, diagnostics, Journey, and inspector | Keep hot data as plain Lua tables; use many-to-many zone/instance indexes; show per-zone counts in zone views and global counts in global views; decode cold data only if a packed archive is adopted |
| 3 | How to reuse data on another character | Keep raw history per character; share bounded account-wide aggregates and static metadata; never copy another character's raw history |
| 4 | Is nested JSON the best representation | No. Nested Lua tables are the native form; depth is not the problem, repeated keys are. JSON is only for external interchange if ever needed |
| 5 | Should data be compressed; is Base64 worthwhile | Not for hot data. Packed cold blocks only after a measured win. Base64 is not compression; it adds about 33% size plus its own encode/decode CPU, and is only a wrapper for binary cold blocks |
| 6 | Can an entry, zone, or mob name be a checksum instead of repeated text | No. Checksums are not reversible and can collide. `mapID` is already a stable compact zone key. Use `npcID`, `instanceID`, level, or a local numeric ID plus a name dictionary for mobs. A checksum may detect corruption of a packed block; it is not an identity |
| 7 | Can kills be 64×64 zone cells instead of exact coordinates | Yes for kill heatmaps. A kill maps to one of 4,096 cells. Exact coordinates remain only for deaths and, if approved later, Journey |
| 8 | How to deduplicate for a smaller SavedVariables | Store names/static metadata once; use numeric keys; omit zero/default fields; create optional sub-tables lazily; cap/collapse contexts; keep heatmap cells sparse; do not save indexes; pack only cold data if measured |

## Representation rules

### Hot data

- Plain nested Lua tables with direct lookup.
- `npcID` is the primary mob identity. A normalized name plus a local numeric
  ID is the fallback for name-only mobs.
- Store the name once in the mob record. Do not repeat it in views or keys.
- Do not store zone names; use `mapID` and resolve the name from the client or
  static metadata.
- If static metadata covers an NPC, the ID may be enough and the name can be
  resolved at display time. Keep the name for name-only or unknown NPCs.
- Prefer numeric IDs where the client provides them. Current stringified numeric
  keys are a small cost; migrate them only with a reason.
- Keep the current 64×64 cell index (`(row - 1) * 64 + col`, with 1-based
  row/column) as a sparse numeric map.
- Do not make every page rebuild from raw history.
- Do not introduce a per-kill event log.

### Optional fields

`EnsureMob` currently creates every sub-table and zero field for every mob:
`killsAtLevel`, `killsByMap`, `killsByAreaLevel`, `killsByInstance`,
`killsByInstanceLevel`, `contexts`, and the `xp` sample table. Most are empty or
zero for most mobs.

- Create optional sub-tables only when first used.
- Omit zero/default fields where normalization already supplies them.
- Audit direct reads before implementing; normalization must stay tolerant of
  missing fields.
- Do not remove a field if it is the only record of a fact.

This is a safe dedup win because it removes repeated keys without changing
identity or making retrieval harder.

### Derived data

| Data | Status | Rule |
|---|---|---|
| `mobs` identity/counts | canonical | source of truth for mob history |
| `mob.killsByMap`, `killsByAreaLevel` | canonical | per-mob open-world detail |
| `mob.killsByInstance`, `killsByInstanceLevel` | canonical | per-mob instance detail |
| `areas`, `levels`, `areaLevels` | derived caches | keep for fast Areas/Levels pages; update on every write, delete, merge, prune, and migration |
| `instances` summary | canonical | instance identity and totals |
| `heatmaps` | canonical | per-zone sparse cells |
| `totals`, `session` | canonical | invariant-checked counters |
| In-memory name/zone/instance indexes | derived | rebuild at load or update incrementally; never save |

`areas`, `levels`, and `areaLevels` are small and make the Areas/Levels pages
cheap. Keep them while they are always kept in sync. Do not treat them as an
independent source of truth. `dungeon` and calibration ratios are also derived
or runtime summaries and follow the same cache rule. If a future archive retains
mobs that the live store prunes, revisit whether these summaries become the
lifetime record.

### Deduplication priorities

1. **Heatmap cells** are the largest synthetic contributor. Keep them sparse and
   keep the per-zone cap.
2. **Contexts** are the next growth risk. Keep the existing cap/age policy.
3. **Per-mob empty/zero fields** are repeated keys. Create them lazily.
4. **Names and static metadata** belong once, not per view or per character.
5. **Numeric keys** are smaller, but the current stringified numeric keys are a
   small share. Do not migrate keys just for size.
6. **Indexes** are rebuilt in memory and not serialized.
7. **Packed cold blocks** only if a measured cold-zone sample justifies them.

Do not delete `areas`/`levels`/`areaLevels` just because they can be derived.
The saving is small; the page-rebuild cost and invariant risk are not.

## Retrieval rules and current gaps

- **Tooltip, NPC ID:** already a direct `mobs[mobKey]` lookup. Keep it O(1).
- **Tooltip, name only:** `GetMobKey` calls `FindNPCKeyByName`, which scans every
  mob. Replace with an in-memory normalized-name index. Report ambiguity; do not
  guess.
- **Mobs list:** currently scans all `db.mobs`. Build a zone/instance index so
  the selected-zone list is O(mobs in zone), not O(all mobs).
- **Overview/Areas/Levels:** use the derived summaries and a compact global
  summary. Do not rescan every mob on each refresh.
- **Heatmap:** `NormalizeHeatmaps` currently iterates every stored zone and every
  cell. Normalize the current/selected zone on demand; keep a small zone list
  for the selector. Render only the selected zone.
- **Diagnostics:** use counts and summary indexes, not a full decode.
- **Missing subset:** fall back to formula/global summary with explicit wording;
  never show a false zero.
- **Journey/inspector:** query the selected zone/cell only, not global raw
  history.

## On-demand reality

AceM2L2 uses:

- `AceM2L2CharDB` — per-character history;
- `AceM2L2DB` — account-wide settings.

`SavedVariablesPerCharacter` loads only the active character. That already keeps
alts out of memory. A normal `SavedVariables` table loads as a whole; Lua/WoW
cannot lazily load one field of it.

Therefore "on demand" means:

- do not normalize every heatmap zone at login;
- do not scan every mob for a tooltip or one zone list;
- do not build every page at startup;
- do not decode cold blocks until selected.

It does not mean the active character's table is partly absent from memory.
Separate normal SavedVariables files split scope but still load together. True
file-level deferral requires a LoadOnDemand companion, and its variable timing
is a V-2 check. There are no per-zone SavedVariables files. See
`docs/DS-5-SAVEDVARIABLES-LOADING-MATRIX.md`.

## Cross-character reuse

- Keep raw kills, contexts, deaths, and per-character history in
  `AceM2L2CharDB`.
- Put only bounded account-wide aggregates in `AceM2L2DB`, namespaced by
  client/project.
- Suitable shared data: zone/level kill and XP aggregates, mob efficiency,
  route/zone summaries, static metadata.
- Merge shared aggregates idempotently. Do not add another character's raw
  totals or copy its records.
- A new alt reads the aggregate; it does not load another character's
  per-character save.
- Account data is loaded for every character, so keep it small.

## Mobs in multiple zones

Yes, this is normal. The same NPC can appear in several zones, several
instances, or both. Treat it as a many-to-many relation, not an exception.

- Keep **one global mob record** per identity.
- Keep per-zone counts in `mob.killsByMap[mapID]` and
  `mob.killsByAreaLevel[mapID][level]`.
- Keep per-instance counts in `mob.killsByInstance[instanceKey]` and
  `mob.killsByInstanceLevel[instanceKey][level]`.
- Do **not** duplicate the mob record per zone. That would multiply names,
  identity, and summary fields and would make deletion/pruning harder.
- Rebuild the zone index as a many-to-many map:
  `zoneToMobs[mapID] = { [mobKey] = true, ... }`. A mob can be in more than one
  zone set. Rebuild it in memory; do not save it.

The storage cost is small: one numeric entry per zone/instance where the mob was
actually killed. It is not a major size driver compared with contexts or heatmap
cells. The issue is display and identity, not capacity.

### Display rules

- **Global Mobs tab:** use `mob.kills` and show the mob once.
- **Zone-filtered Mobs tab:** use `mob.killsByMap[mapID]` for the row count and
  sorting, not the global total. Otherwise “top mobs in this zone” is wrong.
- **Area detail:** top mobs already use `killsByMap[mapKey]`; keep that rule.
- **Mob detail:** show all zone and instance breakdowns, not only the top area.
  The current mob detail shows only the top area.
- **Tooltip:** global total is fine; if the current map is known, a separate
  current-zone count is useful. Never label the global total as a zone count.
- **Deletion:** removing a mob removes its counts from every zone and instance.
  The confirmation should make that clear.

### Count rules

- `totals.uniqueMobs` counts global mob identities, not the sum of per-zone
  unique counts.
- `areas[mapID]` sums `mob.killsByMap[mapID]` across mobs. One mob can appear in
  several areas, but each kill belongs to one area.
- Global kills equal the sum of all mob kills. Open-world area totals sum to the
  open-world part; instance kills stay separate.

### Name-only identity

Same display name does not always mean the same NPC, especially across zones.
The current name-only fallback uses a global `name:` key, which can merge
same-name mobs from different zones.

- Prefer `npcID` identity.
- Do not merge name-only records across zones on name alone.
- Keep ambiguity visible; merge only when an NPC ID confirms the match.
- If needed, scope an unresolved name-only identity by map or instance.

This is a DS-1-F2 index/identity follow-up, not a reason to duplicate the hot
schema.

## 64×64 cells

- A kill heatmap cell is a sparse count keyed by `(row - 1) * 64 + col`, with
  1-based row/column.
- A cell cannot identify the mob, level, or instance. Keep those aggregates
  separately.
- Do not store exact coordinates per kill.
- Keep exact coordinates only for deaths and an approved Journey feature.
- Keep open-world, dungeon, raid, PvP, and scenario/delve records conceptually
  separate; do not fold them into one area total.

## Verification

Already covered:

- `tests/smoke.lua` runs `AssertAggregateInvariant` after a normal kill, prune
  (2,002 mobs down to 2,000), delete, and merge. It checks `totals`, `levels`,
  `areas`, and `areaLevels` against the canonical mob sums.
- `tests/smoke.lua` also covers 64×64 heatmap mapping and legacy-grid migration.
- `./tests/run_all.sh` passes.

Reload persistence belongs to DS-3, not a new representation check.

Deferred until the relevant implementation exists:

1. **Name/zone index:** verify the name-only tooltip and selected-zone list do
   not scan all mobs; verify ambiguity fallback. This is DS-1-F2 / DS-15 work.
2. **Packed cold block:** only if a cold archive is chosen; size/decode one block
   against plain tables. This is DS-7 / DS-12 work.
3. **Cross-character aggregate:** one endgame archive plus one alt lookup. This
   is DS-17.4 work.

No checks are needed for Lua table semantics, SavedVariables being Lua, JSON
quoting cost, Base64 expansion, checksum collision risk, derived-cache
invariants, or cell mapping.

## Rejected for now

- JSON-like strings for hot data.
- Base64 for hot data.
- Checksums as identity.
- A per-kill event log.
- Packing hot data before a measured cold-data win.
- Deleting `areas`/`levels`/`areaLevels` without a page-query plan.
- Splitting SavedVariables or adding a LoadOnDemand companion before measuring
  the active-character table.

## Outputs

- hot representation: nested Lua tables plus in-memory indexes;
- cold representation: plain tables now; packed block only if measured;
- dedup rules: lazy optional fields, one name, numeric keys, sparse cells, no
  saved indexes;
- derived ownership: `areas`/`levels`/`areaLevels` remain derived caches;
- retrieval gaps: name index, zone index, selected-zone heatmap normalization;
- Base64 decision: rejected for hot data;
- checksum decision: corruption detection only, never identity;
- 64×64 decision: confirmed;
- cross-character rule: account-wide aggregates and static metadata only;
- multi-zone rule: one global mob record plus per-zone/instance breakdowns; zone
  views use per-zone counts; name-only identity stays ambiguous across zones;
- follow-ups: DS-1-F2 index, DS-15 retrieval, DS-7/DS-12 cold codec, DS-17.4
  cross-character knowledge.

## Acceptance

- All eight questions have an explicit answer.
- The hot representation is decided, not left as an open matrix.
- No per-kill event log is introduced.
- No checksum is used as a reversible identity.
- Base64 is rejected for hot data.
- 64×64 cell storage is confirmed for kill heatmaps.
- Dedup rules are explicit and do not remove needed lifetime data.
- Tooltip, zone lists, and heatmap retrieval gaps are named.
- Cross-character reuse is defined.
- No production schema change is made in this task.
