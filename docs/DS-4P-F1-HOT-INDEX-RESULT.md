# DS-4P-F1 — Hot-index memory result

**Status:** executed 2026-11-16  
**Harness:** `tests/ds4p_f1_hotindex.lua`  
**Scope:** hot-index representation only; cold blocks and selected-zone decode are
from DS-4P. No production schema.

## Variants

- **baseline:** per-character names + kills/XP/zone arrays + name index.
- **static:** per-character numeric arrays only; 90% shared names/index, 10%
  name-only names hot.
- **static_noidx:** shared names but no shared name→ID index.
- **interned:** per-character name-ID array + shared dictionary/index.
- **records:** per-character array of `{kills,xp,zone,name}` records.
- **stringkeys:** `hot["npc:<id>"] = {...}`.

## 10k mobs

| Variant | Hot heap | Shared heap | Total | Tooltip 10k |
|---|---:|---:|---:|---:|
| baseline | 2.41 MB | 0.00 MB | 2.41 MB | 3.17 ms |
| static | 0.88 MB | 1.60 MB | 2.48 MB | 3.71 ms |
| static_noidx | 0.82 MB | 0.67 MB | 1.49 MB | 3.28 ms |
| interned | 1.00 MB | 1.66 MB | 2.66 MB | 3.33 ms |
| records | 3.42 MB | 0.00 MB | 3.42 MB | 3.02 ms |
| stringkeys | 4.23 MB | 0.00 MB | 4.23 MB | 8.61 ms |

## 100k mobs

| Variant | Hot heap | Shared heap | Total | Tooltip 10k |
|---|---:|---:|---:|---:|
| baseline | **20.67 MB** | 0.00 MB | 20.67 MB | 3.48 ms |
| static | **7.67 MB** | 14.00 MB | 21.67 MB | 3.82 ms |
| static_noidx | **6.83 MB** | 6.00 MB | 12.84 MB | 3.30 ms |
| interned | 8.00 MB | 14.67 MB | 22.67 MB | 5.11 ms |
| records | 32.22 MB | 0.00 MB | 32.22 MB | 4.21 ms |
| stringkeys | 39.45 MB | 0.00 MB | 39.45 MB | 10.33 ms |

Save/reload was not repeated for each hot variant. DS-4P covers the hybrid
cold-block save/reload; F1 only changes the hot representation and the shared
name dictionary.

## Findings

1. **Static metadata cuts per-character hot memory sharply.**
   - baseline 20.67 MB → static 7.67 MB hot at 100k;
   - about 63% lower per-character hot heap.
2. **The shared name index is expensive.** Static total is 21.67 MB because the
   shared name→ID index costs ~8 MB. Without that index, total is 12.84 MB.
3. **A full name index is not needed for NPC-ID lookup.**
   - Tooltip by `npcID` is direct.
   - Name fallback is needed only for name-only/ambiguous mobs.
   - Build/retain the name index for that smaller set, not all 100k static mobs.
4. **Interned name IDs are worse than static names.** They add a per-character
   ID array and a shared dictionary; 22.67 MB total vs static 21.67 MB.
5. **Record tables and string keys are much worse.**
   - records: 32.22 MB hot;
   - string keys: 39.45 MB hot and slower.
6. **Latency stays acceptable.** Tooltip 10k lookups remain 3–5 ms offline; no
   full scan. The static_noindex case is fastest because it avoids the name map.
7. **The best hot shape is numeric arrays + shared names + a lazy/scoped name
   index**, not per-character names and not a global name index for every mob.

## Decision

Adopt for schema/prototype input:

- per-character hot index: numeric arrays for counts/XP/zone/refs;
- shared static name dictionary keyed by `npcID`;
- name→ID index only for name-only/ambiguous mobs, built lazily or scoped;
- no per-character copy of static names;
- no string-keyed record tables;
- no global name index for all static NPCs.

This keeps the per-character hot heap near 7–8 MB for 100k mobs, with the shared
dictionary separate and reusable across characters. It is a measured result, not
an MB target.

## New task required

**DS-4P-F2 — Scoped/lazy name index**

- build name→ID only for name-only/ambiguous/non-static mobs;
- resolve static names by `npcID`;
- verify name fallback for name-only mobs and no full scan;
- verify 10k/100k hot heap and lookup;
- keep the static dictionary shared and versioned.

## Follow-ups

- DS-6 static metadata source/size/licensing.
- DS-7/DS-12 final cold-block codec.
- DS-15 retrieval/cache.
- DS-16 save/checkpoint.
- DS-17.5 schema/migration.

No production code changed; prototype only.
