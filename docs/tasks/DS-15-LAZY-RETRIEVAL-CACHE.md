# DS-15 — Lazy retrieval, zone-scoped queries, and cache

**Status:** pending; blocked by DS-17.4A/B/C and DS-17.5  
**Depends on:** DS-17.5, DS-7/DS-12, DS-17.3, DS-17.4A/B  
**Blocks:** DS-16, DS-11

## Why

The codec and model need a retrieval layer:

- per-character Journey blocks;
- account-wide Knowledge target;
- tooltip, danger, best zone, heatmap;
- no full scan.

## Scope

- Decode only the selected zone/instance/level block.
- Base64-decode only that block; no whole-payload decode.
- Resolve a block's mob key through:
  - current character Journey;
  - account-wide stable metadata/Knowledge;
  - `NPC <id>` fallback.
- Tooltip:
  - current mob stats from Journey;
  - danger by combat context;
  - XP by XP context;
  - account Knowledge if available.
- Best zone:
  - current level;
  - XP/hour from zone/level XP and active time;
  - confidence/samples;
  - “not enough data” fallback.
- Heatmap best part:
  - top cells by density/XP/hour;
  - current character overlay optional.
- Bounded block cache/LRU.
- Invalidate on save, rename, level/zone change, character switch.
- Missing/corrupt block or metadata behavior.
- No per-zone SavedVariables files.

## Test profiles

- 10k/100k/350k cold mobs;
- 200 zones/200 instances;
- ~256–512-mob blocks;
- 64/32/16 grids;
- 4 cold contexts;
- account metadata/Knowledge 0/10k/100k;
- base64 lazy decode;
- cache hit/miss;
- missing/corrupt.

Measure:

- selected-block and base64 decode;
- tooltip/danger/best-zone/heatmap query latency;
- cache hit rate/memory;
- no full scan;
- fallback correctness;
- save/reload.

## Acceptance

- Only the relevant block is decoded.
- No full payload decode or global scan.
- Tooltip/danger/best-zone/heatmap use Journey + Knowledge correctly.
- Missing data yields a safe fallback.
- Cache is bounded and invalidates correctly.
- DS-16/DS-11 can proceed.

## Not required

- UI redesign;
- merge implementation;
- account-wide writes;
- route recommendation;
- live client test.
