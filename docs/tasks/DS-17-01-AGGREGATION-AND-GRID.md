# DS-17.1 — Aggregation model and 64×64 sufficiency

**Status:** research/design task, not implemented  
**Parent:** DS-17  
**Depends on:** DS-1 (consumer inventory), DS-2 (real-store baseline), DS-3
(synthetic scale matrix), DS-5 (SavedVariables/loading API matrix)  
**Blocks:** DS-17.2, DS-17.3, DS-4  
**Question:** can 12,000–25,000 kills be represented by aggregates at 64×64
without losing a required feature?

## Scope

Determine the minimum durable data units for:

- heatmap activity;
- mob identity/kill counts;
- level bands;
- zones and instances;
- session/rate summaries;
- future Journey and cell-inspector use cases.

Confirm whether the current 64×64 cells plus per-mob/level/zone/instance counters
are sufficient, or whether a specific feature needs extra identity.

## Research questions

1. **Kill math.** Confirm 250 kills/level × 48/60 levels, plus 100 kills ×
   30/50/100 instances. Record the minimum, typical, and completionist totals.
2. **Unique cardinality.** How many unique mobs, zones, and instances does a
   real 1–60 run create? Use DS-2 data and synthetic DS-3 profiles.
3. **Feature-to-data matrix.** For each feature (heatmap, mob list, area list,
   level list, tooltip, Journey, cell inspector), list the required fields and
   whether an aggregate can answer it.
4. **64×64 quantization.** How many kills per cell are realistic? Does a cell
   aggregate preserve the route/heat/cell-inspector meaning? What is lost versus
   a 96×96 or 128×128 grid? How do wide, tall, and irregular zones affect
   occupied versus empty cells and effective resolution per axis?
5. **Identity needs.** Which features need mob identity, level identity, or
   instance identity beyond a cell count?
6. **Aggregation dimensions.** Confirm the minimum keys:
   `mob`, `level`, `map`, `instance`, `context`, `session`.
7. **Kill events.** Prove that no per-kill timestamp/event log is needed. If one
   is needed, name the exact feature, retention, and cost.
8. **Cap pressure.** Compare 40 heatmap zones/100 instances/2,000 mobs with
   official counts and observed data.
9. **Sparse versus dense.** Estimate cells per visited zone at 100, 1k, and
   4,096 active cells.
10. **Aspect ratio and empty cells.** Measure 1:1, 4:1, 1:4, and irregular
    zone/land shapes. Record occupied versus empty cells, storage cost of empty
    cells (should be zero in sparse tables), effective east-west/north-south
    resolution, and whether a square grid wastes resolution or storage.
11. **Grid alternatives.** Compare square 64, 96/128, rectangular, and
    occupied-mask options only after the aspect-ratio data is collected.

## Official counts already recorded

- Retail 12.1.5: 350 zone-type maps / 212 unique names; 897 dungeon-type maps /
  308 unique names; 1,306 `MapDifficulty.MapID`s.
- Forever 1.60.1: 55 zone-type maps / 54 names; 82 `MapDifficulty.MapID`s.

## Work items

- Build a feature-to-field table from DS-1.
- Add kill/cardinality cases to the DS-3 harness.
- Run 64×64 occupancy and quantization experiments on real/synthetic data,
  including wide/tall/irregular zones and empty-cell ratios.
- Decide whether 64×64 is sufficient for heatmap, route, and inspector, or
  whether an aspect-aware/occupied-mask option is justified.
- Record what must be stored per mob/level/zone/instance.
- Produce a short "do not store per kill" decision with evidence.

## Deliverables

- Aggregation decision note.
- Feature-to-data matrix.
- Unique-cardinality table per profile.
- 64×64 sufficiency recommendation.
- Required-key list for DS-4 schema prototypes.

## Acceptance criteria

- Every feature has a documented data requirement.
- The 64×64 grid is explicitly accepted or rejected with occupancy,
  aspect-ratio, and empty-cell evidence.
- No per-kill log is introduced without a named feature and measured cost.
- The required aggregate keys are stable enough for DS-4.
- DS-17.2/DS-17.3 can proceed without guessing.

## Risks

- 64×64 may be too coarse for a future cell inspector; that is acceptable only
  if the inspector does not require finer resolution.
- Real players may visit many more zones than 40; the cap decision belongs to
  DS-17.3/SC.
- Cardinality may be dominated by contexts, not kills.
