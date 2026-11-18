# DS-17.6A3 — Storage, retrieval, and save audit

**Status:** complete (read-only audit)  
**Parent:** `docs/tasks/DS-17-06A-DATA-MODEL-VALIDATION.md`  
**Slice:** `docs/tasks/DS-17-06A3-STORAGE-RETRIEVAL.md`  
**Output:** this file only.

## Scope

In scope:

- physical Journey storage blocks and block metadata;
- packed encode/decode, checksum, base64 wrapper;
- dirty-block save, backup/restore, oversize guard, migration/downgrade/reset;
- login decode count, selected-block lazy decode, block/heatmap caches;
- scan behavior of the retrieval/query API;
- sparse 64×64 heatmap cells and top-N;
- caps/retention and contexts-as-arrays with top-8 + `other`;
- proof that no per-kill save exists.

Out of scope (owned by sibling slices): logical field ownership and per-field
capture semantics (A1/A2), and UI/command truth and presentation (A4). This
report only follows retrieval entry points far enough to judge decode/scan
behavior.

Baseline decisions used for comparison: DS-11 (`docs/DS-11-DECISION-RECORD.md`),
DS-17.1 (`docs/DS-17-1-CAPACITY-AND-STRATEGY.md`), DS-17.3
(`docs/DS-17-3-RETENTION-DECISION.md`), DS-17.4C
(`docs/DS-17-04C-RETENTION-MERGE-COMPATIBILITY-RESULT.md`), DS-17.5
(`docs/DS-17-05-SCHEMA-AND-MIGRATION-RESULT.md`), DS-14/15/16 results.

## Files read

Production:

- `KillHistory/JourneyStorage.lua`
- `KillHistory/Journey.lua`
- `KillHistory/Module.lua`
- `KillHistory/Data.lua`
- `KillHistory/Util.lua`
- `KillHistory/JourneyQueries.lua`
- `KillHistory/JourneyIndex.lua`
- `KillHistory/Heatmap.lua`
- `KillHistory/Events.lua` (save/migration/prune lifecycle)
- `KillHistory/Tracking.lua` (kill/XP entry points into Journey)
- `KillHistory/Tooltip.lua` (selected-zone retrieval entry point)
- `KillHistory/Commands.lua` (reset/recovery surface)
- `KillHistory/World.lua` (death/respawn caps)
- `KillHistory/Calibration.lua` (context record shape)
- `KillHistory/UI/Diagnostics.lua` (storage stats surface)

Tests inspected (not run):

- `tests/journey_storage.lua`
- `tests/journey_save_guard.lua`
- `tests/ds16_save_policy.lua`
- `tests/ds17_5_schema.lua`
- `tests/storage_sanity.lua`
- `tests/capacity_assessment.lua`
- supporting coverage: `tests/tooltip_fallback.lua`,
  `tests/heatmap_bounded.lua`, `tests/heatmap_lazy_zone.lua`,
  `tests/context_cap.lua`, `tests/cap_boundaries.lua`, `tests/smoke.lua`,
  `tests/ds17_4c_retention.lua`, `tests/run_all.sh`

Decision/result docs inspected: DS-11, DS-17.1, DS-17.3, DS-17.4C, DS-17.5,
DS-14, DS-15, DS-16, DS-7/12, DS-3, IMP-1B2/B3/B4.

## Method

Static, line-level inspection of the login → kill → logout → reload path, the
migration/reset path, and every retrieval entry point that can reach block
decode (tooltip, detail, heatmap list/top-N, mob summary, heatmap cells). Each
claim is anchored to `file:line` or `file:function`. Existing offline test
assertions and prior result documents are cited as evidence of intended/observed
behavior; nothing was executed here.

## Limitations

- No client was run. Login decode count, durability ordering, and latency are
  inferred from code and from prior offline results, not re-measured.
- No tests were run, per the slice contract; test status is "asserts this" not
  "passed now".
- `storage_sanity.lua`, `ds16_save_policy.lua`, and `ds17_5_schema.lua` are
  prototypes/harnesses, not production-path tests; they are cited only for the
  policy/behavior they exercise.
