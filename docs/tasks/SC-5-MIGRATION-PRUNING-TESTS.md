# SC-5 — Migration, pruning, and cap tests

**Status:** next; non-live implementation/validation  
**Depends on:** SC-1..SC-4, SC-6, IMP-1B11 prep  
**Blocks:** V-2, final limit release

## Why

The chosen tier and context policy need one consolidated migration/pruning
story before live validation and flag removal.

## Scope

- Confirm versioned normalization for:
  - adaptive mob/quest limits;
  - respawn 4,000;
  - heatmap 64;
  - hot context 12;
  - cold top-8+other policy (documentation/schema readiness).
- Add cap-boundary tests for every changed store.
- Verify pruning is deterministic and recency-based.
- Document downgrade and reset behavior.
- Ensure no data loss outside the stated retention rules.
- Feed V-2.

## Acceptance

- Every changed cap has a boundary test.
- Pruning order is documented and deterministic.
- Migration/normalization is idempotent.
- Reset clears the new limits consistently.
- No account Knowledge/merge.

## Not required

- live memory;
- new UI;
- account merge;
- route recommendation.
