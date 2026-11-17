# SC-3 — Tier decision result

**Status:** decided 2026-11-17  
**Test:** `tests/limit_tier.lua`; `./tests/run_all.sh`  
**Scope:** accepted 6× shape and selective cap changes only.

## Decision

**Accept the 6× tier.**

Do not raise every cap by the same factor.

## Cap changes

| Store | Decision |
|---|---|
| Mobs | **Adaptive** limit: 500 per visited area/instance, minimum 2,000, hard ceiling **12,000** |
| Quests | **Adaptive** limit: 100 per visited area/instance, minimum 500, hard ceiling **10,000** |
| Deaths | Keep **100**; 6× shape is 96 |
| Respawn NPCs | Raise **300 → 4,000**; known Forever creatures are 3,478 |
| Heatmap zones | Raise **40 → 64**; the source lists 50 zones |
| Level history | Keep **200** |
| Rate samples | Keep **240** |
| Instances | Keep **100** |
| Contexts/mob | Keep **12** |
| Instance keys/mob | Keep **20** |

## Why quests are adaptive

The real SC-1 sample was unrepresentative: zones commonly contain **50+ quests**.
A fixed 200/500 cap is therefore wrong.

The active quest limit is:

```text
min(10000, max(500, visitedZones * 100))
```

Examples:

- 4 zones → 500 quests / 2,000 mobs;
- 8 zones → 800 quests / 4,000 mobs;
- 24 zones → 2,400 quests / 12,000 mobs;
- 40/50/100 zones → quest cap continues; mobs stay at 12,000.

This gives roughly 2× headroom over 50 quests/zone and scales with actual traversal.
The hard ceiling prevents unbounded growth.

## Why not raise everything

The 6× shape is under the mob, death, heatmap, level, rate, instance, and
context caps. Raising them now would be unrelated to the measurement and would
weaken safety rails.

## Tests

`tests/limit_tier.lua` verifies:

- adaptive mob limit: 4 zones → 2,000; 8 → 4,000; 24 → 12,000;
- respawn cap is 4,000 and 414 records survive;
- quest hard ceiling is 10,000;
- 4 visited zones → 500;
- 40 visited zones → 4,000;
- 100 visited zones → 10,000;
- 40-zone/3,000-quest data is not pruned;
- small-zone overgrowth prunes to the adaptive limit;
- the 6× respawn shape is not trimmed.

Passing output:

```text
Limit tier passed
```

`./tests/run_all.sh` passes.

## Follow-up

The engine can do more than fixed caps: it can measure its own footprint and
make bounded retention/eviction decisions. That is the next task:
**SC-6 — Capacity self-assessment**.

## Artifacts

- `KillHistory/Data.lua`
- `KillHistory/World.lua`
- `KillHistory/UI/Diagnostics.lua`
- `README.md`
- `tests/limit_tier.lua`
- `tests/run_all.sh`
- `docs/tasks/SC-3-TIER-DECISION.md`