- Field population/capture semantics are A1/A2. This report notes storage
  consequences of unpopulated fields but does not audit who writes them.
- UI/command consumers are A4. Only retrieval entry points and the storage
  diagnostics surface were followed.

## Required table

| Area | Expected | Actual | Status | Evidence | Follow-up |
|---|---|---|---|---|---|
| Schema-2 block envelope | Versioned per-zone/instance/level block with schema, kind, zone/band, records, cells | Schema 2 + kind 1 + zone key + records + cells; only `map:`/`instance:` keys, no level-band blocks | Partial | `JourneyStorage.lua:11`, `JourneyStorage.lua:184-205`, `JourneyStorage.lua:336-350` | G4 |
| Block metadata | projectID, generation, zone/band, grid, tier, length/checksum | checksum, record/cell counts, heatmapKills, lastSeen, updatedAt only | Gap | `JourneyStorage.lua:376-383`; DS-17.3 §Archive format | G4 |
| Block payload fields | v2 Journey fields usable from cold storage | 8 mob fields + 5 cell fields; no `byPlayerLevel`, contexts, first/lastSeen, session, deaths, quests, respawns | Gap | `JourneyStorage.lua:114-125`, `JourneyStorage.lua:279-312`; `Tooltip.lua:178-189` | G1 |
| Packed varint encode/decode | Packed varint/delta records | Varint strings/numbers; sorted cells; no delta coding | Partial | `JourneyStorage.lua:21-45`, `JourneyStorage.lua:89-100`, `JourneyStorage.lua:184-205` | G4 |
| Adaptive sparse/bitset cells | Adaptive sparse/bitset cell encoding | Always sparse varint cell list; no dense/bitset variant | Gap | `JourneyStorage.lua:191-203`; DS-11 §2.3 | G4 |
| Base64 wrapper | Per-block base64 for SavedVariables | Per-block base64 in `journey.blocks[key].data` | Pass | `JourneyStorage.lua:55-87`, `JourneyStorage.lua:369-375` | — |
| Per-block checksum | Checksum computed during encode; verified on decode | Rolling mod-65521 checksum; mismatch returns `checksum` | Pass | `JourneyStorage.lua:47-53`, `JourneyStorage.lua:368`, `JourneyStorage.lua:449-451` | — |
| Dirty-block save | Encode only dirty zone/instance/level blocks | Dirty set marks map/instance; flush re-encodes only dirty keys after first build | Pass | `JourneyStorage.lua:229-238`, `JourneyStorage.lua:336-392`; `journey_storage.lua:71-78` | — |
| Incremental index cost | Full encode only for migration/compaction | Block encode is incremental, but `mobZones` and heatmap index are rebuilt from all data each flush | Partial | `JourneyStorage.lua:324-335` | G5 (measure flush cost) |
| No per-kill save | No SavedVariables write per kill | Kill only mutates memory + dirty flag; no `SaveAddOns`/write call exists | Pass | `Journey.lua:230-256`, `Heatmap.lua:649-651`; grep: no `SaveAddOns` in production | — |
| Checkpoint triggers | Session end, logout/reload, SaveAddOns, ADDONS_UNLOADING, compaction | Only `PLAYER_LOGOUT` flush; no SaveAddOns/ADDONS_UNLOADING/compaction | Partial | `Module.lua:471-472`, `Events.lua:140-142`, `Journey.lua:335-353`; DS-16 §1 | G5 |
| Previous-generation backup/restore | Keep previous generation; explicit restore | Per-zone backup kept before rewrite; `RestoreJourneyBlocks()` exists and is tested | Pass | `JourneyStorage.lua:358-365`, `JourneyStorage.lua:394-405`; `journey_save_guard.lua:24-40` | — |
| Backup/restore operability | User-visible recovery after oversize | No command or automatic compaction path calls restore/reset; save-blocked state is not surfaced | Gap | `JourneyStorage.lua:407-435`; no `GetJourneySaveState`/`RestoreJourneyBlocks` callers outside storage | G5 |
| Oversize guard | `SAVED_VARIABLES_TOO_LARGE` stops writes, preserves backup | Blocks further flushes, ignores other add-ons, reset hook exists | Pass | `Events.lua:144-151`, `JourneyStorage.lua:321-323`; `journey_save_guard.lua:42-63`; DS-14 | — |
| Migration v1 → per-project | Versioned, idempotent, backed up | Root legacy keys moved to `clients[project]`; backup + stranded markers; idempotent | Pass | `Data.lua:612-673`; `smoke.lua:1064-1093` | — |
| Downgrade / newer schema | Newer schema rejected read-only, not overwritten | storage/data/calibration schema gates set `schemaBlocked`; newer block schema fails decode | Pass | `Data.lua:622-625`, `Data.lua:689-719`, `JourneyStorage.lua:266-273`; `smoke.lua:1095-1107` | — |
| Reset behavior | Clear Journey + blocks + caches | `ResetJourneyData` drops `db.journey` and caches; kill reset also clears heatmaps | Pass | `Journey.lua:322-333`, `Commands.lua:875-931`, `Heatmap.lua:494-503` | — |
| Login decode count | Zero cold blocks at login | Login path never touches `journey.blocks`; only blockIndex metadata is read | Pass (inspection; no direct login test) | `Events.lua:153-159`, `JourneyStorage.lua:207-227`, `JourneyStorage.lua:491-518`; indirect `journey_storage.lua:41,63` | G9 |
| Selected-block lazy decode | Decode one selected block, reuse cache | Cache miss decodes one block, verifies checksum, caches; repeat returns same record | Pass | `JourneyStorage.lua:437-462`; `journey_storage.lua:43-51`; `tooltip_fallback.lua:37-53` | — |
| Bounded block cache | Bounded LRU for active blocks | Capacity 8, LRU order, eviction counter | Pass | `JourneyStorage.lua:12`, `JourneyStorage.lua:240-264`; `Module.lua:87-116` | — |
| Bounded heatmap cache | Bounded selected-zone cache | Selected-zone LRU capacity 4; a separate full-shape normalizer keeps a whole-map copy | Partial | `Heatmap.lua:278-299`, `Heatmap.lua:404-419`, `Heatmap.lua:422-492` | G8 |
| No arbitrary block scans | Global/selected lookups use summary/index, not block scans | Heatmap list and mob summary are summary/index paths; block fallback loops an uncapped per-mob zone list | Partial | `JourneyStorage.lua:491-518`, `JourneyStorage.lua:520-555`, `JourneyStorage.lua:127-150` | G6 |
| Sparse 64×64 cells | Sparse cells only; 64×64 hot | 64×64, cell index 1..4096, only occupied cells stored | Pass | `Heatmap.lua:22-27`, `Heatmap.lua:624-632`, `JourneyStorage.lua:191-203` | — |
| 32/16 cold downsampling | 64 hot, 32 warm/cold, 16 summary | No 32/16 downsample or tier metadata; legacy 32/16 grids are upgraded on load | Gap | `Heatmap.lua:22-25`, `Heatmap.lua:240-246`; DS-17.3 §Downsampling | G4 |
| Top-N hotspot summary | Stored top-N summary; global heatmap reads need no block decode | Top-N is recomputed from a decoded zone block; `blockIndex` stores only total kills/lastSeen/cellCount | Gap | `JourneyQueries.lua:279-321`, `JourneyStorage.lua:376-383`, `heatmap_bounded.lua:40-47` | G10 |
| Adaptive caps/retention | Dynamic hot/warm/cold, not fixed 2,000/40/100/12 | Mobs/quests adapt only within floors; deaths=100, maps=64, instances=100, contexts=12, levels=200, rates=240, respawns=4000, mob-instance links=20 stay fixed | Gap | `Util.lua:12-20`, `Data.lua:30-32`, `Data.lua:86-98`, `World.lua:23-25`, `Heatmap.lua:26`, `Data.lua:1700-1733`; `cap_boundaries.lua:7-87` | G3 |
| Hot/warm/cold movement | Packed cold archive with dynamic movement | Blocks duplicate legacy hot tables; no archive tier, no eviction/downsample of stored blocks | Gap | `JourneyStorage.lua:324-335`; DS-17.1 §Strategy, DS-17.3 §Decision | G4 |
| Contexts as arrays | Array/list records | String-keyed `mob.contexts[contextKey]` map | Gap | `Calibration.lua:168-191`; `Util.lua:14` | G2 |
| Top-8 + `other` | Top-8 cold contexts + one `other` aggregate | No top-N selection, no `other`, no cold context packing; only age/12-entry pruning | Gap | `Events.lua:274-303`; `context_cap.lua:19-50`; DS-17.4C §1 | G2 |
| Project/character separation | Per-character raw Journey, per-project namespace | `AceM2L2CharDB.xpTooltip.clients[projectID]`; blocks live under that character record | Pass | `Data.lua:616-672`, `Data.lua:697-701`; `smoke.lua:107-109` | — |
| Storage diagnostics | Block/heatmap cache + save state visible | Cache stats and total block bytes reported; saveBlocked/backupZones/decoded counter not surfaced and counter is global | Partial | `Module.lua:87-116`, `Module.lua:185-193`, `JourneyStorage.lua:421-435` | G5/G7 |

