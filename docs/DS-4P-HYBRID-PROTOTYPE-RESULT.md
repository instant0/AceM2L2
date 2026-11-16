# DS-4P — Hybrid hot/cold prototype result

**Status:** executed 2026-11-16; offline prototype  
**Harness:** `tests/ds4p_hybrid.lua`  
**Scope:** hot index + packed cold blocks, selected-zone decode, tooltip lookup,
zone list, prototype save/reload. No live client and no production schema.

## Tiers

| Tier | Mobs | Zones | Instances | Cells/zone | Contexts/mob |
|---|---:|---:|---:|---:|---:|
| A | 2,000 | 40 | 100 | 4,096 | 12 |
| B | 10,000 | 100 | 200 | 1,000 | 12 |
| C | 100,000 | 200 | 200 | 1,000 | 12 |

## Results

| Tier | Hot heap | Cold rows | Total structural | Build | Selected-zone decode | Tooltip 10k | Zone list |
|---|---:|---:|---:|---:|---:|---:|---:|
| A | 1.75 MB | 0.61 MB | 2.36 MB | 214 ms | 1.5 ms | 0.60 ms | 0.002 ms |
| B | 4.73 MB | 1.02 MB | 5.75 MB | 384 ms | 1.1 ms | 0.54 ms | 0.003 ms |
| C | **38.50 MB** | **8.07 MB** | **46.56 MB** | 3.14 s | **3.7 ms** | **0.55 ms** | 0.005 ms |

Prototype save/reload:

| Tier | Save | Reload | Prototype file |
|---|---:|---:|---:|
| A | 1.6 ms | 2.0 ms | 0.67 MB |
| B | 5.2 ms | 9.4 ms | 1.28 MB |
| C | 52.9 ms | 97.5 ms | **10.78 MB** |

## What was proven

- A hot index can resolve a mob by NPC ID without scanning all mobs.
- A selected zone can be decoded from one packed cold block.
- Zone listing uses metadata, not a mob scan.
- Tier C (100,000 mobs / 200 zones / 200 instances / 1.2M contexts) builds and
  retrieves correctly.
- No 2,000/40/100 global stop is needed in the design.
- Prototype save/reload preserves hot index and cold blocks.
- Checksums detect block corruption in the prototype.

## Limits

- The cold block codec is a placeholder varint format, not DS-7/DS-12 final.
- The prototype uses compact arrays and generated names; it is not the current
  production field shape.
- It measures hot/cold structural size and Lua heap, not client SavedVariables.
- Tooltip lookup tests the hot index; exact current-zone detail still requires
  decoding the selected block.
- No UI, events, migrations, or live-client timing.
- Tier C hot heap is large (38.5 MB); optimization is still open.

## Findings

1. **Hybrid retrieval works.** Tooltip lookup is O(1) in the hot index; selected
   zone decode is milliseconds; zone list is metadata-only.
2. **Cold blocks scale.** 100k mobs / 200 zones / 200 instances produced ~8 MB
   of packed cold data in the placeholder codec.
3. **Hot heap is the next cost.** 100k mobs cost ~38.5 MB in the prototype,
   mostly hot arrays/names. This needs a dedicated optimization study.
4. **Prototype save/reload is viable but not client-level.** 10.78 MB file,
   ~98 ms reload offline; final client timing is V-2.
5. **No full scan was required** for tooltip, zone list, or selected-zone decode.
6. **No arbitrary cap was required** to build tier C.

## New task required

**DS-4P-F1 — Hot-index memory optimization**

Evaluate:

- numeric/local IDs instead of repeated names in hot arrays;
- shared/static name dictionaries;
- array vs nested layouts;
- interning/name dedup;
- moving more names/detail cold;
- 10k/100k hot heap and lookup trade-offs.

Acceptance: no arbitrary MB target; measure hot heap, lookup latency, and
selected-zone decode; feed DS-17.5 schema.

## Follow-ups already covered

- **DS-7/DS-12** — final packed-block codec.
- **DS-15** — selected-zone cache/eviction and query APIs.
- **DS-16** — save/checkpoint policy.
- **DS-17.5** — final schema/migration.
- **V-2** — client SavedVariables/file timing.

No production code changed; only the prototype harness and docs.
