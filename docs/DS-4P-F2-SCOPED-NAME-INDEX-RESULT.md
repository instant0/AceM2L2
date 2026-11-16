# DS-4P-F2 — Scoped/lazy name index result

**Status:** executed 2026-11-16  
**Harness:** `tests/ds4p_f2_nameindex.lua`  
**Scope:** hot name-index representation only; no production schema.

## Model

- Shared static names keyed by `npcID` for known NPCs.
- Per-character hot names only for:
  - name-only mobs (10% test mix);
  - IDs missing from static metadata (1% mix).
- Scoped name→ID index only for those hot names.
- Static NPC names are resolved by `npcID`, not by a global name index.
- Ambiguous names return `nil`; they are not guessed.
- No full mob scan.

## Results

### 10k mobs

| Metric | Value |
|---|---:|
| Hot heap | **0.95 MB** |
| Shared static heap | **0.67 MB** |
| Total | **1.62 MB** |
| Scoped name-index entries | 1,101 |
| Tooltip 10k lookups | 1.38 ms |
| Name lookup 10k | 3.30 ms |
| Name hits (first 10k IDs) | 1,100 |

### 100k mobs

| Metric | Value |
|---|---:|
| Hot heap | **7.73 MB** |
| Shared static heap | **5.97 MB** |
| Total | **13.70 MB** |
| Scoped name-index entries | 11,001 |
| Tooltip 10k lookups | 1.48 ms |
| Name lookup 10k | 2.94 ms |
| Name hits (first 10k IDs) | 1,100 |

## Comparison

| Model | Hot | Shared | Total |
|---|---:|---:|---:|
| F1 baseline names + global index | 20.67 MB | 0 | 20.67 MB |
| F1 static + global index | 7.67 MB | 14.00 MB | 21.67 MB |
| F1 static, no name index | 6.83 MB | 6.00 MB | 12.84 MB |
| **F2 scoped name index** | **7.73 MB** | **5.97 MB** | **13.70 MB** |

F2 is close to the no-index lower bound while retaining name-only/ambiguous
fallback.

## Findings

1. A global name→ID index is unnecessary for NPC-ID tooltip lookup.
2. Scoping the name index to name-only/missing-static mobs adds only ~0.9 MB hot
   at 100k in this prototype.
3. Shared static names cost ~6 MB for 100k in this model; that is reusable across
   characters.
4. Static NPC names are not in the name index. If the client exposes no NPC ID,
   a static name cannot be resolved by name; the tooltip falls back rather than
   guessing.
5. Name-only and missing-static names resolve correctly.
6. Ambiguous names return `nil`.
7. Tooltip/name lookup remains fast and scan-free.
8. No arbitrary MB target is used.

## Decision

Adopt:

- numeric hot arrays for counts/XP/zone/refs;
- shared/versioned static names keyed by `npcID`;
- scoped name→ID index only for name-only/ambiguous/missing-static mobs;
- no per-character copies of static names;
- no global name index for all static NPCs;
- ambiguous names stay unresolved.

If static-name fallback without an NPC ID is later required, build a per-zone
scoped name index on demand rather than a global one. That is a DS-15 query
decision, not a reason to inflate the hot index now.

## Follow-up completed

**DS-6 — Static metadata feasibility** was executed 2026-11-16 and revised
after review (`docs/DS-6-STATIC-METADATA-RESULT.md`). Outcome:

- no portable public name-by-ID API; capture stays authoritative;
- **no shipped all-name list**; metadata is learned live and stored in a
  per-character registry keyed by `npc:<id>` or `name:<lower>`;
- cold blocks store no names; missing names fall back to `NPC <id>`;
- the scoped name index remains only for name-only/ambiguous captured names;
- the shipped-name measurements are retained as the rejected alternative;
- do not copy QuestieDB/ATT/Carbonite.

The scoped index is still required, but it indexes live-captured names rather
than a shipped static dictionary.

## Artifacts

- `tests/ds4p_f2_nameindex.lua`
- `docs/DS-4P-F1-HOT-INDEX-RESULT.md`
- `docs/DS-4P-HYBRID-PROTOTYPE-RESULT.md`

No production code changed.
