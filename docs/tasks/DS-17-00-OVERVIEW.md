# DS-17.0 — Character lifecycle and cross-character storage: overview

**Status:** task map, not implemented  
**Parent:** `docs/TASK-DS-17-CHARACTER-LIFECYCLE-DATA.md`  
**Purpose:** define the dependency graph and research scope for the future
database.

## Aggregate-first rule

A leveling life has at least ~12,000 kills (250 × 48) and commonly 18,000–25,000
with instances. We do **not** store one row per kill. The 64×64 heatmap plus
per-mob, per-level, per-zone, and per-instance counters are the storage unit.

DS-17.1 must prove that this aggregate model answers every required feature; if
not, it must name the minimum extra identity that is needed.

## Dependency graph

```text
DS-1  consumer inventory ─┐
DS-2  real-store baseline ─┼─> DS-17.1 aggregation / 64x64 sufficiency
DS-3  synthetic matrix ────┤        │
DS-5  loading API ─────────┘        ├─> DS-17.2 modes / lifecycle
                                     │        │
                                     │        ├─> DS-17.3 retention / compression
                                     │        │        │
                                     │        │        └─> DS-17.4 cross-character knowledge and routes
                                     │        │                 │
                                     │        └─────────────────┴─> DS-17.5 schema / migration
                                     │                                     │
                                     └─────────────────────────────────────┴─> DS-17.6 validation / decision
                                                                                       │
                                                                                       v
                                                                                     DS-11
```

## Sub-tasks

| Task | File | Depends on | Blocks |
|---|---|---|---|
| DS-17.1 Aggregation and 64×64 sufficiency | `docs/tasks/DS-17-01-AGGREGATION-AND-GRID.md` | DS-1, DS-2, DS-3, DS-5 | DS-17.2, DS-17.3, DS-4 |
| DS-17.2 Modes and lifecycle | `docs/tasks/DS-17-02-MODES-AND-LIFECYCLE.md` | DS-17.1 | DS-17.3, DS-9, DS-11 |
| DS-17.3 Retention and compression | `docs/tasks/DS-17-03-RETENTION-AND-COMPRESSION.md` | DS-17.1, DS-17.2 | DS-17.4, DS-17.5, DS-9 |
| DS-17.4 Cross-character knowledge and route recommendations | `docs/tasks/DS-17-04-CROSS-CHARACTER-KNOWLEDGE.md` | DS-17.1, DS-17.2, DS-17.3 | DS-17.5 |
| DS-17.5 Schema and migration | `docs/tasks/DS-17-05-SCHEMA-AND-MIGRATION.md` | DS-17.1..DS-17.4, DS-4, DS-9 | DS-11 |
| DS-17.6 Validation and decision | `docs/tasks/DS-17-06-VALIDATION-AND-DECISION.md` | DS-17.1..DS-17.5, SC-1/SC-2 | DS-11 |

## Research index

- **Cards:** official zone/instance counts, unique mobs per level, heatmap
  occupancy, wide/tall/irregular zones and empty-cell ratios.
- **Kills:** 12k minimum, 18–25k realistic; aggregate per cell/mob/level/zone/
  instance; no per-kill log.
- **Modes:** leveling vs endgame, max-level archive, level-cap generations.
- **Compression:** hot/warm/cold, heatmap downsampling, context collapse,
  packed blocks.
- **Alts:** account-wide aggregate knowledge, confidence, privacy.
- **Migration:** backup, downgrade, companion/split file.
- **Decision:** DS-11 after DS-17.6.

## Sequencing

1. DS-1, DS-2, DS-3, DS-5 evidence.
2. DS-17.1 aggregation decision.
3. DS-17.2 lifecycle.
4. DS-17.3 compression.
5. DS-17.4 cross-character.
6. DS-17.5 schema/migration.
7. DS-17.6 measure and decide.
8. DS-11 final architecture decision.

## Definition of done for DS-17

- No per-kill log is introduced unless DS-17.1 proves it is required.
- 12k–25k kills are represented by aggregate counts.
- Leveling and endgame modes are explicit.
- Older state has defined compression tiers.
- Prior-character leveling knowledge is available to a new character.
- Migration and downgrade are safe.
- DS-11 has measured evidence.
