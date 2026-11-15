# DS-17.1 — Data organization and query sufficiency

**Status:** next; capacity model and DS-3B validation complete; remaining
feature-to-data, hot/warm/cold boundary, required keys, and 64×64 decision  
**Parent:** DS-17  
**Depends on:** DS-1 (consumer contract), DS-2 (reference baseline only), DS-3
(small/medium sanity check), DS-3B (massive synthetic validation), DS-5
(loading/API matrix), `docs/DS-17-1-CAPACITY-AND-STRATEGY.md`  
**Blocks:** DS-17.2, DS-17.3, DS-4P, DS-17.5. DS-4 hot representation is settled.  
**Question:** what minimum durable units and hot/warm/cold split serve
long-term play, 15k–32.5k+ kills, 200+ zones/instances, and no artificial global
element cap?

## Scope

Decide:

- the feature-to-data matrix;
- the hot/warm/cold boundary;
- the required hot-index and cold-block fields;
- whether 64×64 is sufficient for heatmap, route, and cell-inspector meaning;
- the no-global-cap retention rule;
- long-term behavior beyond the current 2,000/40/100 implementation caps;
- what must be stored per mob/level/zone/instance/context/session.

Do **not** reopen choices already settled by DS-4/DS-5:

- Lua tables, not JSON;
- stable IDs, not checksum identity;
- sparse 64×64 cells, not per-kill coordinates;
- no per-kill event log;
- account vs per-character scope;
- no per-zone SavedVariables files.

Include zone-scoped retrieval:

- tooltip lookup for the hovered mob without loading every zone;
- current/selected heatmap zone with eviction;
- a compact global identity/name index for fallback;
- correct behavior when a subset is not loaded.

Exact content counts are not required.

## Inputs

- **Primary capacity input:** `docs/DS-17-1-CAPACITY-AND-STRATEGY.md`.
- **Validated by:** `docs/DS-3B-MASSIVE-SYNTHETIC-RESULT.md` — 8.69 MB
  compact / 9.94 MB client estimate / 23 MB stable / 27–37 MB transient Lua heap.
- **Long-term pressure:** `docs/DS-3C-LONG-TERM-GROWTH.md` — current caps are
  too small; 2h/day hits 2,000 mobs in ~3 months and rate samples turn over in
  2.4h. Do not use the current-cap profile as the target.
- **Consolidated research:** `docs/STORAGE-STRATEGY.md`.
- **Consumer contract:** `docs/tasks/DS-1-CONSUMER-CONTRACT.md`.
- **Loading/API constraints:** `docs/DS-5-SAVEDVARIABLES-LOADING-MATRIX.md`.
- **Reference only:** `docs/tasks/DS-2-REAL-STORE-BASELINE.md`; the 762-kill
  store is not the design target.
- **Small/medium proof only:** `docs/DS-3-STORAGE-SANITY-RESULT.md`.
- **Heatmap measurements:** `docs/H64-9-BENCHMARK-REPORT.md`.

## DS-5 loading constraints

- A normal addon loads all of its SavedVariables together. Account data loads
  for every character; per-character data loads only for the active character.
- Multiple variables do not defer loading. Only a LoadOnDemand companion can
  defer its code and, subject to V-2 timing proof, its variables.
- There are no per-zone SavedVariables files. Zone laziness is in-memory
  decode/normalize/UI, packed blocks, or a companion.
- `LoadSavedVariablesFirst` changes order only; it does not reduce load.
- `SaveAddOns` is a checkpoint, not a synchronous durability guarantee.
- `SAVED_VARIABLES_TOO_LARGE` is an out-of-memory load-failure path; the
  variables will not save on the next logout.

Do not design a layout that assumes partial SavedVariables loading.

## Required scale cases

Exact content counts are not required. Use player and dimension tiers.

| Dimension | Tier A | Tier B | Tier C |
|---|---:|---:|---:|
| Kills | 15,000 | 22,500 | 32,500 |
| Unique mobs | 500 | 1,000 | 2,000 |
| Open-world zones/areas | 40 | 100 | 200 |
| Instance records | 50 | 100 | 200 |
| Heatmap cells per zone | 100 | 1,000 | 4,096 |
| Contexts per mob | 4 | 8 | 12 |
| Mob map/instance links | 2–4 | 4–8 | 8–20 |

Player scenarios:

- level 1, first character;
- level 20 leveling;
- max-level/endgame;
- first alt with a 1–60 archive;
- 10-year veteran with multiple alts/archives.

The 100,000-entry and 350,000-entry (AllTheThings-scale) figures are stress
ceilings, not player scenarios or targets.

The design must represent these without a per-kill row and without
special-casing a particular content count.

## Research questions

1. **Kill math.** Confirm 250 kills/level × 60/90 levels, plus 100 kills ×
   30/50/100 instances. Record minimum, typical, and completionist totals.
