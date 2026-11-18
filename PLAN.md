# AceM2L2 plan

Updated: 2026-11-14  
Current release: **2.5.2**

## Plan map

| Workstream | Status | Task group |
|---|---|---|
| 64x64 heatmap | Measured; F1/F2/F4/F5/R-4/UI-3/UI-4/H64-10 done | H64-9-F3/F6; V-1 |
| Full generated map overlays | Implemented 2.3.0; R-4 audit done | V-5 visual/frame |
| Heat alpha | Superseded by the 2.4.4 gradient | A-3; V-1 |
| Heat intensity/warm colors | Implemented in 2.4.0; gradient in 2.4.4 | HC-1/A-2/A-3; V-1 |
| Data diagnostics | Implemented 2.4.0; instance/heatmap stats in 2.5.0; HC-5 baseline done | HC-2; V-2 |
| XP attribution | Group/remote XP without identity fixed; aggregate only | ATTR-1; V-2 |
| README feature guide | Completed in 2.4.1 | HC-6 |
| Documentation claim audit | Completed; README re-review added UI-3/UI-4 | README-CLAIM-REVIEW |
| Instance attribution and heatmap collection | Implemented in 2.5.0 | G-4a/G-4b; V-1/V-2 |
| UI responsiveness | UI-1..UI-5 done | V-6 visual/frame |
| Client compatibility | 120107 interface added; 12.1.7 API/live audit pending | CL-1; V-6 |
| Release hygiene | Released 2.5.2 | REL-1; V-6 |
| Memory | 3.2–3.85MB real; policy done; guardrails open | MEM-1; V-2 |
| Scope/grid/limit review | Static/offline analysis first | SC-1..SC-5, G-1..G-3, A-1, HC-7; V-3 |
| Data storage architecture | S2A kill/backfill done; mutation parity next | DS-17.11; S2B+; V-2 |
| Character lifecycle and cross-character data | S2A mutation parity next; ALT future | DS-17.11 now; DS-17.6B later; V-2 |
| Journey overlay | Proposed, after DS | J-1..J-6; V-4 |
| Cell inspector | Proposed, after DS | M-1..M-6; V-4 |
| Carbonite | Deferred | CB-0..CB-6 when reopened |
| KillStory split | Deferred | Decision list |
| Final live validation | Deferred until all static work is done | V-1..V-6 |

### Completeness check since 2.3.0

Covered in this plan:

- 64x64 heatmap and migration (2.3.0)
- full generated map overlays and reveal setting (2.3.0)
- stronger heat alpha (2.3.1)
- heat intensity/warm colors and data diagnostics (2.4.0)
- multi-stop heat gradient and gradient legend (2.4.4)
- instance identity/attribution and heatmap collection gate (2.5.0)
- responsive mob list and window layout (2.5.1)
- toggle keybinding removed, minimap/compartment retained (unreleased)
- feature-focused README rewrite (2.4.1)
- grid-resolution/coordinate reliability review
- 2x/4x/6x limit scope review
- API-first storage architecture investigation
- full 1-60 lifecycle, compression, and cross-character leveling-data plan
- Journey overlay proposal
- 4x4 hover cell inspector proposal
- Carbonite and KillStory split deferred work

Structural corrections: completed 2.3.0 full-map work moved out of Deferred;
H64 and CB task IDs added; a plan map and completeness check now precede the
workstreams.

### Validation policy

Default to **static validation first**:

- read the current code and call sites;
- check WoW API documentation and client-loading rules;
- inspect generated data and SavedVariables files offline;
- build synthetic datasets and offline Lua harnesses;
- review release artifacts and README claims against code.

Live in-game checks are consolidated into **one final validation phase** after
the static/open work. Do not create a separate in-game test task for every
feature.

## Recommended execution order

### Phase 1 — static audit of shipped work

Do these first; they are code/data/documentation reviews, not live tests.

Done:

- [x] **H64-8 — Static implementation audit.** Data model, migration, lazy
  cells, cache, and tests reviewed; extra coverage and the rescale fix landed.
- [x] **A-1 + HC-4 — Static heatmap visual review.** Formula, theme colors,
  intensity multiplier, warm palette, cache keys, and theme hook reviewed.
- [x] **A-3 — Multi-stop heat gradient.** Hue + alpha ramp, contrast-based
  intensity, gradient legend, and offline 1..13 spread tests.
- [x] **HC-5 — Offline diagnostics review.** Real store estimate 82,614 vs
  70,661 actual (+16.9%), moderate and extreme synthetic profiles, `totalTracked`
  instance fix, and baseline `docs/HC-5-DIAGNOSTICS-BASELINE.md`.

Next:

1. ~~**H64-9-F1 + F2 — Heatmap rescale/disabled fixes.**~~ **Done 2026-11-16.**
   Result: `docs/H64-9-F1-F2-HEATMAP-RESULT.md`.
2. ~~**H64-9-F4 — Zone-scoped/lazy normalization.**~~ **Done 2026-11-16.**
   Result: `docs/H64-9-F4-ZONE-NORMALIZATION-RESULT.md`.
3. ~~**R-4 — Static overlay/art audit.**~~ **Done 2026-11-16.**
   Result: `docs/R-4-OVERLAY-ART-AUDIT-RESULT.md`.
4. ~~**UI-3 — Death/respawn view.**~~ **Done 2026-11-16.**
   Result: `docs/UI-3-HISTORY-VIEW-RESULT.md`.
5. ~~**UI-4 — Quest XP ledger view.**~~ **Done 2026-11-16.**
   Result: `docs/UI-4-QUEST-LEDGER-RESULT.md`.
6. ~~**MEM-2 — Load/unload and eviction policy.**~~ **Done 2026-11-16.**
   Result: `docs/MEM-2-LOAD-UNLOAD-RESULT.md`.
7. ~~**IMP-1B11 — Rollback retirement preparation.**~~ **Done 2026-11-16.**
   Result: `docs/IMP-1B11-ROLLBACK-RETIREMENT-PREP.md`.
8. ~~**H64-9-F5 — Aspect/occupied-mask study.**~~ **Done 2026-11-16.**
   Result: `docs/H64-9-F5-ASPECT-OCCUPANCY-RESULT.md`.
9. ~~**SC-1 — Real-store measurement.**~~ **Done 2026-11-16.**
   Result: `docs/SC-1-REAL-STORE-MEASUREMENT-RESULT.md`.
10. ~~**SC-2 — 2x/4x/6x benchmark.**~~ **Done 2026-11-17.**
   Result: `docs/SC-2-SCALE-BENCHMARK-RESULT.md`.
11. ~~**SC-3 — Choose a tier.**~~ **Done 2026-11-17.**
   Result: `docs/SC-3-TIER-DECISION-RESULT.md`.
12. ~~**SC-6 — Capacity self-assessment.**~~ **Done 2026-11-17.**
   Result: `docs/SC-6-CAPACITY-SELF-ASSESSMENT-RESULT.md`.
13. ~~**SC-4 — Context cap.**~~ **Done 2026-11-17.**
   Result: `docs/SC-4-CONTEXT-CAP-RESULT.md`.
14. ~~**SC-5 — Migration/pruning/cap tests.**~~ **Done 2026-11-17.**
   Result: `docs/SC-5-MIGRATION-PRUNING-RESULT.md`.
15. ~~**G-2 — Grid occupancy study.**~~ **Done 2026-11-17.**
    Result: `docs/G-2-GRID-OCCUPANCY-RESULT.md`.
16. ~~**G-3 — Grid decision.**~~ **Done 2026-11-17: keep 64x64.**
    Result: `docs/G-3-GRID-DECISION-RESULT.md`.
17. ~~**G-1A — Coordinate source and policy review.**~~ **Done 2026-11-17.**
    Result: `docs/G-1A-COORDINATE-REVIEW-RESULT.md`.
18. ~~**G-1B — Heatmap commit-time position refresh.**~~ **Done 2026-11-18.**
    Result: `docs/G-1B-POSITION-REFRESH-RESULT.md`.
19. ~~**HC-7 — Tracking-limit configurability decision.**~~ **Done 2026-11-18: keep internal limits.**
    Result: `docs/HC-7-LIMIT-CONFIGURABILITY-RESULT.md`.
20. ~~**UI-5 — Heatmap zone/instance selector.**~~ **Done 2026-11-18.**
    Result: `docs/UI-5-HEATMAP-ZONE-SELECTOR-RESULT.md`.
21. ~~**DS-17.4D — Account Knowledge derivation prototype.**~~ **Done 2026-11-18.**
    Result: `docs/DS-17-04D-ACCOUNT-KNOWLEDGE-RESULT.md`.
22. ~~**DS-17.6A — Current data-model validation.**~~ **Done 2026-11-18.**
    Result: `docs/DS-17-06A-DATA-MODEL-VALIDATION-RESULT.md`.
23. ~~**DS-17.7 — Data-model reconciliation and migration plan.**~~ **Done 2026-11-18.**
    Result: `docs/DS-17-07-DATA-MODEL-RECONCILIATION-RESULT.md`.
24. ~~**DS-17.8 — Data-model P0 safety fixes.**~~ **Done 2026-11-18.**
    Result: `docs/DS-17-08-DATA-MODEL-P0-SAFETY-RESULT.md`.
25. ~~**DS-17.9 — S1 data-model scaffolding.**~~ **Done 2026-11-18.**
    Result: `docs/DS-17-09-DATA-MODEL-S1-SCAFFOLDING-RESULT.md`.
26. ~~**DS-17.10 — S2A mob model migration.**~~ **Done 2026-11-18 (kill/backfill).**
    Result: `docs/DS-17-10-S2A-MOB-MODEL-RESULT.md`.
27. **DS-17.11 — S2A mutation parity.** **Next; implementation.**
28. **DS-17.6B — ALT/account-feature validation.** Future; only after migration and ALT scheduling.
21. **MEM-1 — Real memory measurement.** Compare AceM2L2 with ATT/FLG and decide
    whether H64-9-F3 is needed; do not optimize from the 20MB fixture figure.

### Phase 2 — storage evidence

This is the critical path for limits, Journey, and the inspector.

1. **DS-1 — Feature contract and consumer inventory.**
2. **DS-2 — Real-store baseline.**
3. **DS-4 — Storage representation and retrieval design.**
4. **DS-5 — SavedVariables/loading API matrix.**
5. **DS-6 — Static metadata feasibility.** Done 2026-11-16; revised.
6. **DS-3 — Storage sanity check.**
7. **DS-3B — Massive synthetic store validation.**
8. **DS-3C — Long-term growth and cap pressure.**
9. **DS-17.1 — Aggregation and 64x64 sufficiency.**
10. **DS-7 — Packing/compression feasibility.** Done 2026-11-16; required for
   the massive cold tier, not optional.

**DS-1, DS-2, DS-3, DS-3B, DS-3C, DS-4, DS-5, DS-6, and DS-7/DS-12 are
complete.** DS-1 is in
`docs/tasks/DS-1-CONSUMER-CONTRACT.md`; DS-2 is in
`docs/tasks/DS-2-REAL-STORE-BASELINE.md`; DS-3 is in
`docs/DS-3-STORAGE-SANITY-RESULT.md`; DS-3B is in
`docs/DS-3B-MASSIVE-SYNTHETIC-RESULT.md`; DS-3C is in
`docs/DS-3C-LONG-TERM-GROWTH.md`; DS-4 is in `docs/STORAGE-DIRECTION.md`;
DS-5 is in `docs/DS-5-SAVEDVARIABLES-LOADING-MATRIX.md`; DS-17.1 is in
`docs/DS-17-1-AGGREGATION-DECISION.md`; DS-17.2, DS-17.3, DS-1-F2, DS-4P,
DS-4P-F1, DS-4P-F2, DS-6, DS-7/DS-12, and DS-6-F1 are complete.
Next non-live: DS-17.11 (S2A mutation parity). UI-5, HC-7, G-1A/G-1B, and G-2/G-3 are complete; keep 64x64. V-2 is deferred to live-only residual checks.

### Phase 3 — storage design and prototypes

**Full data-model plan:** `docs/DATA-MODEL-PLAN.md`

1. **DS-17.2 — Modes and lifecycle.** Done 2026-11-16.
2. **DS-17.3 — Retention and compression.** Done 2026-11-16.
3. **DS-4P — Hybrid hot/cold prototype.** Done 2026-11-16.
4. **DS-4P-F1 — Hot-index memory optimization.** Done 2026-11-16.
5. **DS-4P-F2 — Scoped/lazy name index.** Done 2026-11-16.
6. **DS-6 — Static metadata feasibility.** Done 2026-11-16; revised after
   review. Result: `docs/DS-6-STATIC-METADATA-RESULT.md`. No all-name list is
   shipped; names are learned live; mobs are zone/instance/grid-localized.
   **DS-6-F1 — Mob metadata registry.** Done 2026-11-16. Result:
   `docs/DS-6-F1-MOB-METADATA-REGISTRY-RESULT.md`.
7. **DS-8 — Display redesign study.**
8. **DS-9 — Retention and migration.**
9. **DS-17.4 — Cross-character knowledge and route recommendations.** Split
   into DS-17.4A–D below.
10. **DS-17.5 — Schema and migration.** Done 2026-11-16. Result:
    `docs/DS-17-05-SCHEMA-AND-MIGRATION-RESULT.md`.
11. **DS-7 + DS-12 — Packed block codec.** Done 2026-11-16. Result:
   `docs/DS-7-12-PACKED-BLOCK-CODEC-RESULT.md`.
12. **DS-13 — On-demand companion packaging.**
13. **DS-14 — Constant-table/oversize guard.** Done 2026-11-16. Result:
    `docs/DS-14-OVERSIZE-GUARD-RESULT.md`.
14. **CAP-1 — Journey capture fields.** Done 2026-11-16. Result:
    `docs/CAP-1-JOURNEY-CAPTURE-FIELDS-RESULT.md`.
