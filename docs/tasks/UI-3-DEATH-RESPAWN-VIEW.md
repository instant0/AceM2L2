# UI-3 — Death and respawn history view

**Status:** executed 2026-11-16; no storage schema change  
**Result:** `docs/UI-3-HISTORY-VIEW-RESULT.md`  
**Harness:** `tests/history_view.lua`  
**Depends on:** UI-1, DS-1  
**Blocks:** none  
**Related:** README claim review, `docs/README-CLAIM-REVIEW.md`

## Why

The data and commands already exist:

- `/acem2l2 xpt deaths [count]`
- `/acem2l2 xpt respawns [name]`

But the README previously implied death locations and respawn intervals were in
the Kill Story window. They were not. This task adds the missing UI without
changing storage.

## Scope

Add a compact Deaths/Respawns section or tab that shows:

- recent deaths: age, zone/map name, coordinates;
- respawn records: NPC name, sample count, average/min/max interval, last seen;
- sort/filter;
- clear "no data" and "not available on this client" states;
- a link/reminder for the existing commands.

Use the existing `db.deaths`, `db.respawns`, `GetRespawnStats`, and map-name
helpers. Do not add a new SavedVariables root.

## Requirements

- Respect `hasMapPosition` and `hasGUIDIdentity`.
- Do not invent a death or respawn when the client API is unavailable.
- Keep the list bounded; cap displayed rows, not stored data.
- Match the command output for the same records.
- Do not add per-kill events or exact coordinates for kills.

## Acceptance

- Existing deaths/respawns are visible in the window.
- Values match `/acem2l2 xpt deaths` and `/acem2l2 xpt respawns`.
- Missing API/data states are explicit.
- No schema or storage change.
- README can move death/respawn history back under the window claim.

## Not required

- Map pins or route animation.
- New storage.
- Live client test beyond the normal validation gate.
