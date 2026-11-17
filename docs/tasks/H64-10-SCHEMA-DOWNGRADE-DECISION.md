# H64-10 — Schema/downgrade decision

**Status:** decided 2026-11-16; non-live  
**Result:** `docs/H64-10-SCHEMA-DOWNGRADE-DECISION-RESULT.md`  
**Harness:** `tests/schema_decision.lua`  
**Depends on:** DS-11, H64-9  
**Blocks:** final grid/limit decisions

## Why

The 64×64 heatmap is the durable grid, but the per-client data schema is still
`1`. The known ambiguity is a pre-2.2.0 32×32 heatmap saved without `gridSize`
and with every cell index `<= 256`: it is inferred as 16×16.

## Decision needed

Choose one:

1. Keep per-client data schema `1` and document the legacy inference.
2. Bump the per-client schema to force a migration/grid normalization.

## Constraints

- Do not rewrite existing 64×64 saves unnecessarily.
- Do not make older builds misread new saves without a documented downgrade
  block.
- Preserve the 16×16/32×32 migration tests unless the decision changes them.
- No storage-format redesign; Journey block schema is separate.
- No account Knowledge/merge.

## Acceptance

- Decision recorded with rationale.
- Legacy inference behavior documented and tested.
- README schema section updated.
- No unrelated migration or data deletion.
