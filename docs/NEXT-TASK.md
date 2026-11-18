# Next task

## UI-5 — Heatmap zone/instance selector

**Status:** next; non-live UI feature  
**Task document:** `docs/tasks/UI-5-HEATMAP-ZONE-SELECTOR.md`  
**Depends on:** G-3, IMP-1B10, UI-3/UI-4, H64-9-F5  
**Live gate:** V-1 visual/frame check after implementation

### Why this is next

- The Heatmap tab still switches zones only with `<` / `>` and `Current zone`.
- With up to 64 heatmap zones plus attributable instance maps, sequential
  paging is slow and gives no overview.
- The selector can show name, heatmap kills, and recorded player-level range in
  one alphabetical list.
- HC-7 is complete; no limit-control work is pending.

### Work

1. Build one row per heatmap map ID, merging zone and instance metadata.
2. Use heatmap kills as the primary count; fall back to area/instance kills.
3. Use recorded player levels for the level range; never invent a content range.
4. Sort alphabetically, case-insensitively, with deterministic tie-breaks.
5. Add a dedicated `Select` button and a bounded scrollable popup.
6. Keep `<`, `>`, and `Current zone`.
7. Selecting a row updates `heatmapZoneKey` and the existing render path.
8. Close on selection, Escape, click outside, tab change, or window close.
9. Add focused model/UI tests and run the full offline suite.

### Output

- heatmap zone/instance selector;
- alphabetical name/kills/level-range rows;
- focused tests and result document.

### Not required

- non-heatmap instance selection;
- map pins or a new tab;
- schema/storage change;
- account Knowledge;
- live client test.
