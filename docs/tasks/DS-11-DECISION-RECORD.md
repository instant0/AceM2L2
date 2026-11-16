# DS-11 — Decision record

**Status:** executed 2026-11-16  
**Result:** `docs/DS-11-DECISION-RECORD.md`  
**Depends on:** DS-1..DS-17.5, DS-16, DS-15  
**Blocks:** implementation, DS-14, V-2, UI work

## Purpose

Record the final storage/data-model decision and separate:

- what is settled;
- what is deferred;
- what still requires live/V-2 verification;
- what implementation work follows.

## Decisions to record

1. **Storage model**
   - per-character Journey in `AceM2L2CharDB`;
   - account-wide Knowledge target in `AceM2L2DB`, derived later;
   - no uploads/privacy/community sharing.
2. **Hot/cold**
   - dynamic hot/warm/cold, no arbitrary 2,000/40/100/12 design caps;
   - per-zone/instance/level blocks;
   - 64×64 hot, 32/16 cold, top-N hotspot summary.
3. **Codec**
   - packed varint/delta blocks;
   - adaptive sparse/bitset cells;
   - per-block checksum;
   - per-block base64 for SavedVariables.
4. **Names/metadata**
   - no shipped all-name list;
   - learned live;
   - stable `npc:<id>` metadata account-wide;
   - name-only per character;
   - no global name index.
5. **Journey schema**
   - player-level vs mob-level fields separated;
   - array contexts, not keyed maps;
   - top-8 + `other` cold retention;
   - active time, danger/XP contexts, death attribution, heatmap XP/time.
6. **Retrieval**
   - selected-block lazy decode;
   - no full decode at login;
   - bounded LRU;
   - best-zone/heatmap summaries without block decode;
   - global cold tooltip limited to hot/registry/summary.
7. **Save**
   - no per-kill save;
   - dirty-block incremental encode;
   - backup/restore;
   - `SAVED_VARIABLES_TOO_LARGE` recovery path.
8. **Merge**
   - not implemented now;
   - Journey remains source data;
   - account Knowledge is a future derivation.

## Open items

- V-2: LoadOnDemand companion variable timing.
- V-2: actual `SaveAddOns` durability and logout/reload.
- V-2: real `SAVED_VARIABLES_TOO_LARGE` threshold/recovery.
- V-2: killer attribution, health/buffs/group, per-zone active time, cell XP/time.
- V-2: Forever/Midnight capture differences.
- UI: tooltip danger, suggested zone, heatmap best part.
- DS-14: oversize guard implementation.
- DS-17.4D: account Knowledge prototype.
- Route recommendation: future.

## Deliverable

`docs/DS-11-DECISION-RECORD.md`

## Acceptance

- Settled decisions are explicit.
- Deferred work is explicit.
- V-2 checks are explicit.
- Implementation order is explicit.
- No new storage study is opened.
- No production code.
