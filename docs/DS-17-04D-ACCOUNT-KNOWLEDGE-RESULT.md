# DS-17.4D — Account Knowledge derivation result

**Status:** executed 2026-11-18  
**Harness:** `tests/ds17_4d_knowledge.lua`  
**Scope:** offline synthetic prototype. No production code, SavedVariables writes,
UI, or cross-account merge. The local real save was not present in this session;
the synthetic corpora are the proof.

## 1. Corpus growth

| Sources | Mobs | Zones | Instances | Heatmaps | Quests | Serialized bytes | Heap delta KB | Derive ms |
|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 1 | 3 | 1 | 0 | 1 | 2 | 2,662 | 11.0 | 0.0 |
| 3 | 6 | 3 | 1 | 3 | 4 | 6,268 | 25.4 | 0.1 |
| 5 | 8 | 3 | 1 | 3 | 4 | 7,663 | 31.3 | 0.1 |

Knowledge size grows with sources but remains small in this synthetic shape.
The 5-source corpus is still only ~7.7 KB serialized.

## 2. Merge and coverage

| Metric | Source total | Knowledge total |
|---|---:|---:|
| Mob records | 13 | 8 |
| Kills | 129 | 129 |
| XP | 12,300 | 12,300 |
| Combat samples | 124 | 124 |

- Shared NPC IDs merged into one row.
- Counts, XP, and samples are additive.
- Mob-record count drops because shared identities collapse.
- Name-only ambiguous records stay separate.

Representative rows:

| Case | Result |
|---|---|
| Defias Pillager (`npc:101`) | 73 kills, 7,300 XP, zones 12 and 1421 |
| Kobold Vermin (`npc:102`) | classification `unknown`, conflict flag set |
| `Mysterious Stranger` | 2 ambiguous name-only rows across sources |
| 5-source quests | merged by quest ID, no copied quest text |

## 3. Heatmap, rate, and confidence

- `1421`: 3 cells, 25 kills, top-1 cell 10 kills, top-10 summary present.
- Heatmaps are **level-agnostic**; no fake level band was introduced.
- `1421` zone: 36 kills, 3,420 XP, 1,350 engaged seconds → **9,120 XP/hour**
  recomputed from sums.
- Defias danger: 3 deaths / 73 samples → Wilson 95% **1.4%–11.4%**.
- Confidence inputs are preserved; bounds are computed on read.

## 4. Idempotence and rebuild

| Check | Result |
|---|---|
| Re-run same sources | byte-identical |
| Reversed source order | byte-identical |
| Remove one source | mob count 8 → 7 |
| Deleted source ambiguity | 2 ambiguous rows → 0 |
| Source tables mutated | no |

Deleting the ambiguous source leaves the remaining single name-only record as a
unique name row, so it is no longer ambiguous.

## 5. Separation and query cost

| Check | Result |
|---|---|
| Project 18 corpus | 1 source, no project-1 mob |
| Project 1 source | 1 source, project-1 mob present |
| Mob query | ~0.14 µs |
| Zone query | ~0.14 µs |
| Instance query | ~0.03 µs |
| Heatmap query | ~0.12 µs |
| Quest query | ~0.15 µs |

These are offline Lua timings, not client frame claims.

## 6. Aggregate-only output

The derived table contains only aggregate fields. It does not contain:

- the source `journey` table;
- source character IDs;
- source `deaths` or `sessions` tables;
- raw coordinates;
- per-kill rows.

The check passed as `aggregate_only=true`.

## 7. Findings

1. **Account Knowledge is derivable from the v2 Journey shape.**
2. **NPC ID is the correct identity anchor.** Name-only records need an explicit
   ambiguity policy; blind name merges are unsafe.
3. **Counts, XP, time, and context samples are additive.** Rates must be
   recomputed from merged sums.
4. **Heatmaps stay level-agnostic.** The source schema does not carry per-cell
   player level, so Account heatmaps cannot be level-banded.
5. **Exact `byPlayerLevel` is small in this synthetic corpus.** No banding was
   needed; measure a real multi-alt corpus before deciding.
6. **Deterministic rebuild works.** Re-running and reversing source order
   produced identical bytes.
7. **Source deletion is clean.** Removing a source removes its contribution and
   re-evaluates ambiguity.
8. **Project/interface/level-cap/mode separation works.**
9. **Runtime account persistence is still unsolved.** Per-character
   SavedVariables are not co-loaded in game; this prototype reads offline data.
10. **Missing production fields still cap usefulness.** Danger contexts, active
    time, and per-cell XP/time depend on V-2/production capture.

## 8. Decision

Account Knowledge derivation is **technically feasible** and suitable for future
ALT advice, but it is not ready to ship.

Recommended follow-ups:

- keep per-character Journey primary;
- keep Account Knowledge derived and read-only;
- design an account-level derived save or companion before runtime use;
- retain the NPC-ID-first, ambiguity-aware merge rule;
- keep heatmaps level-agnostic until Journey stores per-cell level;
- measure a real multi-alt corpus before choosing level bands;
- use V-2 to confirm danger/active-time fields before promising danger or
  best-zone advice.

## 9. Limitations

- Synthetic corpora only; the local real save was absent.
- No client memory or load/save timing.
- No runtime co-loading or account persistence design.
- Query timings are offline Lua, not client frame times.
- The synthetic context/level distribution is not a real alt population.
- No UI, route recommendation, or production merge.

## 10. Next

**DS-17.6 — Validation, measurement, and decision** / ALT feature scheduling.
Live gates remain **MEM-1**, **V-1**, and **V-2**.

## Artifacts

- `tests/ds17_4d_knowledge.lua`
- `tests/run_all.sh`
- `docs/tasks/DS-17-04D-ACCOUNT-KNOWLEDGE-PROTOTYPE.md`
- `docs/DATA-MODEL-PLAN.md`