2. **Scenario cardinality.** For level 1, level 20, max level, first alt, and
   10-year veteran, record unique mobs, zones, instances, contexts, and cells
   using the capacity tiers. Do not use the 762-kill baseline as the target.
3. **Feature-to-data matrix.** For each feature (heatmap, mob list, area list,
   level list, tooltip, diagnostics, Journey, cell inspector), record:
   - scope;
   - required fields;
   - hot/warm/cold unit;
   - query/index;
   - fallback when a subset is absent;
   - retention.
4. **64×64 quantization.** How many kills per cell are realistic? Does a cell
   aggregate preserve route/heat/cell-inspector meaning? What is lost versus
   96×96 or 128×128? How do wide/tall/irregular zones affect occupied versus
   empty cells and effective resolution?
5. **Identity needs.** Which features need mob identity, level identity, or
   instance identity beyond a cell count?
6. **Aggregation dimensions.** Confirm the minimum keys:
   `mob`, `level`, `map`, `instance`, `context`, `session`.
7. **Kill events.** Prove that no per-kill timestamp/event log is needed. If one
   is needed, name the exact feature, retention, and cost.
8. **Cap pressure.** Compare 40/100/200 zones and 50/100/200 instances with the
   player tiers. The current 2,000-mob/40-zone/100-instance caps are too small
   for the massive tier; decide the replacement retention rule.
9. **Sparse versus dense.** Estimate active cells per visited zone at 100, 1,000,
   and 4,096.
10. **Aspect ratio and empty cells.** Measure 1:1, 4:1, 1:4, and irregular
    shapes. Record occupied versus empty cells, storage cost of empty cells
    (zero in sparse tables), effective resolution per axis, and whether a square
    grid wastes resolution or storage.
11. **Hot/warm/cold split.** For each feature and data unit, state what stays
    hot, what is downsampled, what is packed, and what is summarized/dropped.
12. **Grid alternatives.** Compare square 64, 96/128, rectangular, and
    occupied-mask options only after the aspect-ratio data is collected.

## Work items

- Build the feature-to-data matrix from DS-1.
- Consume DS-3B actual bytes/Lua heap and correct the capacity range if needed.
- Define hot/warm/cold boundaries and replace the 2,000-mob/40-zone/100-instance
  global caps with per-zone/per-block retention.
- Define the hot-index fields and the cold packed-block fields separately.
- Reuse the capacity tiers; use the DS-3/H64-9 harness only for 64×64 occupancy
  and quantization tests.
- Run 64×64 occupancy and quantization experiments, including wide/tall/
  irregular zones and empty-cell ratios.
- Decide whether 64×64 is sufficient for heatmap, route, and inspector, or
  whether an aspect-aware/occupied-mask option is justified.
- Record what must be stored per mob/level/zone/instance/context/session.
- Produce a short "do not store per kill" decision with evidence.
- Produce the DS-4P inputs: hot-index fields, cold-block fields, per-zone
  retention, and the query/index list.

## Deliverables

- aggregation decision note;
- feature-to-data matrix;
- unique-cardinality table per player profile;
- 64×64 sufficiency recommendation;
- hot/warm/cold boundary and cap-retention policy;
- required-key list for the hot index and cold blocks;
- DS-4P hybrid prototype inputs;
- named follow-ups.

## Acceptance criteria

- Every feature has a documented scope, required fields, hot/cold unit, query,
  fallback, and retention.
- The 64×64 grid is explicitly accepted or rejected with occupancy,
  aspect-ratio, and empty-cell evidence.
- The design does not rely on the current 2,000-mob/40-zone/100-instance caps as
  the massive-scale limit.
- Hot, warm, and cold storage units are explicit.
- No per-kill log is introduced without a named feature and measured cost.
- Settled DS-4/DS-5 choices are not reopened.
- Required keys are stable enough for DS-4P and DS-17.5.
- DS-17.2/DS-17.3 can proceed without guessing.

## Risks

- 64×64 may be too coarse for a future cell inspector; that is acceptable only
  if the inspector does not require finer resolution.
- The 40-zone hot tier is not a content limit; DS-17.3 sets retention and
  downsampling.
- Cardinality is dominated by contexts and heatmap cells, not kills.
- Entry-count stress tests can mislead; use player tiers plus dimensions.
- A single projected byte count is false precision until the hot/cold boundary
  is chosen.

## Safe execution

1. Finish the feature-to-data matrix and required keys. No code.
2. Run the 64×64/aspect-ratio decision. Offline only.
3. Feed DS-17.2/DS-17.3 and DS-4P.
4. Do not change production schema or global caps in this task.

The first safe code task after DS-17.1 is `DS-1-F2` in-memory indexes.
