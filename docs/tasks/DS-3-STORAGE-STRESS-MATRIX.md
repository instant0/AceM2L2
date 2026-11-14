# DS-3 — Storage sanity check

**Status:** executed 2026-11-14; passed  
**Result:** `docs/DS-3-STORAGE-SANITY-RESULT.md`  
**Purpose:** prove only the current-store facts that DS-4 and prior research do
not already establish: save/reload correctness and acceptable load/save cost.
Do not retest known Lua/WoW behavior or known retrieval gaps.

## What we need to know

1. Data survives save/reload without loss or double counting.
2. The current store still loads and saves in reasonable time at real size and a
   simple 10× synthetic size.

Known gaps are not tests here:

- name-only tooltip lookup scans all mobs (DS-1-F2 / DS-15);
- heatmap normalization iterates every stored zone (H64-9-F4 / DS-15);
- account-wide alt knowledge is not implemented (DS-17.4).

Nothing else is required for the first decision.

## Inputs

- Existing 762-kill / 85-mob / Silverpine 408-kill sample.
- The 389-kill / 25-mob figure is a memory sample, not a SavedVariables file;
  it is not used for storage timings.
- DS-4 answers: `docs/tasks/DS-4-STORAGE-REPRESENTATION.md`.
- DS-1 contract: `docs/tasks/DS-1-CONSUMER-CONTRACT.md`.
- One simple 10× synthetic copy. Use 100× only if the 10× run is cheap.

## Test 1 — Correctness

- Load the real sample.
- Save and reload.
- Verify totals, mob counts, area/level/instance totals, heatmap totals.
- Verify no double counting between open world and instances.
- Verify missing/empty stores do not create false data.

Pass: identical useful data after reload.

## Test 2 — Load and save cost

Use the real sample and one 10× synthetic copy.

Record:

- file bytes;
- load time;
- save time;
- one kill write.

Pass: no pathological growth; load/save remain usable at 10×.

## Result

- Real sample and 10× synthetic both passed save/reload and aggregate checks.
- Keep the current layout; no schema change.
- Full report: `docs/DS-3-STORAGE-SANITY-RESULT.md`.
- Harness: `tests/storage_sanity.lua`.

## Acceptance

- Both checks pass or have a named blocker.
- Known tooltip/heatmap/alt gaps are recorded, not retested.
- No exact content census required.
- No long-lived save required.
- No 100×/multi-layout matrix required.
- The result is enough to decide whether DS-4P needs a prototype or no change.
