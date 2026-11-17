# UI-4 — Quest XP ledger view result

**Status:** executed 2026-11-16  
**Production modules:** `KillHistory/UI/List.lua`,
`KillHistory/UI/Detail.lua`, `KillHistory/UI/Window.lua`  
**Test:** `tests/quest_ledger.lua`; `./tests/run_all.sh`  
**Scope:** existing quest ledger data only. No schema or storage change.

## 1. Quests tab

Added a **Quests** tab backed by `db.quests`.

Rows show:

- quest name;
- total XP;
- gain count.

Controls:

- search by quest name or key;
- sort cycle: **XP → Count → Name → Recent**;
- default XP ordering matches the command’s primary ordering;
- displayed rows are capped at 100; stored records are untouched.

## 2. Quest detail

The detail panel shows:

- quest ID/key;
- total XP;
- gain count;
- average XP per gain;
- first seen;
- last seen;
- command hint.

No quest identity is inferred when the client does not provide it.

## 3. Client gating

`hasPerMobXP` gates the ledger:

- supported clients show normal rows;
- unsupported/Midnight clients show an explicit
  “Quest XP is not tracked on this client” state, not a false empty ledger.

## 4. Tests

`tests/quest_ledger.lua` verifies:

- Quests tab and row count;
- default XP sort;
- count/name/recent sorts;
- search by name;
- detail values and average;
- command parity for summary and rows;
- empty state;
- unsupported state;
- displayed-row cap.

Passing output:

```text
Quest ledger passed
```

`./tests/run_all.sh` passes.

## 5. Limitations

- No quest database or static metadata.
- No new storage/schema.
- Live Forever/Midnight presentation remains a V-2 visual check.
- Command remains available for full output.

## 6. Next

**MEM-2 — Load/unload and eviction policy.**

## Artifacts

- `KillHistory/UI/List.lua`
- `KillHistory/UI/Detail.lua`
- `KillHistory/UI/Window.lua`
- `tests/quest_ledger.lua`
- `tests/run_all.sh`
- `README.md`
