# UI-1 — Responsive mob list and window layout

**Status:** implemented offline; live check remains in V-1/V-6  
**Priority:** high — visible usability defect  
**Scope:** list row count, row width reflow, kills column, resize bounds  
**Depends on:** none  
**Related:** V-1/V-6 for live visual confirmation

---

## 1. Problem

Two layout defects are visible in the Kill Story Mobs tab:

1. **The list is fixed at 13 rows.**
   `Util.VISIBLE_ROWS = 13` is used to create exactly 13 row frames. The list
   scrolls through more data, but a taller window still renders only those 13
   rows. The empty space below them is not used for additional rows.

2. **The right-side kills text does not reflow with the window.**
   `rowWidth` is calculated once in `CreateUI()`. The row frames, name text,
   value text, and scroll child keep that original width after the window is
   resized. The kills value uses a fixed `200` px width anchored to the right.
   When the window is narrowed below the width used at creation, the row remains
   wider than the visible list panel and the kills text is clipped off the right
   edge. The bar can still be visible at roughly 25% width, leaving blank space
   before the missing number. Enlarging the window does not expand the row
   content either.

The fixed maximum resize width (`1400`) also stops the window from growing on
large screens even when the screen has room.

---

## 2. Root causes in code

### Fixed row count

- `KillHistory/Util.lua`: `VISIBLE_ROWS = 13`.
- `KillHistory/UI/Window.lua` `CreateUI()`: creates a row for
  `index = 1, VISIBLE_ROWS` only.
- `KillHistory/UI/List.lua` `UpdateRows()`: iterates `#self.rows`, so it can
  never render more than the originally created 13 rows.

### One-time width calculation

- `KillHistory/UI/Window.lua` `CreateUI()`:
  - `listWidth` and `rowWidth` are calculated once from `frame:GetWidth()`.
  - `scrollChild:SetSize(rowWidth, 1)`.
  - each row is sized `rowWidth`.
  - name text uses `text:SetWidth(max(110, rowWidth - 250))`.
  - value text uses `value:SetWidth(200)` and is anchored `RIGHT`.
- `KillHistory/UI/List.lua` `BuildList()` uses `self.ui.rowWidth`; it never
  updates it.
- `OnSizeChanged` calls `SafeRefreshUI()`, which rebuilds the list and rows but
  never recalculates `rowWidth`, row sizes, or text widths.
- `SaveUIPosition()` persists the new window size, but the layout stays at the
  old width.

### Resize bounds

- `SetResizeBounds(frame, 900, 600, 1400, 1050)`.
- The hard maximum width keeps the window from becoming wider than 1400 even on
  a larger display.

---

## 3. Goals

- Derive the visible row count from the actual list viewport height, not a
  fixed constant.
- Reflow row width, name width, value width, and bar width on every resize.
- Keep the kills text visible at the minimum width.
- Let the kills text move with the right edge of the row instead of reserving a
  fixed 200 px column that gets clipped.
- Allow the window to grow wider/taller when the screen has room.
- Preserve scroll position, selection, tabs, and existing row content.

## 4. Non-goals

- New columns or sorting behavior.
- Changing row height or row visual design.
- Changing the underlying data model.
- Mobile/console layouts.
- Live visual validation; that remains in V-1.

---

## 5. Proposed design

### 5.1 Dynamic row pool

Replace the fixed `VISIBLE_ROWS` row creation with a reusable pool:

- `ROW_HEIGHT` remains `28`.
- Compute:
  - `viewportHeight = scrollFrame:GetHeight()`
  - `visibleRows = max(1, ceil(viewportHeight / ROW_HEIGHT))`
- Ensure the pool has at least `visibleRows` rows, creating rows lazily.
- Hide extra rows when the window shrinks.
- Cap the pool at the number of entries or a safety maximum (for example 64)
  so a very tall window cannot allocate unbounded rows.
- `UpdateRows()` loops `1..visibleRows`, not `#self.rows`.
- Keep `Util.VISIBLE_ROWS` only as a fallback/minimum if the viewport size is
  unavailable; rename it to make that role explicit if practical.

