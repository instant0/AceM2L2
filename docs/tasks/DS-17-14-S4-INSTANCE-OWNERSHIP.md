# DS-17.14 — S4A instance ownership migration

**Status:** executed 2026-11-18 (S4A).  
**Result:** `docs/DS-17-14-S4-INSTANCE-OWNERSHIP-RESULT.md`  
**Depends on:** DS-17.13  
**Blocks:** S4B instance time, S5 deaths, S6 quests/respawns  
**Source:** `docs/DS-17-07-DATA-MODEL-RECONCILIATION-RESULT.md`

## Goal

Make `journey.instances` canonical for exact instance identity and totals:

- name/type/ID/difficulty/map ID;
- kills;
- XP totals;
- player-level subcounts;
- first/last seen.

Legacy `db.instances` remains a compatibility projection.

## Exact vs unavailable

| Field | Source | Coverage |
|---|---|---|
| instance identity | `db.instances` | exact |
| kills | `db.instances` | exact |
| XP | `db.instances` | exact |
| player-level kills | `db.instances.killsAtLevel` | exact |
| first/last seen | `db.instances` | exact |
| presence/engaged time | none in legacy | unavailable |
| deaths/sessions per instance | none in legacy | unavailable |

Do not invent per-instance time or split `journey.zones["0"]` historically; that
aggregate cannot be assigned to individual instances.

## Scope

- Backfill `journey.instances` from `db.instances`.
- Add `SyncModelInstanceFromLegacy(instanceKey)` and bulk sync.
- Sync after kill/XP/quest/merge/delete/prune/load.
- Keep `db.instances` as a compatibility projection.
- `GetModelInstance` becomes v2-only.
- No block payload/UI/retirement.
- Do not change `journey.zones["0"]` in this task.

## Tests

`tests/s4_instance_ownership.lua`:

- identity parity;
- kills/XP/player-level parity;
- non-attributable instance keeps its own v2 record;
- attributable instance map remains separate;
- sync after kill/merge/delete;
- idempotence;
- v2-only reads with `db.instances` removed;
- time/deaths/sessions marked unavailable, not zero;
- no block/UI/retirement changes.

## Acceptance

- `journey.instances` canonical for exact identity/totals/XP/player levels.
- Legacy remains compatibility projection.
- Unavailable per-instance time is not invented.
- No double counting.
- Full suite passes.
- S4B can handle instance time separately.

## Not required

- per-instance time/deaths/sessions (S4B);
- death/quest/respawn migration;
- block payload v2 completeness;
- legacy retirement;
- live client test.
