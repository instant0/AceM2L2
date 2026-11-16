# IMP-1B3 — Block-backed retrieval integration result

**Status:** retrieval integration slice executed 2026-11-16  
**Production modules:** `KillHistory/JourneyStorage.lua`,
`KillHistory/JourneyQueries.lua`  
**Test:** `tests/journey_storage.lua`; `./tests/run_all.sh`  
**Scope:** block-backed mob lookup and query fallback. No legacy retirement, UI,
or save/guard completion yet.

## 1. Implemented

- `journey.mobZones` compact index: mob key → zone/instance block keys.
- `GetJourneyMobZones(mobKey)`.
- `GetJourneyMob(mobKey[, zoneKey])`:
  - tries the selected block or indexed blocks;
  - uses lazy decode/cache;
  - falls back to legacy `db.mobs` only if blocks miss.
- `GetMobJourneySummary` falls back to block storage when legacy mob records are
  absent, marked with `source = "block"`.
- Block flush rebuilds `journey.mobZones`.

## 2. Test result

`tests/journey_storage.lua` now verifies:

- block-backed mob lookup after `db.mobs` is emptied;
- mob zone index returns `map:12`;
- summary falls back to block storage;
- block kills reflect the dirty rebuild.

Passing output:

```text
Journey block storage passed
```

`tests/run_all.sh` passes.

## 3. What this proves

- Journey blocks can serve mob data without legacy mob records.
- Lazy selected-block decode and cache work through the query path.
- The compact mob → block index is sufficient for lookup.
- The system can migrate toward block-only storage incrementally.

## 4. What remains

- Legacy `db.mobs`/`areas`/`levels` still active and authoritative for UI.
- Block storage still duplicates legacy data.
- Tooltip/UI still read legacy paths.
- Save/oversize guard is not fully integrated with block writes.
- Heatmaps/quests/deaths/respawns are not packed.
- Full migration/retirement needs a switchover and rollback plan.
- No account Knowledge/merge.

## 5. Next

**IMP-1B4 — Legacy retirement and save/guard integration.**

- Switch tooltip/UI reads to block/Journey queries where safe.
- Add migration/retirement and rollback.
- Integrate dirty-block save with DS-16/DS-14 guard.
- Remove duplication only after tests/backup.
- Keep current smoke/query/storage tests green.

## Artifacts

- `KillHistory/JourneyStorage.lua`
- `KillHistory/JourneyQueries.lua`
- `tests/journey_storage.lua`
- `docs/IMP-1B2-JOURNEY-BLOCK-STORAGE-RESULT.md`
- `docs/IMP-1B-JOURNEY-QUERY-RESULT.md`
