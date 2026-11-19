# DS-17.17 — S6 quest/respawn ownership

**Status:** executed 2026-11-18.  
**Result:** `docs/DS-17-17-S6-QUEST-RESPAWN-OWNERSHIP-RESULT.md`  
**Depends on:** DS-17.16  
**Blocks:** S7 heatmaps, S8 block payload  
**Source:** `docs/DS-17-07-DATA-MODEL-RECONCILIATION-RESULT.md`

## Goal

Make `journey.quests` and `journey.respawns` canonical.

### Quests

- Backfill from `db.quests` and `journey.questAnchors`.
- Canonical fields: quest ID, count, XP, lastTurnInAt, mapID, playerLevel, lastSeen.
- Resolve names from the quest ledger; do not copy quest text.
- `GetModelQuest` becomes v2-only.

### Respawns

- Backfill `journey.respawns` from `db.respawns`.
- Canonical fields: NPC identity, interval samples, count/min/max/sum, lastSeen/lastDeath.
- Preserve interval cap/sample policy.
- `GetModelRespawn` becomes v2-only.

Keep `db.quests`/`db.respawns` as compatibility projections.

## Not in S6

- full quest history/text;
- session history beyond the existing live bucket;
- level-history ownership (already handled by S3 levels);
- block payload/UI/legacy retirement.

## Tests

`tests/s6_quest_respawn_ownership.lua`:

- quest ID/count/XP/last/map/level parity;
- anchors and quest ledger remain resolvable;
- respawn intervals and aggregates parity;
- mutation/prune sync;
- idempotence;
- v2-only reads with legacy removed;
- no block/UI/retirement.

## Acceptance

- `journey.quests` and `journey.respawns` canonical.
- Legacy remains compatibility projection.
- No quest text duplication.
- No double counting.
- Full suite passes.
