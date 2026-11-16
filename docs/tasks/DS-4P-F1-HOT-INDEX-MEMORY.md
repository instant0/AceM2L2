# DS-4P-F1 — Hot-index memory optimization

**Status:** executed 2026-11-16  
**Result:** `docs/DS-4P-F1-HOT-INDEX-RESULT.md`  
**Depends on:** DS-4P, DS-1-F2  
**Blocks:** DS-17.5 schema, DS-15 retrieval

## Why

DS-4P tier C measured **38.5 MB hot Lua heap** for 100,000 mobs, 200 zones,
200 instances, 1,000 cells/zone, and 12 contexts/mob. The hybrid retrieval works,
but the hot index is the largest cost.

This is not an arbitrary MB target. The goal is the smallest correct hot index
that keeps tooltip and zone retrieval fast.

## Questions

1. How much hot memory is from names vs counts vs tables?
2. Can static metadata resolve names from `npcID` so hot data stores IDs only?
3. Can names be interned/shared without a full scan?
4. Are arrays of numeric IDs cheaper than string-keyed nested tables?
5. What detail must stay hot for tooltip/current-zone lookup?
6. What can move cold with no retrieval regression?
7. Does name-only/ambiguous identity need a hot name index at all?
8. What is the selected-zone decode/lookup cost after each change?

## Variants

1. **Baseline:** per-character names + kills/XP/zone arrays + name index.
2. **Static metadata:** per-character numeric arrays only; shared name dictionary
   and name index.
3. **Static without name index:** same, but no name→ID map.
4. **Interned names:** per-character name-ID array + shared dictionary/index.
5. **Record tables:** per-character array of `{kills,xp,zone,name}` records.
6. **String-keyed records:** `hot["npc:<id>"] = {...}`.

Measure per-character hot heap and shared/static heap separately. Use the DS-4P
cold blocks for selected-zone decode; F1 changes only the hot index.

## Test profiles

- 10k and 100k mobs;
- 200 zones;
- 10% name-only mix for static variants;
- tooltip by NPC ID and name fallback;
- zone list/global summary.
- No 4/8/12 context matrix here; contexts are cold in DS-4P.

Measure:

- hot Lua heap;
- cold bytes;
- tooltip lookup;
- selected-zone decode;
- zone/instance list;
- save/reload.

## Acceptance

- Hot heap is materially reduced versus the DS-4P baseline at 100k mobs.
- Tooltip and selected-zone retrieval do not regress.
- Per-character and shared memory are reported separately.
- No full scan.
- No fake identity or checksum identity.
- No arbitrary global cap.
- Results feed DS-17.5/DS-15.

## Not required

- live client test;
- final codec;
- production schema;
- UI changes.