### 5.2 Responsive row width

Create one layout helper, for example `UpdateListLayout()`, called from:

- `CreateUI()` after the scroll frame exists;
- `BuildList()` before sizing the scroll child;
- `UpdateRows()`;
- `OnSizeChanged` after the resize debounce.

It computes:

```lua
local viewportWidth = max(1, scrollFrame:GetWidth() - scrollbarAllowance)
local rowWidth = max(MIN_ROW_WIDTH, viewportWidth)
local valueWidth = clamp(70, 200, floor(rowWidth * 0.30))
local nameWidth = max(80, rowWidth - LEFT_PADDING - CREST_WIDTH
  - valueWidth - RIGHT_PADDING - VALUE_GAP)
```

Then applies:

- `scrollChild:SetWidth(rowWidth)`
- every visible row `SetWidth(rowWidth)`
- name text `SetWidth(nameWidth)`
- value text `SetWidth(valueWidth)`
- value text remains anchored to the row's right edge with a small padding
- bar width is recalculated from the row width and percentage

The kills text must not reserve fixed space when the row is narrow. It should
shrink toward its text width and stay inside the row.

### 5.3 Kills text and bar

- Value text is right-aligned in a dynamic column.
- When the row is wide, the column can grow up to 200 px.
- When the row is narrow, the column shrinks to a readable minimum (for example
  70 px) so the number remains visible.
- No fixed `rowWidth - 250` name width.
- The value text's right edge must stay at least 8 px inside the row.
- The progress bar remains a percentage of the row width and must not extend
  under the value text if that causes overlap; if needed, reserve a small
  right-side gap for the value while keeping the bar proportional to the
  remaining content width.

### 5.4 Resize bounds

- Keep a usable minimum width (currently 900; evaluate 800–900).
- Raise or remove the hard 1400 maximum. Use a screen-aware maximum, for
  example:
  - `maxWidth = min(1920, UIParent:GetWidth() - 40)`
  - `maxHeight = min(1200, UIParent:GetHeight() - 80)`
- Ensure `SaveUIPosition()` persists the larger size and that clamped sizes
  remain valid on the next login.
- Do not force a resize on every login; only clamp if the saved size exceeds
  the current screen.

### 5.5 Scroll and selection behavior

- Preserve the current scroll offset when resizing.
- Keep the selected row visible if it remains in range.
- Recompute `startIndex` from the scroll offset after the visible-row count
  changes.
- Do not reset the scroll position when only the window size changes.
- `BuildList()` must still set `scrollChild` height to
  `max(1, #list * ROW_HEIGHT)`.

---

## 6. Validation

### Offline UI tests

The fixture UI mocks support frame sizes, so these can be static tests.

1. **Taller window:** set the frame to `1150x600`, `1150x780`, and
   `1400x1050`; assert visible rows increase and are greater than 13 at the
   larger heights.
2. **Shorter window:** assert the visible-row count drops and extras are hidden.
3. **Narrow width:** set the frame to the minimum width; assert:
   - row width equals the current scroll-frame width;
   - name and value widths are positive;
   - value right edge stays inside the row;
   - the kills value remains shown.
4. **Wide width:** set the frame above 1400; assert the row expands, the value
   column grows only up to its cap, and no blank fixed column remains.
5. **Scroll preservation:** scroll down, resize, assert the start index is
   preserved.
6. **Selection:** select a row, resize, assert selection and detail remain.
7. **Pool growth:** assert rows are created lazily and hidden/shown correctly
   when the viewport changes.
8. **Saved size:** assert a larger width/height is persisted and a size larger
   than the current screen is clamped safely.

### Live validation

Visual confirmation of row count, text/bar overlap, and resize behavior remains
in V-1/V-6.

---

## 7. Acceptance criteria

- A taller Mobs window shows more than 13 rows when the data contains more
  entries.
- A shorter window shows fewer rows and hides the extras.
- Narrowing the window keeps the kills text visible and inside the row; it no
  longer disappears behind the right edge.
- The kills text moves with the row's right edge instead of staying in a fixed
  200 px column.
- Widening the window expands the row content up to the new width instead of
  leaving the old content width behind.