15. **IMP-1 — Journey schema/retrieval integration.** Integration slice done
    2026-11-16. Result: `docs/IMP-1-JOURNEY-SCHEMA-RETRIEVAL-RESULT.md`.
16. **IMP-1A — Production Journey instrumentation.** Done 2026-11-16. Result:
    `docs/IMP-1A-JOURNEY-INSTRUMENTATION-RESULT.md`.
17. **IMP-1B — Production Journey query API.** Done 2026-11-16. Result:
    `docs/IMP-1B-JOURNEY-QUERY-RESULT.md`.
18. **IMP-1B2 — Production migration and block storage.** Done 2026-11-16.
    Result: `docs/IMP-1B2-JOURNEY-BLOCK-STORAGE-RESULT.md`.
19. **IMP-1B3 — Journey migration and retrieval integration.** Done
    2026-11-16. Result: `docs/IMP-1B3-BLOCK-RETRIEVAL-RESULT.md`.
20. **IMP-1B4 — Legacy retirement and save/guard integration.** Save/guard
    slice done 2026-11-16. Result: `docs/IMP-1B4-SAVE-GUARD-RESULT.md`.
21. **IMP-1B5 — Tooltip/Detail block fallback and rollback.** Done 2026-11-16.
    Result: `docs/IMP-1B5-TOOLTIP-FALLBACK-RESULT.md`.
22. **IMP-1B6 — Journey mob index.** Index core done 2026-11-16. Result:
    `docs/IMP-1B6-JOURNEY-MOB-INDEX-RESULT.md`.
23. **IMP-1B7 — Mobs list/Overview switch to Journey index.** Done
    2026-11-16. Result: `docs/IMP-1B7-MOBS-LIST-OVERVIEW-RESULT.md`.
24. **IMP-1B8 — Remaining legacy read audit and safe command switch.** Done
    2026-11-16. Result: `docs/IMP-1B8-LEGACY-READ-AUDIT-RESULT.md`.
25. **IMP-1B9 — Areas/Levels parity and switch.** Done 2026-11-16. Result:
    `docs/IMP-1B9-AREAS-LEVELS-RESULT.md`.
26. **IMP-1B10 — Heatmap UI bounded query.** Done 2026-11-16. Result:
    `docs/IMP-1B10-HEATMAP-BOUNDED-RESULT.md`.
27. **IMP-1B12 — Remaining area/level summary reads.** Done 2026-11-16.
    Result: `docs/IMP-1B12-AREA-LEVEL-SUMMARIES-RESULT.md`.
28. **V-2 — Live-only residual verification.** Deferred; live client.
    `docs/tasks/V-2-LIVE-VERIFICATION.md`.
29. **IMP-1B11 — Rollback retirement.** Preparation done 2026-11-16; final removal after V-2.
    `docs/tasks/IMP-1B11-ROLLBACK-RETIREMENT.md`.
14. **DS-17.4A — Journey/Knowledge model validation.** Done 2026-11-16.
    Result: `docs/DS-17-04A-JOURNEY-KNOWLEDGE-MODEL-RESULT.md`.
    **DS-17.4B — Danger and XP/hour prototypes.** Done 2026-11-16.
    Result: `docs/DS-17-04B-DANGER-AND-XP-HOUR-RESULT.md`.
    **DS-17.4C — Retention/aggregation compatibility.** Done 2026-11-16.
    Result: `docs/DS-17-04C-RETENTION-MERGE-COMPATIBILITY-RESULT.md`.
    **DS-17.4D — Account Knowledge derivation prototype.** **Done 2026-11-18.**
    `docs/tasks/DS-17-04D-ACCOUNT-KNOWLEDGE-PROTOTYPE.md`.
15. **DS-15 — Lazy retrieval/cache.** Done 2026-11-16. Result:
    `docs/DS-15-LAZY-RETRIEVAL-CACHE-RESULT.md`.
16. **DS-16 — Save/checkpoint policy.** Done 2026-11-16. Result:
    `docs/DS-16-SAVE-CHECKPOINT-RESULT.md`.
17. **DS-10 — Offline prototype.**
18. **DS-17.6 — Validation and decision.**
19. **DS-11 — Decision record.** Done 2026-11-16. Result:
    `docs/DS-11-DECISION-RECORD.md`.
20. **H64-10 — Schema/downgrade decision.** Decided 2026-11-16: keep
    per-client schema `1`. Result:
    `docs/H64-10-SCHEMA-DOWNGRADE-DECISION-RESULT.md`.

### Phase 4 — limits and grid decisions

Run after DS-2/DS-3 measurements:

1. ~~**SC-1 — Real-store measurement.**~~ **Done 2026-11-16.**
   Result: `docs/SC-1-REAL-STORE-MEASUREMENT-RESULT.md`.
2. ~~**SC-2 — 2x/4x/6x benchmark.**~~ **Done 2026-11-17.**
   Result: `docs/SC-2-SCALE-BENCHMARK-RESULT.md`.
3. ~~**SC-3 — Choose a tier.**~~ **Done 2026-11-17.**
   Result: `docs/SC-3-TIER-DECISION-RESULT.md`.
4. ~~**SC-6 — Capacity self-assessment.**~~ **Done 2026-11-17.**
   Result: `docs/SC-6-CAPACITY-SELF-ASSESSMENT-RESULT.md`.
5. ~~**SC-4 — Context cap.**~~ **Done 2026-11-17.**
   Result: `docs/SC-4-CONTEXT-CAP-RESULT.md`.
6. ~~**SC-5 — Migration/pruning/cap tests.**~~ **Done 2026-11-17.**
   Result: `docs/SC-5-MIGRATION-PRUNING-RESULT.md`.
7. ~~**G-2 — 64 vs 96/128 occupancy study.**~~ **Done 2026-11-17.**
   Result: `docs/G-2-GRID-OCCUPANCY-RESULT.md`.
8. ~~**G-3 — Grid decision.**~~ **Done 2026-11-17: keep 64x64.**
   Result: `docs/G-3-GRID-DECISION-RESULT.md`.
9. ~~**G-1A — Coordinate source and policy review.**~~ **Done 2026-11-17.**
   Result: `docs/G-1A-COORDINATE-REVIEW-RESULT.md`.
10. ~~**G-1B — Heatmap commit-time position refresh.**~~ **Done 2026-11-18.**
    Result: `docs/G-1B-POSITION-REFRESH-RESULT.md`.
11. ~~**HC-7 — Tracking-limit configurability decision.**~~ **Done 2026-11-18: keep internal limits.**
    Result: `docs/HC-7-LIMIT-CONFIGURABILITY-RESULT.md`.
12. ~~**UI-5 — Heatmap zone/instance selector.**~~ **Done 2026-11-18.**
    Result: `docs/UI-5-HEATMAP-ZONE-SELECTOR-RESULT.md`.
13. ~~**DS-17.4D — Account Knowledge derivation prototype.**~~ **Done 2026-11-18.**
    Result: `docs/DS-17-04D-ACCOUNT-KNOWLEDGE-RESULT.md`.
14. ~~**DS-17.6A — Current data-model validation.**~~ **Done 2026-11-18.**
    Result: `docs/DS-17-06A-DATA-MODEL-VALIDATION-RESULT.md`.
15. ~~**DS-17.7 — Data-model reconciliation and migration plan.**~~ **Done 2026-11-18.**
    Result: `docs/DS-17-07-DATA-MODEL-RECONCILIATION-RESULT.md`.
16. ~~**DS-17.8 — Data-model P0 safety fixes.**~~ **Done 2026-11-18.**
    Result: `docs/DS-17-08-DATA-MODEL-P0-SAFETY-RESULT.md`.
17. ~~**DS-17.9 — S1 data-model scaffolding.**~~ **Done 2026-11-18.**
    Result: `docs/DS-17-09-DATA-MODEL-S1-SCAFFOLDING-RESULT.md`.
18. ~~**DS-17.10 — S2A mob model migration.**~~ **Done 2026-11-18 (kill/backfill).**
    Result: `docs/DS-17-10-S2A-MOB-MODEL-RESULT.md`.
19. **DS-17.11 — S2A mutation parity.** **Next; implementation.**
20. **DS-17.6B — ALT/account-feature validation.** Future.

### Phase 5 — proposed features

Only after DS-11:

1. **HIST-1 — Historical/outleveled character value.** HIST-1A/1B/1C done;
   HIST-1D future. See `docs/tasks/HIST-1-HISTORICAL-RELEVANCE.md`.
   - HIST-1A relevance classifier + historical tooltip/Detail. Done
     2026-11-17. Result: `docs/HIST-1A-HISTORICAL-RELEVANCE-RESULT.md`;
   - HIST-1B historical zone surfaces in selected Area Detail with persisted
     overlay toggles. Done 2026-11-17. Result:
     `docs/HIST-1B-HISTORICAL-ZONE-RESULT.md`;
   - HIST-1C bounded quest-anchor log. Done 2026-11-17. Result:
     `docs/HIST-1C-QUEST-ANCHOR-RESULT.md`;
   - HIST-1D account Knowledge integration later.
2. **J-1..J-6 — Journey overlay.**
3. **M-1..M-6 — Cell inspector.**
4. ~~**UI-5 — Heatmap zone/instance selector.**~~ **Done 2026-11-18.**
   Alphabetical name/kills/level-range list in addition to the existing arrows.
   Result: `docs/UI-5-HEATMAP-ZONE-SELECTOR-RESULT.md`.

### Phase 6 — final live validation

Only after all static work:

- **V-1..V-6**, plus deferred Carbonite checks if reopened.

### Storage design objectives

The goal is not "store 350k entries"; it is the best data organization for:

| Objective | What it means |
|---|---|
| **Efficiency** | few bytes per retained fact; sparse cells; short/repeated keys; avoid duplicate views; compression only where it pays |
| **Speed** | fast login/load, kill write, zone/mob/level queries, heatmap normalization, UI refresh, and save/reload |
| **Correctness** | stable mob/instance identity, no double counting, deterministic pruning, aggregation fidelity, migration/backup, client isolation |
| **Reuse** | one canonical store feeding Mobs/Areas/Levels/Heatmap/Journey/Inspector; shared leveling knowledge for alts; static metadata not duplicated per character |
| **Simplicity** | debuggable schema, bounded caches, clear hot/warm/cold boundaries, no per-kill log |

Capacity tiers (100 / 1k / 10k / 100k entries; 350k external reference) are
stress tests, not the design target. A design that only handles 350k rows but is
slow, duplicative, or hard to query is not acceptable.

### Zone-scoped loading and query requirements

The runtime should not need every zone/mob resident for ordinary play:

- **Tooltip:** resolve the hovered mob from the current zone or a compact global
  identity index; never scan/decode every zone. If the zone subset is not
  loaded, fall back to formula/global summary without claiming no data.
- **Heatmap:** load the current zone; on zone switch, load the selected zone and
  evict the previous one unless it fits a small LRU budget.
- **Startup:** load account settings and active-character metadata, not all
  zones, archives, or alts.
- **Switching:** decode only the selected zone block; release or bound the old
  block.
- **Correctness:** a missing subset must fall back predictably, not silently
  show zero kills.
- **Feasibility:** zone-first indexes may require a schema change; DS-4/DS-15
  must prove the query/index design before implementation.

The goal is on-demand subsets that are fast and low-memory **if possible**,
without breaking correctness for tooltip, heatmap, or lists.

### Work packages and grouping

Use these groups to avoid duplicate harnesses and release churn:

| Package | Tasks | Why grouped |
|---|---|---|
| **REL-1** 2.5.2 release hygiene | UI-2, CL-1 interface, HC-5 fix | **Released 2.5.2** |
| **WP-1** heatmap measurement/fixes | H64-9 (done), H64-9-F1/F2/F3/F4, SC-2, DS-3, G-2/G-3 (done) | One synthetic harness; measured rescale/disabled/normalize follow-ups |
| **WP-2** research and targeted evidence | DS-1, DS-4, DS-3, SC-1, DS-2 | Use Lua/WoW docs and code first; test only unresolved behavior |
| **WP-3** storage lifecycle | DS-17.1..DS-17.6, DS-4P/4P-F1/9/11/12/13/14/15/16 | Sequential design: aggregation → modes → compression → shared data → schema → decision |
| **WP-4** overlay audit | R-4 done with R-5/R-9/R-10 | Live visual/frame remains V-5 |
| **WP-5** limits and grid decision | SC-3/SC-4/SC-5, G-3 (done), G-1A/G-1B (done), HC-7 (done) | Depends on WP-1/WP-2 measurements |
| **WP-6** memory | MEM-1, MEM-2, H64-9-F3 (gated) | Measure real memory and define load/unload/eviction |
| **WP-7** future features | J-1..J-6, M-1..M-6 | Blocked by DS-11 |

#### Recommended next sequence

1. **REL-1 — released 2.5.2** with UI-2, CL-1 interface `120107`, and the HC-5
   `totalTracked` fix. Remaining: V-6 runtime installation/UI check.
2. **WP-2 / DS-1 — Consumer inventory and player scenarios.** Define every field
   that must survive for level 1, level 20, max-level/endgame, first alt, and
   10-year-veteran scenarios. No exact content census is needed.
3. **WP-2 / DS-4 — Representation and retrieval design.** **Done 2026-11-14.**
   Working answers in `docs/STORAGE-DIRECTION.md`; no new representation check.
4. **WP-2 / DS-3 — Targeted sanity check.** **Done 2026-11-14.** Save/reload and
   size/cost passed for the small/medium store. This is not a massive-scale
   proof; DS-4P is required for the hybrid.
5. **WP-2 / DS-5 — SavedVariables/loading API matrix.** **Done 2026-11-14.**
   Constraints in `docs/DS-5-SAVEDVARIABLES-LOADING-MATRIX.md`.
6. **WP-2 / DS-2 — Real-store baseline.** **Done 2026-11-14.**
   `docs/tasks/DS-2-REAL-STORE-BASELINE.md`.
