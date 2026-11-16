# Performance and storage task review

**Status:** reviewed 2026-11-15  
**Scope:** completed tasks that affect storage, retrieval, loading, and memory:
H64-9, HC-5, DS-1, DS-2, DS-3, DS-4, DS-5, MEM-1, and the capacity model.  
**Question:** are the choices correct, or only provisional?  
**Full data-model plan:** `docs/DATA-MODEL-PLAN.md`  
**Model/test record:** `docs/DATA-MODEL-AND-TEST-MATRIX.md`

## Verdict

Some choices are solid. Some are provisional. None of the completed tasks proves
that the **current production system** handles massive datasets, because most of
them are analysis or offline measurement, not implementation.

| Area | Verdict |
|---|---|
| Lua tables, not JSON | Correct |
| No checksum identity | Correct |
| No Base64 for hot data | Correct |
| 64×64 sparse cells for heatmap counts | Correct as the heatmap model; not yet proven for 200 zones or live frame time |
| No per-kill log | Correct for current features; Journey still needs an explicit decision |
| Account vs per-character roots | Correct |
| No per-zone SavedVariables files | Correct |
| Static metadata outside the character save | DS-6/F1: no shipped all-name list; account-wide stable `npc:<id>` metadata (name, fixed level range, ≤4 zone refs) + per-character name-only; local account part 0.02 MB; account-only 10k 2.38 MB map / 0.42 MB packed |
| Derived `areas`/`levels` caches | Correct; covered by smoke invariants |
| Current nested hot tables as the whole solution | **Incorrect/incomplete**; they are a hot tier only |
| 2,000/40/100/12 global caps as the design | **Incorrect**; too small for the massive tier |
| DS-3 10× as massive proof | **Incorrect**; it is small/medium only |
| HC-5 2.1 MB as a ceiling | **Incorrect**; it is a truncated lower bound |
| Capacity estimates 11–14 MB / 18–25 MB | **Partially validated:** actual 2k/40/24k/163k profile is 8.69 MB compact / 9.94 MB client estimate, with 23 MB stable / 27–37 MB transient Lua heap |
| 64×64 sufficiency for route/inspector | **Provisional**; only dense-heatmap measurements exist |
| Context cap 12 per mob | **Provisional**; 24k contexts is ~8–9 MB by itself |
| LoadOnDemand companion | **Provisional**; timing is a V-2 check |
| Retrieval indexes and selected-zone normalization | **Not implemented** |
| Packed cold blocks and retention | **Not implemented** |

## Task-by-task findings

### H64-9 — heatmap benchmark

Solid for what it measured:

- dense 64×64 first render ~9.4 ms offline;
- rescale ~6.4–11.6 ms;
- incremental ~0.75–1.3 ms;
- 40/41 dense maps normalize ~91–93 ms;
- disabled refresh still hides ~4,100 cells.

Limits:

- offline fixture and UI mocks, not live client frame time;
- one dense zone and 40-map normalization, not 200 zones;
- does not decide 64 vs 96/128 for route/inspector;
- H64-9-F1/F2 fixes are still pending.

**Conclusion:** 64×64 is workable for the heatmap hot path; it is not sufficient
evidence for "64×64 is best for everything."

### HC-5 — diagnostics baseline

Solid for the small real sample:

- 70,661 actual bytes;
- 82,614 estimate (+16.9%);
- 85 mobs, 762 kills, 2 zones, 193 cells, 1 instance.

Limits:

- the extreme estimate is truncated at 200,000 entries;
- the 2.1 MB figure is a lower bound;
- the sample has zero contexts and is far below caps.

**Conclusion:** good estimator baseline; not a capacity ceiling.

### DS-1 — consumer contract

Good work:

- identified tooltip name-only full scan;
- identified all-zone heatmap normalization;
- identified duplicate `areas`/`levels`/`areaLevels`;
- defined load/fallback contracts.

Limits:

- it is a contract, not an implementation;
- name/zone indexes are still not built;
- missing-subset behavior is not implemented.

