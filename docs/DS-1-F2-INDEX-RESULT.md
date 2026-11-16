# DS-1-F2 — In-memory identity and query indexes result

**Status:** executed 2026-11-16; tested  
**Task:** `docs/tasks/DS-1-FOLLOWUP-TASKS.md`  
**Files changed:** `KillHistory/Data.lua`, `KillHistory/Tracking.lua`,
`KillHistory/Commands.lua`, `tests/smoke.lua`

## What was implemented

Derived, in-memory indexes:

- `npcID -> mobKey` (`byNpc`);
- normalized name -> NPC keys plus all keys (`byName`);
- `mapID -> mobKeys` (`byZone`);
- `instanceKey -> mobKeys` (`byInstance`).

Public helpers:

```lua
XPTooltip:FindNPCKeyByName(name)
XPTooltip:GetMobKey(name, npcID)
XPTooltip:GetMobKeyByNpcID(npcID)
XPTooltip:GetMobKeysForMap(mapID)
XPTooltip:GetMobKeysForInstance(instanceKey)
XPTooltip:InvalidateMobIndex()
```

`FindNPCKeyByName` no longer scans every mob. It resolves from the name index;
ambiguous names still return `nil` and fall back to a `name:` key.

## Invalidation

The index is rebuilt on demand after:

- character load / `EnsureDB`;
- a new mob;
- an NPC ID or name change;
- a name-only/NPC merge;
- mob deletion;
- prune/remove;
- reset.

The normal kill path updates zone/instance links incrementally when the index is
already built. If not built, the next query builds it from canonical data.

The index is stored on the module, **not** in SavedVariables.

## Tests

Added smoke assertions for:

- NPC-index lookup;
- unique-name lookup;
- name-only fallback;
- ambiguous-name fallback;
- multi-zone mob membership (same mob in map 12 and 13);
- incremental zone-link update after the index is already built;
- instance membership;
- index refresh after deletion.

Full offline suite passes:

- Forever, Midnight, missing APIs, secret identity, secret booleans, secret
  name, unknown;
- embedded libraries;
- layout/syntax checks;
- no LuaJIT present, so that leg was skipped.

## Result

- Tooltip name fallback is now index-based instead of an all-mob scan.
- Zone/instance query APIs are ready for the Mobs list/Areas work.
- No schema or SavedVariables field was added.
- No per-kill event log was added.
- Index rebuild is O(mobs) only when invalidated; queries are direct.

## Follow-ups

- Wire the zone index into a zone-filtered Mobs list when that UI exists.
- Consider using the instance index in Areas/Detail.
- The heatmap already uses map-keyed data; no extra heatmap index is needed.