7. **WP-2 / DS-3B — Massive synthetic validation.** **Done 2026-11-15.**
8. **WP-2 / DS-3C — Long-term growth and cap pressure.** **Done 2026-11-15.**
9. **WP-3 / DS-17.1** — aggregation and 64×64 sufficiency. **Done 2026-11-16.**
10. **WP-3 / DS-17.2 + DS-1-F2** — lifecycle and in-memory indexes. **Done
    2026-11-16.**
11. **WP-3 / DS-17.3** — retention/compression and hot/warm/cold movement.
    **Done 2026-11-16.**
12. **WP-3 / DS-4P** — hybrid hot/cold prototype. **Done 2026-11-16.**
13. **WP-3 / DS-4P-F1** — hot-index memory optimization. **Done 2026-11-16.**
14. **WP-3 / DS-4P-F2** — scoped/lazy name index. **Done 2026-11-16.**
15. **WP-2 / DS-6 — static metadata feasibility.** **Done 2026-11-16.**
16. **WP-3 / DS-7 + DS-12** — final packed-block codec. **Done 2026-11-16.**
17. **WP-3 / DS-6-F1** — mob metadata registry. **Done 2026-11-16.**
18. **WP-3 / DS-17.4A** — Journey/Knowledge model validation. **Done
    2026-11-16.**
19. **WP-3 / DS-17.4B** — danger and XP/hour prototypes. **Done 2026-11-16.**
20. **WP-3 / DS-17.4C** — retention/aggregation compatibility. **Done
    2026-11-16.**
21. **WP-3 / DS-17.5** — schema, field ownership, migration. **Done
    2026-11-16.**
22. **WP-3 / DS-16** — save/checkpoint policy. **Done 2026-11-16.**
23. **WP-3 / DS-15** — lazy retrieval/cache. **Done 2026-11-16.**
24. **WP-3 / DS-11** — decision record. **Done 2026-11-16.**
25. **WP-3 / DS-14** — oversize guard. **Done 2026-11-16.**
26. **WP-3 / CAP-1** — Journey capture fields. **Done 2026-11-16.**
27. **WP-3 / IMP-1** — Journey schema/retrieval integration. **Slice done
    2026-11-16.**
28. **WP-3 / IMP-1A** — production Journey instrumentation. **Done
    2026-11-16.**
29. **WP-3 / IMP-1B** — production Journey query API. **Done 2026-11-16.**
30. **WP-3 / IMP-1B2** — production migration/block storage. **Done
    2026-11-16.**
31. **WP-3 / IMP-1B3** — Journey migration/retrieval integration. **Done
    2026-11-16.**
32. **WP-3 / IMP-1B4** — legacy retirement/save guard. **Done 2026-11-16.**
33. **WP-3 / IMP-1B5** — tooltip/detail block fallback/rollback. **Done
    2026-11-16.**
34. **WP-3 / IMP-1B6** — Journey mob index core. **Done 2026-11-16.**
35. **WP-3 / IMP-1B7** — Mobs list/Overview switch. **Done 2026-11-16.**
36. **WP-3 / IMP-1B8** — remaining legacy read audit and safe command switch.
    **Done 2026-11-16.**
37. **WP-3 / IMP-1B9** — Areas/Levels parity and switch. **Done 2026-11-16.**
38. **WP-3 / IMP-1B10** — heatmap UI bounded query. **Done 2026-11-16.**
39. **WP-3 / IMP-1B12** — remaining area/level summary reads. **Done
    2026-11-16.**
40. **WP-3 / V-2** — live API/data and SavedVariables verification. **Next.**
41. **WP-3 / IMP-1B11** — rollback retirement after V-2.
42. **WP-1 / H64-9-F1 + F2** — rescale/disabled UI fixes. **Done 2026-11-16.**
43. **WP-1 / H64-9-F4** — zone-scoped/lazy normalization. **Done 2026-11-16.**
44. **WP-4 / R-4** — static overlay/art audit. **Done 2026-11-16.**
45. **WP-5** — limits/grid decisions after measurements.
46. **WP-6 / MEM-1** — dense/future Midnight memory sample, gating F3.
47. **WP-7 / J/M** — only after DS-11.

### Safe execution order for massive storage

This is the low-risk order. Design/offline work comes before production schema or
cap changes.

1. **DS-3B — massive synthetic store validation.** **Done 2026-11-15.**
2. **DS-3C — long-term growth/cap pressure.** **Done 2026-11-15.** Current caps
   are too small; no fixed target.
3. **DS-17.1 — feature-to-data, keys, and 64×64 decision.** **Done 2026-11-16.**
4. **DS-1-F2 — in-memory identity/zone/instance indexes.** **Done 2026-11-16.**
5. **DS-17.2 — lifecycle and archive modes.** **Done 2026-11-16.**
6. **DS-17.3 — retention and hot/warm/cold movement.** **Done 2026-11-16.**
7. **DS-4P — hybrid hot/cold prototype.** **Done 2026-11-16.**
8. **DS-4P-F1 — hot-index memory optimization.** **Done 2026-11-16.**
9. **DS-4P-F2 — scoped/lazy name index.** **Done 2026-11-16.**
10. **DS-6 — static metadata feasibility.** **Done 2026-11-16.**
11. **DS-7 / DS-12 — final packed-block codec.** **Done 2026-11-16.**
12. **DS-6-F1 — mob metadata registry.** **Done 2026-11-16.**
13. **DS-17.4A — Journey/Knowledge model validation.** **Done 2026-11-16.**
14. **DS-17.4B — danger and XP/hour prototypes.** **Done 2026-11-16.**
15. **DS-17.4C — retention/aggregation compatibility.** **Done 2026-11-16.**
16. **DS-17.5 — schema, field ownership, migration.** **Done 2026-11-16.**
17. **DS-16 — save/checkpoint policy.** **Done 2026-11-16.**
18. **DS-15 — lazy retrieval/cache.** **Done 2026-11-16.**
19. **DS-11 — decision record.** **Done 2026-11-16.**
20. **DS-14 — oversize guard implementation.** **Done 2026-11-16.**
21. **CAP-1 — Journey capture fields.** **Done 2026-11-16.**
22. **IMP-1 — Journey schema/retrieval integration.** **Slice done 2026-11-16.**
23. **IMP-1A — production Journey instrumentation.** **Done 2026-11-16.**
24. **IMP-1B — production Journey query API.** **Done 2026-11-16.**
25. **IMP-1B2 — production migration/block storage.** **Done 2026-11-16.**
26. **IMP-1B3 — Journey migration/retrieval integration.** **Done 2026-11-16.**
27. **IMP-1B4 — legacy retirement/save guard.** **Done 2026-11-16.**
28. **IMP-1B5 — tooltip/detail block fallback/rollback.** **Done 2026-11-16.**
29. **IMP-1B6 — Journey mob index core.** **Done 2026-11-16.**
30. **IMP-1B7 — Mobs list/Overview switch.** **Done 2026-11-16.**
31. **IMP-1B8 — remaining legacy read audit and safe command switch.** **Done
    2026-11-16.**
32. **IMP-1B9 — Areas/Levels parity and switch.** **Done 2026-11-16.**
33. **IMP-1B10 — heatmap UI bounded query.** **Done 2026-11-16.**
34. **IMP-1B12 — remaining area/level summary reads.** **Done 2026-11-16.**
35. **V-2 — live-only residual verification.** Deferred; live client.
36. **MEM-2 — load/unload/eviction policy.** **Done 2026-11-16.**
37. **IMP-1B11 — rollback retirement preparation.** **Done 2026-11-16.**
38. **H64-9-F5 — aspect/occupied-mask study.** **Done 2026-11-16.**
39. **SC-1 — real-store measurement.** **Done 2026-11-16.**
40. **SC-2 — 2x/4x/6x benchmark.** **Done 2026-11-17.**
41. **SC-3 — choose a tier.** **Done 2026-11-17.**
42. **SC-6 — capacity self-assessment.** **Done 2026-11-17.**
43. **SC-4 — context cap.** **Done 2026-11-17.**
44. **SC-5 — migration/pruning/cap tests.** **Done 2026-11-17.**
45. **G-2 — 64 vs 96/128 occupancy study.** **Done 2026-11-17.**
46. **G-3 — grid decision.** **Done 2026-11-17: keep 64x64.**
47. **G-1 — coordinate capture code review.** **Next; non-live.**

Do not start global-cap removal, schema migration, the LoadOnDemand companion,
or a production cold tier before step 5 is proven.

### Consolidation candidates

Before executing Phase 2/4, merge overlapping work where practical:

- **H64-9 + SC-2:** one synthetic heatmap harness for 64/96/128 grids,
  1x/2x/4x/6x caps, and sparse/dense zones. DS-3 only uses the storage checks
  that remain unresolved.
- **HC-5 + SC-1 + DS-2:** one real-store/offline diagnostics measurement pass, including the `/mnt/r` reference corpus.
- **DS-4 + DS-10:** one schema prototype harness only if DS-3 leaves a real
  representation question; the live prototype is V-2.
- **DS-7 + DS-12:** one packing study that chooses the codec before implementing
  it.

## Workstreams and status

### 64x64 heatmap — implementation complete; benchmark open

**Status:** static audit done; offline benchmark and schema decision remain.
Live checks are consolidated in V-1. Carbonite work is deferred.

**Implemented**

- `HEATMAP_GRID_SIZE = 64`, `HEATMAP_CELLS = 4096`.
- Generic migration:
  - 16x16 -> 64x64: each cell becomes a 4x4 block.
  - 32x32 -> 64x64: each cell becomes a 2x2 block.
  - 64x64 -> 64x64: copied unchanged.
  - Counts are split evenly with remainders preserved.
- `GetHeatmapZones()` exposes `gridSize`; CLI percentages use the zone's grid.
- Heat cells are created lazily per used index; the panel no longer preallocates
  4,096 textures.
- Incremental refresh updates only changed cells when the zone, geometry, theme,
  and maximum are unchanged; a changed maximum now recolors active cells in
  place, and only zone/layout/theme changes trigger a full rebuild.
- A normalized-heatmap cache prevents copying every cell on each UI refresh.
- 64x64 layout uses a 1px gap only when `stride >= 8`; smaller windows keep
  readable full-stride cells.
- Offline coverage now includes 64x64 capture, 16/32-to-64 migration, lazy cell
  creation, incremental refresh, and cache reuse.
- Discovered-area map overlays are composited above the base zone art using
  `C_MapExplorationInfo.GetExploredMapTextures`; mouseover-only highlights are
  not baked into the static background.

**Remaining**

- [x] **H64-8 — Static implementation audit.** Reviewed the data model,
      migration, lazy-cell paths, incremental refresh, cache invalidation, and
      tests.
      - Added offline coverage for the 40-map cap, duplicate numeric/string map
        keys, legacy remainder distribution, reset/cache invalidation, and
        stale-cell hiding.
      - Fixed a per-kill full rebuild: a new per-zone maximum now recolors
        active cells in place instead of hiding and re-showing the whole pool.
      - Residual risk: a 32x32 save with no `gridSize` and every cell index
        `<= 256` is inferred as 16x16. Saves written since 2.2.0 always carry
        `gridSize = 64`, so this only affects a user skipping 2.2.0. Keep the
        current 16x16 default and document it under H64-10.
- [x] **H64-9 — Offline dense-zone benchmark.** Executed; results in
      `docs/H64-9-BENCHMARK-REPORT.md`; follow-ups in
      `docs/tasks/H64-9-05-FOLLOWUP-WORK.md`. Task documents:
      `docs/tasks/H64-9-00-OVERVIEW.md` (master),
      `docs/tasks/H64-9-01-HARNESS-AND-DATA.md`,
      `docs/tasks/H64-9-02-SCENARIO-MATRIX.md`,
      `docs/tasks/H64-9-03-MEASUREMENTS-AND-REPORT.md`,
      `docs/tasks/H64-9-04-FOLLOWUP-DECISIONS.md`.
      Build a reusable harness for the 64x64 data/UI paths and the later
      SC-2/DS-3 matrix. Record:
      - sparse/medium/dense zones (about 100, 1k, and 4,096 active cells);
      - aspect ratios 1:1, 4:1, 1:4, and irregular map/land shapes, recording
        occupied versus empty cells and effective resolution per axis;
      - first render, repeated kills in one cell, new cells, a new maximum
        (rescale), map switches, theme/intensity changes, resize, and the
        collection-disabled state;
      - full rebuilds vs in-place rescales vs incremental updates;
      - normalization, capture, map-cap pruning (1/40/41 maps), and memory
        growth (`collectgarbage("count")`, table/cell counts);
      - UI operation counts from the fixtures (`CreateTexture`, `SetPoint`,
        `SetSize`, `SetColorTexture`, `Show`, `Hide`) for art/cells/legend;
      - map-art on/off and the current 40-zone cap.
      Report relative scaling and operation counts, not live frame rate. Live
      frame cost remains in V-1. Output: reusable benchmark harness plus a short
      report usable by SC-2/DS-3.
  - [x] **H64-9.1 — Harness and data.**
  - [x] **H64-9.2 — Scenario matrix.**
  - [x] **H64-9.3 — Measurements and report.**
  - [x] **H64-9.4 — Follow-up decisions.**
  - [x] **H64-9-F1 — Rescale path optimization.** Executed 2026-11-16. No
    geometry/Show work when only color changes. Result:
    `docs/H64-9-F1-F2-HEATMAP-RESULT.md`.
  - [x] **H64-9-F2 — Disabled-state hide guard.** Executed 2026-11-16. First
    disabled refresh hides once; repeats do no per-cell work. Result:
    `docs/H64-9-F1-F2-HEATMAP-RESULT.md`.
  - [ ] **H64-9-F3 — Display detail/cell-pool study.** Gated by MEM-1. Dense
    fixture memory ~20MB is fixture-object memory, far below the ATT 51–686 MB reference range and
    FLG 48MB; evaluate 32x32 display only if real client memory or V-1 warrants
    it. `docs/tasks/MEM-1-MEMORY-BUDGET.md`.
  - [x] **H64-9-F4 — Zone-scoped/lazy normalization.** Executed 2026-11-16.
    Metadata-only zone index plus selected-zone normalization/cache. Result:
    `docs/H64-9-F4-ZONE-NORMALIZATION-RESULT.md`.
  - [x] **H64-9-F5 — Aspect/occupied-mask follow-up.** Executed 2026-11-16.
    Real spans near-square; wide/tall synthetic cheaper; keep 64×64, no mask.
    Result: `docs/H64-9-F5-ASPECT-OCCUPANCY-RESULT.md`.
  - [ ] **H64-9-F6 — Art/overlay cost follow-up.** Offline art cost inconclusive;
    feed R-4/V-5.
