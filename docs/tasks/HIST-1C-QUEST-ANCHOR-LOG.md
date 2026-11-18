# HIST-1C — Bounded quest-anchor log

**Status:** executed 2026-11-17  
**Result:** `docs/HIST-1C-QUEST-ANCHOR-RESULT.md`  
**Harness:** `tests/quest_anchors.lua`  
**Depends on:** HIST-1A, HIST-1B, IMP-1A  
**Blocks:** HIST-1D

## Why

Area Detail currently shows only the latest quest anchor from `db.quests`. A
historic journey view needs multiple timestamped turn-in locations, without a
per-kill log or a quest database.

## Revised storage shape

Add an optional sparse field:

```text
journey.questAnchors = {
  { questID, mapID, x, y, at, playerLevel, xp },
  ...
}
```

Rules:

- **no quest name stored** — resolve it from `db.quests`;
- no quest text duplication;
- coordinates are optional and omitted when unavailable;
- one record per turn-in event;
- no per-kill timestamps;
- no static quest database.

## Capture

Capture on quest turn-in only, from `OnJourneyQuestTurnIn`:

- `questID` when available;
- `mapID` from the player map position or current map;
- `x`/`y` only when the map-position API returns a real position;
- `at` timestamp;
- player level;
- XP reward.

If the position is unavailable, store map/level/time but do **not** invent
coordinates.

## Retention

- cap: **5,000 anchors**;
- newest by `at`, deterministic tie-break;
- no age pruning initially;
- no block encoding initially;
- optional field remains compatible with older builds.

5,000 covers the known 50-zone, 50+ quests/zone shape (about 2,500 normal
turn-ins) with headroom. It is not a per-kill or per-quest-text log.

## Schema

- add optional `journey.questAnchors`;
- no journey schema bump required for an optional additive field;
- older builds ignore unknown optional data;
- `ResetKills` clears anchors with the rest of Journey.

## UI use

Area Detail’s “Latest quest anchors” section should:

1. prefer anchors for the selected map;
2. sort by `at` descending;
3. resolve names from `db.quests`;
4. fall back to the existing `lastTurnInAt` fields when no anchors exist;
5. cap displayed rows.

## Tests

- one turn-in produces one anchor;
- missing position stores no fake coordinates;
- map/level/time captured correctly;
- quest names resolve from `db.quests`, not duplicated in anchors;
- cap 5,000 enforced deterministically;
- Area Detail filters by map and falls back cleanly;
- no per-kill records are created.

## Acceptance

- Sparse anchor log exists.
- Capture is event-driven and bounded.
- Area Detail uses it without changing active behavior.
- No quest text duplication.
- No account Knowledge.

## Not required

- full quest history;
- quest text database;
- account merge;
- live client test.
