# README claim review

**Status:** reviewed/edited 2026-11-15; UI-3/UI-4 implemented 2026-11-16  
**File reviewed:** `README.txt`  
**Question:** does the README claim features that are not actually in the addon?

## Verdict

Most headline claims map to real code or commands. Three claims were misleading
about **where** the feature exists, and one was too broad. The README was edited
and follow-up UI tasks were created.

## Findings

| Claim | Actual state | Action |
|---|---|---|
| “Quest XP ledger (Forever)” under Kill Story window | Data, `/acem2l2 xpt quests`, and the Quests tab now exist; Overview also shows the summary. | **UI-4 done**; README restored the window claim. |
| “Death locations, respawn intervals” under Kill Story window | Both exist via `/acem2l2 xpt deaths`, `/acem2l2 xpt respawns`, and the History tab. | **UI-3 done**; README restored the window claim. |
| “Kill history by … session” | Current-session totals exist; there is no session-history list. | README now says “current-session totals” |
| “Full zone art” | Map art where the client/generated data provides it; not a guarantee for every zone. | README now says “Zone-map art where … available” |
| XP, kills-to-level, reputation repeats | Implemented in core/chat | No change |
| Tabs and mob/area/level history | Implemented | No change |
| Level history/splits | Implemented as level-time/kill splits, not speedrun segments | Already qualified |
| Dungeon XP/goals/splits | Implemented; dungeon XP Forever-only | Already qualified |
| Loot value, gold/hour, gear upgrades | Implemented; gear compare is live-unverified | README adds live-unverified caveat |
| Grinding spot | Overview, Forever-only | README now says Overview |
| Heatmap 64×64, art, reveal, gradient, paging | Implemented | No change except “full art” wording |
| Diagnostics | Implemented | No change |
| Tooltips/nameplates | Implemented and client-gated | No change |
| Search/filter/sort/themes/3D model | Implemented | No change |
| Per-character and per-client storage | Implemented | No change |

## Edits made to README.txt

- Quest ledger → Quests tab plus command.
- Death/respawn → History tab plus commands.
- Session history → current-session totals.
- “Full zone art” → “Zone-map art where available.”
- Added a live-unverified caveat for gear comparison, Midnight dungeon/death
  data, and zone art coverage.

## Tasks generated

- **UI-3 — Death and respawn history view**
  `docs/tasks/UI-3-DEATH-RESPAWN-VIEW.md`
- **UI-4 — Quest XP ledger view**
  `docs/tasks/UI-4-QUEST-XP-LEDGER-VIEW.md`

Both use existing data/commands and require no storage-schema change.

## Not changed

- No production code.
- No new storage.
- No claim was removed if it was already available through a command or setting;
  the wording now says where it lives.
