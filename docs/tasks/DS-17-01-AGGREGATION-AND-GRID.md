# DS-17.1 — Data organization and query sufficiency

**Status:** research/design task, not implemented  
**Parent:** DS-17  
**Depends on:** DS-1 (consumer inventory), DS-2 (real-store baseline), DS-3
(synthetic scale matrix), DS-5 (SavedVariables/loading API matrix)  
**Blocks:** DS-17.2, DS-17.3. DS-4 representation design is complete.  
**Question:** what organization best serves efficiency, speed, correctness, and
reuse while representing 12k–32.5k kills without a per-kill log?

## Scope

Determine the minimum durable data units for:

- heatmap activity;
- mob identity/kill counts;
- level bands;
- zones and instances;
- session/rate summaries;
- future Journey and cell-inspector use cases.

Confirm whether the current 64×64 cells plus per-mob/level/zone/instance counters
are sufficient, or whether a specific feature needs extra identity. Evaluate
zone-first, identity/count split, packed blocks, and hybrid layouts against the
storage objectives. Include **zone-scoped loading**:

- tooltip lookup for the hovered mob without loading every zone;
- current/selected heatmap zone with eviction;
- a compact global identity/name index for fallback;
- correct behavior when a subset is not loaded.

Exact content counts are not required; capacity tiers are stress tests.

### DS-5 loading constraints

Use `docs/DS-5-SAVEDVARIABLES-LOADING-MATRIX.md` as a hard input:

- A normal addon loads all of its SavedVariables together. Account data loads
  for every character; `SavedVariablesPerCharacter` loads only the active
  character.
- Multiple variables do not defer loading. Only a LoadOnDemand companion can
  defer its code and, subject to V-2 timing proof, its variables.
- There are no per-zone SavedVariables files. Zone laziness is in-memory
  decode/normalize/UI, packed blocks, or a companion.
- `LoadSavedVariablesFirst` changes only the file/`ADDON_LOADED` order. It does
  not reduce what is loaded.
- `SaveAddOns` is a checkpoint, not a per-kill write and not a synchronous
  durability guarantee.
- `SAVED_VARIABLES_TOO_LARGE` is an out-of-memory load-failure path; the
  variables will not save on the next logout.

Do not design a layout that assumes partial SavedVariables loading.

## Required scale cases

Exact content counts are not required. Use entry tiers and player scenarios:

- 100 / 1,000 / 10,000 / 100,000 entries; 350,000 as an external upper-bound
  reference (AllTheThings-scale), not a target.
- Level 1, level 20, max-level/endgame, first alt with a 1–60 archive, and a
  10-year veteran with multiple alts/archives.
- Forever 1–60 at 250 kills/level = 15,000 kills; 18k–25k with instances.
- Midnight 1–90 = 22,500 leveling kills; 25.5k–32.5k with instances.
- 40/100/200 zones, 50/100/200 instances as capacity tiers, not exact game
  counts; dungeons, raids, PvP, and scenarios are separate categories.
- 500/1,000/2,000 tracked mobs; 4/8/12 contexts.
- 100/1,000/4,096 heatmap cells; 1:1, 4:1, 1:4, irregular.

The model must represent these totals without a per-kill row and without
special-casing a particular content count.

## Research questions

1. **Kill math.** Confirm 250 kills/level × 48/60 levels, plus 100 kills ×
   30/50/100 instances. Record the minimum, typical, and completionist totals.
2. **Scenario cardinality.** How many unique mobs, zones, and instances do the
   level-1, level-20, max-level, first-alt, and 10-year-veteran scenarios create?
   Use DS-2 data and synthetic DS-3 profiles; no exact game census is required.
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
8. **Cap pressure.** Compare 40 heatmap zones/100 instances/2,000 mobs with the
   scenario profiles and capacity tiers; treat dungeons, raids, PvP, and
   scenarios as separate categories.
9. **Sparse versus dense.** Estimate cells per visited zone at 100, 1k, and
   4,096 active cells.
10. **Aspect ratio and empty cells.** Measure 1:1, 4:1, 1:4, and irregular
    zone/land shapes. Record occupied versus empty cells, storage cost of empty
    cells (should be zero in sparse tables), effective east-west/north-south
    resolution, and whether a square grid wastes resolution or storage.
11. **Grid alternatives.** Compare square 64, 96/128, rectangular, and
    occupied-mask options only after the aspect-ratio data is collected.

## Content categories

Use planning buckets rather than exact counts:

- outdoor zones (~200 unique names on Midnight);
- dungeons;
- raids;
- PvP battlegrounds/arenas;
- scenarios/delves.

`UiMap` dungeon-type rows include variants/difficulties; do not treat them as
unique dungeons. Exact counts are not required for this task.

## Work items

- Build a feature-to-field table from DS-1.
- Reuse the DS-3 harness for kill/cardinality cases; add only cases the
  aggregation decision actually needs.
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
