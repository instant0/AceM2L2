# IMP-1B5 — Tooltip/Detail block fallback result

**Status:** executed 2026-11-16  
**Production modules:** `KillHistory/Tooltip.lua`,
`KillHistory/UI/Detail.lua`, `KillHistory/JourneyStorage.lua`  
**Test:** `tests/tooltip_fallback.lua`; `./tests/run_all.sh`  
**Scope:** legacy-first, block-fallback single-entry reads with call budget.
No list/overview switch, no UI redesign, no merge.

## 1. Tooltip behavior

- Legacy `db.mobs[mobKey]` remains first.
- If missing, one block/Journey lookup is attempted:
  - current `map:<id>` zone first;
  - then the compact mob→zone index.
- Block fallback shows:
  - name / NPC ID / classification;
  - total kills;
  - mob level range where available.
- Block fallback does **not** show:
  - “this level” kills;
  - session kills;
  - exact context XP;
  - total XP.

No false zeros.

## 2. Detail behavior

- Legacy mob record remains first.
- If missing, block fallback shows:
  - name / classification / NPC ID;
  - total kills;
  - mob level range where available;
  - an explicit “Block detail: session/area/XP context unavailable” note.
- Unavailable fields are not rendered as zero.

## 3. Call budget

Tested with `journeyDecodedBlocks`:

| Case | Block decodes |
|---|---:|
| Legacy tooltip hit | **0** |
| Cold block tooltip | **1** |
| Repeated tooltip / cache hit | **0 additional** |
| Rollback flag off | **0** |

No best-zone, heatmap, list, or detail query is called from the tooltip.
No block build/flush occurs during a tooltip.

## 4. Rollback

- `journey.blockReadFallback` defaults to true.
- Setting it false disables block fallback for tooltip/Detail.
- Legacy data remains authoritative.
- No legacy deletion.

## 5. Tests

`tests/tooltip_fallback.lua` verifies:

- legacy tooltip has kills and “this level”;
- legacy path decodes 0 blocks;
- block tooltip has total kills but no fake “this level”;
- cold block decodes once;
- cached tooltip does not decode again;
- Detail block fallback shows the block note;
- rollback disables block decode.

Passing output:

```text
Tooltip/Detail fallback passed
```

`./tests/run_all.sh` passes.

## 6. Limitations

- Block records do not yet contain `killsAtLevel`, session kills, contexts, or
  full Detail fields.
- Tooltip fallback is less detailed than legacy.
- Detail fallback is explicitly partial.
- Mobs/Areas/Levels lists, Overview, commands, and heatmap UI still use legacy
  data.
- Legacy data still duplicates block data.
- No account Knowledge/merge.

## 7. Next

**IMP-1B6 — Journey mob index and list/overview switch.**

- compact global Journey mob index;
- list/overview/area/level queries;
- switch views behind flags;
- retain legacy rollback;
- no account Knowledge/merge or UI redesign.

## Artifacts

- `KillHistory/Tooltip.lua`
- `KillHistory/UI/Detail.lua`
- `KillHistory/JourneyStorage.lua`
- `tests/tooltip_fallback.lua`
- `tests/run_all.sh`
- `docs/IMP-1B4-SAVE-GUARD-RESULT.md`
