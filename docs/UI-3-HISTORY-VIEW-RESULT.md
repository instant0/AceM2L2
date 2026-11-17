# UI-3 — Death and respawn history view result

**Status:** executed 2026-11-16  
**Production modules:** `KillHistory/World.lua`,
`KillHistory/UI/List.lua`, `KillHistory/UI/Detail.lua`,
`KillHistory/UI/Window.lua`  
**Test:** `tests/history_view.lua`; `./tests/run_all.sh`  
**Scope:** existing death/respawn data only. No schema or storage change.

## 1. History tab

Added a **History** tab that combines recent deaths and respawn records.

- Death rows:
  - map name;
  - age;
  - coordinates.
- Respawn rows:
  - NPC name;
  - sample count;
  - average duration when enough samples exist;
  - otherwise “need N samples”.
- Search filters deaths by map name and respawns by NPC name.
- Sort cycles between **Recent** and **Name**.
- Displayed rows are capped:
  - 25 deaths;
  - 50 respawn records.
- Stored data is not truncated by the view.

## 2. Details

- Death detail: time, age, map, coordinates, command hint.
- Respawn detail: average, min/max, samples, last seen, NPC ID, command hint.
- Low-sample respawns show the required sample count instead of inventing an
  average.
- Empty and unavailable states are explicit.

## 3. Availability

`GetHistoryAvailability()` mirrors the command gates:

- deaths need the map-position API;
- respawns need kill tracking and GUID identity;
- missing APIs produce an explicit unavailable message, not a false empty row.

## 4. Tests

`tests/history_view.lua` verifies:

- death and respawn rows;
- recent/name sorting;
- search by map and NPC;
- death/respawn detail values;
- low-sample state;
- command parity for `deaths` and `respawns`;
- empty state;
- unavailable state;
- displayed-row cap.

Passing output:

```text
History view passed
```

`./tests/run_all.sh` passes.

## 5. Limitations

- No map pins or route animation.
- No new storage or schema.
- Live map-position/nameplate behavior remains a V-2 check.
- Death/respawn data remains command-accessible.

## 6. Next

**UI-4 — Quest XP ledger view.**

## Artifacts

- `KillHistory/World.lua`
- `KillHistory/UI/List.lua`
- `KillHistory/UI/Detail.lua`
- `KillHistory/UI/Window.lua`
- `tests/history_view.lua`
- `tests/run_all.sh`
- `README.md`
