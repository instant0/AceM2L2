# UI-5 — Heatmap zone/instance selector

**Status:** next; non-live UI feature  
**Depends on:** G-3, IMP-1B10, UI-3/UI-4, H64-9-F5  
**Related:** Areas tab, `GetHeatmapZoneIndex`, `db.instances`  
**Live gate:** V-1 visual/frame check after implementation

## Why

The Heatmap tab currently switches zones with `<` / `>` and a “Current zone”
button. With up to 64 heatmap zones plus attributable instance maps, sequential
paging is slow and gives no overview of what is available.

Add an actual selector that lists heatmap-capable zones/instances with:

- **name** (alphabetical);
- **kills**;
- **level range**.

Keep the arrows for quick stepping.

## Locked decisions

1. **Heatmap-capable rows only.** The selector lists map IDs with heatmap data.
   Non-attributable instances and zones without heatmaps stay in the Areas tab;
   do not present a dead selector row as if it had a heatmap.
2. **One row per map ID.** Merge zone and instance metadata by `mapID`.
3. **Kills means heatmap kills.** Use the zone/map heatmap `total`; for an
   instance map, use its heatmap total. Fall back to total area/instance kills
   only if no heatmap total exists.
4. **Level range means recorded player levels.** Use `db.areaLevels` for zones
   and the union of `instance.killsAtLevel` for instance maps. This matches the
   existing Area/Instance Detail label.
5. **Dedicated Select button.** Keep `<` / `>` and `Current zone`; add a
   `Select` button rather than relying on a clickable label alone.
6. **Flat alphabetical list.** Sort by display name, case-insensitively, with a
   small `Dungeon` tag on instance maps.

## Scope

### Selector rows

One row per heatmap map ID:

- open-world zones with a heatmap;
- attributable instance maps with a heatmap (for example a real dungeon UI map).

If multiple `db.instances` entries share a map ID (difficulty variants), merge
them into one row:

- kills = sum of instance kills (or the heatmap total);
- level range = union of `killsAtLevel`;
- name = the most recently seen instance name;
- type = dungeon.

Excluded from this task:

- non-attributable instances with no heatmap;
- zones with no heatmap data;
- map pins or a new tab.

### Row fields

| Field | Source |
|---|---|
| Name | `GetMapName(mapID)`; for instance maps prefer the most recent `db.instances[].name` |
| Kills | heatmap `total`; fallback to `db.areas[mapKey]` or summed instance kills |
| Level range | `db.areaLevels[mapKey]` for zones; union of `instance.killsAtLevel` for instance maps |
| Type | zone or dungeon tag |
| Key | `mapID` / heatmap zone key |

If no levels are recorded, show `—`.

### Sorting

- Case-insensitive alphabetical by display name.
- Tie-break by map ID.
- No “recent first” ordering in the selector; recency remains the fallback for
  the initial selection.

### UI

- Add a dedicated `Select` button next to the arrows.
- Open a bounded popup/list anchored under the selector row.
- Show roughly 10 rows at a time with a scroll frame.
- Selected row is highlighted.
- Row layout: name (left), kills (right), level range (far right), optional
  `Dungeon` tag.
- Selecting a row sets `self.heatmapZoneKey` and refreshes the existing heatmap.
- Close on selection, Escape, click outside, tab change, or window close.
- Keep `<`, `>`, and `Current zone`.
- No new SavedVariables; selection remains in-memory.
- Build the row list through a testable helper and keep it in the heatmap UI
  table for tests; do not expose it as a public data API.

### Cost

- Build the row metadata once per open/refresh, not per frame.
- Use existing zone/instance metadata; do not decode heatmap blocks for the
  list.
- Row count is bounded by existing heatmap-zone and instance caps.
- No per-frame `OnUpdate`.

## Tests

- Builds rows for zones and attributable instances.
- Merges duplicate map IDs and does not duplicate rows.
- Uses heatmap kills, not total zone kills, and shows the fallback when needed.
- Sorts alphabetically, case-insensitively, with deterministic tie-breaks.
- Shows kills from the correct source and heatmap-total fallback.
- Shows player-level ranges from `areaLevels` / `killsAtLevel`, or `—`.
- Selecting a zone updates `heatmapZoneKey` and refreshes the grid.
- Selecting an instance map updates the same state.
- Popup closes on tab change and window close.
- Arrow paging still works.
- No heatmap block decode while building the list.
- Existing heatmap/UI/full offline suites pass.

## Acceptance

- The Heatmap tab has a visible zone/instance selector in addition to arrows.
- Rows show name, kills, and player-level range, alphabetically.
- Selection drives the existing heatmap render path.
- No duplicate zone/instance rows for the same map.
- No schema, storage, or block-format change.
- No per-frame work.
- No non-heatmap instance is presented as if it had a heatmap.

## Not required

- map pins or a new tab;
- non-heatmap instance selection;
- account Knowledge;
- schema/storage change;
- live client test;
- new cap.

## Risks

- Instance naming can differ across difficulty entries sharing one map ID; use a
  deterministic “most recent name” rule and document it.
- Level range is player-level, not content-level. The addon does not store a
  content level range; do not invent one.
- Heatmap kills and total zone kills can differ; the selector uses heatmap kills
  and says so in the header or tooltip.
- A popup list adds layout/close-state complexity; keep it bounded and reuse
  existing list/scroll patterns.
