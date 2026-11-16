# IMP-1 — Journey schema and retrieval integration slice result

**Status:** integration prototype executed 2026-11-16; production wiring remains  
**Harness:** `tests/imp1_integration.lua`  
**Local source:** `/mnt/r/AceM2L2.lua`  
**Scope:** end-to-end offline slice; no production code, no merge, no UI.

## 1. What was connected

- v2-ish mob records with name, NPC ID, kills, XP, ≤4 zone refs;
- per-zone cold blocks;
- base64/checksum block envelope;
- login loads blocks but decodes **zero** blocks;
- selected-zone decode;
- event-driven presence/engaged time;
- quest turn-in as a sparse presence anchor;
- separated `killXP`/`questXP`/`otherXP` for zone ranking;
- best-zone total vs kill-only XP/hour;
- heatmap top-cell query;
- danger query by combat context;
- missing/corrupt block fallback.

## 2. Local integration measurements

| Metric | Result |
|---|---:|
| Local mobs | 158 |
| Zone blocks | 3 |
| Mobs in zone blocks | 106 |
| Encoded block data | 2.2 KB |
| Login decoded blocks | **0** |
| Selected zone | map 1424 |
| Selected-block decode | **0.32 ms** |
| Records in selected block | 44–45 |
| Selected lookup | ~0.01 ms |
| Heatmap cells (map 1421) | 198 |
| Top-10 heatmap share | 23.2% |

The 52 instance/name-only mobs are not in map blocks in this slice; production
needs instance blocks and name-only local refs.

## 3. Event-driven time and quest anchor

Sequence:

```text
zone/level enter
kill
kill
quest turn-in
kill
```

Result:

```text
presenceSeconds = 160
engagedSeconds = 130
questXP = 1,150
timer_used = false
```

Quest turn-in closed the presence segment and added quest XP, but did **not**
add engaged kill time.

## 4. Best zone: total vs kill-only

Synthetic zone totals with a quest-XP zone:

| Mode | Rank 1 | XP/hour | Kill XP/hour |
|---|---|---:|---:|
| Total XP | Zone C | 300,000 | 150,000 |
| Kill-only XP | Zone B | 250,000 | 250,000 |

The ranking changes when quest XP is separated. Best-zone results should expose
both total and kill-only metrics rather than hiding quest XP inside one number.

## 5. Danger query

| Context | Samples | Death rate | Verdict |
|---|---:|---:|---|
| Solo healthy | 404 | 1.0% | safe/slaughter |
| Solo low health | 90 | 33.3% | dangerous |
| Sparse | 2 | 0% | not enough data |

## 6. Fallback

- Missing block: safe fallback.
- Corrupt block: checksum rejected.
- No full scan.
- Quest state not in mob context.
- Quest anchor does not count as engaged time.

## 7. Findings

1. **The offline pieces connect.** Selected-zone decode, event time, quest anchor,
   best-zone XP/hour, heatmap top cells, and danger all work together.
2. **Login decodes zero blocks.**
3. **Selected-block decode is sub-millisecond** on the local sample.
4. **Quest turn-in is useful as a sparse anchor.** It updates presence and quest
   XP without inflating engaged kill time.
5. **Quest XP changes the best-zone ranking.** Keep `killXP`, `questXP`,
   `otherXP`, and total XP separate.
6. **Instance/name-only mobs need their own blocks/references** in production.
7. **No production code changed.** This is an integration slice, not the final
   wiring.

## 8. Decisions carried forward

- Event-driven time only; no timer/OnUpdate.
- Quest turn-in via existing `QUEST_TURNED_IN`; no new event.
- Best zone: total XP/hour and kill-only XP/hour.
- Selected-block lazy decode.
- No full scan.
- No merge/UI.
- Production integration remains.

## 9. Follow-ups

- **IMP-1A** — production Journey integration:
  - v2 schema/migration in production code;
  - capture fields from CAP-1;
  - instance/name-only blocks;
  - dirty-block save/guard;
  - selected decode/cache;
  - tooltip/danger/best-zone/heatmap;
  - tests.
- **V-2** — live API/data timings.
- **UI** — tooltip danger, suggested zone, heatmap best part.

## Acceptance

- Offline integration slice: **yes**.
- Login zero decode: **yes**.
- Event-driven time: **yes**.
- Quest anchor/XP split: **yes**.
- Best-zone total vs kill-only: **yes**.
- Heatmap/danger/fallback: **yes**.
- Production code: **no**.
- No merge/UI/online: **yes**.

## Artifacts

- `tests/imp1_integration.lua`
- `docs/CAP-1-JOURNEY-CAPTURE-FIELDS-RESULT.md`
- `docs/DS-17-05-SCHEMA-AND-MIGRATION-RESULT.md`
- `docs/DS-15-LAZY-RETRIEVAL-CACHE-RESULT.md`
- `docs/DS-16-SAVE-CHECKPOINT-RESULT.md`
- `docs/DS-11-DECISION-RECORD.md`
