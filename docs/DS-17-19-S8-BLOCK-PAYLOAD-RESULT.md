# DS-17.19 — S8 block payload v2 completeness result

**Status:** executed 2026-11-18  
**Scope:** schema 3 block payload from v2 roots; schema 1/2 decode compatibility.  
**Test:** `tests/s8_block_payload.lua`; full suite passes.

## 1. Schema boundary

- `journey.schema` remains **2** (data model).
- `journey.storageSchema` is now **3** (block payload).
- The SavedVariables root `storageSchema` remains **2**.
- Schema 1 and 2 blocks still decode with their original shape.
- Old readers reject schema 3 safely as an unsupported block.

## 2. Payload source

Blocks are built from:

- `journey.mobs`
- `journey.zones`
- `journey.instances`
- `journey.heatmaps`

`db.mobs`, `db.areas`, `db.instances`, and `db.heatmaps` are not read during
encoding. If a v2 root is empty, the existing one-time legacy sync runs before
the block index is built. Once the root has data, flush never consults legacy.

## 3. Schema 3 contents

Each block contains:

- zone key and zone/instance kind;
- only the mobs belonging to that zone/instance;
- mob identity, classification, NPC ID, global kills/XP, first/last seen;
- mob level range, sample count, global player-level records;
- zone/instance kills/XP and player-level records;
- context array plus derived combat/XP/top-8/`other` views on decode;
- heatmap cell kills only, with total/lastSeen/gridSize and coverage flags;
- zone/instance totals, time, deaths/sessions, and coverage flags.

No per-kill timestamps, no all-mob list, and no second `byZone`/`byInstance`
map are written.

## 4. Read and index behavior

- `GetJourneyBlockData` returns `schema`, `records`, `cells`, `zone`, and
  heatmap metadata.
- `GetJourneyBlock` keeps its record/cell contract and also returns the zone.
- `blockIndex` gains `zoneKind`, `zoneKills`, `zoneXP`, `hasZone`, and grid size.
- Heatmap stale-prune keeps blocks that still carry mobs or a zone summary.
- Zone-only blocks survive heatmap clearing.
- Checksum and format failures still fail safely.

## 5. Tests

- schema 1/2 decode compatibility;
- schema 3 zone/instance summary round-trip;
- mob identity, globals, zone totals, levels, first/last seen;
- context order, top-8, `other`, and combat coverage;
- zone-level kills/XP/time merge;
- heatmap kills with absent XP/time;
- no legacy reads during encode;
- no all-mob duplication across map/instance blocks;
- dirty rebuild without decode;
- zone-only block retention after heatmap clear;
- corrupt block rejection and restore;
- root schema unchanged.

Passing output:

```text
S8 block payload passed
...
All offline checks passed.
```

## 6. Limits

- 32/16 cold archive and adaptive caps remain S9.
- Legacy retirement remains S10.
- UI readers still use legacy cells and blocks where they already do.
- Live save/load and oversize validation remain V-2C.

## 7. Next

**DS-17.20 — S9 adaptive caps, retention, and archive policy.**

## Artifacts

- `KillHistory/JourneyStorage.lua`
- `KillHistory/Heatmap.lua`
- `tests/s8_block_payload.lua`
- `tests/journey_storage.lua`
- `tests/journey_save_guard.lua`
- `tests/p0_data_model_safety.lua`
- `tests/run_all.sh`
- `docs/tasks/DS-17-19-S8-BLOCK-PAYLOAD.md`
