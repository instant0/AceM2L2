# Non-live backlog

**Status:** inventory, 2026-11-16  
**Purpose:** keep code, audits, and decisions moving without waiting for a live
client. Live-only residuals are in `docs/tasks/V-2-LIVE-VERIFICATION.md`.

## 1. Ready, concrete, offline

| Task | Why | Notes |
|---|---|---|
| **H64-9-F1** heatmap rescale optimization | Done 2026-11-16 | `docs/H64-9-F1-F2-HEATMAP-RESULT.md` |
| **H64-9-F2** disabled-state hide guard | Done 2026-11-16 | `docs/H64-9-F1-F2-HEATMAP-RESULT.md` |
| **R-4** static overlay/art audit | Done 2026-11-16 | `docs/R-4-OVERLAY-ART-AUDIT-RESULT.md` |
| **H64-9-F4** zone-scoped/lazy normalization | Done 2026-11-16 | `docs/H64-9-F4-ZONE-NORMALIZATION-RESULT.md` |
| **UI-3** death/respawn view | Done 2026-11-16 | `docs/UI-3-HISTORY-VIEW-RESULT.md` |
| **UI-4** quest XP ledger view | Done 2026-11-16 | `docs/UI-4-QUEST-LEDGER-RESULT.md` |
| **MEM-2** load/unload policy | Done 2026-11-16 | `docs/MEM-2-LOAD-UNLOAD-RESULT.md` |
| **IMP-1B11** rollback retirement | Preparation done 2026-11-16 | `docs/IMP-1B11-ROLLBACK-RETIREMENT-PREP.md`; final removal after V-2 |
| **DS-13** on-demand companion packaging | Code/package split can be built offline | Variable timing remains live |
| **DS-17.4D** account Knowledge prototype | Done 2026-11-18 | `docs/DS-17-04D-ACCOUNT-KNOWLEDGE-RESULT.md` |
| **DS-17.6A** current data-model validation | Done: production is v1 + additive Journey | `docs/DS-17-06A-DATA-MODEL-VALIDATION-RESULT.md` |
| **DS-17.7** data-model reconciliation | Done: v2 target, staged migration | `docs/DS-17-07-DATA-MODEL-RECONCILIATION-RESULT.md` |
| **DS-17.8** P0 data-model safety | Done 2026-11-18 | `docs/DS-17-08-DATA-MODEL-P0-SAFETY-RESULT.md` |
| **DS-17.9** S1 data-model scaffolding | Done 2026-11-18 | `docs/DS-17-09-DATA-MODEL-S1-SCAFFOLDING-RESULT.md` |
| **DS-17.10** S2A mob model migration | Done: kill/backfill + v2-only reads | `docs/DS-17-10-S2A-MOB-MODEL-RESULT.md` |
| **DS-17.11** S2A mutation parity | Done 2026-11-18 | `docs/DS-17-11-S2A-MUTATION-PARITY-RESULT.md` |
| **DS-17.12** S2B context shape | Done 2026-11-18 | `docs/DS-17-12-S2B-CONTEXT-SHAPE-RESULT.md` |
| **DS-17.13** S3 zone/level ownership | Done 2026-11-18 | `docs/DS-17-13-S3-ZONE-LEVEL-OWNERSHIP-RESULT.md` |
| **DS-17.14** S4A instance ownership | Done 2026-11-18 | `docs/DS-17-14-S4-INSTANCE-OWNERSHIP-RESULT.md` |
| **DS-17.15** S4B instance time | Done 2026-11-18 | `docs/DS-17-15-S4B-INSTANCE-TIME-RESULT.md` |
| **DS-17.16** S5 death ownership | Done 2026-11-18 | `docs/DS-17-16-S5-DEATH-OWNERSHIP-RESULT.md` |
| **DS-17.17** S6 quest/respawn | Done 2026-11-18 | `docs/DS-17-17-S6-QUEST-RESPAWN-OWNERSHIP-RESULT.md` |
| **DS-17.18** S7 heatmap ownership | Done 2026-11-18 | `docs/DS-17-18-S7-HEATMAP-OWNERSHIP-RESULT.md` |
| **DS-17.19** S8 block payload | Done 2026-11-18 | `docs/DS-17-19-S8-BLOCK-PAYLOAD-RESULT.md` |
| **DS-17.20** S9 caps/archive | Done 2026-11-18 | `docs/DS-17-20-S9-CAPS-ARCHIVE-RESULT.md` |
| **DS-17.21** S10 legacy retirement | S10A/S10B done; S10C pending | `docs/DS-17-21-S10A-QUERY-RETIREMENT-RESULT.md` |
| **DS-17.22** S10B UI reads | Done 2026-11-18 | `docs/DS-17-22-S10B-UI-READS-RESULT.md` |
| **DS-17.23** S10C retirement | S10C-1 + V-2A harness done; S10C-2 blocked | `docs/DS-17-23-S10C1-RETIREMENT-READINESS-RESULT.md`, `docs/V-2A-PROBE-HARNESS-RESULT.md` |
| **DS-17.6B** ALT/account validation | Future only | DS-17.7, DS-17.4D, V-2, MEM-1 |
| **H64-10** schema/downgrade decision | Decide schema bump policy | Offline |

## 2. Studies and decisions

