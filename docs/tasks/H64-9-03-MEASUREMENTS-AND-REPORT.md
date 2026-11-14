# H64-9.3 — Run protocol, measurements, and report

**Status:** executed; report complete  
**Parent:** H64-9  
**Owner:** offline benchmark engineer  
**Depends on:** H64-9.1, H64-9.2  
**Blocks:** H64-9.4  
**Deliverables:** `docs/H64-9-BENCHMARK-REPORT.md` and raw result files

## Run protocol

1. Confirm `lua` version and fixture path.
2. Run each scenario 3 times; report median and range.
3. `collectgarbage("collect")` before each measured run.
4. Record data-path and UI-path metrics separately.
5. Record whether the map art is mocked, unavailable, or counted.
6. Keep raw output in `tests/fixtures/heatmap/results/` or a temp directory; do
   not commit large generated output unless small and useful.
7. Do not mix live observations into the offline report.

## Metrics

### Data model

- `NormalizeHeatmaps` time;
- `RecordHeatmapKill` time;
- `GetHeatmapZones` time;
- map-cap pruning time;
- table entries, cells, zones;
- memory before/after.

### UI

- first render time;
- full rebuild time;
- rescale time;
- incremental update time;
- map switch time;
- resize/theme/intensity refresh time;
- texture/cell/art/legend counts;
- operation counts from H64-9.1.

### Shape and occupancy

- active cells;
- occupied cells;
- empty cells;
- aspect ratio;
- occupied percentage;
- effective resolution per axis;
- for irregular masks: occupied bounding box.

### Art

- base art tiles;
- overlay tiles;
- explored overlay tiles;
- legend swatches;
- art on/off effect.

## Execution result

The report is complete at `docs/H64-9-BENCHMARK-REPORT.md`. Key results:

- dense 4,096-cell first render: ~9.4 ms;
- dense rescale: ~6.4 ms; incremental: ~0.75 ms;
- 40/41 dense maps normalize in ~91–93 ms;
- disabled refresh still hides ~4,100 cells, ~0.6 ms;
- wide/tall 1,024-cell profiles: ~2.2 ms full render;
- 41 maps prune to 40 before rendering.

Harness limitations and follow-ups are in the report and
`docs/tasks/H64-9-05-FOLLOWUP-WORK.md`.

## Report template

`docs/H64-9-BENCHMARK-REPORT.md` must contain:

1. **Environment** — Lua version, date, fixture version, commit/workspace state.
2. **Profiles** — IDs, shapes, maps, active/occupied cells.
3. **Results table** — median time, memory, counts per scenario.
4. **Operation counts** — rebuild/rescale/incremental/art/cell.
5. **Aspect-ratio findings** — wide/tall/irregular empty-cell impact.
6. **Cap findings** — 40 vs 41 maps.
7. **Disabled/art findings** — no-work path and art cost.
8. **Interpretation** — what is acceptable, what needs optimization.
9. **Follow-up decisions** — link to H64-9.4.
10. **Limitations** — mocks, no live frame time.

Example table:

| Scenario | Active | Occupied | Empty | Maps | First render ms | Rescale ms | Incremental ms | Memory KB | Cells | Art tiles |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| sparse_square_1 | 100 | 100 | 3996 | 1 | | | | | | |
| dense_square_1 | 4096 | 4096 | 0 | 1 | | | | | | |
| dense_wide_1 | 4096 | 1024 | 3072 | 1 | | | | | | |

## Interpretation rules

- Compare **relative** times; do not claim live FPS.
- A dense zone being slower is expected; focus on scaling and repeated-refresh
  cost.
- Separate data cost from UI/art cost.
- Treat empty cells as zero storage, but record the effective resolution loss.
- A new maximum should not trigger a full cell-pool rebuild; verify operation
  counts.
- Map-cap pruning should be deterministic and should retain the newest zones.
- Collection-off must perform no heatmap/art work.

## Acceptance criteria

- Report contains all required sections.
- Raw results are reproducible from the unchecked-in command.
- Every minimum scenario has a result or a documented fixture gap.
- Findings distinguish data, UI, art, aspect ratio, and cap behavior.
- Follow-up recommendation is evidence-based.
- No production code changed without a separate issue/task.

## Risks

- Offline timing may be dominated by Lua/fixture overhead.
- Art mocks may not reflect real draw cost.
- Repeated GC or timer scheduling can add noise.
- Large dense profiles may hit memory limits in the test process.