## Required checks

| Check | Result | Evidence |
|---|---|---|
| Login decodes zero cold blocks | Pass by inspection | `Events.lua:153-159` does not touch blocks; `JourneyStorage.lua:207-227` only shapes tables; `GetJourneyHeatmapZones` reads `blockIndex` (`JourneyStorage.lua:495-511`). Indirect asserts: `journey_storage.lua:41,63`, `heatmap_bounded.lua:30`. No literal login test exists. |
| Selected tooltip decodes one block and reuses it | Pass | `Tooltip.lua:157-190` selected-zone-first; `journey_storage.lua:43-51` (1 decode, then 0); `tooltip_fallback.lua:37-53` (1 decode, cached). |
| Missing/corrupt block fails safely | Pass | `JourneyStorage.lua:443-453` returns `missing`/`decode`/`checksum`/`format`; `journey_storage.lua:80-88`; `heatmap_bounded.lua:60-70`. |
| Oversize/save-guard behavior covered | Pass (behavior); recovery gap | `journey_save_guard.lua:42-63` blocks writes and resumes after reset; DS-14 state machine. But no user-facing restore/compaction caller. |
| Caps adaptive, not old fixed 2,000/40/100/12 | Fail (partial only) | Only mob/quest caps adapt (`Data.lua:86-98`); deaths=100, instances=100, contexts=12 remain fixed and are asserted fixed in `cap_boundaries.lua`/`context_cap.lua`. |

