# HIST-1A — Historical relevance and tooltip/Detail result

**Status:** executed 2026-11-17  
**Production modules:** `KillHistory/Data.lua`,
`KillHistory/Tooltip.lua`, `KillHistory/UI/Detail.lua`  
**Test:** `tests/historical_relevance.lua`; `./tests/run_all.sh`  
**Scope:** level-based active/historical presentation. No schema change.

## 1. Relevance classifier

Added:

- `GetMobLevelRange(mob, unitLevel)`
- `GetMobRelevance(mob, unitLevel, playerLevel)`

Rules:

- content level comes from:
  - observed `UnitLevel`;
  - block `mobLevelMin`/`mobLevelMax`;
  - recorded context `mobLevel`;
- `historical` when `playerLevel > maxContentLevel + 5`;
- otherwise `active`;
- unknown content level defaults to `active` rather than hiding XP.

Age is not used for relevance. Level is the primary signal.

## 2. Historical tooltip

Shows:

- kill count;
- classification/type;
- first seen;
- last seen;
- top area.

Omits:

- XP estimate;
- kills-to-level;
- XP remaining;
- context/this-level kills;
- rested/bonus lines.

Adds:

```text
Historical content: XP lines omitted.
```

## 3. Historical Detail

Shows:

- total kills;
- mob level range where known;
- top area;
- historical player-level range;
- first/last seen;
- block-fallback note when applicable;
- explicit historical marker.

Omits:

- session kills;
- average base/total XP;
- active XP context.

## 4. Active behavior

Within the content band, existing behavior is unchanged:

- normal XP estimate;
- XP remaining;
- kills-to-level;
- session/XP Detail.

## 5. Tests

`tests/historical_relevance.lua` verifies:

- level 60 vs level-10 mob → historical;
- historical tooltip has kills/last-seen and no XP;
- historical Detail has no session/XP;
- level 12 vs level-10 mob → active;
- active tooltip/Detail retain XP.

Passing output:

```text
Historical relevance passed
```

`./tests/run_all.sh` passes.

## 6. Limitations

- No historical zone panel yet.
- No rare/death/quest-anchor filtering yet.
- No account Knowledge.
- Unknown mob levels default to active.
- Quest completion history still only has the last anchor.

## 7. Next

**HIST-1B — Historical zone surfaces.**

## Artifacts

- `KillHistory/Data.lua`
- `KillHistory/Tooltip.lua`
- `KillHistory/UI/Detail.lua`
- `tests/historical_relevance.lua`
- `tests/run_all.sh`
- `docs/tasks/HIST-1-HISTORICAL-RELEVANCE.md`
