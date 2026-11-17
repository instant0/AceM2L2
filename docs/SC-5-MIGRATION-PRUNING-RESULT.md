# SC-5 — Migration, pruning, and cap tests result

**Status:** executed 2026-11-17  
**Test:** `tests/cap_boundaries.lua`; `tests/limit_tier.lua`;
`tests/context_cap.lua`; `./tests/run_all.sh`  
**Scope:** boundary tests, deterministic pruning, idempotence, and reset/downgrade
documentation. No new schema.

## 1. Boundaries covered

| Store | Boundary | Behavior |
|---|---:|---|
| Mobs | 2,000–12,000 adaptive | zone-derived limit; hard ceiling |
| Quests | 500–10,000 adaptive | 100/visited zone; hard ceiling |
| Respawns | 4,000 NPCs | newest retained |
| Heatmap zones | 64 | newest retained |
| Deaths | 100 | newest retained |
| Level records | 200 | oldest finalized removed |
| Rate samples | 240 | newest retained |
| Instances | 100 | newest retained |
| Mob instances | 20/mob | highest counts retained |
| Contexts | 12/mob | oldest/expired removed |
| Context age | 120 days | expired removed |

## 2. Tests

`tests/cap_boundaries.lua` verifies:

- deaths: 101 → 100, oldest removed;
- respawns: 4,001 → 4,000, oldest removed;
- level records: 201 → 200, oldest finalized removed;
- rates: 241 → 240, oldest removed;
- instances: 101 → 100, oldest removed;
- repeated normalization is idempotent.

Existing suites also cover:

- adaptive mob/quest limits;
- 6× shape;
- heatmap cap;
- hot context cap and expiry;
- capacity pressure.

Passing output:

```text
Cap boundaries passed
```

`./tests/run_all.sh` passes.

## 3. Pruning rules

- Recency is the default tie-breaker.
- Level history prefers dropping finalized records before the active one.
- Contexts drop expired entries first, then oldest `lastSeen`.
- Mob instances keep highest kill counts.
- Adaptive caps use visited area/instance count.
- Hard ceilings remain safety rails.

## 4. Reset/downgrade

- `ResetKills` clears:
  - mobs, quests, areas, instances, levels, areaLevels;
  - Journey data/blocks;
  - deaths, respawns, heatmaps;
  - rates, level history, economy, goal;
  - calibration.
- Per-client schema remains `1`.
- Storage schema remains `2`.
- A newer schema is read-only/blocked; it is not rewritten.
- Downgrade behavior remains documented and unchanged.

## 5. Remaining limitation

Cold context encoding (top-8 + `other`) is policy-ready but not yet part of the
packed block schema. This is a future schema task.

## 6. Next

**G-2 — 64 vs 96/128 occupancy study.**

## Artifacts

- `tests/cap_boundaries.lua`
- `tests/limit_tier.lua`
- `tests/context_cap.lua`
- `tests/run_all.sh`
- `docs/tasks/SC-5-MIGRATION-PRUNING-TESTS.md`
