# IMP-1B5 — Tooltip/Detail block fallback and rollback

**Status:** executed 2026-11-16  
**Result:** `docs/IMP-1B5-TOOLTIP-FALLBACK-RESULT.md`  
**Harness:** `tests/tooltip_fallback.lua`  
**Depends on:** IMP-1B4, IMP-1B3, DS-15, DS-16  
**Blocks:** IMP-1B6, V-2, UI

## Why

Block storage and save guards work, but the UI still reads legacy data. A full
list/overview switch is not safe yet because those views iterate every mob and
need a normalized Journey mob index. The safe first step is single-entry reads.

## Scope

### Switch

- Tooltip single-mob lookup:
  - legacy `db.mobs[mobKey]` first;
  - block/Journey fallback if legacy entry is missing;
  - `NPC <id>`/no-data fallback if both miss.
- Mob Detail single-entry view:
  - same legacy-first, block-fallback order;
  - block fallback is partial until block records carry more fields.

### Field safety

Current block records contain:

- key, NPC ID, name, classification;
- total kills, total XP;
- mob level range.

They do **not** contain:

- session kills;
- kills-at-player-level;
- contexts/XP samples;
- model/instance detail beyond the mob identity.

So:

- `killsAtLevel` is displayed in the tooltip. Block fallback must either:
  - include a compact per-level kills map; or
  - suppress the “this level” suffix when it is unavailable.
  Do not show zero.
- Total XP and session kills are not displayed by the tooltip and must not be
  fetched/queried just to fill a line.
- Detail fallback must mark unavailable sections or stay legacy-only until the
  block record is expanded.
- Keep the legacy path active; no deletion.

### Do not switch yet

- Mobs list.
- Areas/Levels list.
- Overview.
- Commands that iterate all mobs/areas/levels.
- Heatmap list/rendering.

These need a global Journey mob index and query layer; that is IMP-1B6.

### Rollback

- Add a read-mode flag, e.g. `journey.blockReadFallback = true`.
- Legacy remains authoritative and can be used without block decode.
- If block decode/checksum fails, fall back to legacy/no data.
- No legacy data deletion in this task.

## Tooltip information inventory

### Required for the tooltip

| Field | Source | Block fallback |
|---|---|---|
| unit name / GUID / NPC ID | client | same client values |
| total kills | legacy mob or block | block `kills` |
| kills at current player level | legacy `killsAtLevel` | **not in block yet — full-parity decision required** |
| raw mob level | `UnitLevel` | same client value |
| player level / XP state | client | same client values |
| XP estimate | existing formula/calibration | existing formula if no context |
| exact per-context XP | legacy `mob.contexts` | optional; formula fallback is acceptable |
| total XP | legacy or block | **not displayed by the tooltip** |
| session kills | legacy | **not displayed by the tooltip** |

### Not needed by the tooltip

- session kills;
- full context tables;
- XP samples;
- best zone;
- heatmap cells;
- list/overview data;
- quest summaries;
- model/detail-only fields.

Do not fetch or decode these for a tooltip.

## Tooltip call budget

Per tooltip invocation:

| Case | Mob lookup | Block decodes | Full scans |
|---|---:|---:|---:|
| Legacy mob exists | 0 Journey calls | 0 | 0 |
| Legacy miss, block cached | 1 lookup | 0 | 0 |
| Legacy miss, block cold | 1 lookup | **1 normal target** | 0 |
| Current-zone block miss/corrupt | 1 lookup + fallback | ≤4 zone attempts max | 0 |
| No legacy/block | 1 lookup | 0–1 | 0 |

Rules:

- Try the current zone block first when available.
- Never decode all zone blocks.
- Never build/flush blocks during a tooltip.
- Never call best-zone, heatmap, list, or detail queries from a tooltip.
- Cache the decoded block and reuse it.
- If block fields are unavailable, show only fields that exist; do not render
  false zeros for `killsAtLevel`, session kills, or exact XP context.

## Tests

- Tooltip output identical when legacy data exists.
- Tooltip block fallback when legacy mob is absent.
- Detail block fallback when legacy mob is absent.
- Corrupt/missing block falls back safely.
- Rollback flag disables block fallback.
- Tooltip call budget:
  - legacy hit decodes 0 blocks;
  - cold block hit decodes 1 block;
  - repeated tooltip decodes 0 additional blocks;
  - no best-zone/heatmap/list query is called;
  - no block build/flush occurs.
- Existing smoke/query/storage/save-guard tests remain green.
- No full decode at login; no full scan.

## Acceptance

- Single-entry tooltip/detail can be served from blocks when legacy is absent.
- Legacy remains authoritative by default.
- Rollback flag works.
- No list/overview/commands switch.
- No data deletion.
- No full decode/scan.
- No account Knowledge/merge/UI redesign.

## Not required

- global mob index;
- list/overview switch;
- heatmap UI;
- account Knowledge/merge;
- live client test.
