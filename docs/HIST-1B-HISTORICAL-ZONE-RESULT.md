# HIST-1B — Historical Area Detail overlays result

**Status:** executed 2026-11-17  
**Production modules:** `KillHistory/UI/Detail.lua`,
`KillHistory/UI/Window.lua`, `Core/Defaults.lua`  
**Test:** `tests/historical_zone.lua`; `./tests/run_all.sh`  
**Scope:** selected Area Detail overlays only. No new tab, schema, or capture
format.

## 1. Overlay toggle row

Added a compact row in Area Detail:

```text
[Deaths] [Rares] [Quests] [Heatmap]
```

- Buttons appear only on the Areas tab.
- Pushed state reflects the persisted setting.
- Clicking a button updates the Detail immediately.
- Settings persist under `ui.historyOverlays`.
- Defaults for all four are on.
- Toggling affects presentation only; stored data is untouched.

## 2. Area sections

For the selected area:

### Notable deaths
- filters `db.deaths` by map;
- newest entries first;
- age and coordinates;
- capped at 3.

### Rare/elite mobs
- filters `elite`, `rare`, `rareelite`, `worldboss`;
- uses the Journey mob index when available;
- top 3 by kills in that map.

### Latest quest anchors
- filters quests by recorded `mapID`;
- sorts by `lastTurnInAt`;
- top 3;
- labeled “Latest quest anchors”, not a full journey.

### Heatmap summary
- metadata/legacy summary only;
- cell count and kill total;
- no block decode.

## 3. Tests

`tests/historical_zone.lua` verifies:

- deaths/rares/quests/heatmap sections appear for the selected area;
- another area does not leak records;
- each toggle hides only its section;
- settings persist;
- the toggle row is Areas-only;
- historical Area Detail adds no XP claims;
- no block decode is needed.

Passing output:

```text
Historical zone passed
```

`./tests/run_all.sh` passes.

## 4. Limitations

- Quest sections only use the latest anchor, not full completion history.
- Deaths use the last-100 recency store.
- Heatmap summary is metadata, not a rendered zone overlay.
- No account Knowledge.
- No map pins or new zone selector.

## 5. Next

**HIST-1C — Bounded quest-anchor log.**

## Artifacts

- `KillHistory/UI/Detail.lua`
- `KillHistory/UI/Window.lua`
- `Core/Defaults.lua`
- `tests/historical_zone.lua`
- `tests/run_all.sh`
- `docs/tasks/HIST-1B-HISTORICAL-ZONE-SURFACES.md`
