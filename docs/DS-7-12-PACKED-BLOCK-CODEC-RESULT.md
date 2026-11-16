# DS-7 + DS-12 — Packed block codec result

**Status:** executed 2026-11-16  
**Harness:** `tests/ds7_codec.lua`  
**Scope:** cold-history/static-locality block codec. Offline prototype; not
production schema. No names are shipped or embedded.

## Review context

DS-6 was revised after review:

- do not ship a list of all names; names are learned live;
- mobs are localized to zones/instances/grid-refs, not present in every grid of
  every zone/continent;
- cold history is a set of per-zone/per-instance blocks, not a global all-mob
  matrix.

The codec below therefore stores **no names**. Stable `npc:<id>` metadata is
account-wide; name-only metadata is per character. A miss displays `NPC <id>`.
The registry also holds the fixed level range and at most four zone/instance
refs, so no separate spawn index is required.

## Test model

- 100k mobs (10k and 350k stress profiles);
- 80% open-world across 200 zones, 20% across 200 instances;
- one block per zone/instance (plus a 350k sub-block profile); each mob belongs
  to exactly one block, so there is no mobs × zones × grids cross-product;
- sparse NPC IDs (`100000 + index * 7 + index % 3`);
- 64/32/16 grids; 5% is near the local sparse baseline, 15%/30% are stress
  profiles;
- 4/8/12 contexts per mob;
- level counts and top-N entries per block;
- metadata registry separate: account-wide stable `npc:<id>` + per-character
  name-only (local sample: 158 entries).

No block stores a name. `cold_inline_names=0` is by construction. Cold blocks
remain per-character and generation/mode-separated; stable metadata is shared
account-wide, name-only metadata is per character, and neither is raw history.

Sizes and heap are deterministic for a given profile. Single-run CPU timings
vary between runs; the tables show representative values, and every conclusion
below is based on the size/decoded-cost direction, not a single millisecond.

## Codec variants

| Variant | Cells | IDs | Names | Checksum |
|---|---|---|---|---|
| plain | Lua tables | n/a | none | no |
| varint_dense | every grid cell written | varint delta | none | per block |
| varint_sparse | sparse delta cells | varint delta | none | per block |
| bitcells_sparse | bitset + set-cell counts | varint delta | none | per block |
| hybrid_cells | per-block sparse or bitset | varint delta | none | per block |

## 100k mobs, 200 zones/200 instances, 64 grid, 15%, 4 contexts

| Variant | Cold bytes | Cold MB | Heap | Encode | Selected decode |
|---|---:|---:|---:|---:|---:|
| plain | 0 | 0 | **175.42 MB** | 0 | 1.75 ms/10k |
| varint_dense | 5,280,546 | 5.04 | 5.17 MB | 2.44 s | 2.50 ms |
| varint_sparse | 4,133,346 | 3.94 | 4.07 MB | 1.94 s | 4.13 ms |
| bitcells_sparse | 4,092,546 | 3.90 | 4.03 MB | 1.68 s | 4.25 ms |
| **hybrid_cells** | **4,092,546** | **3.90** | **4.03 MB** | **1.93 s** | **4.45 ms** |

Plain tables are not viable. Dense cells add ~1.15 MB. Sparse/bit/hybrid are
close; hybrid picks the smaller cell form per block.

## 100k mobs, 12 contexts

| Variant | Cold MB | Heap | Encode | Selected decode |
|---|---:|---:|---:|---:|
| plain | 0 | **431.77 MB** | 0 | 0 |
| varint_dense | 10.32 | 10.47 MB | 4.72 s | 7.06 ms |
| varint_sparse | 9.23 | 9.38 MB | 4.29 s | 7.58 ms |
| bitcells_sparse | 9.19 | 9.34 MB | 4.83 s | 6.81 ms |
| **hybrid_cells** | **9.19** | **9.34 MB** | **4.77 s** | **7.10 ms** |

Contexts dominate cold size: 4 = 3.90 MB, 8 = 6.54 MB, 12 = 9.19 MB at 100k.
Cold blocks should keep a collapsed context set (4), not 8/12.

## Cell density and grid

100k mobs, 4 contexts, 64 grid:

| Density | varint_sparse | bitcells_sparse | hybrid_cells |
|---:|---:|---:|---:|
| 5% | **3.63 MB** | 3.75 MB | **3.63 MB** |
| 15% | 3.94 MB | **3.90 MB** | **3.90 MB** |
| 30% | 4.41 MB | **4.14 MB** | **4.14 MB** |