- [x] **H64-10 — Schema/downgrade decision.** Decided 2026-11-16: keep
      per-client schema `1`; document/test the legacy 16/32 inference. Result:
      `docs/H64-10-SCHEMA-DOWNGRADE-DECISION-RESULT.md`.
- Live checks: consolidated under V-1.

### Client compatibility — 12.1.7 readiness

- [x] **REL-1 — 2.5.2 release hygiene.** Released 2.5.2 with UI-2 keybinding
  removal, CL-1 `120107` interface support, and HC-5 `totalTracked` fix.
  Version/docs/SHA updated; both archives built; `CHECK_RELEASE=1` passed.
  Remaining: V-6 runtime installation/UI check.
- [x] **MEM-2 — Load/unload and eviction policy.** Executed 2026-11-16.
  Bounded block/heatmap caches, UI release, transient-cache release, diagnostics,
  and tests. Result: `docs/MEM-2-LOAD-UNLOAD-RESULT.md`.
- [ ] **MEM-1 — Memory footprint and budget.** Real samples: latest 2.5.2
  Hunter 389 kills / 25 mobs, UI open = **3.2 MB**; Priest 762 kills / 85 mobs,
  Silverpine heatmap open (408 kills) = **3.85 MB**. ATT reference range is
  51–686 MB (a main-character report showed **686 MB**); ForeverLevelingGuide
  is 48 MB. Ordinary-play samples do not justify H64-9-F3; keep it gated for
  unusually dense or future Midnight profiles.
  `docs/tasks/MEM-1-MEMORY-BUDGET.md`.
- [ ] **CL-1 — Midnight 12.1.7 readiness.** Interface `120107` confirmed by an
  external TOC and shipped in 2.5.2 alongside `120105`/`16001`. Retail is still
  **12.1.5.70783**; 12.1.7 is PTR **12.1.7.70892** as of 2026-11-14. Remaining:
  API audit, map-overlay decision, PTR/live install check, V-6. Full task:
  `docs/TASK-CL-1-MIDNIGHT-12.1.7.md`.

### UI responsiveness — implemented in 2.5.1

- [x] **UI-1 — Responsive mob list and window layout.** Implemented in 2.5.1.
  Live confirmation: multiple mobs, resize, and scrolling work. Fix the fixed
  13-row list, one-time row width, clipped kills text on narrow windows, and the
  hard 1400 px maximum width. Full specification:
  `docs/TASK-UI-1-RESPONSIVE-LIST.md`.
- [x] **UI-2 — Remove the toggle keybinding.** Removed `Bindings.xml`, the TOC
  entry, binding globals, and the public binding function. Kept `Bindings.lua`
  for the addon-compartment entry point and the minimap icon.
- [x] **UI-3 — Death and respawn history view.** Executed 2026-11-16. Result:
  `docs/UI-3-HISTORY-VIEW-RESULT.md`.
- [x] **UI-4 — Quest XP ledger view.** Executed 2026-11-16. Result:
  `docs/UI-4-QUEST-LEDGER-RESULT.md`.
- [x] **UI-5 — Heatmap zone/instance selector.** Executed 2026-11-18.
  Alphabetical name/kills/level-range list in addition to the arrows.
  Result: `docs/UI-5-HEATMAP-ZONE-SELECTOR-RESULT.md`.

### Instance attribution and heatmap collection — implemented in 2.5.0

**Status:** released; residual live checks are in V-1/V-2.

**Implemented**

- `IsInInstance()` is the authoritative inside/outside-dungeon signal; the map
  ID never decides instance state.
- Instance state is cached from zoning events and checked cheaply per kill;
  `GetInstanceInfo()` is queried on transitions or mismatches, not every kill.
- Instance kills are stored in `db.instances`, `mob.killsByInstance`, and
  `mob.killsByInstanceLevel`; open-world kills stay in `areas`/`killsByMap`.
- Instance keys use the instance map ID and difficulty, then the normalized
  name, then `unknown`.
- Historical world-map rows (for example map 947/Azeroth) migrate once to an
  "Unattributed instance" record with level breakdowns preserved.
- `heatmapEnabled` is a master collection switch. Disabling it stops capture,
  normalization, exploration-event registration, and new saving; the Heatmap
  tab stays visible with a disabled message.
- The clear action is available from diagnostics and
  `/acem2l2 xpt heatmap clear`.
- Diagnostics reports instances, instance kills, heatmap collection state, and
  estimated heatmap bytes.

**Validated offline**

- Captured Forever data: 145 instance kills migrated to
  `legacy:947`; level 20 kept 145; `Skeleton` kept 28 instance kills; dungeon
  totals stayed 145 kills / 7,455 XP.
- 334 static assertions; all seven client scenarios pass.

**Residual risks**

- `GetInstanceInfo()` exposes an instance map ID, not a unique instance ID;
  clients without it fall back to the normalized name.
- Instances without an attributable UiMap have no heatmap or death-location
  data.
- Live persistence and UI behavior remain in V-2/V-1.

### Documentation claim audit — completed

Most headline features are implemented. The audit found several claims that
were client-specific, best-effort, or overstated; the player and promotional
docs were corrected.

| Claim area | Status | Notes |
|---|---|---|
| XP, kills-to-level, reputation repeats | Implemented | Core XP/reputation and chat output. |
| Kill Story tabs and mob/area/level history | Implemented | Overview, Mobs, Areas, Heatmap, Levels; session shown as current totals. |
| Quest XP ledger | Quests tab and command implemented, Forever-only | `/acem2l2 xpt quests` and the Quests tab; explicit unsupported state elsewhere. |
| Level history and splits | Implemented | Level-time/kill splits, not route-segmented speedrun splits. Wording corrected. |
| Dungeon XP, goals, splits | Implemented | Dungeon XP is Forever-only; goals/splits work on both clients. Docs now qualify it. |
| Loot value, gold/hour, gear upgrades | Implemented | Gear alerts compare item level and depend on readable item/equipped data; live-unverified. |
| Deaths, respawns, grinding spots | Commands, History tab, and Overview | Deaths/respawns are in the History tab and commands; grinding spot is Overview/Forever. |
| Heatmap and zone art | Implemented where client data exists | 64x64 now; base art uses `C_Map.GetMapArtLayers`/`GetMapArtLayerTextures`, with discovered-area overlays. No legacy art fallback; README now says “where available.” |
| Nameplate levels | Implemented, Midnight-only | Off by default; sightings still feed respawn tracking. |
| 3D model | Implemented | A model hero card with fallback, not a browsable 3D gallery. Wording corrected. |
| Search, filters, sort, themes, minimap, compartment | Implemented | UI/List, UI/Theme, UI/Minimap, Bindings.lua, TOC. |
| Settings sections and Tooltip/Heatmap subpages | Implemented | Native Settings API and client-gated sections. |
| Per-client storage and secret-data handling | Implemented and tested | Separate Forever/Midnight namespaces; defensive API reads. |
| Documented caps | Implemented | Adaptive mobs (500/zone, min 2,000, max 12,000), adaptive quests (100/zone, min 500, max 10,000), 4,000 respawn NPCs/20 samples, 100 deaths, 200 level records, 240 rate samples, 64 heatmap zones, 100 instance records, 20 instance keys per mob. |
| Midnight XP/rate/calibration/rested/grinding off | Implemented | Midnight profile capabilities are intentionally disabled. |
| "Live verification pending" | Accurate caveat | Quest/dungeon/group XP semantics, gear compare, heatmap art/performance, instance attribution/persistence, heatmap collection gating, and several Midnight paths still need live verification. |

**Documentation corrections made**

- Replaced "speedrun splits" with "level-time splits".
- Replaced "3D mob browser" with "3D mob model card".
- Softened "clear gear-upgrade notifications" to "gear-upgrade notifications".
- Clarified that quest XP, dungeon XP, and grinding spots are Forever-only.
- Removed the inaccurate legacy `GetMapInfo` heatmap-art claim.
- Updated all current 32x32 references to 64x64; historical changelog entries
  remain as history.

### Scope increase review — proposed, not implemented

**Status:** analysis only. Heat alpha/controls changed in 2.3.1/2.4.0; no storage
or grid limits changed. Current limits are safety/performance caps, not measured
behavioral limits.

#### Heat color

- Existing ramp: `0.30 + 0.70 * density`.
- 2.3.1 ramp: `0.45 + 0.55 * density^0.70`.
- The floor is higher and mid-density cells are boosted without changing the
  theme color.
- Static review first; live visual check is deferred to V-1.
- Heat intensity (50-200%) and warm colors are now implemented in 2.4.0; live
  visual verification remains (A-1; live in V-1).

#### Grid resolution and coordinate reliability

- Current data grid: 64x64 (4,096 cells).
- Heatmap coordinates are captured by `CaptureUnit` from
  `C_Map.GetPlayerMapPosition`, which is the **player's** position, not the
  mob's position.
- `UNIT_DIED` uses the last target/mouseover capture; if a target is held for a
  long fight, the stored position can be several seconds old.
- Ranged/nameplate kills can be far from the player's position.
- 64x64 is about 1.6% of zone width per cell; 128x128 is about 0.8%. API float
  precision is not the limiter; capture semantics are.
- A 128x128 grid quadruples cells, storage, and potential UI textures. Dense
  zones would be much heavier, and small windows would show 3-4 px cells.
- Recommendation: do not raise the grid yet. First improve/measure capture, then
  compare 64 vs 128 occupancy and noise. A 128 cap could be stored with a 64
  display fallback, but that gives no visual gain in small windows.

#### Current limits: guestimates or measured?

They are fixed engineering caps, not derived from collected telemetry. The repo
has no recorded usage distribution or benchmark behind the values. The old
`MAX_MOBS = 2000` was enforced by a test, but that only proved the cap worked;
it did not justify the number. It is now replaced by an adaptive limit:
500 per visited area/instance, minimum 2,000, hard ceiling 12,000. Other caps
remain conservative safety rails.

#### Proposed scope tiers (review only)

| Limit | Current | 2x | 4x | 6x |
|---|---:|---:|---:|---:|
| Mobs | 2000–12000 adaptive | 4000+ | 8000+ | 12000 |
| Contexts per mob | 12 | 16 | 20 | 24 |
| Quests | 200 | 400 | 800 | 1200 |
| Level records | 200 | 400 | 800 | 1200 |
| Rate samples | 240 | 480 | 960 | 1440 |
| Deaths | 100 | 200 | 400 | 600 |
| Respawn NPCs | 300 | 600 | 1200 | 1800 |
| Respawn samples | 20 | 30 | 40 | 60 |
| Heatmap zones | 40 | 80 | 160 | 240 |
| Context age | 120d | 180d | 240d | 360d |

Do **not** scale contexts linearly without measurement; they dominate mob-entry
size. `MAX_PENDING_DEATHS`, visible rows, grinding thresholds, and
`MAX_HEATMAP_COUNT` are runtime/algorithm guards, not storage-scope limits.

#### Rough storage impact

- A synthetic worst-case 2000-mob/12-context dataset is about 6-7 MB of
  SavedVariables text; real data is smaller.
- A blanket 6x with 72 contexts per mob is unsafe: synthetic worst-case exceeds
  100 MB.
- 2x with 16 contexts is the lowest-risk tier; 4x needs measurement; 6x needs
  compaction/pruning or a different storage format.
- Heatmap zones are sparse in normal play. Dense 64x64 data grows roughly with
  zone count; 128x128 compounds it fourfold.
- These numbers are planning estimates, not acceptance thresholds.

#### Review tasks

- [x] **SC-1 — Measure the current real store.** Executed 2026-11-16. Result:
      `docs/SC-1-REAL-STORE-MEASUREMENT-RESULT.md`. Long-lived/dense/Midnight
      saves remain optional future samples.
- [x] **SC-2 — Benchmark 2x/4x/6x.** Executed 2026-11-17. Result:
      `docs/SC-2-SCALE-BENCHMARK-RESULT.md`.
- [x] **SC-3 — Choose a tier.** Decided 2026-11-17: accept 6×; adaptive mob and
      quest caps; respawn cap 4,000; heatmap zones 64; no blanket increases.
      Result: `docs/SC-3-TIER-DECISION-RESULT.md`.
- [x] **SC-4 — Protect contexts.** Decided/validated 2026-11-17: hot cap 12,
      cold top-8+other policy. Result: `docs/SC-4-CONTEXT-CAP-RESULT.md`.
- [x] **SC-5 — Migration/pruning/cap tests.** Executed 2026-11-17. Result:
      `docs/SC-5-MIGRATION-PRUNING-RESULT.md`.
- [x] **G-1A — Coordinate source and policy review.** Executed 2026-11-17.
      Result: `docs/G-1A-COORDINATE-REVIEW-RESULT.md`. Decided kill-time,
      replace-only, local-player group policy, same-map guard, no attribution
      change, and deferred unit/world-position APIs.
- [x] **G-1B — Heatmap commit-time position refresh.** Executed 2026-11-18.
      Result: `docs/G-1B-POSITION-REFRESH-RESULT.md`. Heatmap-only refresh at
      the `RecordHeatmapKill` call; replace-only; same-map guard; no
      attribution change.
