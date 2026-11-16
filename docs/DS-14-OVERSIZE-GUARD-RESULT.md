# DS-14 — Constant-table and oversize guard result

**Status:** executed 2026-11-16  
**Harness:** `tests/ds14_oversize_guard.lua`  
**Scope:** offline guard/recovery prototype; no production code, no merge, no UI.

## 1. Constant-budget guard

The exact client constant-table limit is not assumed here. A configurable
budget is used; the real limit remains a V-2 check.

Prototype profile:

- budget: **100,000** constants/chunk;
- 400 packed blocks;
- 850 constants/block;
- total: **340,000** constants.

Result:

| Metric | Value |
|---|---:|
| Chunks | 4 |
| Blocks covered | 400 / 400 |
| Largest chunk | 99,450 constants |
| Within budget | yes |
| Single block over budget | rejected with reason |

A block that exceeds the budget by itself is rejected rather than silently
truncated. The packer must split or compact before save.

## 2. Oversize/save-blocked state

State machine:

```text
normal -> oversized -> compacting -> normal
```

Verified:

- `SAVED_VARIABLES_TOO_LARGE`-style event sets `saveBlocked = true`;
- save attempts are rejected while blocked;
- no write occurs while blocked;
- compaction requires a backup;
- backup restore succeeds;
- normal save resumes after compaction;
- no silent data drop;
- recovery is user-visible.

Save/write counts in the prototype:

```text
save attempts = 3
writes = 2
```

Only the allowed saves wrote.

## 3. Schema downgrade guard

- schema 2 accepted;
- schema 3 rejected by the current build;
- newer schema is read-only, not overwritten.

## 4. Policy

- Packed blocks are split under a measured constant budget.
- A single oversized block is rejected, not truncated.
- `SAVED_VARIABLES_TOO_LARGE` is a load failure:
  - stop normal saving;
  - preserve previous generation;
  - run explicit compaction/reset;
  - show diagnostics.
- No per-kill save.
- No account Knowledge write.
- No merge/UI.
- No silent data loss.

## 5. Findings

1. **Chunking is required.** A 340k-constant payload split into four budgeted
   chunks remains under the prototype budget.
2. **Oversized single blocks must be rejected**, not written partially.
3. **Save blocking works.** Blocked saves do not write.
4. **Backup/restore works.**
5. **Downgrade is safe.** Newer schemas are read-only.
6. **The exact client limit is still a V-2 check.**
7. **No production code changed.**

## 6. Follow-ups

- **V-2** — verify actual Lua constant-table limit and `SAVED_VARIABLES_TOO_LARGE`
  behavior on Forever/Midnight.
- **CAP-1** — capture fields required by the v2 Journey.
- **IMP-1** — integrate schema, save, guard, retrieval.
- **DS-11** — decision record remains the governing decision.

## Acceptance

- Constant-budget chunking: **yes**.
- Oversized block rejected: **yes**.
- Save-blocked state: **yes**.
- Backup/restore: **yes**.
- Downgrade guard: **yes**.
- No per-kill save, merge, UI, production code: **yes**.
- No online source: **yes**.

## Artifacts

- `tests/ds14_oversize_guard.lua`
- `docs/DS-16-SAVE-CHECKPOINT-RESULT.md`
- `docs/DS-5-SAVEDVARIABLES-LOADING-MATRIX.md`
- `docs/DS-11-DECISION-RECORD.md`
