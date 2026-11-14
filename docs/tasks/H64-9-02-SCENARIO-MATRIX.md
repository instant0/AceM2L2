# H64-9.2 — Scenario matrix and data generation

**Status:** executed; scenario matrix implemented in the harness  
**Parent:** H64-9  
**Owner:** offline benchmark engineer  
**Depends on:** H64-9.1  
**Blocks:** H64-9.3  
**Deliverable:** deterministic scenario data and run matrix

## Scenario dimensions

Run the cross-product where practical, and a reduced matrix where it is not.

### Density

| ID | Active cells | Purpose |
|---|---:|---|
| sparse | ~100 | Typical early zone |
| medium | ~1,000 | Busy leveling zone |
| dense | 4,096 | All cells active |
| few_hot | 20 cells with high counts + sparse tail | Realistic hot-spot shape |

### Shape

| ID | Aspect | Cells |
|---|---|---|
| square | 1:1 | 64×64 |
| wide | 4:1 | 64×64 with large empty bands |
| tall | 1:4 | 64×64 with large empty columns |
| irregular | land-mask | 64×64 with a sampled/irregular occupied set |

### Map count

- 1 map
- 40 maps (cap boundary)
- 41 maps (prune trigger)

### Actions

For each selected profile:

1. first render;
2. repeated kills in one cell;
3. new cells appearing;
4. a new per-zone maximum (rescale path);
5. map switch;
6. theme change;
7. intensity change;
8. window resize;
9. heatmap collection disabled;
10. heatmap collection re-enabled;
11. map art enabled/disabled;
12. reveal unexplored on/off.

### Count distributions

- uniform: every active cell = same count;
- linear: counts 1..N;
- skewed: a few high-count cells, long tail of 1s;
- max edge: one cell at the maximum, one at 1.

## Data required

```lua
{
  id = "dense_square",
  aspect = "1:1",
  maps = 40,
  activeCells = 4096,
  occupiedCells = 4096,
  emptyCells = 0,
  distribution = "skewed",
  maxCount = 1000,
  art = true,
  reveal = true,
  heatmapEnabled = true,
}
```

Rules:

- Empty cells must not be inserted into `cells`; sparse storage is the point.
- For wide/tall profiles, occupied cells are a subset of the 4,096 indices.
- For irregular profiles, use a deterministic land mask (seeded) and document
  the mask generation.
- Total kills must equal the sum of cell counts.
- Map IDs must be valid in the fixture `C_Map` mocks.

## Required scenarios (minimum)

| ID | Density | Shape | Maps | Focus |
|---|---|---:|---:|---|
| `sparse_square_1` | sparse | 1:1 | 1 | baseline |
| `medium_square_1` | medium | 1:1 | 1 | typical |
| `dense_square_1` | dense | 1:1 | 1 | worst case |
| `fewhot_square_1` | few hot | 1:1 | 1 | realistic |
| `dense_wide_1` | dense | 4:1 | 1 | empty columns |
| `dense_tall_1` | dense | 1:4 | 1 | empty rows |
| `dense_irregular_1` | dense | irregular | 1 | land mask |
| `dense_square_40` | dense | 1:1 | 40 | cap boundary |
| `dense_square_41` | dense | 1:1 | 41 | prune trigger |
| `disabled_square` | dense | 1:1 | 1 | collection off |
| `noart_square` | dense | 1:1 | 1 | art fallback |

## Required measurements per scenario

- data: normalize, record, prune, memory;
- UI: first render, rescale, incremental, map switch, resize;
- operation counts by type;
- occupied/empty/rasterization counts;
- duration and variance over repeated runs.

## Data generation rules

- Use deterministic seeds so reports are reproducible.
- Generate profiles in Lua, not by copying another addon's data.
- Keep total cell counts and totals consistent.
- For 40/41 maps, use distinct map IDs and varied `lastSeen`.
- For empty cells, leave indices absent; do not store zero cells.

## Execution notes

- `dense_wide_1`, `dense_tall_1`, and `dense_irregular_1` now generate unique
  occupied indices; earlier index formulas could collapse to ~64 cells.
- `dense_square_41` selects the newest map so pruning does not leave the
  measured zone empty.
- Wide/tall profiles contain 1,024 occupied and 3,072 empty cells; empty cells
  are absent from the sparse cell table.

## Acceptance criteria

- Every minimum scenario is runnable by ID.
- Wide/tall/irregular profiles explicitly report empty-cell counts.
- 40/41 map profiles exercise the cap.
- Disabled collection covers the no-work path.
- Data is deterministic and documented.
- Results can be compared across runs.

## Follow-up

H64-9.3 consumes this matrix. Any scenario that cannot run because of a fixture
gap becomes a harness follow-up, not a production change.
