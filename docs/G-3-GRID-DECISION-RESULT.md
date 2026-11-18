# G-3 — Grid decision result

**Status:** decided 2026-11-17  
**Input:** `docs/G-2-GRID-OCCUPANCY-RESULT.md`  
**Scope:** decision only. No code, schema, storage, or UI change.

## Decision

**Keep the durable 64×64 sparse heatmap grid.**

- 64×64 remains the stored grid.
- Cells remain sparse; empty cells store nothing.
- The UI keeps lazy per-active-cell allocation.
- No migration, schema bump, or block-format change.

## Rejected options

### 96×96

Rejected.

- Adds 2.25× potential cells.
- Real-shape active cells grow ~1.4×.
- Does not nest under 64: area-weighted 96→64 downsample preserves only
  2–9 of the top-10 hotspots; recorded real shapes preserve 7–8 of 10.
- Worst migration/merge/display target of the three square grids.

### 128×128

Rejected for now.

- Adds 4× potential cells.
- Real-shape active cells grow 1.67–1.81×.
- 75–78% of real-shape 128 cells become single-kill cells; isolated cells rise
  from 1.5–2.2% to 5.4–11.2%.
- Dense stress costs ~2.85× cells, ~3.03× table bytes, and ~2.86× the offline
  render envelope.
- The extra resolution mostly fragments existing signal.
- It is the only allowed future data grid because it nests exactly under 64
  (10/10 hotspot preservation), but it needs a concrete feature and live cost
  proof before adoption.

### Rectangular durable grid

Rejected.

- Stored coordinates are normalized 0–1 on both axes.
- The heatmap record does not carry map world dimensions or aspect ratio.
- A durable rectangle would guess at geometry and complicate cell indexing,
  migration, downsampling, and merge logic.
- Wide/tall synthetic profiles already occupy narrow bands in the square grid,
  with 53–60% span occupancy; they do not demonstrate wasted stored cells.

### Occupied mask

Rejected.

- Empty cells already cost zero storage.
- The UI allocates cells only for active indices.
- A mask adds a second representation plus merge/downsample complexity.
- The real sample is only 4.5–4.8% occupied, but that sparsity is already
  handled correctly.

## Allowed future paths

1. **Per-cell detail at 64.** If the cell inspector needs more meaning, add
   bounded top-mob/level/instance summaries per 64-cell. This does not require a
   finer grid.
2. **Display-only aspect treatment.** If a reliable map-dimension source becomes
   available, an aspect-aware display can be evaluated without changing durable
   indexing.
3. **128 durable grid only if:**
   - a concrete feature needs it;
   - the feature cannot be served by per-cell summaries at 64;
   - live V-1/V-2 checks show acceptable frame and memory cost;
   - a 64 display fallback and downsample path are part of the design.

96×96 remains excluded.

## What does not change

- `HEATMAP_GRID_SIZE` stays 64.
- Journey block schema stays 2.
- Sparse cell storage and LRU behavior stay as-is.
- Existing 32/16 cold downsample paths stay valid.
- No new migration is needed.

## Follow-ups

- **G-1** — coordinate capture code review remains queued.
- **V-3** — only needed if G-1 finds a coordinate-capture change. It is not
  needed for this grid decision.
- **M-1..M-6** — cell inspector should start from 64-cell aggregates.
- **V-1** — live heatmap frame checks remain a general confirmation, not a
  blocker for keeping 64.

## Artifacts

- `docs/G-2-GRID-OCCUPANCY-RESULT.md`
- `docs/tasks/G-2-GRID-OCCUPANCY.md`
- `docs/H64-9-F5-ASPECT-OCCUPANCY-RESULT.md`
- `docs/SC-1-REAL-STORE-MEASUREMENT-RESULT.md`
- `docs/SC-2-SCALE-BENCHMARK-RESULT.md`
