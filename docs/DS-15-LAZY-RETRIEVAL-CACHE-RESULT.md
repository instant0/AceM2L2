# DS-15 — Lazy retrieval/cache result

**Status:** executed 2026-11-16  
**Harness:** `tests/ds15_retrieval.lua`  
**Scope:** offline retrieval prototype; no production code, no merge, no UI.

## 1. On-demand model

The cold payload is stored as per-block base64 strings plus a small block index.

At login:

- load the block index and base64 strings;
- **decode zero blocks**;
- build/load only the compact metadata needed for queries.

On demand:

- decode the selected zone/instance/level block;
- verify its checksum;
- parse only that block;
- cache it.

The current build has no LoadOnDemand companion. Therefore the base64 strings
are still loaded by SavedVariables at login, but their **decode** is deferred.
A companion could defer the strings themselves; that remains a V-2 timing check.

## 2. Measurements

Synthetic: 400 blocks × 250 mobs = 100,000 mobs.

| Metric | Result |
|---|---:|
| Raw cold bytes | 1.76 MB |
| Base64 blocks | 2.35 MB |
| Login load, no decode | **8.0 ms** |
| Login decoded blocks | **0** |
| Full decode of all blocks | **586 ms** |
| Selected block decode | **1.7 ms** |
| Selected-block tooltip, 10k lookups | **1.2 ms** |
| Best-zone query, 10k | 77.6 ms |
| Heatmap top-cell query, 10k | 0.34 ms |

### Selected-zone tooltip

One block decode (1.7 ms) then 10,000 lookups in 1.2 ms. This is the intended
path.

### Random global cold tooltip

10,000 random mobs across 400 cold blocks:

| Cache | Time | Hit rate | Decoded blocks |
|---|---:|---:|---:|
| none | 16.2 s | 0% | 10,000 |
| 16 | 14.2 s | 3.8% | 9,615 |
| 64 | 12.6 s | 15.7% | 8,430 |
| 256 | 5.8 s | 62.3% | 3,768 |

**Finding:** decoding arbitrary cold blocks for a global tooltip is too
expensive. Global tooltip lookup must use hot data, the metadata registry, or
account Knowledge. Cold block decode is for the selected/active zone or a
bounded cache miss.

## 3. Best zone and heatmap

- Best-zone query uses per-zone/level XP and active-time summaries; no block
  decode.
- 10k queries in 77.6 ms.
- Heatmap top-cell query uses the retained top-N hotspot summary; no block
  decode.
- 10k queries in 0.34 ms.

## 4. Fallback and corruption

- Missing block → safe fallback; no crash.
- Corrupt block → checksum rejected; cache not poisoned.
- Previous block/backup remains available.

## 5. Decisions

- Login must **not** decode all cold blocks.
- Decode only the selected block; cache it.
- Use a bounded LRU; size it for active zones, not arbitrary global access.
- Tooltip:
  - current hot mob first;
  - account/static metadata;
  - selected cold block if needed;
  - `NPC <id>` fallback.
- Best zone and heatmap use summaries, not block decode.
- No full scan, no global name index.
- No merge/UI.
- A LoadOnDemand companion may defer the base64 strings themselves; V-2 check.

## 6. Findings

1. **On-demand decode works.** Login decoded zero blocks.
2. **Selected block decode is 1.7 ms**, and 10k selected-zone lookups are 1.2 ms.
3. **Full decode is 586 ms** and must not happen at login.
4. **Random global cold tooltips are too expensive**, even with a 256-block
   cache; use hot/registry/summary paths.
5. **Best-zone and heatmap summaries are cheap** and require no block decode.
6. **Missing/corrupt blocks fail safely.**
7. **Base64 strings still load at login** unless a companion defers them.
8. **No merge/UI/production code.**

## 7. Follow-ups

- **DS-11** — decision record with V-2-conditional items.
- **V-2** — LoadOnDemand variable timing, selected-block latency, cache behavior,
  SavedVariables load/serialize.
- **DS-14** — oversize guard implementation.
- **DS-17.4D** — account Knowledge prototype later.
- **UI** — tooltip danger, suggested zone, heatmap best part later.

## Acceptance

- Login decodes zero blocks: **yes**.
- Selected-block decode/cache: **yes**.
- Best-zone/heatmap summary queries: **yes**.
- No full scan: **yes**.
- Missing/corrupt fallback: **yes**.
- Random global cold tooltip limitation measured: **yes**.
- No merge/UI/production code: **yes**.
- No online source: **yes**.

## Artifacts

- `tests/ds15_retrieval.lua`
- `tests/ds16_save_policy.lua`
- `docs/DS-16-SAVE-CHECKPOINT-RESULT.md`
- `docs/DS-17-04C-RETENTION-MERGE-COMPATIBILITY-RESULT.md`
- `docs/DATA-MODEL-PLAN.md`