## Findings

### What matches DS-11 / DS-17.5

1. **Block coding path is real and defensive.** `encodeZone` writes a schema/kind
   header, zone key, record count, mob records and sparse cells
   (`JourneyStorage.lua:184-205`); `decodeZone` accepts only schema 1/2 and
   kind 1 and raises on truncation (`JourneyStorage.lua:266-315`). Reads wrap
   base64/format/checksum in `pcall` and return a reason instead of throwing
   (`JourneyStorage.lua:437-462`).
2. **Checksums are per block and computed at encode time.** `checksum` is stored
   with the block (`JourneyStorage.lua:368-371`) and compared before decode
   (`JourneyStorage.lua:449-451`).
3. **Dirty-block save works and is incremental per block.** Kills and quest
   turn-ins mark the active map/instance dirty (`Journey.lua:250-251`,
   `Journey.lua:307-309`); `FlushJourneyBlocks` rebuilds only dirty keys after
   the first build (`JourneyStorage.lua:337-350`) and backs up the previous
   block/index before overwriting (`JourneyStorage.lua:358-365`).
4. **No per-kill save exists.** The kill path updates memory and marks dirty
   only; there is no `C_AddOns.SaveAddOns`, `SaveVariables`, or file write in
   production (grep over `KillHistory`/`Core`). Flush runs from logout
   (`Journey.lua:350-352`), not per kill.
5. **Login does not decode cold blocks.** `OnLogin` starts a session, level
   history, rates and a scheduled prune (`Events.lua:153-159`); `EnsureDB`
   migrates/normalizes only legacy tables (`Data.lua:675-760`). The block list
   is metadata-only (`JourneyStorage.lua:491-518`).
