# DS-17.22 — S10B UI read retirement result

**Status:** executed 2026-11-18  
**Scope:** UI list/detail/tooltip/index reads use v2 roots; writes unchanged.  
**Test:** `tests/s10_ui_read_retirement.lua`; full suite passes.

## 1. Read ownership

The following no longer read legacy aggregate roots directly:

- mob list, Overview top mobs, Tooltip, and mob detail;
- quest ledger rows and detail;
- death/respawn history rows and detail;
- area/instance/level detail;
- heatmap selector and detail summaries;
- footer/status and diagnostics counts.

The mob index is built from `journey.mobs` and exposes v2 session kills, player
level splits, zone/instance splits, and XP statistics through a compatibility
view for existing UI code.

## 2. Sessions and XP stats

S10B adds v2 `sessionKills` and `xpStats` so UI session filters and average XP
remain available after reading the v2 mob record. Session reset clears both the
legacy projection and v2 mob counters.

## 3. Fallbacks

- Block fallback remains only when no v2 mob record exists.
- Quest names still resolve through the quest ledger.
- Writes and normalizers are unchanged.

## 4. Tests

- mob list/detail without legacy mobs;
- v2 session and XP stats;
- quest/death/respawn rows without legacy roots;
- area/instance/level detail;
- heatmap selector/detail;
- Overview/footer/diagnostics;
- updated smoke, history, quest, heatmap, tooltip, and rollback tests.

Passing output:

```text
S10 UI read retirement passed
...
All offline checks passed.
```

## 5. Limits

- Direct legacy reads remain outside UI (normalizers, writes, migration backup).
- S10C remains live-gated by V-2.
- Quest ledger names await a v2 name source.

## 6. Next

**DS-17.23 — S10C live-gated retirement.**