- The window can grow beyond 1400 px when the screen has room.
- Scroll position, selection, tab switching, filters, and detail remain intact.
- Offline layout tests pass.

---

## 8. Implementation checklist

- [ ] Add a reusable row pool and dynamic `visibleRows` calculation.
- [ ] Add `UpdateListLayout()` and call it from creation, build, row refresh, and
  resize.
- [ ] Remove the one-time `rowWidth`/`text:SetWidth`/`value:SetWidth` assumptions.
- [ ] Recalculate bar width from the live row width.
- [ ] Replace the fixed 1400 max resize bound with a screen-aware bound.
- [ ] Preserve scroll offset and selection on resize.
- [ ] Add offline UI tests for tall/short/narrow/wide sizes and saved sizes.
- [ ] Update README/UI notes if the minimum/maximum changes.
- [ ] Keep live visual checks in V-1/V-6.

---

## 9. Open questions

1. **Value alignment.** Default plan: keep the kills value right-aligned to the
   live row edge so it moves left as the row narrows. Evaluate in V-1 whether
   anchoring it directly after the bar end reads better. Do not make every row's
   number float independently without a mock review; it can look ragged.
2. **Minimum width.** Keep 900 or lower to 800 if the detail panel still fits.
3. **Maximum width.** Use a screen-aware 1920 cap or the full usable screen
   width. Do not remove all bounds.
4. **Detail panel.** It is fixed at 300 px. At the minimum width, decide whether
   to keep it fixed, shrink it, or collapse it. Keep this out of the first fix
   unless it blocks the minimum width.
5. **Very narrow widths.** Two-line rows are out of scope unless the minimum
   width cannot keep the name and kills text readable.

## 10. Review log

### v1 — initial draft

- Identified the fixed 13-row limit and the one-time `rowWidth` calculation.
- Proposed dynamic rows and a responsive value column.

### v2 — revised after code review

- Confirmed the exact cause of the disappearing kills text: rows retain the
  creation-time width while the scroll frame shrinks, so the right-aligned value
  is clipped outside the visible list.
- Added the fixed 1400 maximum width as a separate resize-bound defect.
- Specified a single `UpdateListLayout()` helper so creation, list rebuild, row
  refresh, and resize cannot diverge again.
- Specified an explicit value-width clamp so the kills text slides with the row
  edge instead of occupying a fixed 200 px column.
- Added scroll-position and selection preservation requirements.
- Added offline tests for tall/short/narrow/wide windows and saved sizes.
- Kept live visual checks in V-1/V-6.

### v3 — final task review

- Confirmed the disappearing kills text is caused by stale creation-time row
  width, not by the bar itself.
- Confirmed the hard 1400 px maximum is a separate resize-bound defect.
- Clarified the value behavior: it should reflow with the row edge by default;
  a bar-anchored variant is an explicit V-1 evaluation, not an assumed change.
- Added open questions for minimum width, maximum width, detail-panel width,
  and very narrow layouts.
- Kept the task implementation-ready: row pool, layout helper, resize bounds,
  scroll/selection preservation, and offline tests.

### v4 — implementation review

- Implemented a reusable row pool; `UpdateRows()` now derives `visibleRows` from
  the scroll-frame height and creates rows on demand up to 64.
- Added `UpdateListLayout()`. It recalculates row, name, value, and scroll-child
  widths from the live scroll-frame/frame geometry.
- The kills column is now capped at 200 px and shrinks to 70 px; the name column
  keeps at least 80 px. The fixed 200 px column is gone.
- Resize bounds are now screen-aware: minimum 800x560, maximum 1920x1200 or the
  usable screen area. Saved sizes are clamped on creation.
- The offline UI mocks report zero anchored widths/heights, so the layout helper
  falls back to the parent frame geometry. This is safe in-game and testable
  offline.
- Added tests for tall, wide, short, and narrow windows, row-pool growth/hiding,
  responsive text widths, and scroll-offset preservation. Total offline coverage
  is now 349 assertions.
- No release version was bumped; live resize/text/bar review remains in V-1/V-6.