6. **Selected-block lazy decode and bounded cache are implemented and tested.**
   Cache capacity is 8 with LRU reordering (`JourneyStorage.lua:12,240-264`);
   the first selected read increments `journeyDecodedBlocks`, the second does
   not (`journey_storage.lua:43-51`). The heatmap selected-zone cache is a
   separate LRU of 4 (`Heatmap.lua:404-419`).
7. **Migration, backup, idempotence, and downgrade are implemented.** Storage
   schema > 2 returns blocked before any legacy move (`Data.lua:622-625`);
   legacy root keys move into `clients[projectID]` with a recoverable
   `migrationBackup` (`Data.lua:638-665`); `EnsureDB` blocks newer
   storage/data/calibration schemas without rewriting them (`Data.lua:689-719`).
   `smoke.lua:1064-1107` asserts migration, backup idempotence, and read-only
   future schema.
8. **Reset clears Journey state and caches.** `ResetJourneyData` drops
   `db.journey` and clears the block cache (`Journey.lua:322-333`);
   `ResetKills` also resets heatmaps (`Commands.lua:875-931`).
9. **Heatmap cells are sparse 64×64.** Grid is 64 (`Heatmap.lua:22`), cell =
   `(row-1)*64+col` clamped to 1..4096 (`Heatmap.lua:624-626`), and only
   occupied cells are encoded (`JourneyStorage.lua:191-203`).

### Where production diverges

1. **Schema-2 blocks are a projection of legacy hot tables, not the v2
   Journey.** `FlushJourneyBlocks` builds from `self.char` via
   `buildMobZoneIndex(db)` / `buildHeatmapZoneIndex(db)`
   (`JourneyStorage.lua:318-335`), reading `db.mobs.killsByMap`,
   `killsByInstance`, `totalXP` and `db.heatmaps`. The v2 names (`journey.mobs`,
   `byPlayerLevel`, `byZone`, `byInstance`, array contexts, `journey.instances`,
   `journey.deaths`, `journey.quests`, `journey.respawns`) do not exist in
   production: the only `journey.*` fields written are `schema`, `projectID`,
   `mode`, `zones`, `levels`, `questAnchors`, `time`, and the storage fields
   (`Journey.lua:40-68`; `JourneyStorage.lua:210-219`). DS-17.5 §1 is therefore
   only partially represented in storage.
2. **Cold blocks omit the data needed for full retrieval.** `encodeMob` writes
   key, npcID, name, classification, kills, xp, mobLevelMin/Max
   (`JourneyStorage.lua:114-125`). There is no `byPlayerLevel`, contexts,
   firstSeen/lastSeen, session, deaths, quest anchors, respawn or top-N in the
   block. The block-backed tooltip deliberately blanks those sections
   (`Tooltip.lua:178-189`, asserted by `tooltip_fallback.lua:44-46`). After
   legacy retirement, block reads cannot reproduce the current tooltip/detail
   fields.