- [x] **G-2 — 64 vs 96/128 occupancy study.** Executed 2026-11-17; keep 64.
      Compared occupancy, trail noise, aspect, hotspot stability, and offline
      storage/render envelopes for 64/96/128 plus rectangular and mask options.
      Result: `docs/G-2-GRID-OCCUPANCY-RESULT.md`.
- [x] **G-3 — Decide grid.** Decided 2026-11-17: keep the durable 64x64 grid;
      reject 96/128, rectangular durable, and occupied mask.
      Result: `docs/G-3-GRID-DECISION-RESULT.md`.
- [x] **G-4a — Instance identity and attribution.** Implemented in 2.5.0. Detect inside/outside
      dungeon state with `IsInInstance`, cache it from zoning events, store
      instance kills in `db.instances`/`mob.killsByInstance`, stop attributing
      map-less instances to Azeroth (947), and migrate historical world-map
      rows honestly. Ship first.
- [x] **G-4b — Heatmap collection gate.** Implemented in 2.5.0.
      Add `heatmapEnabled` to stop heatmap
      capture, normalization, event registration, and new saving when off. Keep
      the tab visible with a disabled message; `showHeatmap` remains the
      tab-only control. Ship after G-4a.
      Residual live checks: V-2 for instance attribution, legacy migration, and
      collection persistence; V-1 for the disabled-tab state and event gating.
- [x] **A-1 — Static alpha-ramp review.** Verified the 2.3.1 alpha-only ramp,
      intensity multiplier, warm palette, theme accent fallback, and cache key.
      Superseded by A-3. Live visual comparison is deferred to V-1.
- [x] **A-2 — Heat intensity/warm-color setting.** Implemented in 2.4.0;
      live verification is consolidated in V-1.
- [x] **A-3 — Multi-stop heat gradient.** Implemented in 2.4.4. Revised scope:
      - Three-stop RGB ramp: theme accent (low) -> gold (mid) -> red (high);
        the fire setting swaps in amber -> orange -> deep red.
      - Alpha rises from a weak floor to full strength, so the weakest cell is
        visibly weaker than the hottest.
      - Intensity (50-200%) now reshapes the alpha floor and gamma instead of
        multiplying the final alpha and clamping. At 200% contrast increases
        instead of every cell becoming fully opaque.
      - The legend is a 15-swatch Low-to-High gradient bar.
      - `XPTooltip.GetHeatColor` is exposed for offline verification.
      - Tests use a 1..13 count spread: hue and alpha are distinct at low, mid,
        and high counts; 200% does not collapse the ramp; the legend swatches
        span the palette.
      - Live visual confirmation remains in V-1.

### Heatmap controls and data diagnostics — implemented in 2.4.0; extended in 2.5.0

**Status:** static heatmap review done; offline diagnostics review open; live
checks in V-1/V-2.

**Heatmap controls**

- `heatmapIntensity` (50-200%, default 100%) is under Settings > Heatmap.
  It reshapes the gradient floor and gamma: higher values increase contrast,
  lower values flatten it.
- `heatmapWarmColors` (off by default) switches the gradient from the theme
  accent/gold/red ramp to an amber/orange/deep-red fire ramp.
- The current ramp is a three-stop colour gradient (theme accent -> gold -> red)
  with alpha rising from a weak floor to 1.0.
- Both settings invalidate the heat-cell color cache and refresh the panel.

**Data diagnostics**

- Added a diagnostics frame with per-character/per-client counts, limits, usage
  percentages, heatmap cells, heatmap collection state/bytes, instances and
  instance kills, contexts, calibration entries, total tracked entries, and an
  approximate store size.
- Open it with **middle-click on the minimap icon** or `/acem2l2 xpt data`.
- The frame is draggable, Escape-closable, and has Refresh/Close buttons plus a
  Clear heatmap action.
- Size is an estimate from a bounded recursive traversal, not a SavedVariables
  file-size API. It is labeled as approximate.
- Counts clarify that the 2000-mob cap is **per character and per client across
  all zones**, not per zone.

**Limit scope clarification**

- Mobs: total unique mob entries for this character/client, all maps combined.
  Silverpine's 500 mobs consume 25% of that character's global mob budget.
- Quests: unique quest-ledger entries for this character/client, not per zone.
- Deaths: the last 100 death locations for this character/client; separate from
  heatmaps.
- Heatmaps: up to 40 map IDs/zone grids, separate from the mob cap.
- Respawns: 300 NPCs with 20 intervals each, per character/client.
- Level records: 200 level-up records; rate samples: 240 recent XP samples.
- Contexts: 12 calibration contexts per mob, globally per character/client.

**Tasks**

- [x] **ATTR-1 — Group/remote XP without identity.** Fixed 2026-11-16. Identity-
      less group XP is stored as `unattributed` XP, not a fake `name:unknown`
      mob. It contributes XP/rate/level history, not kills/areas/heatmaps.
      Result: `docs/ATTR-1-GROUP-UNATTRIBUTED-XP.md`.
- [x] **HC-1 — Heatmap intensity/color settings.**
- [x] **HC-2 — Data diagnostics frame and icon/command access.**
- [x] **HC-3 — Clarify cap scope in README/BROCHURE and diagnostics.**
- [x] **HC-4 — Static visual-code review.** Verified the ramp, warm palette,
      intensity clamp, theme accent key, `renderedMaximum` rescale path, and
      `hooksecurefunc` theme refresh. Live visual comparison is deferred to V-1.
- [x] **HC-5 — Offline diagnostics review.** Compared the estimate with the
      real 70,661-byte store (82,614 estimate, +16.9%), a moderate synthetic
      profile, and an extreme truncated profile. Fixed `totalTracked` to include
      instances. Baseline: `docs/HC-5-DIAGNOSTICS-BASELINE.md`. Live
      real-character comparison is deferred to V-2.
- [x] **HC-6 — Player README rewrite.** README.txt is now a concise feature
      guide with a short performance/data note.
- [x] **HC-8 — Heatmap Settings subpage.** Heatmap tab/reveal/intensity/warm
      controls moved out of Tooltip into Settings > Heatmap.
- [x] **HC-7 — Decide whether tracking limits become player-configurable.**
      Decided 2026-11-18: keep internal adaptive limits; no player-facing cap
      controls. Result: `docs/HC-7-LIMIT-CONFIGURABILITY-RESULT.md`. Revisit
      after MEM-1/live memory guardrails.

### Data storage architecture investigation — plan only

**Status:** investigation plan; no storage changes implemented. Working
direction: `docs/STORAGE-DIRECTION.md`; consolidated addon/method research and
strategy: `docs/STORAGE-STRATEGY.md`.

**Why:** the 2000-mob cap is **per character, per client, across all zones**.
A zone with 500 unique mobs consumes 25% of that character's entire mob budget,
so other zones lose detail. The cap counts unique mob identities, not kill
events.

**Important correction:** the current model is already aggregated, not a
per-kill log. Each mob entry stores counts such as `killsAtLevel`,
`killsByMap`, `killsByAreaLevel`, and `contexts`. The user's example — 15 kills
at level 15 and 300 at level 16 of one mob in one zone — is already close to
`killsByAreaLevel[zone][level] = count`. The problem is the **global mob-entry
cap and the shape of the tables**, not per-kill storage.

#### Questions to answer

1. Can a zone-first schema retain detail for many more zones without a global
   2000-mob ceiling?
2. Can mob identity (name, NPC ID, classification) be separated from per-zone
   counts so the same NPC is not duplicated across zones?
3. Do we need per-cell mob/level detail, or is the heatmap sufficient as a
   separate aggregate plus a zone-level mob list?
4. Can static metadata be shipped as Lua, like QuestieDB, to shrink saved data?
   (Answered by DS-6/F1: no all-name list; account-wide stable metadata for
   `npc:<id>`, per-character name-only metadata, and no pre-kill spawn data
   required.)
5. Does the client support multiple SavedVariables, per-character variables, or
   LoadOnDemand variables usefully? (No per-zone SavedVariables files exist.)
6. Which WoW loading/SavedVariables APIs let us store compactly and expand on
   demand? Addon implementations are reference patterns only; their data is not
   copied.

#### Storage candidates

- **A — Current global mob table.** One `db.mobs[mobKey]` per unique mob with
  zone/level sub-tables. Simple, but globally capped and duplicates identity
  across zones only once globally.
- **B — Identity/count split.** Small `mobIndex[mobKey] = {name, npcID,
  classification}` plus `zoneCounts[zone][mobKey][level] = count` and optional
  per-cell counts. Allows per-zone caps and preserves global identity.
- **C — Zone-first records.** `zones[mapID].mobs[mobKey] = {levels={...},
  cells={...}}`, with a shared identity registry. Natural for zone pages and
  per-zone pruning.
- **D — Heatmap-only aggregate.** Sum all mobs per cell and drop per-mob detail
  for cells. Smallest, but loses "which mob" and level breakdown; only viable
  as a display aggregate, not the primary store.
- **E — Static metadata DB.** Ship NPC/mob/zone metadata as a TOC-loaded Lua
  database (QuestieDB style); saved data stores IDs and counts only.
- **F — Packed/compressed history.** Store per-zone count blocks as packed
  strings or compressed blobs, decode lazily; reduces file size, increases CPU
  and migration complexity.
- **G — Multiple SavedVariables / LoadOnDemand.** Split settings, per-character
  history, and cold zone data. Multiple SV variables are supported but load
  together; only a LoadOnDemand companion can defer. The client has no per-zone
  SV files, and companion saved-variable timing is a V-2 measurement.

#### WoW API surface to use

The design should be driven by the client API, not by another addon's data.

- **SavedVariables directives:** `SavedVariables` and
  `SavedVariablesPerCharacter` accept comma-separated names. Multiple variables
  are allowed; account and character scopes are separate.
- **Load order:** default is addon files → SavedVariables → `ADDON_LOADED`;
  `ADDON_LOADED` is the earliest reliable read point. `LoadSavedVariablesFirst: 1`
  moves SavedVariables before the addon files. It exists on the targeted
  retail/PTR/Forever clients.
- **Multiple variables:** all normal SavedVariables load together. Adding
  variables does not defer them; only a LoadOnDemand companion can defer.
- **On-demand addon:** `## LoadOnDemand: 1` plus
  `C_AddOns.LoadAddOn(name)`, which returns `loaded, reason`. Detect with
  `C_AddOns.DoesAddOnExist`, `C_AddOns.IsAddOnLoadOnDemand`,
  `C_AddOns.IsAddOnLoadable`, and `C_AddOns.IsAddOnLoaded` (returns
  `loadedOrLoading, loaded`). Do not call `LoadAddOn` inside an `ADDON_LOADED`
  handler; the companion may never receive its own `ADDON_LOADED`. Use
  `PLAYER_LOGIN`, a user action, or a later timer/event. Its `ADDON_LOADED`
  marks availability.
- **Metadata:** `C_AddOns.GetAddOnInfo`, `GetAddOnMetadata`,
  `GetAddOnInterfaceVersion`, `GetAddOnDependencies`, and
  `GetAddOnOptionalDependencies` for compatibility and capability checks.
- **Explicit save/compaction:** `C_AddOns.SaveAddOns()` requests a save. Treat
  it as a checkpoint, not a per-kill write; no synchronous disk-durability
  guarantee is documented.
- **Oversize signal:** `SAVED_VARIABLES_TOO_LARGE` fires after `ADDON_LOADED`
  when saved variables cannot load because of an out-of-memory error. It can
  affect account and/or per-character variables, and the variables will not save
  on the next logout. Treat it as a load-failure/recovery path, not a normal size
  warning. The client also emits `ADDONS_UNLOADING: closingClient` before unload;
  use it for a final checkpoint, not as a guaranteed flush.
- **Practical limits:** there is no documented hard file-size limit, but the
  Lua VM's constant-table limit is roughly 262,144 unique literal values per
  file. Large plain tables can also hit practical 50-60 MB write problems. This
  is why packed strings and split variables matter.

#### Reference patterns, not data to copy

Use the addon implementations to learn API and loading patterns only. Do not
copy their databases, saved data, or schemas verbatim.

- **AllTheThings:** multiple `SavedVariables` plus
  `SavedVariablesPerCharacter` in the TOC; large static database under `db/`
  loaded as Lua, with account/character completion data separate.
- **Carbonite:** one `CarbData` AceDB with `profile`, `global`, and `char`
  scopes; `DataPersistence` exposes `Nx.CurCharacter` and
  `db.global.Characters`. Per-character data lives inside the global SV table.
- **Questie / QuestieDB:** `QuestieDB` is a separate Lua database addon, while
  Questie uses `QuestieConfig` and per-character `QuestieConfigCharacter`;
  Questie's TOC sets `LoadSavedVariablesFirst: 1`.
- **ForeverLevelingGuide:** closed/paid; inspect the installed addon during the
  investigation, but do not assume its internals. Likely static guide data plus
  per-character progress.
- **WoW SavedVariables:** multiple variables and account/per-character scopes
  are supported; no per-zone files. `LoadSavedVariablesFirst` changes load
  order. Test the historical Forever SavedVariables read/write bug on 1.60.1.

#### API-driven storage design

The target is **small persistent indexes plus packed cold blocks, expanded on
demand**, not one huge Lua table.

1. **Main index (small, always loaded).** Schema version, per-character summary,
   zone IDs, block lengths/checksums, and global totals. This supports the
   Overview, tooltips, diagnostics, and zone paging without touching cold data.
2. **Cold zone blocks.** One packed string per zone (or per zone/level group):
   numeric IDs, varint/delta counts, optional bit-packed level/cell entries.
   A block is decoded only when its zone is selected, then cached in an LRU
   with a small cap.
3. **Write path.** Update the active block in memory; re-pack only that block.
   Periodically compact append-only deltas. `SaveAddOns` is a checkpoint after
   major changes, not a per-kill operation.
