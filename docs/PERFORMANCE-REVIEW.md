# Performance and storage task review

**Status:** reviewed 2026-11-15  
**Scope:** completed tasks that affect storage, retrieval, loading, and memory:
H64-9, HC-5, DS-1, DS-2, DS-3, DS-4, DS-5, MEM-1, and the capacity model.  
**Question:** are the choices correct, or only provisional?

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
| Static metadata outside the character save | Correct direction; DS-6 not done |
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
- 200-zone/200-instance and 10k/100k-mob cold-tier prototype (DS-4P/DS-17.3);
- live client memory and save/load timing (V-2).

## Task adjustment

- **DS-3B — Massive synthetic store validation** is complete.
- **DS-3C — Long-term growth and cap pressure** is complete.
- **DS-17.1** is next; it consumes the actual DS-3B and DS-3C numbers.
- **DS-4P** remains required.
- **DS-1-F2** remains the first safe code task after validation/design.
- **DS-7/DS-12** remain required for cold packing.
- **MEM-2** remains the load/unload policy task.
- **DS-17.5/DS-11** remain the schema/migration/decision gate.

No production code changed.
