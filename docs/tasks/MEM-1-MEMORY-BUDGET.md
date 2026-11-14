# MEM-1 — Memory footprint and budget

**Status:** partial measurement; one real client sample recorded  
**Priority:** low/medium — context suggests our fixture memory is not a concern  
**Scope:** real addon memory measurement, comparison, and budget  
**Depends on:** H64-9 (benchmark), V-2 (runtime storage)  
**Related:** H64-9-F3 (display/cell pool), G-2, SC-1, SC-2

## Context

Observed memory use from other addons:

| Addon | Memory |
|---|---:|
| AllTheThings, loaded | **51 MB** |
| AllTheThings, opened | **65 MB** |
| AllTheThings on Midnight | **several hundred MB** |
| Forever LevelingGuide | **48 MB** |
| AceM2L2 heatmap fixture process | ~20 MB for a dense 4,096-cell profile |

The 20 MB H64-9 figure is **fixture UI-object memory**, not real in-game texture
or Lua memory. It is already far below the reference addons. Do not optimize the
heatmap cell pool solely because the offline fixture reached 20 MB.

The real question is: **what does AceM2L2 actually use in the client, and is it
within a sensible budget at idle, with the heatmap open, and with dense data?**

## Measured samples

### Sample 1 — Hunter, 2026-11-14

| Field | Value |
|---|---|
| Client/version | latest (2.5.2 workspace), UI opened |
| Character | Hunter |
| Kills | 389 |
| Unique mobs | 25 |
| Kills since Lua dump | none |
| Addon memory | **3.2 MB** |
| Reference ATT | ~51 MB loaded / ~65 MB opened |
| Reference ForeverLevelingGuide | ~48 MB |

Interpretation: with a small 389-kill/25-mob profile and the UI open, AceM2L2 is
far below the reference addons. This does not justify display-detail or cell-pool
optimization. Dense or future Midnight samples are optional; a long-lived save
is not a prerequisite for closing H64-9-F3.

### Sample 2 — Priest, 2026-11-14

| Field | Value |
|---|---|
| Client/version | latest 2.5.2 workspace, UI opened |
| Character | Priest |
| Kills | 762 |
| Unique mobs | 85 |
| Heatmap | Silverpine Forest, 408 kills |
| Addon memory | **3.85 MB** |
| Reference ATT | ~51 MB loaded / ~65 MB opened |
| Reference ForeverLevelingGuide | ~48 MB |

Interpretation: the heatmap-open state adds only about **0.65 MB** over the
389-kill/25-mob sample, and the total remains far below the reference addons.
These real samples do not justify H64-9-F3 for ordinary play. Keep it gated for
unusually dense or future Midnight profiles only. The addon is new, so no
long-lived save exists; that is not a blocker.

## Goals

- Measure real AceM2L2 memory on Forever and Midnight.
- Separate idle, UI-open, heatmap-tab, dense-zone, collection-off, and
  post-close states.
- Compare with AllTheThings and ForeverLevelingGuide as reference points.
- Decide whether H64-9-F3 (display detail/cell pool) is needed.
- Avoid optimizing based on fixture-object memory.

## Non-goals

- Changing the heatmap grid or storage layout.
- Chasing ATT/FLG memory parity.
- Live frame-time measurement (V-1).
- Storage-size measurement (HC-5/SC-1).

## Measurement questions

1. What is AceM2L2's `GetAddOnMemoryUsage`/`C_AddOns.GetAddOnMemoryUsage` after
   login?
2. What is it after opening the UI on Overview, Mobs, and Heatmap?
3. What is it after opening a dense zone?
4. What is it after closing the UI?
5. What is it with `heatmapEnabled=false`?
6. What is it after `/reload`?
7. How much is Lua heap (`collectgarbage("count")`) versus UI textures/frames?
8. How do the numbers compare with ATT 51/65 MB and FLG 48 MB?
9. Does the cell pool grow across zones and remain allocated?
10. Does memory return after closing the heatmap or clearing data?

## API research

Verify on both clients:

- `UpdateAddOnMemoryUsage()`
- `GetAddOnMemoryUsage(addonName)`
- `C_AddOns.GetAddOnMemoryUsage(addonName)` if present
- `collectgarbage("count")`
- Any frame/texture memory introspection

If only `collectgarbage` is portable, label it as Lua-heap-only and do not call
it total addon memory.

## Measurement method

- Same character/realm/client for each run.
- Capture after a clean login and after a `/reload`.
- Record before/after for each UI state.
- Repeat 3 times; report median/range.
- Compare with other addons on the same client/session.
- Keep SavedVariables size separate from runtime memory.

## Acceptance criteria

- Real addon memory numbers exist for both clients.
- Numbers are separated by UI state.
- Comparison to ATT/FLG is recorded.
- A simple memory budget/decision is recorded.
- H64-9-F3 is either closed as unnecessary or scheduled with a measured reason.
- Samples 1–2 (3.2 MB Hunter; 3.85 MB Priest with heatmap open) are below any
  reasonable budget and support closing F3 for ordinary play; keep it gated for
  dense/future Midnight profiles.
- No heatmap/storage change is made from fixture memory alone.

## Plan updates

- Add `MEM-1` to the plan map and work packages.
- Mark H64-9-F3 as “measurement-gated” rather than automatically scheduled.
- Link the results from the H64-9 report.
- Live measurement stays in V-2 unless it blocks the heatmap decision.

## Review notes

- 51/65/48 MB reference points make a 20 MB fixture process look unremarkable.
- The fixture includes mock UI objects and retained frames, so it is not a
  real-client budget.
- The correct next step is measurement, not speculative optimization.
