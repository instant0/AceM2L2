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
| **DS-17.4D** account Knowledge prototype | Derive from character SavedVariables | Future alt feature; fully offline |
| **DS-17.6** validation/decision | Consolidate model evidence | Offline |
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
| **G-1** code review | Coordinate limits change | SC-3 |
| **G-2** 64 vs 96/128 occupancy | Next | SC-2/H64-9-F5 |
| **G-3** grid decision | Final grid | G-2 |
| **HC-7** tracking-limit configurability | User-facing limits | SC-3 |

## 3. Feature work

- **HIST-1A — historical/outleveled tooltip and Detail.** Next. Use heatmap,
  kill counts, deaths, rares, and journey anchors; hide stale XP.
- **HIST-1B/1C** historical zone surfaces and bounded quest-anchor log.
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
14. **G-2** grid occupancy study. **Next.**
15. **DS-17.4D / DS-17.6** as the next design block.

V-2 should not block these. Run it when a live client is available and keep it
focused on the live-only table.
