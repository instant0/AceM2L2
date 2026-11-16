# DS-16 — Save/checkpoint policy result

**Status:** executed 2026-11-16  
**Harness:** `tests/ds16_save_policy.lua`  
**Scope:** offline save/checkpoint prototype; no production code, no merge.

## 1. Policy

### In-memory writes

- Kills/XP/contexts update the in-memory Journey immediately.
- Mark the affected zone/instance/level block dirty.
- Do not write SavedVariables or encode cold blocks per kill.

### Checkpoints

| Trigger | Action |
|---|---|
| Session end | Encode dirty cold blocks; checkpoint |
| Logout/reload | Normal SavedVariables save; no synchronous durability promise |
| `C_AddOns.SaveAddOns` | Explicit checkpoint; not per kill |
| `ADDONS_UNLOADING` | Final checkpoint opportunity; not a guaranteed flush |
| Migration/compression | Full re-encode with backup |
| Level/zone change | Optional dirty-block checkpoint if measured useful |

### Dirty-block encoding

- Only dirty zone/instance/level blocks are re-encoded.
- Checksum is computed during encode.
- Base64 is produced per block.
- Full-payload encode only for migration/compaction, not normal play.
- Decode only the selected block at retrieval; do not base64-decode the entire
  payload at login.

### Account Knowledge

- Not written in the current build.
- When ALT features exist, write only after merge/checkpoint, never per kill.
- No raw Journey is copied.

## 2. Measurements

Synthetic: 400 cold blocks, 10 KB raw each.

| Operation | Time | Size |
|---|---:|---:|
| Full encode, 400 blocks | 795.5 ms | 3.83 MB raw / 5.11 MB base64 |
| Dirty 1 block | 2.1 ms | 0.01 MB |
| Dirty 10 blocks | 21.2 ms | 0.13 MB base64 |
| Dirty 100 blocks | 206.5 ms | 1.28 MB base64 |
| Save encoded file | 4.2 ms | 5.12 MB |
| Full reload + base64 decode all | 1,153.6 ms | — |

### Findings

- Dirty-block saves are far cheaper than full encodes.
- Full base64 decode of 400 blocks is ~1.15 s; this must not happen at login.
- Lazy selected-block decode is required (DS-15).
- Full encode is appropriate only for migration/compaction.
- A checksum/corruption check passes on reload.

## 3. Backup and restore

- Previous encoded block generation is retained before a rewrite.
- A corrupted/new block can be discarded and the previous block restored.
- Migration/compaction must keep a recoverable previous state.
- The prototype verifies previous-block retention and restore.

## 4. `SAVED_VARIABLES_TOO_LARGE`

Policy:

1. Treat the event as a **load failure**, not a warning.
2. Set `saveBlocked = true`.
3. Stop normal saving; do not overwrite the previous file.
4. Keep/restore the previous backup.
5. Offer explicit compaction/reset recovery.
6. Do not silently drop Journey data.
7. Record the failure in diagnostics.

State machine:

```text
normal -> oversized -> compacting -> normal
```

The prototype exercises all states and confirms `saveBlocked` and
`backupAvailable`.

## 5. Decisions

- No per-kill disk writes.
- Dirty-block/incremental cold encode at checkpoints.
- Checksum during encode.
- Per-block base64; lazy decode only.
- Full encode only for migration/compaction.
- Previous generation retained for restore.
- Oversize is a failure path: stop saving, backup, compact/reset.
- Account Knowledge writes deferred.
- No merge implementation.
- No UI.

## 6. Required follow-ups

- **DS-14** — implement the oversize guard/constant-table checks and recovery
  hooks.
- **DS-15** — selected-block retrieval; do not decode all at login.
- **V-2** — verify `SaveAddOns` durability, logout/reload, `ADDONS_UNLOADING`,
  oversize threshold, base64 decode timing, and Lua 5.1/JIT behavior.
- **DS-11** — final decision.

## Acceptance

- No per-kill save: **yes**.
- Dirty-block/incremental encode: **yes**.
- Checksum/corruption handling: **yes**.
- Backup/restore: **yes**.
- Oversize recovery defined: **yes**.
- Account/character write timing explicit: **yes**.
- No merge/UI/production code: **yes**.
- No online source: **yes**.

## Artifacts

- `tests/ds16_save_policy.lua`
- `docs/DS-17-05-SCHEMA-AND-MIGRATION-RESULT.md`
- `docs/DS-7-12-PACKED-BLOCK-CODEC-RESULT.md`
- `docs/DS-5-SAVEDVARIABLES-LOADING-MATRIX.md`
