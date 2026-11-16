# IMP-1B2 — Production Journey block storage result

**Status:** block storage core executed 2026-11-16  
**Module:** `KillHistory/JourneyStorage.lua`  
**Test:** `tests/journey_storage.lua`; included in `tests/run_all.sh`  
**Scope:** per-zone/instance block storage, base64/checksum, lazy decode, cache,
dirty flush. No full legacy removal, no UI, no merge.

## 1. Implemented

- Per-zone/instance block builder from current `db.mobs`:
  - `map:<id>`
  - `instance:<key>`
- Compact block encoding:
  - varint schema/kind;
  - zone key;
  - record count;
  - key/name/classification strings;
  - NPC ID, per-zone kills, per-zone XP, mob level range.
- Per-block checksum.
- Base64 encode/decode.
- `journey.blocks` and `journey.blockIndex`.
- Dirty-zone tracking and `FlushJourneyBlocks`.
- Lazy `GetJourneyBlock` decode.
- Bounded LRU block cache (8 blocks).
- `GetJourneyBlockMob`.
- Missing/corrupt fallback.
- `ClearJourneyBlockCache`.

## 2. Dirty/save behavior

- Kills and quest turn-ins mark the current zone/instance dirty.
- `OnJourneyLogout` flushes dirty blocks.
- First flush builds all zone/instance blocks.
- Later flushes rebuild only dirty keys.
- Login loads the base64 block strings but decodes none.

## 3. Test result

`tests/journey_storage.lua` seeds:

- two map zones;
- one instance;
- NPC and name-only records;
- per-zone kills.

Asserted:

- map and instance blocks built;
- flush decodes zero blocks;
- first selected decode increments decode count;
- second selected read uses cache and does not decode again;
- block mob lookup works;
- changing per-zone kills + dirty mark + flush updates the block;
- corrupt base64 block fails safely;
- missing block returns `missing`.

Passing output:

```text
Journey block storage passed
```

`tests/run_all.sh` passes.

## 4. Important limitations

- This builds blocks **from legacy `db.mobs`**; it does not yet remove or replace
  the legacy schema.
- `journey.mobs` full v2 migration is not implemented.
- Heatmaps, quests, deaths, respawns, and level/instance summaries are still read
  from legacy tables; only zone/instance mob blocks are packed.
- The base64 block storage duplicates cold data while legacy data remains.
- Tooltip/UI/save/guard are not yet switched to block retrieval.
- No account Knowledge/merge.

## 5. Decisions

- Blocks are per zone/instance, not global.
- Per-zone Kills/XP are stored, not total-only.
- Lazy decode + LRU is the retrieval path.
- Checksums reject corrupt blocks.
- Dirty-zone flush is the save unit; full rebuild is migration/first build only.
- No timer/OnUpdate.
- No merge/UI.

## 6. Follow-up

**IMP-1B3 — Journey migration/retrieval integration.**

- Full v2 migration or legacy retirement after blocks prove stable.
- Pack heatmaps/quests/deaths/respawns as needed.
- Wire tooltip/danger/best-zone/heatmap queries to blocks.
- Dirty-block save/oversize guard integration.
- Remove duplication only after tests/backup.
- No account Knowledge/UI yet.

## Artifacts

- `KillHistory/JourneyStorage.lua`
- `KillHistory/Journey.lua`
- `AceM2L2.toc`
- `tests/journey_storage.lua`
- `tests/run_all.sh`
- `docs/IMP-1B-JOURNEY-QUERY-RESULT.md`