4. **Optional companion addon.** Put cold blocks in a second addon with
   `LoadOnDemand: 1`. The main addon calls `C_AddOns.LoadAddOn` when history is
   opened. Test whether that companion's SavedVariables load only on demand on
   both clients; if not, keep the split for constant-table isolation only.
5. **Static metadata.** Ship generated official Lua metadata (NPC/zone IDs,
   names, levels, classification) so saved blocks contain numeric IDs and counts,
   not repeated strings.
6. **Safety.** Version/checksum every block, keep one previous block/backup,
   handle `SAVED_VARIABLES_TOO_LARGE`, and stay below the Lua constant-table
   limit by using packed strings rather than thousands of literals.

**Retrieval rules:** never load every zone to build a tooltip or the Mobs tab.
Use the index for totals and the active zone blocks for detail. Decode on
selection, keep a bounded cache, and drop cold blocks when the cache exceeds its
budget.

#### Proposed experiments

1. **Inventory consumers.** List every feature that reads mob data: Mobs tab,
   Areas/Levels, tooltips, calibration, heatmap, deletion, deletion-unknown,
   respawns, and migration.
2. **Measure the current store.** Use the 2.4.0 Data diagnostics panel plus a
   real SavedVariables file to record counts, contexts, heatmap cells, and
   bytes for the available real samples and projected zone-heavy characters.
3. **Build synthetic datasets.** One zone with 500 mobs, many zones, sparse and
   dense levels, 1x/2x/4x/6x caps. Record bytes, load time, prune time, UI
   build time, and heatmap normalize/refresh time.
4. **Prototype schemas offline.** Implement A–D in a Lua harness using the same
   read/write patterns; compare bytes and query complexity.
5. **Map SavedVariables/loading APIs from docs and source.** Document
   `SavedVariables`/`SavedVariablesPerCharacter`, `LoadSavedVariablesFirst`,
   `C_AddOns.LoadAddOn`, `IsAddOnLoaded`, `DoesAddOnExist`,
   `IsAddOnLoadOnDemand`, `SaveAddOns`, and `SAVED_VARIABLES_TOO_LARGE`.
   Confirm LoadOnDemand companion timing at runtime in V-2, not here.
6. **Evaluate the per-character mob metadata registry.** No all-name list.
   Learn name, fixed level range, and at most 4 zone/instance refs from live
   kills. A pre-kill spawn index is deferred. Do not copy QuestieDB/ATT/
   Carbonite data. Use official client data or our own observations.
7. **Evaluate packing.** Compare plain tables, numeric-only arrays, packed
   strings, and compression; measure save/load/CPU and debuggability.
8. **Design display.** Zone-scoped mob list with a level filter; heatmap cell
   aggregate plus optional "top mobs in this cell" list; avoid discarding
   identity just to fit the grid.

#### Tasks to investigate

- [x] **DS-1 — Feature contract and consumer inventory.** Contract in
  `docs/tasks/DS-1-CONSUMER-CONTRACT.md`; quality pass verified against the
  current UI, tooltip, commands, diagnostics, calibration, and world modules.
  Follow-ups in `docs/tasks/DS-1-FOLLOWUP-TASKS.md`:
  - [ ] **DS-1-F1 — Canonical versus derived ownership.**
  - [x] **DS-1-F2 — Zone-scoped identity/query index.** Executed 2026-11-16;
    in-memory indexes and tests. Result: `docs/DS-1-F2-INDEX-RESULT.md`.
  - [ ] **DS-1-F3 — Instance/area separation and count rules.**
  - [ ] **DS-1-F4 — Missing-subset/archive fallback.**
  - [ ] **DS-1-F5 — Diagnostics count-only access.**
- [x] **DS-2 — Real-store baseline.** Executed 2026-11-14. Real baseline:
  70,661 client bytes, 82,614 estimate, 85 mobs, 762 kills, 617 open / 145
  instance, 2 heatmap zones / 193 cells, 1 instance. Ratios: 0.1115 unique
  mobs/kill, 8.96 kills/unique mob, 19.0% instance share. Projection anchors:
  492,835 bytes at 10×; HC-5 extreme 2,116,643 estimated but truncated, so a
  lower bound. No measured kills/hour. Task/result:
  `docs/tasks/DS-2-REAL-STORE-BASELINE.md`. Large-dataset strategy:
  `docs/DS-17-1-CAPACITY-AND-STRATEGY.md`. Reference corpus remains optional;
  recorded figures are sufficient.

  | File | Bytes | Tables | Entries | Depth | Dominant shape |
  |---|---:|---:|---:|---:|---|
  | `AceM2L2.lua` (current) | 70,661 | 729 | 3,366 | 7 | 21.6 KB key text; 2,326 numbers; 2.6 KB strings |
  | `Blizzard_Console.lua` | 1,328,130 | 1,057 | 3,168 | 2 | 1,295 KB strings; 1,054 message/timestamp pairs |
  | `TradeSkillMaster.lua` | 234,786 | 688 | 2,415 | 4 | 2,237 string keys / 30.8 KB; one 166.7 KB item-info string; nested UI state |
  | `AllTheThings.lua` (old sample) | 204,987 | 1,724 | 11,433 | 5 | sparse numeric ID sets; 50.5 KB key text; account/character/cache/UI roots |
  | `AllTheThings.lua` (new retail previous-expansion sample) | 2,673,713 | ~2,500 | ~186,000 | 5 | sparse numeric ID sets; ~57 KB key text; large account/character roots |

  For each store record:

  - bytes, table count, entry count, max depth, key bytes, and value types;
  - largest child subtree and whether it is player state, cache, UI, or static
    metadata;
  - numeric/sparse-key shape versus named-key shape;
  - string blobs versus per-entry tables;
  - account-wide, per-character, per-client, and profile scope;
  - retention policy and whether the data can be reconstructed;
  - serialization overhead from long or repeated key names.

  Lessons already visible: key text can dominate structured data (our current
  store spends ~21.6 KB of 70.7 KB on keys); one large string can be cheaper than
  thousands of tiny records (Blizzard console); long namespaced keys and UI
  state can dominate even with small value payloads (TSM); sparse numeric ID
  sets are compact per entry but need clear account/character separation (ATT).

  Planning ratios from this corpus (not hard limits): sparse numeric/boolean
  maps run roughly 18-21 bytes per entry; namespaced nested/UI state roughly
  80-100 bytes per entry; large text blobs roughly 1.2 KB per record. Our
  current store is already at the low end per entry, so future growth will come
  from more mob keys, contexts, instances, and heatmap cells rather than one
  large value.

  Organization consequences: separate account-wide, per-character, cache/UI,
  and static metadata roots; prefer numeric ID keys for sets; keep long text in
  blobs; avoid repeated long prefixes; and split reconstructable metadata from
  player history. Combine these findings with DS-5 and DS-14.
- [x] **DS-3 — Storage sanity check.** Executed 2026-11-14; passed. Real 762-kill
  save plus 10× synthetic: save/reload identical, aggregate invariants hold,
  empty store invents nothing, 10× reloads in ~12 ms and saves in ~51 ms offline.
  This is a small/medium-store proof, not a massive-scale decision. Result:
  `docs/DS-3-STORAGE-SANITY-RESULT.md`; harness: `tests/storage_sanity.lua`.
- [x] **DS-3B — Massive synthetic store validation.** Executed 2026-11-15.
  2,000 mobs / 24,000 contexts / 40 × 4,096 cells / 100 instances: compact
  8,689,981 bytes (~8.29 MiB), client-format estimate 9,938,701 bytes, Lua heap
  23 MB stable / 27–37 MB transient, load ~120 ms, normalize ~105 ms, serialize ~1,068 ms offline,
  invariants pass, no parser failure. The old 11–14 MB file estimate was high;
  the heap is the real pressure. Result:
  `docs/DS-3B-MASSIVE-SYNTHETIC-RESULT.md`; harness:
  `tests/ds3b_massive.lua`.
- [x] **DS-3C — Long-term growth and cap pressure.** Executed 2026-11-15.
  At 100 kills/hour, 2h/day reaches ~18,000 kills in 3 months and hits the
  2,000-mob cap; rate samples turn over in 2.4 hours. 23 MB is a current-cap
  profile, not a long-term state. The current caps are too small; design for
  dynamic hot/cold and archives. Result: `docs/DS-3C-LONG-TERM-GROWTH.md`.
- [x] **DS-4 — Storage representation and retrieval design.** Revised for
  massive scale 2026-11-14. The current nested tables are the **hot tier**, not
  the whole solution. Keep stable IDs, sparse cells, derived summaries, and
  in-memory indexes; reject JSON/Base64/checksum identity for hot data. Massive
  data requires packed cold zone/level blocks, static metadata, per-zone
  retention, and an optional companion. See
  `docs/tasks/DS-4-STORAGE-REPRESENTATION.md`,
  `docs/STORAGE-DIRECTION.md`, and
  `docs/DS-17-1-CAPACITY-AND-STRATEGY.md`. DS-4P is required.
- [x] **DS-4P — Hybrid hot/cold prototype.** Executed 2026-11-16. Tier C:
  100k mobs/200 zones/200 instances: 38.50 MB hot heap, 8.07 MB cold blocks,
  46.56 MB structural; selected-zone decode 3.7 ms; tooltip 10k 0.55 ms; no full
  scan; prototype save/reload 10.78 MB/97.5 ms. No 2,000/40/100 stop. Result:
  `docs/DS-4P-HYBRID-PROTOTYPE-RESULT.md`.
- [x] **DS-4P-F1 — Hot-index memory optimization.** Executed 2026-11-16.
  Baseline 20.67 MB hot at 100k; static names + numeric arrays 7.67 MB hot
  (+14 MB shared index); static without index 6.83 MB hot (+6 MB shared).
  Numeric arrays + shared names + scoped name index is the best shape. Result:
  `docs/DS-4P-F1-HOT-INDEX-RESULT.md`.
- [x] **DS-4P-F2 — Scoped/lazy name index.** Executed 2026-11-16. 100k mobs:
  7.73 MB hot + 5.97 MB shared, 11,001 index entries; no global name index;
  name-only/missing-static fallback works; ambiguous returns nil. Result:
  `docs/DS-4P-F2-SCOPED-NAME-INDEX-RESULT.md`.
- [x] **DS-6 — Static metadata feasibility.** Executed 2026-11-16; revised
  after review. **No shipped all-name list.** Stable `npc:<id>` metadata is
  learned live into an account-wide registry; name-only `name:<lower>` metadata
  stays per character; missing names fall back to `NPC <id>`. Mobs are
  zone/instance/grid-localized, so cold history is per-zone/per-instance blocks,
  not a global all-mob matrix. A pre-kill spawn index is deferred and is not
  copied from a third-party database.
  Shipped-name measurements (100k/24 3.51 MB packed vs 10.67 MB map; 350k
  12.80 vs 40.35 MB) are retained as the rejected alternative. Result:
  `docs/DS-6-STATIC-METADATA-RESULT.md`.
- [x] **DS-5 — SavedVariables/loading API matrix.** Executed 2026-11-14.
  Result: `docs/DS-5-SAVEDVARIABLES-LOADING-MATRIX.md`. Key conclusions:
  account + per-character split is correct; multiple normal variables still load
  together; only a LoadOnDemand companion can defer, and its exact variable
  timing is a V-2 check; `SaveAddOns` is a checkpoint, not per-kill durability;
  `SAVED_VARIABLES_TOO_LARGE` is a load-failure/recovery path; no per-zone SV
  files; do not load a companion from inside `ADDON_LOADED`.
- [x] **DS-7 — Packing/compression feasibility.** Executed 2026-11-16.
  Selected hybrid sparse/bitset cell encoding, varint/delta fields, per-zone/
  instance/level-band blocks, no inline names, per-block checksum, and per-block
  base64 in SavedVariables. Result:
  `docs/DS-7-12-PACKED-BLOCK-CODEC-RESULT.md`.
- [ ] **DS-8 — Display redesign study.** Zone-first Mobs/Areas/Levels and
  heatmap-cell detail without losing identity.
- [ ] **DS-9 — Retention and migration.** Per-zone caps, global totals, pruning,
  downgrade behavior, schema version, reset paths, and the DS-17 hot/warm/cold
  lifecycle.
- [ ] **DS-10 — Offline prototype.** Use saved-variable fixtures and synthetic
  zone-heavy/projected profiles to exercise packing, decode, and query paths.
  Live client verification is deferred to V-2.
- [x] **DS-11 — Decision record.** Executed 2026-11-16. Settled Journey/
  Knowledge, hot/cold, codec, schema, retrieval, save, rejected alternatives,
  implementation order, and V-2 checklist. Result:
  `docs/DS-11-DECISION-RECORD.md`.
- [x] **DS-14 — Constant-table/oversize guard.** Executed 2026-11-16.
  340k constants split into 4 chunks under a 100k budget; oversized block
  rejected; save-blocked state, backup/restore, and downgrade guard pass.
  Result: `docs/DS-14-OVERSIZE-GUARD-RESULT.md`.
- [x] **CAP-1 — Journey capture fields.** Executed 2026-11-16. Health bands,
  context split, mob level range, active time, heatmap cell XP/time, and death
  attribution/fallback prototyped. Result:
  `docs/CAP-1-JOURNEY-CAPTURE-FIELDS-RESULT.md`.
- [x] **IMP-1 — Journey schema/retrieval integration.** Integration slice
  executed 2026-11-16: local 158 mobs/3 zone blocks; login 0 decode; selected
  block 0.32 ms; event time + quest anchor + best-zone total/kill + heatmap +
  danger + fallback. Result:
  `docs/IMP-1-JOURNEY-SCHEMA-RETRIEVAL-RESULT.md`.
