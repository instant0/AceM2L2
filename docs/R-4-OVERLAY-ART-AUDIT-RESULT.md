# R-4 — Static overlay/art audit result

**Status:** executed 2026-11-16  
**Production files:** `KillHistory/MapOverlayData.lua`,
`KillHistory/UI/Heatmap.lua`, `tests/generate_map_overlays.py`  
**Test:** `tests/map_overlay_audit.lua`; `./tests/run_all.sh`  
**Scope:** static code/data audit only. No art replacement, grid change, or live
visual comparison.

## 1. Confirmed issues fixed

### Duplicate generated overlays

The generated data contained **50 exact duplicate tuples** across art IDs. They
would consume overlay budget and draw identical pixels more than once.

- Removed all exact duplicates from the checked-in data.
- Updated the generator to deduplicate by full tuple.
- Kept same-geometry entries when their tile lists differ.
- Added a runtime exact-tuple dedupe in static overlay parsing.

Checked-in data after cleanup: **3,423 overlay tuples**, **0 exact duplicates**.

### Overlay identity collision risk

`OverlayKey` packed width/height/offset values into one double using bit shifts.
Large map dimensions can exceed safe integer precision.

Replaced it with a string key:

```text
width:height:offsetX:offsetY
```

Explored/static matching remains compatible and collision-safe.

### Incomplete cache signatures

Explored-overlay signatures only included width, height, offset, texture count,
first texture, and last texture. A middle-texture change could reuse stale art.

- Explored signatures now include every texture ID.
- Static signatures now include every texture ID and are deduped.
- Exact duplicate explored overlays are ignored.
- Art cache invalidation now reacts to any texture-list change.

## 2. Audit findings with no code change

- Base art, explored overlays, static unexplored overlays, and heat cells have
  the intended relative phase order.
- Tile row/column, offset, scale, edge-size, and `NextPowerOfTwo` texture
  coordinates are consistent with the generated data.
- Static overlay maximum per art ID is **363 tiles**, below the **600** overlay
  budget in the checked-in data.
- `MAX_ART_TILES` and surplus-tile hiding are applied consistently.
- Reveal-disabled, explored-key suppression, and art-key invalidation paths
  remain correct.
- Live visual/frame comparison still belongs to V-5.

## 3. Tests

`tests/map_overlay_audit.lua` verifies:

- required projects exist;
- every overlay tuple is well-formed;
- dimensions/offsets are valid;
- tile IDs are positive and unique within an entry;
- no exact duplicate tuples exist per art ID;
- duplicate explored overlays render once;
- a middle-texture change invalidates cached art.

Passing output:

```text
Map overlay audit passed
```

`./tests/run_all.sh` passes.

## 4. Limitations

- The audit is static; visual quality and frame cost remain V-5.
- Generated tile grids are validated structurally, not against live client
  rendering.
- No art replacement or storage/grid change.
- No new runtime flag.

## 5. Next

**UI-3 — Death and respawn history view.**

## Artifacts

- `KillHistory/MapOverlayData.lua`
- `KillHistory/UI/Heatmap.lua`
- `tests/generate_map_overlays.py`
- `tests/map_overlay_audit.lua`
- `tests/run_all.sh`
