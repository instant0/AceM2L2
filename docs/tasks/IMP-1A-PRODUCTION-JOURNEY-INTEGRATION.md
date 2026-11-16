# IMP-1A — Production Journey instrumentation

**Status:** executed 2026-11-16  
**Result:** `docs/IMP-1A-JOURNEY-INSTRUMENTATION-RESULT.md`  
**Module:** `KillHistory/Journey.lua`  
**Test:** `tests/journey.lua`  
**Next:** IMP-1B storage/retrieval integration

## Scope

Implemented:

- additive `self.char.journey` table;
- event-driven `presenceSeconds`/`engagedSeconds`;
- no timer/OnUpdate;
- `PLAYER_LOGOUT` finalizer;
- existing zone/level/kill/XP event hooks;
- quest turn-in anchor and `killXP`/`questXP`/`otherXP` split;
- production test in `tests/run_all.sh`.

Not implemented:

- v2 schema migration of existing data;
- block save/retrieval;
- instance/name-only blocks;
- danger/health/death fields;
- heatmap cell XP/time;
- tooltip/best-zone/heatmap query integration;
- account Knowledge/merge;
- UI.

## Acceptance

- Event-driven time works without a timer.
- Quest turn-in anchors presence, not engaged time.
- XP split is recorded.
- Existing smoke suite passes.
- Additive production instrumentation does not replace existing schema.
- Storage/retrieval remains for IMP-1B.
