# HIST-1B — Historical zone surfaces

**Status:** executed 2026-11-17  
**Result:** `docs/HIST-1B-HISTORICAL-ZONE-RESULT.md`  
**Harness:** `tests/historical_zone.lua`  
**Depends on:** HIST-1A, IMP-1B10, UI-3  
**Blocks:** HIST-1C

## Revised scope

Do **not** add another zone selector or tab. Reuse the existing **Areas** tab and
extend the selected-area Detail with historical sections.

This is the smallest useful historical zone surface:

- no new navigation;
- no new capture format;
- no schema change;
- no full heatmap decode.

## Overlay toggle row

Add a compact, persisted row of toggle buttons in Area Detail:

```text
[Deaths] [Rares] [Quests] [Heatmap]
```

Behavior:

- each button toggles only its Detail section;
- pushed state reflects the current setting;
- settings persist in the profile under `ui.historyOverlays`;
- defaults: Deaths, Rares, Quests, Heatmap all on;
- buttons visible only on the Areas tab;
- no map pins, no new zone selector, no schema change;
- turning a section off must not affect stored data.

## What to add to Area Detail

For the selected area/map:

1. **Zone history summary**
   - total kills;
   - first/last recorded activity where available;
   - heatmap summary if already loaded or available from metadata.
2. **Notable deaths**
   - recent deaths in that map;
   - age and coordinates;
   - cap the displayed list (for example 3–5).
3. **Rare/elite mobs**
   - `rare`, `rareelite`, `worldboss` classifications;
   - top by kills in that map;
   - cap the list.
4. **Quest anchors**
   - quests whose recorded `mapID` matches the area;
   - latest anchor per quest;
   - cap the list;
   - label clearly as “latest anchor”, not full completion history.
5. **Heatmap link**
   - point to the Heatmap tab/command;
   - no cell scan in Area Detail.

## Data sources

- `db.areas` / `GetAreaRows` for area totals.
- `db.deaths` filtered by `mapID`.
- `GetJourneyMobRows()` for classification and `killsByMap`.
- `db.quests` filtered by `mapID` and sorted by `lastTurnInAt`.
- `db.heatmaps` summary or `GetJourneyHeatmapZones()` metadata.

No new storage.

## Constraints

- Do not claim a full quest journey from `lastTurnInAt`.
- Do not show XP in this historical section.
- Do not decode all heatmap zones.
- Do not add per-kill timestamps.
- Keep active Areas behavior and existing top-mob/level sections.
- Omit unavailable sections rather than showing fake zero.
- Overlay toggles affect presentation only.

## Tests

- Area Detail shows deaths/rares/quest anchors for a seeded map.
- Different map does not leak records.
- Missing data omits sections.
- No XP lines added.
- Overlay buttons toggle sections and persist across reopen.
- Defaults are on; button state matches settings.
- Existing active Areas behavior unchanged.
- Heatmap metadata path does not decode blocks.

## Acceptance

- Selected Area Detail has the historical sections.
- No new tab/navigation.
- No schema/capture change.
- Output is bounded and explicit.

## Not required

- quest-anchor history log;
- new zone UI;
- account Knowledge;
- live client test.
