# SC-3 — Choose a tier

**Status:** decided 2026-11-17  
**Result:** `docs/SC-3-TIER-DECISION-RESULT.md`  
**Harness:** `tests/limit_tier.lua`  
**Depends on:** SC-1, SC-2, DS-3B, DS-7  
**Blocks:** SC-4, SC-5, G-2/G-3

## Why

SC-2 measured the real shape at 2×/4×/6×. A tier choice is needed before changing
any cap.

## Inputs

- 4× fits current caps for the measured shape.
- 6× exceeds only the current respawn-NPC cap in that shape.
- 6× serialized size is still ~0.73 MB.
- Contexts remain the cold-storage stress variable.
- Dense heatmaps remain a synthetic stress case, not a real-shape problem.

## Decision

Choose one:

1. Keep current caps as the default tier.
2. Approve a measured 4× tier.
3. Allow 6× with selective cap changes.
4. Keep 6× but let the respawn cap trim.

Do **not** raise every constant by the same factor.

## Constraints

- No arbitrary MB target.
- Use measured sections, not total bytes alone.
- Keep context and heatmap stress separate from normal growth.
- No schema change.
- No live client requirement.

## Acceptance

- Tier decision recorded with rationale.
- Cap changes, if any, are selective and named.
- SC-4/SC-5 receive the decision.
- No unrelated limit changes.

## Not required

- live memory;
- UI redesign;
- account Knowledge/merge.
