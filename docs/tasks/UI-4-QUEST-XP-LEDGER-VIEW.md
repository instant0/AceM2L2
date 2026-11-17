# UI-4 — Quest XP ledger view

**Status:** executed 2026-11-16; Forever-only; no storage schema change  
**Result:** `docs/UI-4-QUEST-LEDGER-RESULT.md`  
**Harness:** `tests/quest_ledger.lua`  
**Depends on:** UI-1, DS-1  
**Blocks:** none  
**Related:** README claim review, `docs/README-CLAIM-REVIEW.md`

## Why

The quest data and command already exist:

- `db.quests`
- `/acem2l2 xpt quests`

But the README previously implied a quest ledger was part of the Kill Story
window. Only the summary appears in Overview; the full list is command-only.
This task adds the missing UI without changing storage.

## Scope

Add a Forever-only quest ledger view:

- quest name or key;
- gain count;
- total XP;
- last seen;
- optional average XP per gain;
- sort by XP/count/name/recent;
- search/filter;
- summary line.

Use the existing `db.quests` ledger and `GetQuestSummary`. Do not add a new
SavedVariables root.

## Requirements

- Gate on `hasPerMobXP`; Midnight shows "quest XP is not tracked on this client."
- Match `/acem2l2 xpt quests` for the same records.
- Do not infer quest identity when the client does not provide it.
- Keep the list bounded; cap displayed rows, not stored data.
- No schema or storage change.

## Acceptance

- Existing quest records are visible in the window on Forever.
- Values match `/acem2l2 xpt quests`.
- Midnight shows an explicit unsupported state, not an empty false ledger.
- No schema or storage change.
- README can move the quest ledger back under the window claim.

## Not required

- New storage.
- Quest database/static metadata.
- Live client test beyond the normal validation gate.