100k mobs, 4 contexts, 15% density:

| Grid | hybrid cold |
|---:|---:|
| 64 | 3.90 MB |
| 32 | 3.58 MB |
| 16 | 3.50 MB |

Hybrid matches the better cell form at every measured density. At very low
density it uses sparse; at 15%+ it uses bitset.

## Scale and block size

| Profile | Cold MB | Heap | Encode | Selected block decode |
|---|---:|---:|---:|---:|
| 10k / 40 zones / 100 inst / 8 ctx | 0.76 | 0.82 MB | 0.39 s | 1.18 ms |
| 100k / 200 / 200 / 4 ctx | 3.90 | 4.03 MB | 1.86 s | 2.67 ms |
| 100k / 200 / 200 / 8 ctx | 6.54 | 6.70 MB | 3.04 s | 3.75 ms |
| 100k / 200 / 200 / 12 ctx | 9.19 | 9.34 MB | 4.53 s | 5.30 ms |
| 350k / 200 / 200 / 4 ctx | 12.56 | 12.71 MB | 6.20 s | 10.31 ms |
| 350k / ~800 zone blocks / 4 ctx | 13.22 | 13.60 MB | 6.65 s | **2.55 ms** |

A 350k-mob zone block (~1,400 mobs) decodes in ~10 ms. Splitting into ~350-mob
level-band/sub-blocks restores ~2.5 ms selected-block decode for ~5% more cold
bytes. **Use per-zone/level-band sub-blocks of roughly 256-512 mobs; do not put a
whole 1,400-mob zone in one block.**

The 10k plain baseline is 33.38 MB; the packed version is 0.76 MB.

## Storage encoding

Cold blocks must survive SavedVariables serialization. Raw binary in a Lua
string is escaped; base64 is smaller but needs a decode step.

100k/4 profile:

| Encoding | Bytes | MB | Cost |
|---|---:|---:|---:|
| raw cold | 4,092,546 | 3.90 | — |
| escaped Lua string (`%q` estimate) | 7,825,084 | 7.46 | — |
| base64 | 5,456,728 | 5.20 | 0.77 s encode / 1.38 s full decode |
| per-block base64, first block | 20,900 | 0.02 | 3.76 ms decode |

100k/12 and 350k/4 (base64 size computed; round-trip verified at 100k/4):

| Profile | Raw MB | Escaped MB | Base64 MB | First block base64 | Block decode |
|---|---:|---:|---:|---:|---:|
| 100k/8 | 6.54 | 12.40 | 8.72 | 35,652 B | 6.24 ms |
| 100k/12 | 9.19 | 17.38 | 12.25 | 50,468 B | 10.36 ms |
| 350k/4 one-zone block | 12.56 | 23.62 | 16.74 | 69,288 B | 13.08 ms |
| 350k/4 ~350-mob sub-block | 13.22 | 25.12 | 17.63 | 18,476 B | 3.55 ms |

**Decision: per-block base64 in SavedVariables, decoded lazily for the selected
block.** Escaped raw is ~1.9× the raw size; base64 is ~1.33×. Full base64 decode
of 3.9 MB raw costs 1.38 s, so do not decode the whole payload at load.

For addon-shipped optional spawn/locality data (not names), a raw long-bracket
string can be used because it is not reserialized by SavedVariables; that is a
packaging choice, not the cold-history path.

## Name-only probe (superseded by DS-6-F1)

Names are not in cold blocks. This section was a name-only probe; DS-6-F1 later
replaced it with the metadata registry (account-wide stable `npc:<id>` +
per-character name-only; name + fixed level range + ≤4 zone refs).

| Seen names | Map heap | Lookup 10k | Missing fallback |
|---:|---:|---:|---|
| 10k | 0.95 MB | 0.23 ms | `NPC <id>` |
| 100k | 8.33 MB | 0.25 ms | `NPC <id>` |

DS-6-F1 registry numbers are the current decision: local 158 entries 0.05 MB;
10k entries 4.11 MB map / 0.43 MB packed; 100k 38.25 / 4.32 MB. Do not ship the
list.

## Checksum and corruption

- Per-block checksum detects a flipped byte.
- Truncated blocks fail varint parsing and are rejected.
- Bad schema/version is rejected.
- A rejected block must leave the previous backup intact; it must not silently
  drop history.

