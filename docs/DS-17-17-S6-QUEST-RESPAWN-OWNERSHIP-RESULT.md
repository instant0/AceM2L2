# DS-17.17 — S6 quest/respawn ownership result

**Status:** executed 2026-11-18  
**Scope:** canonical quest and respawn records.  
**Test:** `tests/s6_quest_respawn_ownership.lua`; full suite passes.

## 1. Quests

`journey.quests` is canonical for:

- quest ID, count, XP;
- last turn-in timestamp;
- map ID and player level;
- first/last seen.

Quest **names are not copied** into v2. `GetModelQuest` resolves the name from the
legacy quest ledger while it remains available.

`db.quests` remains a compatibility projection.

## 2. Respawns

`journey.respawns` is canonical for:

- NPC identity/name;
- interval samples;
- sample count, min/max/sum;
- lastSeen/lastDeath.

`db.respawns` remains a compatibility projection.

## 3. Sync

- `EnsureModelQuests` / `EnsureModelRespawns` backfill once.
- Individual and bulk sync rebuild from final legacy state.
- `RecordQuestXP` syncs quests after the turn-in updates.
- `RecordRespawnInterval` syncs the affected NPC.
- Load normalization syncs both.
- Deleted legacy records are removed from v2.
- `GetModelQuest` / `GetModelRespawn` are v2-only.

## 4. Tests

- quest ID/count/XP/last/map/level parity;
- quest name resolved, not duplicated;
- respawn intervals and aggregate parity;
- production quest/respawn updates;
- bulk idempotence;
- deleted legacy records removed;
- v2-only reads with legacy removed.

Passing output:

```text
S6 quest/respawn ownership passed
...
All offline checks passed.
```

## 5. Limits

- No full quest history or quest text.
- No session-history migration.
- Level-history ownership remains the S3 model.
- Block/UI/legacy retirement unchanged.

## 6. Next

**DS-17.18 — S7 heatmap ownership and top-N.**

## Artifacts

- `KillHistory/JourneyModel.lua`
- `KillHistory/Data.lua`
- `KillHistory/World.lua`
- `tests/s6_quest_respawn_ownership.lua`
- `tests/run_all.sh`
- `docs/tasks/DS-17-17-S6-QUEST-RESPAWN-OWNERSHIP.md`