**Conclusion:** correct contract; incomplete implementation.

### DS-2 — real-store baseline

Solid as reference:

- 70.7 KB real file;
- 3.2 MB and 3.85 MB memory samples;
- ratios for unique mobs and instance share.

Limits:

- 762 kills is not the massive target;
- 389-kill sample has no file;
- it is not a design decision.

**Conclusion:** reference only. Correctly demoted.

### DS-3 — storage sanity

Solid for small/medium:

- save/reload identical;
- aggregate invariants pass;
- 10× = 492,835 bytes, 850 mobs, 20 zones, 1,930 cells, 10 instances;
- 10× reload ~12 ms, save ~51 ms offline.

Limits:

- contexts = 0;
- quests/deaths/respawns/rates/level history were not scaled;
- no 2,000-mob/24,000-context/163,840-cell case;
- offline serializer, not client file.

**Conclusion:** valid sanity check; not a massive-scale proof.

### DS-4 — representation

Solid decisions:

- plain Lua tables for hot data;
- stable IDs;
- no JSON/checksum identity/Base64 hot;
- one mob record with many-to-many zone/instance counts;
- derived summaries and in-memory indexes.

Limits:

- originally based on the small sample;
- now revised to "hot tier only";
- hot context/cell cost is the real issue;
- cold packing was previously optional, now required;
- index implementation is pending.

**Conclusion:** correct for the hot tier; incomplete for massive data.

### DS-5 — loading/API matrix

Solid:

- normal SavedVariables load together;
- per-character loads only the active character;
- no per-zone files;
- only a LoadOnDemand companion can defer;
- `SaveAddOns` is a checkpoint;
- `SAVED_VARIABLES_TOO_LARGE` is a load failure;
- do not call `LoadAddOn` inside `ADDON_LOADED`.

Limits:

- companion timing/persistence is V-2;
- no implementation of companion or split.

**Conclusion:** correct constraints; execution pending.

### MEM-1 — memory samples

Solid but small:

- 3.2 MB (389 kills/25 mobs);
- 3.85 MB (762 kills/85 mobs, heatmap open);
- ATT 51/65 MB; FLG 48 MB.

Limits:

- sample data is tiny;
- no 2,000-mob/24,000-context case;
- no dense 200-zone case;
- no live large-store measurement.

**Conclusion:** shows headroom and reference scale; not a large-store budget.

### Capacity model

Useful but provisional:

- 11–14 MB at 2,000 mobs/40 dense zones/12 contexts;
- 18–25 MB at 200 dense zones/200 instances;
- contexts and cells dominate, not kills.

Limits:

- structural estimate, not an actual SavedVariables file;
- context cost is approximate;
- calibrated from a no-context 10× sample;
- estimator truncation makes HC-5 unusable as a ceiling.

**Conclusion:** direction is credible, but the model overestimated the file
(8.69 MB compact vs 11–14 MB) and underestimated heap pressure (23 MB stable / 27–37 MB transient).
DS-3B supplies the actual numbers.

### DS-3B — massive synthetic validation

Executed:

- 2,000 mobs, 24,000 contexts, 40 × 4,096 cells, 100 instances;
- compact file **8,689,981 bytes** (~8.29 MiB);
- client-format estimate **9,938,701 bytes** (~9.48 MiB);
- Lua heap delta **26.99 MB** write / **36.54 MB** fresh reload before GC; **23.07 MB** stable after GC;
- load ~120 ms, normalize ~105 ms, serialize ~1,068 ms offline;
- invariants pass, fresh-process reload passes, no parser failure.

Limits:

- offline serializer, not client;
- no 200-zone hot test (current normalizer caps at 40);
- no 4/8-context variant;
- no live client memory/timing.

**Conclusion:** the current hot profile loads. Its measured heap is ~23 MB
stable / 27–37 MB transient, which is acceptable relative to ATT 51–65 MB. There
is no fixed MB target; optimize the method, not an arbitrary number. It is a
current-cap profile, not a long-term state.

## What is actually correct

These choices should stay:

- Lua tables, not JSON;
- stable IDs, not checksum identity;
- no Base64 for hot data;
- 64×64 sparse cells as the heatmap aggregate;
- no per-kill log for current features;
- one mob record with per-zone/instance counts;
- account vs per-character scope;
- no per-zone SavedVariables files;
- static metadata outside the character save;
- `SaveAddOns` as a checkpoint;
- selected-zone retrieval and in-memory indexes as the retrieval direction.

## What is still provisional

- 64×64 as the final grid for route/inspector;
- 4/8/12 context policy;
- 40 hot zones / 100 hot instances;
- 11–14 MB and 18–25 MB capacity estimates;
- packed-block format and compression ratio;
- LoadOnDemand companion;
- hot/cold boundary and retention windows;
- per-zone/per-block caps.

## What was wrong or incomplete

- Treating the current capped system as massive-ready.
- Treating DS-3 10× as a massive proof.
- Treating HC-5's truncated 2.1 MB as a ceiling.
- Treating the 2,000/40/100 caps as the design instead of retention thresholds.
- Assuming the capacity model is exact without an actual large synthetic file.
- Assuming indexes/selected-zone loading exist; they are still tasks.

## Validation result

DS-3B was executed. It validated the current hot profile:

- compact file **8.69 MB**;
- client-format estimate **9.94 MB**;
- Lua heap **23 MB stable / 27–37 MB transient**;
- invariants and fresh-process reload pass;
- no parser/constant-table failure.

It also showed that 23 MB stable is acceptable relative to ATT 51–65 MB; there
is no fixed MB target.

## Remaining validation

- long-term 3/6/12-month profiles and cap pressure (DS-3C done; DS-3C result:
  2h/day hits 2,000 mobs in ~3 months, rate buffer turns over in 2.4h);
- 4/8-context variants, if DS-17.1 finds a measured retrieval or memory benefit;
- 200-zone/200-instance and 10k/100k-mob cold-tier prototype (DS-4P done);
- live client memory and save/load timing (V-2).

## Task adjustment

- **DS-3B — Massive synthetic store validation** is complete.
- **DS-3C — Long-term growth and cap pressure** is complete.
- **DS-17.1 — Aggregation and 64×64 decision** is complete:
  `docs/DS-17-1-AGGREGATION-DECISION.md`.
- **DS-17.2** is complete; `docs/DS-17-2-MODES-LIFECYCLE-DECISION.md`.
- **DS-17.3** is complete; `docs/DS-17-3-RETENTION-DECISION.md`.
- **DS-4P** is complete: tier C 100k/200/200, 38.5 MB hot / 8.07 MB cold,
  selected-zone 3.7 ms, tooltip 0.55 ms/10k, no full scan.
- **DS-4P-F1** is complete: static names + numeric hot arrays reduce 100k
  per-character hot heap from 20.67 MB to 7.67 MB; the scoped name index
  (DS-4P-F2) is complete and now indexes live-captured names.
- **DS-4P-F2** is complete: 100k mobs 7.73 MB hot + 5.97 MB shared, 11,001
  scoped entries; no global name index.
- **DS-6** is complete and revised: **no shipped all-name list**. Metadata is
  learned live into a per-character registry. Local sample: 158 mobs, 0.05 MB;
  10k entries 4.11 MB map / 0.43 MB packed; 100k 38.25 / 4.32 MB. Cold blocks
  store IDs only; missing names fall back to `NPC <id>`. Mobs are
  zone/instance/grid-localized; a pre-kill spawn index is deferred. Shipped-name
  measurements remain as the rejected alternative.
- **DS-1-F2** is complete; `docs/DS-1-F2-INDEX-RESULT.md`.
- **DS-7/DS-12** are complete: hybrid sparse/bitset cells, varint/delta fields,
  per-zone/instance/level-band blocks, no inline names, per-block checksum, and
  per-block base64. 100k/4 contexts is 3.90 MB cold / 4.03 MB heap; 100k/12 is
  9.19 MB; 350k one-zone block 12.56 MB but ~10 ms decode, so split into
  ~256-512-mob sub-blocks (350k sub-block profile: 13.22 MB, 2.55 ms decode).
