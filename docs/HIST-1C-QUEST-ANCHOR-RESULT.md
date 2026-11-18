# HIST-1C — Bounded quest-anchor log result

**Status:** executed 2026-11-17  
**Production modules:** `KillHistory/Journey.lua`,
`KillHistory/JourneyQueries.lua`, `KillHistory/UI/Detail.lua`  
**Test:** `tests/quest_anchors.lua`; `./tests/run_all.sh`  
**Scope:** sparse turn-in anchors only. No quest database, block encoding, or
account Knowledge.

## 1. Storage

Optional field:

```text
journey.questAnchors = {
  { questID, mapID, x, y, at, playerLevel, xp },
  ...
}
```

- no quest name stored;
- coordinates only when available;
- no per-kill records;
- no quest text;
- cap **5,000**;
- newest retained by timestamp;
- loaded over-cap arrays are trimmed at `EnsureJourney`.

## 2. Capture

`OnJourneyQuestTurnIn` now records:

- quest ID;
- map ID from player position, falling back to current map;
- `x`/`y` only when the map-position API returns a real position;
- timestamp;
- player level;
- XP reward.

Missing position stores no coordinates rather than `0,0`.

## 3. Query/UI

Added `GetQuestAnchors(mapID, count)`:

- filters by map;
- sorts by timestamp;
- resolves quest names from `db.quests`;
- caps results.

Area Detail’s “Latest quest anchors” now:

1. prefers anchor records for the selected map;
2. shows time and coordinates when available;
3. falls back to the existing `lastTurnInAt` view when no anchors exist.

## 4. Tests

`tests/quest_anchors.lua` verifies:

- one turn-in creates one anchor;
- map/level/time/XP fields;
- real coordinates captured;
- missing position stores no fake coordinates;
- map filtering;
- names resolve from the quest ledger, not copied into anchors;
- 5,001 → 5,000 cap and oldest pruning;
- Area Detail prefers anchors;
- no block decode.

Passing output:

```text
Quest anchors passed
```

`./tests/run_all.sh` passes.

## 5. Limitations

- No age pruning.
- No block/cold encoding.
- No full quest history beyond the bounded anchor list.
- Quest turn-in location is player position, not necessarily the NPC’s exact
  position.
- No account Knowledge.

## 6. Next

**G-2 — 64 vs 96/128 occupancy study.**

## Artifacts

- `KillHistory/Journey.lua`
- `KillHistory/JourneyQueries.lua`
- `KillHistory/UI/Detail.lua`
- `tests/quest_anchors.lua`
- `tests/run_all.sh`
- `docs/tasks/HIST-1C-QUEST-ANCHOR-LOG.md`
