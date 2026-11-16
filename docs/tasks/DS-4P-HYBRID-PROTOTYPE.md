# DS-4P — Hybrid hot/cold prototype

**Status:** executed 2026-11-16  
**Result:** `docs/DS-4P-HYBRID-PROTOTYPE-RESULT.md`  
**Purpose:** prove the hybrid storage/retrieval model at scales beyond the current
2,000-mob / 40-zone / 100-instance implementation caps. Offline prototype only.

## Inputs

- `docs/DS-17-1-AGGREGATION-DECISION.md`
- `docs/DS-17-2-MODES-LIFECYCLE-DECISION.md`
- `docs/DS-17-3-RETENTION-DECISION.md`
- `docs/DS-3B-MASSIVE-SYNTHETIC-RESULT.md`
- `docs/DS-3C-LONG-TERM-GROWTH.md`
- `docs/DS-1-F2-INDEX-RESULT.md`
- `docs/ATTR-1-GROUP-UNATTRIBUTED-XP.md`

## What to prototype

```text
hot index (small, always loaded)
  -> summary counters
  -> mob identity/name index
  -> zone/instance index
  -> unattributed XP summary
  -> cold-block refs (offset, length, checksum, tier)

cold blocks (packed per zone/level)
  -> mob/level/instance counts
  -> sparse cells (64/32/16)
  -> top-N
  -> dictionaries
```

The cold block codec may be a simple deterministic placeholder; DS-7/DS-12
finalize the real codec.

## Scale tiers

- **A:** 2,000 mobs / 40 zones / 100 instances (current implementation profile).
- **B:** 10,000 mobs / 100 zones / 200 instances.
- **C:** 100,000 mobs / 200 zones / 200 instances (stress, not target).

Also test:

- 3/6/12-month kill profiles;
- leveling and endgame generation archives;
- first alt with a level-60 main: only alt hot + account aggregates;
- 4/8/12 contexts;
- 64/32/16 heatmaps;
- current/selected zone retrieval;
- identity-less group XP stays an aggregate, never a fake mob.

## Measurements

- hot index bytes and Lua heap;
- cold block bytes per zone/level/tier;
- pack/decode time;
- selected-zone load and eviction;
- tooltip lookup without full scan;
- zone/instance list without full scan;
- save/reload;
- archive/restore behavior;
- correctness against canonical aggregates.

## Acceptance

- No query scans all mobs/zones.
- Cold blocks decode only when selected.
- No per-kill log.
- No 2,000/40/100 global stop.
- Tier B/C complete without data loss or double count.
- The prototype identifies codec requirements for DS-7/DS-12.
- The result feeds DS-15/DS-16/DS-17.5/DS-11.

## Not required

- live client test;
- exact content census;
- final codec;
- schema migration;
- production code.
