# DS-3B — Massive synthetic store validation

**Status:** executed 2026-11-15; passed  
**Result:** `docs/DS-3B-MASSIVE-SYNTHETIC-RESULT.md`  
**Purpose:** validate the structural capacity model with one actual worst-case
synthetic file. No live client and no schema change.

## What this answers

- What does the worst-case **current hot profile** actually serialize to?
- Does it load and normalize without hitting a Lua/SavedVariables parser limit?
- How much Lua heap does it add?
- Does save/reload preserve the aggregates?
- Are the 11–14 MB / 18–25 MB model ranges credible, too high, or too low?

## One mandatory profile

Stay within the current hot caps so normalization does not silently prune the
test:

- 2,000 mobs;
- 12 contexts per mob = 24,000 contexts;
- 40 zones × 4,096 cells = 163,840 heatmap cells;
- 100 instance records;
- 200 quests;
- 100 deaths;
- 300 respawn NPCs × 20 interval samples;
- 200 level-history records;
- 240 rate samples;
- all normal mob fields and per-level/map/instance counters;
- derived `areas`, `levels`, `areaLevels`, and instance summaries populated from
  the canonical data.

Use recent timestamps so age pruning does not reduce the profile.

Do **not** add a 200-zone/200-instance variant here. The current normalizer caps
heatmaps at 40 zones and instances at 100; a normalized 200-zone result would be
false. That cold-tier test belongs to DS-4P/DS-17.3.

## Method

- Generate the profile offline with the fixtures and deterministic builder.
- Normalize with `EnsureDB`.
- Record:
  - **actual compact serialized bytes**;
  - **estimated client-format bytes** using the measured DS-3 ratio
    (`70,661 / 61,783 = 1.144`) as a labeled estimate, not a client measurement;
  - Lua heap delta from the pre-load baseline, not total process memory;
  - load, normalize, save, and reload times (`os.clock`, offline only).
- Save the file, reload it in a **fresh Lua process**, and verify:
  - totals/kills/xp/unique mobs;
  - `areas`, `levels`, `areaLevels`;
  - instances and instance levels;
  - heatmap zones/cells/totals;
  - no double count and no invented data.
- Watch for Lua constant-table overflow or parser failure. If the generated file
  cannot load, record that as a real capacity finding, not a test bug.

## Pass criteria

- Save/reload preserves all checked aggregates.
- No double count or invented data.
- Actual bytes and Lua heap are recorded.
- The client-format byte figure is labeled as an estimate.
- Timing is labeled offline, not client frame/save time.
- If actual size is materially outside the 11–14 MB model range, update the
  strategy before DS-17.1 finalizes hot/cold boundaries.
- If actual size is below the range, do not use that as proof that the global
  caps are sufficient; record it.

## Output

- `docs/DS-3B-MASSIVE-SYNTHETIC-RESULT.md`;
- actual compact bytes, client-format estimate, Lua heap delta, timings;
- invariant result;
- corrected capacity range if needed;
- any parser/constant-limit blocker;
- no production code or schema change.

## Not required

- live client test;
- exact content census;
- multi-layout matrix;
- 200-zone hot test;
- schema implementation;
- companion packaging.

## Execution order

DS-3B -> DS-17.1 hot/cold and required keys -> DS-1-F2 indexes.
