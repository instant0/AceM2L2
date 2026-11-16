# DS-7 + DS-12 — Packed block codec

**Status:** executed 2026-11-16  
**Result:** `docs/DS-7-12-PACKED-BLOCK-CODEC-RESULT.md`  
**Harness:** `tests/ds7_codec.lua`  
**Depends on:** DS-6, DS-4P, DS-17.3  
**Blocks:** DS-9, DS-13, DS-14, DS-15, DS-16, DS-17.5

## Why

DS-6 was revised after review:

- do not ship a list of all names; names are learned live;
- mobs are localized to zones/instances/grid-refs, not present in every grid of
  every zone/continent;
- cold history is therefore a set of per-zone/per-instance blocks, not a global
  all-mob matrix.

DS-4P showed the cold zone/level tier is required and can be decoded per selected
zone without a full scan. DS-7/DS-12 choose one codec for cold history and the
optional static locality data.

## Scope

One packing study and one codec decision. Do not implement production schema
yet.

### Required properties

- One block per zone/instance (and level band where needed), not a global
  all-mob table.
- Sparse numeric NPC IDs; no contiguous-ID or stride assumption.
- Sparse cells; adaptive dense/sparse/bitset cell encoding where measured.
- Per-block decode; no full-table decode for a tooltip or one selected zone.
- No inline names in cold blocks. Names resolve from the live account-wide name
  cache; missing names fall back to `NPC <id>`.
- Optional spawn/locality metadata is separate and scoped by
  zone/instance/grid; the codec must not depend on it.
- Contexts collapse for cold blocks (DS-17.3); 4/8/12 contexts are measured to
  choose the cold limit.
- Checksums per block or payload.
- Version/schema/project/interface/build metadata.
- Deterministic output.
- Lua 5.1-compatible encode/decode (no `string.pack`).
- The payload ships as a Lua string literal; no file I/O.

### Compare

1. **Cell encoding:** dense, sparse delta, bitset, adaptive hybrid.
2. **Block index:** global block index vs per-block offset/length.
3. **IDs:** varint deltas vs fixed-width.
4. **Contexts:** 4/8/12; cold collapse vs full.
5. **Checksum:** per block vs whole payload; cost.
6. **Block size:** one zone/instance vs grid/level sub-blocks.
7. **Corruption:** bad magic/version/hash/length; truncated payload.
8. **No names:** confirm cold blocks have zero name bytes.

## Test profiles

- 10k / 100k / 350k mobs;
- 200 zones / 200 instances;
- contexts 4 / 8 / 12;
- grids 64 / 32 / 16;
- cell densities 5% / 15% / 30%;
- per-character metadata registry: local sample, 10k / 100k entries;
- save/reload and encode/decode round-trip.

Measure:

- cold bytes and escaped-source bytes;
- encode/decode time;
- selected-block decode time;
- Lua heap after load and after one-block decode;
- checksum cost;
- name-cache heap/lookup/fallback;
- corruption/truncation detection;
- diff size between adjacent saves.

## Acceptance

- One codec is selected with measured size/CPU, not an arbitrary target.
- Sparse IDs, per-zone/instance blocks, and per-block decode work.
- Cold blocks store no inline names.
- Cell encoding is adaptive or the choice is explained by measurements.
- Context cold limit is justified.
- Version/checksum/corruption behavior is defined.
- Lua 5.1/LuaJIT behavior is verified (or the gap is recorded).
- No third-party codec/database is copied.
- DS-13/DS-15/DS-16/DS-17.5 can proceed.

## Output

- `docs/DS-7-12-PACKED-BLOCK-CODEC-RESULT.md`
- `tests/ds7_codec.lua`
- codec encode/decode prototype functions
- version/checksum/corruption test table
- recommended block size, cell encoding, and context cold limit

## Not required

- production schema or migration;
- live client test (V-2);
- UI work;
- the final companion package (DS-13).