- [x] **IMP-1A — Production Journey instrumentation.** Executed 2026-11-16.
  New `KillHistory/Journey.lua`; event-driven presence/engaged time; quest
  anchor; kill/quest XP split; `PLAYER_LOGOUT` finalizer; tests/journey.lua.
  Result: `docs/IMP-1A-JOURNEY-INSTRUMENTATION-RESULT.md`.
- [x] **IMP-1B — Production Journey query API.** Executed 2026-11-16.
  Read-only best-zone total/kill XP/hour, heatmap top cells, mob/quest/time
  summaries; tests/journey_queries.lua. Result:
  `docs/IMP-1B-JOURNEY-QUERY-RESULT.md`.
- [x] **IMP-1B2 — Production migration/block storage.** Executed 2026-11-16.
  Per-zone/instance base64 blocks, checksum, lazy decode, LRU, dirty-zone flush.
  Result: `docs/IMP-1B2-JOURNEY-BLOCK-STORAGE-RESULT.md`.
- [x] **IMP-1B3 — Journey migration/retrieval integration.** Executed
  2026-11-16. Block-backed mob lookup, mob→zone index, query fallback with
  legacy removed; tests pass. Result:
  `docs/IMP-1B3-BLOCK-RETRIEVAL-RESULT.md`.
- [x] **IMP-1B4 — Legacy retirement and save/guard integration.** Save/guard
  slice executed 2026-11-16: block backup/restore, oversize save-blocking,
  reset path. Result: `docs/IMP-1B4-SAVE-GUARD-RESULT.md`.
- [x] **IMP-1B5 — Tooltip/Detail block fallback and rollback.** Executed
  2026-11-16. Legacy-first/block-fallback tooltip and partial Detail; 0 decode
  legacy, 1 cold block, 0 cache; rollback flag. Result:
  `docs/IMP-1B5-TOOLTIP-FALLBACK-RESULT.md`.
- [x] **IMP-1B6 — Journey mob index core.** Executed 2026-11-16. Lazy global
  index, row lookup, top mobs, filters/search, invalidation. Result:
  `docs/IMP-1B6-JOURNEY-MOB-INDEX-RESULT.md`.
- [x] **IMP-1B7 — Mobs list/Overview switch to Journey index.** Executed
  2026-11-16. Index-backed Mobs list and Overview top mobs; parity, one-build
  budget, invalidation, rollback flag. Result:
  `docs/IMP-1B7-MOBS-LIST-OVERVIEW-RESULT.md`.
- [x] **IMP-1B8 — Remaining legacy read audit and safe command switch.**
  Executed 2026-11-16. Index-backed `kills`/`dump`, zero-kill dump parity,
  deterministic tie-break, remaining-read inventory, rollback. Result:
  `docs/IMP-1B8-LEGACY-READ-AUDIT-RESULT.md`.
- [x] **IMP-1B9 — Areas/Levels parity and switch.** Executed 2026-11-16.
  Overlap-safe shared rows, legacy-canonical counts, separate Journey stats,
  reset consistency, rollback. Result:
  `docs/IMP-1B9-AREAS-LEVELS-RESULT.md`.
- [x] **IMP-1B10 — Heatmap UI bounded query.** Executed 2026-11-16. Schema 2
  zone blocks carry sparse cells; selected-zone query decodes one block and
  caches; legacy fallback; no new flag. Result:
  `docs/IMP-1B10-HEATMAP-BOUNDED-RESULT.md`.
- [x] **IMP-1B12 — Remaining area/level summary reads.** Executed 2026-11-16.
  Shared top-area/level/detail/stat helpers; Overview/footer/minimap/Detail/
  `PrintStats` switched; parity and rollback. Result:
  `docs/IMP-1B12-AREA-LEVEL-SUMMARIES-RESULT.md`.
- [x] **H64-9-F1 + F2 — Heatmap rescale and disabled-state fixes.** Executed
  2026-11-16. Results: geometry/show work removed on rescale; repeated disabled
  refreshes do no per-cell work. Result:
  `docs/H64-9-F1-F2-HEATMAP-RESULT.md`.
- [x] **H64-9-F4 — Zone-scoped/lazy heatmap normalization.** Executed
  2026-11-16. Metadata-only zone index, selected-zone cache, full normalizer
  retained for commands/tests. Result:
  `docs/H64-9-F4-ZONE-NORMALIZATION-RESULT.md`.
- [x] **R-4 — Static overlay/art audit.** Executed 2026-11-16. Deduped generated
  overlays, collision-safe keys, full texture signatures, dedupe tests. Result:
  `docs/R-4-OVERLAY-ART-AUDIT-RESULT.md`.
- [x] **UI-3 — Death/respawn history view.** Executed 2026-11-16. History tab,
  search/sort, details, explicit empty/unavailable states, row caps. Result:
  `docs/UI-3-HISTORY-VIEW-RESULT.md`.

- [ ] **V-2 — Live-only residual verification.** Deferred; only environmental
  checks. Task: `docs/tasks/V-2-LIVE-VERIFICATION.md`.
- [ ] **Non-live backlog.** `docs/NON-LIVE-BACKLOG.md`.
- [x] **IMP-1B11 — Rollback retirement preparation.** Prepared 2026-11-16.
  Inventory/removal checklist and static flag test complete; final removal after
  V-2. Result: `docs/IMP-1B11-ROLLBACK-RETIREMENT-PREP.md`.
- [x] **DS-12 — Packed block codec.** Executed 2026-11-16 with DS-7. Block
  metadata, adaptive cells, base64 storage, checksum, corruption/truncation, and
  block-size guidance are defined. Result:
  `docs/DS-7-12-PACKED-BLOCK-CODEC-RESULT.md`.
- [x] **DS-6-F1 — Mob metadata registry.** Executed 2026-11-16. Local
  `/mnt/r/AceM2L2.lua` sample: 158 mobs, 100 npcID / 58 name-only; 135 in one
  zone/instance, 23 in two; max observed 2 (assume ≤4); fixed level range,
  max width 4. **Account-wide stable `npc:<id>` metadata** (name, level range,
  ≤4 zone refs) + per-character name-only metadata. Local account part: 100
  entries, 0.02 MB / 3.8 KB packed; local name-only: 58 entries, 0.01 MB /
  3.7 KB packed. Account-only 10k: 2.38 MB map / 0.42 MB packed; 100k: 35.97 /
  4.16 MB. Raw history/observed XP stays per character. Result:
  `docs/DS-6-F1-MOB-METADATA-REGISTRY-RESULT.md`.
- [ ] **DS-13 — On-demand companion packaging.** Design the LoadOnDemand
  companion, its TOC, SavedVariables, load call, missing-companion fallback, and
  release packaging from `docs/DS-5-SAVEDVARIABLES-LOADING-MATRIX.md`. Use
  `DoesAddOnExist`, `IsAddOnLoadOnDemand`, `IsAddOnLoadable`, and
  `IsAddOnLoaded`; handle `LoadAddOn`'s `loaded, reason`. Load from
  `PLAYER_LOGIN` or a user action, not the main addon's `ADDON_LOADED` handler.
  Runtime companion variable timing is deferred to V-2.
- [x] **DS-17.4A — Journey/Knowledge model validation.** Executed 2026-11-16.
  Local inventory: 158 mobs, 1 context entry, no active time/combat/XP contexts/
  death attribution/heatmap XP-time. Context stress: 10k×12 contexts 70.7 MB,
  top-8 45.3 MB (93.8% kills/92.3% XP), top-4 23.1 MB (66.7%/64.3%). Schema:
  100k metadata nested 33.75 MB, parallel 26.00 MB, packed 4.45 MB. Heatmap
  downsampling preserves totals. Result:
  `docs/DS-17-04A-JOURNEY-KNOWLEDGE-MODEL-RESULT.md`.
- [x] **DS-17.4B — Danger and XP/hour prototypes.** Executed 2026-11-16.
  Wilson-bound danger, best-zone XP/hour ranking with confidence, and sparse
  local heatmap occupancy (4.83%/4.54%/0.02%) measured. Result:
  `docs/DS-17-04B-DANGER-AND-XP-HOUR-RESULT.md`.
- [x] **DS-17.4C — Retention/aggregation compatibility.** Executed 2026-11-16.
  Array/list contexts are far smaller than keyed maps; top-8 + `other`
  preserves totals with top-8 detail; packed top-8+other 1.43 MB at 10k×12;
  active time/totals preserved; sparse heatmaps 0.5–5%, top-N hotspot needed
  with downsampling. Result:
  `docs/DS-17-04C-RETENTION-MERGE-COMPATIBILITY-RESULT.md`.
- [x] **DS-17.5 — Schema, field ownership, migration.** Executed 2026-11-16.
  v2 Journey renames player-level fields, adds mob level range/activeSeconds/
  combat/XP contexts/death fields, arrays for cold contexts, top-8+other, and
  account Knowledge target. Local migration preserved 158 mobs, 1,993 kills,
  152,816 XP, 385 cells, 16 deaths, 38 quests, 69 respawns; idempotent; 0.49 MB
  v2 heap. Result: `docs/DS-17-05-SCHEMA-AND-MIGRATION-RESULT.md`.
- [x] **DS-16 — Save/checkpoint policy.** Executed 2026-11-16. Dirty-block
  encode 2.1 ms/1 block vs 795 ms/full 400; full base64 decode 1.15 s, so lazy
  selected-block decode required; backup/oversize state machine defined.
  Result: `docs/DS-16-SAVE-CHECKPOINT-RESULT.md`.
- [x] **DS-15 — Lazy retrieval, zone-scoped queries, and cache.** Executed
  2026-11-16. Login decoded zero blocks; selected block 1.7 ms, selected-zone
  10k tooltip 1.2 ms; full decode 586 ms; random global cold tooltip too
  expensive; best-zone/heatmap summaries no decode. Result:
  `docs/DS-15-LAZY-RETRIEVAL-CACHE-RESULT.md`.
- [ ] **DS-17 — Character lifecycle, compression, and cross-character data.**
  Model a full 1–60/1–max leveling life, leveling vs endgame modes, hot/warm/cold
  archive tiers, and account-wide aggregate leveling knowledge for alts. Includes
  official zone/instance counts and cap-pressure analysis. Master:
  `docs/TASK-DS-17-CHARACTER-LIFECYCLE-DATA.md`.
  - [x] **DS-17.1 — Aggregation and 64x64 sufficiency.** Executed 2026-11-16.
    Feature-to-data matrix, cardinality, hot/warm/cold boundary, required keys,
    no-global-cap policy, and 64×64 decision complete. 64×64 accepted for durable
    heatmaps; 96/128 rejected for durable storage; no per-kill log; dynamic hot
    cache and packed cold blocks. Result:
    `docs/DS-17-1-AGGREGATION-DECISION.md`.
  - [x] **DS-17.2 — Modes and lifecycle.** Executed 2026-11-16. Automatic
    leveling archive at max level, endgame separation, level-cap generations,
    first-alt rule, commands/migration. Result:
    `docs/DS-17-2-MODES-LIFECYCLE-DECISION.md`.
  - [x] **DS-17.3 — Retention and compression.** Executed 2026-11-16. Dynamic
    hot/warm/cold movement; 64 hot / 32 warm-cold / 16 summary heatmaps;
    context/rate/quest/death/respawn/level retention; 3/6/12-month and
    beyond-cap profiles. Result: `docs/DS-17-3-RETENTION-DECISION.md`.
  - [ ] **DS-17.4 — Cross-character knowledge and route recommendations.**
    Define account-wide aggregate leveling knowledge, confidence, query use, and
    an explainable efficient-route recommendation with data-sufficiency gates
    and held-out backtesting. Depends DS-17.1/2/3; blocks DS-17.5.
    `docs/tasks/DS-17-04-CROSS-CHARACTER-KNOWLEDGE.md`.
  - [x] **DS-17.5 — Schema and migration.** Done 2026-11-16.
    Finalize field-level ownership,
    versions, backup, downgrade, companion, and codec envelope. High-level
    account/per-character/static/memory/companion split is already in
    `docs/STORAGE-DIRECTION.md`; this task resolves the exact fields and
    migration. Depends DS-17.1..4, DS-4, DS-5, DS-9; blocks DS-11.
    `docs/tasks/DS-17-05-SCHEMA-AND-MIGRATION.md`.
  - [x] **DS-17.6A — Current data-model validation.** Executed 2026-11-18.
    Found production is v1 legacy aggregates + additive Journey, not DS-17.5 v2.
    Result: `docs/DS-17-06A-DATA-MODEL-VALIDATION-RESULT.md`.
  - [x] **DS-17.7 — Data-model reconciliation and migration plan.** Executed
    2026-11-18. v2 is the target; v1+additive Journey is transitional; staged
    migration. Result: `docs/DS-17-07-DATA-MODEL-RECONCILIATION-RESULT.md`.
  - [x] **DS-17.8 — Data-model P0 safety fixes.** Executed 2026-11-18.
    Result: `docs/DS-17-08-DATA-MODEL-P0-SAFETY-RESULT.md`.
  - [x] **DS-17.9 — S1 data-model scaffolding.** Executed 2026-11-18.
    Result: `docs/DS-17-09-DATA-MODEL-S1-SCAFFOLDING-RESULT.md`.
  - [x] **DS-17.10 — S2A mob model migration.** Executed 2026-11-18 (kill/
    backfill; v2-only reads). Result: `docs/DS-17-10-S2A-MOB-MODEL-RESULT.md`.
  - [ ] **DS-17.11 — S2A mutation parity.** **Next.** Sync v2 on merge/delete/
    prune and prove parity. `docs/tasks/DS-17-11-S2A-MUTATION-PARITY.md`.
  - [ ] **DS-17.6B — ALT/account-feature validation.** **Future only.** 1/3/5-alt
    Knowledge, route advice, account persistence. Depends DS-17.11 + migration slices,
    DS-17.4D, V-2, MEM-1, and ALT scheduling.
    `docs/tasks/DS-17-06B-ALT-FEATURE-VALIDATION.md`.

#### Review and revisions to the investigation

