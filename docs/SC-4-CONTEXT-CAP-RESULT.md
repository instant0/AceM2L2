# SC-4 — Context cap result

**Status:** decided/validated 2026-11-17  
**Test:** `tests/context_cap.lua`; `./tests/run_all.sh`  
**Scope:** hot context retention and future cold policy. No schema change.

## 1. Evidence

- SC-1 real sample: **1 context** total.
- DS-17.4C:
  - top-4 detail coverage: ~64–67%;
  - top-8 detail coverage: ~92–94%;
  - top-8 + `other`: **100% of totals**, ~92% detail;
  - packed top-8+other: 1.43 MB vs 1.81 MB full at 10k mobs.
- DS-7: 100k cold contexts 4/8/12 = 3.90/6.54/9.19 MB.
- Contexts dominate cold size; the real sample does not justify 12 for normal
  play.

## 2. Decision

### Hot
Keep **12 contexts/mob** in the keyed hot table.

- The map is needed for active lookup.
- The real sample is far below 12.
- Prune by:
  - context age (120 days);
  - oldest last-seen when over cap.
- No change to calibration/tooltip lookup.

### Cold
When contexts are added to packed cold blocks, use **top-8 + `other`**, not a
full context map.

- Preserves 100% of kill/XP totals.
- Keeps ~92% of detail.
- Packed form is smaller than the full array.
- `other` is one aggregate record, not a per-mob Lua table.

Do not use plain top-4; detail loss is too high.

## 3. What was not changed

- No production schema change yet.
- Cold blocks currently carry mob-level data, not context arrays.
- No top-8+other production implementation until cold context encoding is
  added.
- Hard hot cap remains a safety rail.

## 4. Tests

`tests/context_cap.lua` verifies:

- 20 contexts prune to the 12-context cap;
- newest contexts survive, oldest are removed;
- expired contexts are removed;
- the mob record remains valid.

Passing output:

```text
Context cap passed
```

`./tests/run_all.sh` passes.

## 5. Next

**SC-5 — Migration/pruning/tests.**

## Artifacts

- `tests/context_cap.lua`
- `tests/run_all.sh`
- `docs/tasks/SC-4-CONTEXT-CAP.md`