- **DS-6-F1** is complete: **account-wide stable `npc:<id>` metadata** (name,
  fixed level range, ≤4 zone refs) plus **per-character name-only** metadata.
  Raw history/observed XP stays per character. Local `/mnt/r/AceM2L2.lua`: 158
  mobs, 100 npcID / 58 name-only; 135 in one zone/instance, 23 in two; max level
  width 4. Local account part 100 entries 0.02 MB / 3.8 KB packed; name-only 58
  entries 0.01 MB / 3.7 KB packed. Account-only 10k 2.38 MB map / 0.42 MB
  packed; 100k 35.97 / 4.16 MB. No shipped all-name list.
- **DS-17.4A** is complete: local Journey inventory, context cardinality, schema
  shape, and heatmap downsampling measured. Full contexts at 10k×12 are 70.70 MB;
  top-8 covers 93.8% kills/92.3% XP; 100k metadata is 33.75 MB nested, 26.00 MB
  parallel, 4.45 MB packed. Result:
  `docs/DS-17-04A-JOURNEY-KNOWLEDGE-MODEL-RESULT.md`.
- **DS-17.4B** is complete: Wilson-bound danger, best-zone XP/hour with
  confidence, and sparse local heatmap occupancy (4.83%/4.54%/0.02%) measured.
  Result: `docs/DS-17-04B-DANGER-AND-XP-HOUR-RESULT.md`.
- **DS-17.4C** is complete: array/list contexts 4.37 MB at 10k×12 vs 70.70 MB
  keyed map; top-8+other preserves totals; packed top-8+other 1.43 MB; active
  totals preserved; sparse heatmap hotspot loss measured. Result:
  `docs/DS-17-04C-RETENTION-MERGE-COMPATIBILITY-RESULT.md`.
- **DS-17.5** is complete: v2 Journey schema, player/mob level naming fix,
  migration/backup/downgrade, and account Knowledge target. Local migration
  preserved 158 mobs, 1,993 kills, 152,816 XP, 385 cells, 16 deaths, 38 quests,
  and 69 respawns; idempotent; 0.49 MB v2 heap. Result:
  `docs/DS-17-05-SCHEMA-AND-MIGRATION-RESULT.md`.
- **DS-16** is complete: dirty-block incremental saves, backup/restore, oversize
  state, and lazy decode policy. Full 400-block encode 795 ms; dirty 1 block
  2.1 ms; full base64 decode 1.15 s, so selected-block decode is required.
  Result: `docs/DS-16-SAVE-CHECKPOINT-RESULT.md`.
- **DS-15** is complete: login decoded 0 blocks; selected block 1.7 ms;
  selected-zone 10k tooltips 1.2 ms; full decode 586 ms; random global cold
  tooltip 16.2 s without cache / 5.8 s with 256-block cache. Result:
  `docs/DS-15-LAZY-RETRIEVAL-CACHE-RESULT.md`.
- **DS-11** is complete: settled Journey/Knowledge, hot/cold, codec, schema,
  retrieval, save, rejected alternatives, implementation order, and V-2
  checklist. Result: `docs/DS-11-DECISION-RECORD.md`.
- **DS-14** is complete: 340k constants split into 4 chunks under a 100k
  prototype budget; oversized block rejected; save-blocked/backup/compaction
  and downgrade guards pass. Result: `docs/DS-14-OVERSIZE-GUARD-RESULT.md`.
- **CAP-1** is complete: health bands, combat/XP context split, mob-level range,
  active-time accumulator, heatmap cell XP/time, and death attribution/fallback
  prototyped. Result: `docs/CAP-1-JOURNEY-CAPTURE-FIELDS-RESULT.md`.
- **IMP-1** is next: Journey schema/retrieval integration.
- **MEM-2** remains the load/unload policy task.

DS-1-F2 is the only production-code change; the storage/design tasks remain documentation-only.