- The heatmap alone cannot replace mob entries: it loses mob identity and level.
  Use it as a per-cell aggregate, with a separate identity/level store.
- The current code already aggregates levels and zones per mob; the investigation
  must focus on cap shape and retention, not re-inventing per-kill logging.
- Multiple SavedVariables do not create per-zone files. Any claim that they
  reduce per-zone data must be verified against load/save behavior.
- Static Lua databases solve metadata size, not user history.
- The plan is API-first: use official client APIs and our own generated metadata;
  other addons are implementation references only, not data sources.
- Do not copy Mapster, QuestieDB, AllTheThings, or Carbonite data. Use generated
  official data or our own schema.
- Do not approve 2x/4x/6x until DS-2/DS-3 produce byte and latency numbers.
- Forever's historical SavedVariables bug must be checked in V-2.

**Decision gate:** no storage migration before DS-11 and the DS-12..DS-16
prototype results are reviewed and approved.

### Proposed: Journey overlay and cell inspector — after data-format work

**Status:** proposed only. Both features depend on the DS-1..DS-16 storage
decision. Do not implement them against the current global mob table.

**Ordering:** finish the data-format investigation first, then Journey, then the
cell inspector. The inspector needs richer per-cell identity data than the
current heatmap stores.

#### Feature A — Journey overlay

Show the character's movement through a zone on the heatmap, with deaths and
kill history tied to time.

Possible data:

- `journey[mapID] = { {t=epoch, x=0..1, y=0..1, cell=n}, ... }`
- optional `kills[mapID][cell] = { mobKey = count }` for time-window detail
- deaths already exist as `db.deaths` with `at`, `mapID`, `x`, `y`.

Rendering:

- Draw a polyline between sampled positions.
- Use 5-minute display blocks initially, but sample more frequently (30-60s) and
  aggregate for display if needed. A 5-minute centroid can produce misleading
  straight lines across terrain.
- Mark deaths in the selected time range on the correct map.
- Add a time-window control: session, last 30/60 minutes, all recorded.
- Only show points belonging to the selected zone.
- Label the line as an approximate route, not a measured path.

Storage risks:

- More samples = more SavedVariables data.
- Need caps per zone/session and pruning.
- Could reuse a future event ledger for journey, kills, and cell detail instead of
  creating three unrelated stores.
- Sampling only on kills/deaths/zone changes is cheap but incomplete; periodic
  sampling is better but needs a throttle.

#### Feature B — Hover cell inspector

Mouse over the heatmap to select a 4x4 cell area and show what was killed there.

Display:

- Hover highlight over the 4x4 cell block.
- Aggregate count and percentage for the block.
- Top mobs in that block with count, level range, and last-seen time.
- Optional mob icon or portrait.
- Right-hand panel inside the Heatmap tab.

Data requirement:

- Current heatmap stores only aggregate per-cell counts. It does **not** know
  which mob was killed in each cell.
- Need a new sparse mapping such as
  `zoneCellMobs[mapID][cell][mobKey] = count` and possibly level buckets.
- Without that mapping, the inspector can show only density, not mob identity.

Interaction:

- Do not create 4,096 mouse-enabled cell frames.
- Use one transparent overlay frame and compute the hovered cell from cursor
  position.
- Aggregate the 4x4 block on mouse move, throttled.
- Hide the inspector when the heatmap tab is not visible or when the cursor
  leaves the grid.

Mob icons:

- Verify the available API for NPC/creature portraits before promising icons.
- Candidates: `SetPortraitTexture`, `C_CreatureInfo`, `GetCreatureInfo`, or a
  `PlayerModel` fallback.
- If no reliable icon exists, use a type/faction icon or text-only rows.

#### Priorities

- **P0 — DS-1..DS-11.** Finish the storage decision before adding new history
  stores.
- **P1 — Journey basic.** Zone-filtered route, deaths, session/last-hour filter,
  approximate-route label. High visual value, moderate data.
- **P2 — Cell inspector.** 4x4 hover block, aggregate density, top mobs. Needs
  per-cell mob data and icon verification.
- **P3 — Journey playback.** Time slider, pause/play, route smoothing, multi-zone
  transitions. Nice-to-have after basic Journey.
- **P4 — Rich mob portraits.** Only if a reliable client API exists.

#### Tasks

- [ ] **J-1 — Journey data model.** Decide sample cadence, fields, map/session
  keys, and whether it shares an event ledger with kills.
- [ ] **J-2 — Sampling strategy.** Compare periodic samples, kill/death-only
  samples, and zone-change samples; measure storage and path quality.
- [ ] **J-3 — Retention.** Cap points per zone/session; define pruning and
  migration.
- [ ] **J-4 — Renderer.** Draw zone-filtered polylines and death markers above
  map art but below heat cells or above them as a toggle.
- [ ] **J-5 — Time controls.** Session, last 30/60 minutes, all; optional playback.
- [ ] **J-6 — Journey offline tests.** Validate sampling/retention/render math with fixtures and synthetic routes. Live playback is deferred to V-4.
- [ ] **M-1 — Cell-mob data model.** Define sparse per-cell mob/level counts and
  storage caps.
- [ ] **M-2 — Icon/portrait API review.** Check NPC/creature portrait APIs in
  client docs/source for Forever and Midnight; specify text/type fallback. Live
  visual check is deferred to V-4.
- [ ] **M-3 — Hover hit-testing.** One overlay frame; compute 4x4 block without
  thousands of mouse frames.
- [ ] **M-4 — Inspector panel.** Aggregate block stats, top mobs, levels, last
  seen, and optional icons.
- [ ] **M-5 — Performance/accessibility.** Throttle hover updates, handle missing
  data, and keep the panel readable at minimum window size.
- [ ] **M-6 — Inspector offline tests.** Validate 4x4 hit math, aggregation, empty-data handling, and panel layout with fixtures. Live hover/icon checks are deferred to V-4.

#### Analysis and review

- The current `deaths` store can support death markers immediately, but the
  route needs new time-series data.
- The current heatmap cannot answer “what did I kill in this cell”; it only sums
  counts. The inspector must not pretend otherwise.
- A shared time-stamped event ledger is likely cheaper than separate journey,
  kill-cell, and inspector stores, but it must be evaluated against the current
  aggregate model.
- The 5-minute block idea is useful for display compression, not necessarily for
  raw sampling.
- Both features are local-only; no external services are involved.

### Fully revealed map background — implemented in 2.3.0

**Status:** implemented; static audit first; live check consolidated in V-5.

**Decision:** use a generated full-overlay pack from the official client
`WorldMapOverlay` / `WorldMapOverlayTile` tables. This is the FogClear mechanism
without copying Mapster/Leatrix data.

**Implementation**

- `KillHistory/MapOverlayData.lua` is generated for:
  - Midnight 12.1.5.69848
  - Forever 1.60.1.69913
- Each entry is keyed by `uiMapArtID` and stores overlay width/height/offsets and
  the official texture fileDataIDs.
- The heatmap uses `C_Map.GetMapArtID(mapID)` to select the right data, draws
  static overlays the character has not explored, then draws the official
  explored overlays on top.
- `C_Map.GetMapArtLayers` / `C_Map.GetMapArtLayerTextures` still provide the
  base art, tile sizes, and layer information.
- `Reveal unexplored areas` is a Settings > World option, on by default. When
  off, only the character's explored overlays are drawn.
- The static overlay data is parsed once per art ID and cached.
- Missing/stale data falls back to explored overlays and base art.
- No Mapster or Leatrix overlay data is copied.

**Verification**

- Offline: generated data loads; static overlays reveal missing art; explored
  overlays are not duplicated; the reveal setting disables static data.
- Live comparison: deferred to V-5; static audit is R-4.
- Release: 2.3.0 archive built and validated.

**Tasks**

- [x] **R-5 — Static overlay data.** Generated from official DB2 tables with
      `tests/generate_map_overlays.py`.
- [x] **R-9 — Decision record.** Static generated overlay pack selected over
      parent-crop, minimap, legacy, and child-map approaches.
- [x] **R-4 — Static overlay/art audit.** Executed 2026-11-16. Result:
      `docs/R-4-OVERLAY-ART-AUDIT-RESULT.md`.
- [x] **R-10 — Release/docs.** 2.3.0 documentation and archive built and
      release-validated.
- Deferred: parent/continent crop (R-0..R-3), minimap terrain (R-6), legacy art
      (R-7), and child-map compositing (R-8). The static pack supersedes them for
      the current feature.

**Alternatives not chosen**

- Parent/continent crop: no data, but lower resolution and unproven.
- Minimap terrain: highest detail, too much data/coordinate work.
- Legacy `Interface\WorldMap\...` art: partial coverage.
- Child-map compositing: uncertain coverage.
- CVar/engine force-reveal: no public API.

**Deferred alternative tasks when reopened**

- [ ] **R-0 — Source-map policy.** Choose immediate parent vs highest ancestor
      with art; reject degenerate/non-square crops.
- [ ] **R-1 — Parent-art probe.** Report parent art layers, tile count,
      resolution, map rect, and explored overlay counts.
- [ ] **R-2 — Parent-crop spike.** Render one zone from ancestor art with correct
      texture coordinates; keep base art as fallback.
- [ ] **R-3 — Parent-crop integration.** Default-off setting, cache key, and
      per-map fallback.
- [ ] **R-6 — Minimap terrain feasibility.** Evaluate data size, licensing,
      coordinate work, and Midnight coverage.
- [ ] **R-7 — Legacy art mapping probe.** Test a small zone-to-folder mapping for
      classic zones.
- [ ] **R-8 — Child-map compositing probe.** Check how many child maps return
      independent art and whether compositing helps.

## Final live validation — deferred until last

**Policy:** do not run these until static code/API/data review and offline
prototypes are complete. This is the single live-test gate; do not add separate
in-game tasks to each feature section.

- [ ] **V-1 — Heatmap visual/performance.** 64x64 sparse/dense zones,
      minimum/default/maximum window sizes, map art on/off, full reveal,
      gradient hue/alpha at 50/100/200% intensity, warm palette, gradient
      legend, heat-cell alignment, and frame cost.
- [ ] **V-2 — Storage/diagnostics runtime.** Compare the diagnostics estimate
      with actual SavedVariables sizes on available real and projected
      zone-heavy characters. Verify LoadOnDemand companion variable timing and
      its `ADDON_LOADED` delivery, `SaveAddOns` durability before immediate
      logout, `SAVED_VARIABLES_TOO_LARGE` threshold/recovery, and Forever 1.60.1
      persistence. Verify account-wide stable metadata (name, fixed level range,
      ≤4 zone refs), per-character name-only metadata, per-block
      base64/SavedVariables size, and selected-block latency on
      Forever/Midnight. Any online verification
      requires explicit permission; use Wowhead/official client data, never an
      emulator database as authority.
- [ ] **V-3 — Coordinate confirmation.** Only if G-1 proposes a change:
      compare death-time position capture and 64 vs 96/128 occupancy/noise and
      latency.
- [ ] **V-4 — Journey/inspector runtime.** Only if implemented: route/death
      rendering, time filters, 4x4 hover selection, mob rows/icons, panel
      performance.
- [ ] **V-5 — Map overlays/art runtime.** Fully unexplored zone on Forever and
      Midnight; art-ID/phase alignment, heat-cell alignment, overlay quality, and
      frame cost.
- [ ] **V-6 — Documentation/release and UI sanity.** Verify player/developer
      docs, Data diagnostics access, install from the release zip, final release
      check, and the Mobs list at multiple window sizes (scroll, resize, kills
      text). The first list/resize/scroll pass has been confirmed by the user.

**Carbonite live checks** remain inside the deferred Carbonite section and are
not part of this gate until that work is reopened.

## Deferred work

### Carbonite integration

Deferred by user request. No Carbonite code or provider setup has been added.

Retained conclusions from the research:

- Carbonite's full map background uses the same Blizzard `C_Map` tiled art Kill
  Story already uses.
- Embedding Carbonite's live map frame is not viable.
- The only recommended integration is an optional overlay through the public
  `Carbonite.Map:CreateProvider` API.
- `ZR` rectangle pins must pass a live alignment/zoom/clipping/instance/docked
  minimap spike before implementation.
- The overlay would use adaptive 32x32/16x16 bucketing, capped at 256 pins, and
  would follow Carbonite's visible map rather than the Kill Story pager.
- Carbonite stays optional, default-off, capability-gated, and absent from
  `OptionalDeps`.
- Carbonite's radar-detail tiles and legacy art fallback remain deferred because
  they require private tables, coordinate transforms, and GPL review.

Do not start this work until V-1/V-5 pass and the work is explicitly approved.

**Deferred tasks when reopened**

- [ ] **CB-0 — Live ZR spike.** Validate alignment, zoom, clipping, instance
      levels, docked minimap, 3D mode, and frame cost.
- [ ] **CB-1 — Detector/lifecycle.** Capability gate, retries, lazy provider
      creation, session disable.
- [ ] **CB-2 — Setting/options/probe.** Default-off Carbonite overlay setting
      and diagnostics.
- [ ] **CB-3 — Provider/adaptive buckets.** 32x32/16x16 buckets, 256-pin cap,
      frame level, docked-minimap behavior.
- [ ] **CB-4 — Matching/sync.** Exact/parent matching, coalesced rebuilds,
      toggle/reset/theme/client-switch handling.
- [ ] **CB-5 — Failure isolation.** pcall all Carbonite calls; clear on errors.
- [ ] **CB-6 — Live tests/docs/release.**

### KillStory as a separate addon

Deferred until explicitly approved. When revisited, decide:

- Data ownership and SavedVariables location.
- Public AceM2L2 API, callbacks, capabilities, and version handshake.
- Tooltip ownership between AceM2L2 text and KillStory GUI.
- Two-addon packaging, dependency/load order, and missing-dependency behavior.
- Migration and downgrade behavior.
- Tests for the API contract and load order.

Do not implement the split before those decisions are accepted.