| Task | Why | Gate |
|---|---|---|
| **H64-9-F3** display-detail/cell-pool study | Decide whether 32×32 display cap is justified | MEM-1 real samples |
| **H64-9-F5** aspect ratio / occupied mask | Done 2026-11-16 | `docs/H64-9-F5-ASPECT-OCCUPANCY-RESULT.md` |
| **H64-9-F6** art/overlay cost | Offline art mock is inconclusive | R-4 / live visual |
| **DS-8** display redesign study | UI information architecture | None |
| **DS-9** retention/migration | Legacy migration/retention policy | DS-17.5/DS-11 |
| **SC-1** real-store measurement | Done 2026-11-16 | `docs/SC-1-REAL-STORE-MEASUREMENT-RESULT.md` |
| **SC-2** 2x/4x/6x benchmark | Done 2026-11-17 | `docs/SC-2-SCALE-BENCHMARK-RESULT.md` |
| **SC-3** choose tier | Done 2026-11-17 | `docs/SC-3-TIER-DECISION-RESULT.md` |
| **SC-4** context cap | Done 2026-11-17 | `docs/SC-4-CONTEXT-CAP-RESULT.md` |
| **SC-6** capacity self-assessment | Done 2026-11-17 | `docs/SC-6-CAPACITY-SELF-ASSESSMENT-RESULT.md` |
| **SC-5** migration/pruning/tests | Done 2026-11-17 | `docs/SC-5-MIGRATION-PRUNING-RESULT.md` |
| **G-1A** coordinate source/policy review | Done 2026-11-17 | `docs/G-1A-COORDINATE-REVIEW-RESULT.md` |
| **G-1B** heatmap position refresh | Done 2026-11-18 | `docs/G-1B-POSITION-REFRESH-RESULT.md` |
| **G-2** 64 vs 96/128 occupancy | Done 2026-11-17 | `docs/G-2-GRID-OCCUPANCY-RESULT.md` |
| **G-3** grid decision | Done: keep 64x64 | `docs/G-3-GRID-DECISION-RESULT.md` |
| **HC-7** tracking-limit configurability | Done: keep internal limits | `docs/HC-7-LIMIT-CONFIGURABILITY-RESULT.md` |
| **UI-5** heatmap zone/instance selector | Done 2026-11-18 | `docs/UI-5-HEATMAP-ZONE-SELECTOR-RESULT.md` |

## 3. Feature work

- **HIST-1A — historical/outleveled tooltip and Detail.** Done 2026-11-17.
  `docs/HIST-1A-HISTORICAL-RELEVANCE-RESULT.md`.
- **HIST-1B — historical zone surfaces.** Done 2026-11-17.
  `docs/HIST-1B-HISTORICAL-ZONE-RESULT.md`.
- **HIST-1C — bounded quest-anchor log.** Done 2026-11-17.
  `docs/HIST-1C-QUEST-ANCHOR-RESULT.md`.
- **J-1..J-6** Journey overlay.
- **M-1..M-6** cell inspector.
- Tooltip danger, suggested zone, best heatmap part.

These are feature tasks, not verification gates.

## 4. Live-gated only

- **MEM-1** real-client memory samples.
- **V-2** live-only residual checks.
- Final visual/frame confirmation for heatmap/art tasks.
- LoadOnDemand companion variable timing.
- Actual `SAVED_VARIABLES_TOO_LARGE` behavior.

## Recommended order

1. ~~**H64-9-F1 + F2**~~ — done.
2. ~~**H64-9-F4**~~ — done.
3. ~~**R-4**~~ — done.
4. ~~**UI-3 / UI-4**~~ — done.
5. ~~**MEM-2**~~ — done.
6. ~~**IMP-1B11** removal preparation~~ — done.
7. ~~**H64-9-F5**~~ — done.
8. ~~**SC-1**~~ — done.
9. ~~**SC-2**~~ — done.
10. ~~**SC-3**~~ — done.
11. ~~**SC-6**~~ — done.
12. ~~**SC-4**~~ — done.
13. ~~**SC-5**~~ — done.
14. ~~**G-2** grid occupancy study.~~ — done.
15. ~~**G-3** grid decision.~~ — done: keep 64x64.
16. ~~**G-1A** coordinate source/policy review.~~ — done.
17. ~~**G-1B** heatmap commit-time position refresh.~~ — done.
18. ~~**HC-7** tracking-limit configurability decision.~~ — done.
19. ~~**UI-5** heatmap zone/instance selector.~~ — done.
20. ~~**DS-17.4D** account Knowledge prototype.~~ — done.
21. ~~**DS-17.6A** current data-model validation.~~ — done.
22. ~~**DS-17.7** data-model reconciliation/migration plan.~~ — done.
23. ~~**DS-17.8** P0 data-model safety fixes.~~ — done.
24. ~~**DS-17.9** S1 data-model scaffolding.~~ — done.
25. ~~**DS-17.10** S2A mob model migration.~~ — done.
26. ~~**DS-17.11** S2A mutation parity.~~ — done.
27. ~~**DS-17.12** S2B context shape.~~ — done.
28. ~~**DS-17.13** S3 zone/level ownership.~~ — done.
29. ~~**DS-17.14** S4A instance ownership.~~ — done.
30. ~~**DS-17.15** S4B instance time.~~ — done.
31. ~~**DS-17.16** S5 death ownership.~~ — done.
32. ~~**DS-17.17** S6 quest/respawn ownership.~~ — done.
33. ~~**DS-17.18** S7 heatmap ownership.~~ — done.
34. ~~**DS-17.19** S8 block payload v2 completeness.~~ — done.
35. ~~**DS-17.20** S9 adaptive caps, retention, and archive policy.~~ — done.
36. **DS-17.21** S10 legacy retirement. S10A/S10B done; S10C pending.
37. ~~**DS-17.22** S10B UI read retirement.~~ — done.
38. **DS-17.23** S10C live-gated retirement. S10C-1 + V-2A harness done; S10C-2 blocked.
39. **DS-17.6B** ALT/account validation — future only.

V-2 should not block these. Run it when a live client is available and keep it
focused on the live-only table.