The prototype checksum is a full-byte second pass: 0.17 s at 100k/4, 0.56 s at
350k/4. Compute it during encode, or use a faster checksum, rather than a second
pass.

## Findings

1. **Plain Lua tables are rejected.** 175 MB at 100k/4 and 432 MB at 100k/12.
2. **Hybrid cell encoding wins.** Sparse at 5%, bitset at 15%/30%; hybrid matches
   the better form per block. Local heatmap occupancy is only 4.5–4.8%, so 5%
   is closer to normal and 15%/30% are stress profiles.
3. **No inline names.** Cold blocks contain IDs only; account metadata is
   0.02 MB for the local 100 stable NPCs and 2.38 MB at 10k stable entries
   (0.42 MB packed); name-only is per character.
4. **Contexts dominate.** 4 = 3.90 MB, 8 = 6.54 MB, 12 = 9.19 MB at 100k.
   Cold blocks should keep 4 or collapsed summaries.
5. **Block size matters.** One 1,400-mob zone block decodes ~10 ms; ~350-mob
   sub-blocks decode ~2.5 ms.
6. **Base64 is the right SavedVariables encoding.** ~1.33× vs ~1.9× for escaped
   raw; decode per block, not the whole payload.
7. **Locality is the index.** 200 zones/200 instances = 400 blocks; a tooltip or
   zone view touches one block. No global all-mob/all-grid matrix.
8. **Prototype encode is slow.** 1.9-6.2 s for 100k-350k. Production needs
   dirty-block/incremental encoding; do not encode everything on every kill.
9. **Checksum/truncation behavior works.** Keep the previous backup on failure.
10. **No third-party codec/database.** The codec is pure Lua and 5.1-compatible.

## Decision

Adopt:

- **hybrid_cells** block codec:
  - varint fields and delta IDs;
  - adaptive sparse/bitset cell encoding;
  - per-block checksum;
  - no inline names;
  - version/header per block.
- **Block key:** project/interface, block kind (zone/instance), block ID, level
  band/sub-block, grid, schema, context count, checksum.
- **Block size:** target ~256-512 mobs; split a large zone by level band or
  sub-block.
- **Cold contexts:** 4, or collapsed summaries; 8/12 remain hot/active only.
- **Storage:** per-block base64 in SavedVariables; lazy decode; raw long-bracket
  only for optional addon-shipped locality data.
- **Names:** account-wide stable `npc:<id>` + per-character name-only metadata;
  `NPC <id>` fallback; no shipped list.
- **Locality:** per-zone/instance blocks; the registry holds at most 4 learned
  zone/instance refs; a pre-kill spawn index is deferred and not required.
- **Save:** incremental dirty-block encoding, checksum during encode, previous
  backup retained.
- **Retrieval:** decode/cache the selected block; no full payload decode.
- **No arbitrary global cap.**

## Acceptance

- One codec selected with measured size/CPU: **yes**.
- Sparse IDs, per-zone/instance blocks, per-block decode: **yes**.
- Cold blocks store no inline names: **yes**.
- Cell encoding adaptive and measured: **yes**.
- Cold context limit justified: **yes** (4).
- Version/checksum/corruption behavior defined: **yes**.
- Lua 5.1/JIT: code is 5.1-compatible; only Lua 5.3.6 measured; gap recorded.
- No third-party codec/database: **yes**.
- DS-13/DS-15/DS-16/DS-17.5 can proceed: **yes**.

## Follow-ups

- **DS-6-F1 — Mob metadata registry.** Done 2026-11-16. Result:
  `docs/DS-6-F1-MOB-METADATA-REGISTRY-RESULT.md`.
- **DS-15 — Lazy retrieval/cache.** Selected-block decode, base64 lazy decode,
  name-cache lookup, block cache.
- **DS-16 — Save/checkpoint.** Incremental dirty-block encode, checksum during
  encode, backup/oversize recovery.
- **DS-13 — Packaging.** Optional scoped spawn/locality data; no all-name list.
- **DS-17.5 — Schema/migration.** Block metadata and name-cache version.
- **V-2 — Live check.** SavedVariables serializer size, Lua 5.1/JIT behavior,
  name-cache coverage, selected-zone latency.

## Artifacts

- `tests/ds7_codec.lua`
- `docs/DS-6-STATIC-METADATA-RESULT.md` (revised)
- `docs/DS-4P-HYBRID-PROTOTYPE-RESULT.md`
- `docs/DS-17-3-RETENTION-DECISION.md`

No production code changed.
