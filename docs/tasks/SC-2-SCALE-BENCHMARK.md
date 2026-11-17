# SC-2 — 2×/4×/6× benchmark

**Status:** executed 2026-11-17  
**Result:** `docs/SC-2-SCALE-BENCHMARK-RESULT.md`  
**Harness:** `tests/bench_real_scale.lua`  
**Depends on:** SC-1, DS-3B  
**Blocks:** SC-3, G-2/G-3

## Why

SC-1 measured one real store. SC-2 scales its shape to test growth and choose a
limit tier without waiting for live data.

## Scope

Use the real-store shape from SC-1 and scale dimensions:

- 2× / 4× / 6× mobs;
- 2× / 4× / 6× kills;
- proportional zones/instances;
- respawn NPCs/samples;
- heatmap zones/cells at real occupancy;
- a bounded context stress multiplier.

Measure:

- serialized and estimated bytes;
- section shares;
- mob/context/respawn/heatmap growth;
- normalize/decode/load/save-affecting operations where available;
- prune/cap behavior;
- block-cold sizes from existing DS-7 codec data.

## Constraints

- Offline synthetic scaling from SC-1's real shape.
- Do not edit the real saved store.
- Do not impose a final cap in this task.
- Do not use fixture memory as a client memory claim.
- No schema/storage change.

## Acceptance

- 2×/4×/6× table with bytes and section shares.
- Dominant-growth section identified.
- Recommendation input for SC-3.
- Context/heatmap stress labeled separately from normal growth.
- No live client required.

## Not required

- live memory;
- final cap decision;
- UI redesign;
- account Knowledge/merge.
