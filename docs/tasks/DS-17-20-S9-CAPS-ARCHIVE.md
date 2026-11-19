# DS-17.20 — S9 adaptive caps, retention, and archive policy

**Status:** executed 2026-11-18.  
**Result:** `docs/DS-17-20-S9-CAPS-ARCHIVE-RESULT.md`  
**Depends on:** DS-17.19  
**Blocks:** S10 legacy retirement  
**Source:** `docs/DS-17-07-DATA-MODEL-RECONCILIATION-RESULT.md`, DS-17.3

## Goal

Apply measured retention and archive policy to the v2 model now that the block
payload can carry complete records.

## S9 slice

This slice lands the archive primitives without adding blanket caps:

- explicit 3/6/12-month retention profiles;
- hot/warm/cold block tiers from measured activity age and current-zone status;
- 32×32 and 16×16 heatmap summaries derived from the durable 64×64 source;
- cold context collapse to top-8 plus `other`, preserving sample counts;
- block/index compaction;
- retention diagnostics with tier counts and measured block bytes.

Existing adaptive mob/quest caps and fixed safety ceilings remain unchanged.
Generation-file archives and archive deletion stay out of this slice.

## Policy inputs

- Use measured save size, block size, decode cost, and cap pressure.
- Keep dynamic hot/warm/cold movement from DS-17.3.
- Keep 64×64 durable heatmaps; derive 32/16 cold summaries from them.
- Do not raise every cap at once or add blanket MB caps.
- Use explicit hard safety ceilings only where a structural bound is required.
- Per-character Journey remains primary.

## Scope

- Keep the existing measured/adaptive caps for mobs, quests, deaths, respawns,
  levels, and heatmap maps; do not raise them as part of S9.
- Add hot/warm/cold movement for blocks and heatmap summaries.
- Add the 32/16 cold heatmap summaries without replacing the 64×64 source.
- Define 3/6/12-month and beyond-cap retention profiles.
- Collapse cold contexts with sample counts preserved.
- Compact stale blocks and keep `blockIndex` aligned.
- Keep block writes dirty-zone scoped.
- Expose diagnostics for retained/archived counts and measured bytes.

## Not in S9

- per-generation archive files or archive deletion;
- legacy retirement (S10);
- UI redesign;
- account Knowledge/ALT work;
- live-only validation (V-2C).

## Tests

`tests/s9_caps_archive.lua`:

- hot/warm/cold transitions;
- 64→32→16 summarization parity;
- archive retention by profile;
- cap pressure and hard-ceiling behavior;
- block/index compaction;
- no double counting after archive;
- no unmeasured blanket cap or MB limit.

## Acceptance

- Existing measured/adaptive caps stay in place; no blanket cap or MB limit is
  added.
- 64×64 remains the durable heatmap source and 32/16 totals match it.
- Hot/warm/cold tiers and context collapse use the selected retention profile.
- Archived blocks round-trip through the S8 schema.
- Full suite passes.
