# SC-4 — Context cap

**Status:** decided/validated 2026-11-17  
**Result:** `docs/SC-4-CONTEXT-CAP-RESULT.md`  
**Harness:** `tests/context_cap.lua`  
**Depends on:** SC-1, SC-2, SC-3, SC-6, DS-7  
**Blocks:** SC-5, final hot/cold retention

## Why

Contexts are the dominant cold-size variable:

| Contexts/mob | 100k packed cold |
|---:|---:|
| 4 | 3.90 MB |
| 8 | 6.54 MB |
| 12 | 9.19 MB |

The current cap is 12/mob. The real SC-1 sample had only 1 context, so it does not
justify 12. The old 12 may be excessive for normal play and too low for some
calibration cases; this needs a deliberate decision.

## Questions

1. What context dimensions are actually needed for tooltip/calibration?
2. Is a top-N context policy better than a raw count?
3. Should hot and cold contexts use different caps?
4. What is the merge/downsample behavior when contexts are dropped?
5. Does the capacity assessment suggest pressure before 12?

## Scope

- Measure context counts per mob in real/synthetic data.
- Compare 4/8/12 caps for size, XP-confidence, and merge behavior.
- Prefer top-N retention with an `other` bucket if justified.
- Keep hard safety caps.
- Add tests for pruning/merge/idempotence.
- No schema change unless explicitly chosen.

## Acceptance

- Context cap decision recorded.
- Size and accuracy tradeoff documented.
- Pruning/merge tests pass.
- Capacity pressure can guide soft context retention.
- No data loss outside the chosen retention rule.

## Not required

- live memory;
- account Knowledge/merge;
- UI redesign.