3. **No level-band blocks.** Keys are only `map:<id>` and `instance:<key>`
   (`JourneyStorage.lua:127-150`, `JourneyStorage.lua:336-350`). DS-17.5 §1 and
   DS-16 §1 call for per-zone/instance/**level** blocks.
4. **No adaptive cell codec.** Cells are always a sparse ascending varint list
   (`JourneyStorage.lua:191-203`); there is no dense/sparse or bitset selection
   and no delta coding, so DS-11 §2.3 ("packed varint/delta", "adaptive
   sparse/bitset") is not met.
5. **No top-N hotspot summary is stored.** `blockIndex` keeps aggregate
   `heatmapKills`, `lastSeen`, `cellCount` (`JourneyStorage.lua:376-383`).
   `GetHeatmapTopCells` recomputes top-N by decoding the selected zone block
   (`JourneyQueries.lua:306-321`, `JourneyQueries.lua:279-304`). DS-11 §2.6
   asks for a top-N summary with no block decode.
6. **No 32/16 cold downsampling or archive tier.** Only 64×64 is produced; the
   32/16 paths are legacy-grid *upgrades* on load (`Heatmap.lua:22-25`,
   `Heatmap.lua:240-246`). DS-17.3 requires 64 hot / 32 warm-cold / 16 summary
   and a tier field in block metadata.
7. **Caps are mostly fixed legacy numbers.** Adaptive only for mobs
   (`min(12000, max(2000, zones*500))`, `Data.lua:86-91`) and quests
   (`min(10000, max(500, zones*100))`, `Data.lua:93-98`). Fixed elsewhere:
   deaths 100 (`World.lua:23,179-184`), heatmap maps 64 (`Heatmap.lua:26,638-647`),
   instances 100 (`Util.lua:16`, `Data.lua:265`), mob-instance links 20
   (`Util.lua:17`, `Data.lua:1717-1732`), contexts 12 (`Util.lua:14`,
   `Events.lua:292`), level records 200 (`Data.lua:31,1864-1876`), rate samples
   240 (`Data.lua:32,376-382`), respawn NPCs 4000 (`World.lua:24,362-366`).
   `cap_boundaries.lua:7-87` and `context_cap.lua:42-50` actively assert the
   fixed numbers, so the old design is still the implemented contract.
8. **Contexts are string-keyed maps, not arrays, and there is no `other`.**
   `Calibration.lua:168-191` creates `contexts[contextKey]`; pruning keeps the
   newest 12 and drops entries older than 120 days (`Events.lua:274-303`,
   `Util.lua:14,20`). DS-17.5 §1/§Context storage and DS-17.4C require an
   array/list plus top-8 + one packed `other` aggregate. The prototype proves
   the shape (`tests/ds17_5_schema.lua:45-77`, `tests/ds17_4c_retention.lua:95-120`),
   but production does not use it.
9. **Blocks duplicate hot data instead of forming a cold tier.** All blocks
   (base64 payloads plus one backup generation per zone) stay resident in
   `db.journey.blocks` / `blockBackup`; there is no eviction, archival,
   compaction, or companion variable. DS-17.1 §6/§Strategy and DS-17.3 require
   dynamic hot/warm/cold movement and a previous archive kept separately.
10. **Save-blocked recovery is not wired.** `RestoreJourneyBlocks`,
    `ResetJourneySaveBlock`, and `GetJourneySaveState` exist
    (`JourneyStorage.lua:394-435`) but have no production caller; no slash
    command or UI exposes oversize state or restore/compaction. DS-14 requires
    user-visible recovery and a compaction step before resuming saves.
11. **Checkpoint coverage is narrower than DS-16.** Only `PLAYER_LOGOUT`
    triggers `FlushJourneyBlocks` (`Module.lua:471`, `Events.lua:140-142`,
    `Journey.lua:335-353`); `C_AddOns.SaveAddOns` and `ADDONS_UNLOADING` are not
    used, and there is no level/zone optional checkpoint or compaction path.
12. **Retrieval is still legacy-first for the main query surfaces.** Area/level
    rows read `db.areas`/`db.levels` (`JourneyQueries.lua:83-141`,
    `JourneyQueries.lua:144-231`), and `GetMobJourneySummary` prefers
    `db.mobs` (`JourneyQueries.lua:323-340`). Blocks are a fallback, not the
    source of truth. This is consistent with the additive migration but not
    with "the Journey is the source of truth" (DS-11 §2.1) once blocks are the
    only stored copy.
13. **Global block fallback can decode more than a selected block.** `mobZones`
    is populated with one entry per map and per instance without a 4-ref cap
    (`JourneyStorage.lua:127-150`), and `GetJourneyMob` without a zone key
    decodes each listed block until it finds the mob
    (`JourneyStorage.lua:529-541`). Legacy-first hides this today, but after
    retirement a cold tooltip for an uncapped mob can decode many blocks,
    contradicting DS-11 §2.6 ("must not scan/decode arbitrary blocks").
    Instance links are capped at 20, map links are not.
14. **Latent flush data-loss risk on retirement.** `FlushJourneyBlocks` rebuilds
    records/index from legacy `db.mobs` and deletes a block when the rebuilt
    record list and cell count are empty (`JourneyStorage.lua:324-325`,
    `JourneyStorage.lua:351-353`, `JourneyStorage.lua:366-387`). If legacy mobs
    are removed while Journey blocks remain, any dirty flush would erase that
    zone's mob records (heatmap cells survive only while `db.heatmaps` exists).
    This is an IMP-1B11 retirement blocker.
15. **The decode counter is global, not per-login/per-character.**
    `journeyDecodedBlocks` starts at file load (`JourneyStorage.lua:225`) and is
    never reset on login/character switch; it is only reset by tests. A future
    "login decodes zero" assertion would need a scoped counter.

## Gaps

| ID | Gap | Proposed follow-up |
|---|---|---|
| G1 | Cold blocks carry only an 8-field mob projection; v2 fields (player-level subcounts, contexts, seen stamps, session, deaths, quests, respawns) are absent | Make block payload v2-complete before legacy retirement (IMP-1B11 prerequisite); add fields to `encodeMob`/`decodeZone` and prove round-trip without legacy |
| G2 | Contexts are keyed maps capped at 12; no array, top-8, or `other` cold record | Implement DS-17.4C retention shape: array hot form, packed top-8 + `other` cold form, with sample counts |
| G3 | Caps/retention are mostly fixed (100/64/100/12/200/240/4000/20) and tests assert them | Replace with measured dynamic policy; remove fixed-cap assertions from `cap_boundaries`/`context_cap`; keep only hard safety valves if justified |
| G4 | No hot/warm/cold archive, no 32/16 downsampling, no block metadata (projectID/generation/grid/tier), no delta/adaptive codec | Execute DS-17.3 archive slice: tier downsample, metadata envelope, delta/bitset codec choice, separate previous archive |
| G5 | Save recovery and checkpoint coverage are incomplete: no restore/compaction caller, no SaveAddOns/ADDONS_UNLOADING checkpoint, save state not surfaced | Wire `GetJourneySaveState` into diagnostics/status; expose restore + explicit compaction; add checkpoint triggers after V-2 timing |
| G6 | `mobZones` refs are uncapped; block fallback can decode many blocks per mob | Cap per-mob refs (DS-17.5 ≤4), make selected-zone-first mandatory, and add a worst-case decode test |
| G7 | `journeyDecodedBlocks` is global and includes prior sessions/characters | Reset per login/character and expose a per-login counter for the zero-decode check |
| G8 | Heatmap normalizer keeps a full-shape copy of all stored zones in addition to the 4-entry zone LRU | Use only the bounded per-zone cache for UI/query paths; make the full normalizer explicit/offline |
| G9 | No direct test asserts "login decodes zero cold blocks" | Add a login-path assertion (login event + UI-closed) to the storage suite |
| G10 | No stored top-N hotspot summary; top-N requires a block decode | Store top-N cells (or a packed summary) in `blockIndex`/block metadata and read it without decode |
| G11 | Dirty flush rebuilds from legacy and can delete a zone block when the legacy source is empty (retirement data-loss risk) | Fix flush source/ownership before IMP-1B11: skip deletion when legacy is absent, or build/merge from existing blocks; add a retirement regression test |

## Open questions

1. Is the v2 Journey schema intentionally deferred to IMP-1B11, or should blocks
   become v2-complete now? A5 should assign the owner; today DS-17.5 is only a
   prototype (`tests/ds17_5_schema.lua` prints migration results).
2. Should `journey.blocks` remain a duplicate of `db.mobs`/`db.heatmaps` until
   retirement, or should dirty flush stop rebuilding from legacy first? The
   current order makes retirement data-loss-prone (G11).
3. Are the adaptive floors (2,000 mobs / 500 quests) intended as content
   minimums or leftover old caps? DS-17.1 says the 2,000 cap is not the design.
4. Should `blockBackup` be persisted in SavedVariables (doubling cold bytes),
   or kept in memory only? Nothing in DS-11/DS-16 settles persistence of the
   backup generation.
5. Does `PLAYER_LOGOUT` reliably run before SavedVariables serialization on
   Forever and Midnight? This is a V-2 item; the flush currently relies on it
   for durability.
6. Should the heatmap be stored per zone in blocks even when `db.heatmaps` is
   the capture source, or should capture write blocks directly? The current
   copy-on-flush model duplicates cell data.

**No code changed; no tests run.**
