_____________________________________________________________________________________

Ace Mobs 2 Level 2 (AceM2L2)
XP, reputation, and Kill Story

Author:     faslkjd56
Version:    2.1.0
GameVer.:   Midnight 12.1.5 (Retail) / Forever 1.60.1 (Classic+)
_____________________________________________________________________________________

Level faster with less guesswork.

AceM2L2 shows how many kills or quest hand-ins you need for your next level or
reputation rank. Its bundled Kill Story window keeps the details: what you
killed, where you killed it, how fast you are leveling, what you looted, and
where your kills cluster on each zone map.

_____________________________________________________________________________________

	FEATURES
_____________________________________________________________________________________

Progress at a glance
- Kills-to-level and reputation-repeat estimates in chat.
- XP remaining, kills remaining, and time-to-level.
- XP/hour and XP/minute from measured gains.
- Works with normal kills, unnamed kills, groups, raids, quests, and rested XP.

Kill Story window
- Overview, Mobs, Areas, Heatmap, and Levels tabs.
- Kill history by mob, player level, area, and session.
- Quest XP ledger and per-level leveling history.
- Dungeon XP, leveling goals, and speedrun splits.
- Loot value, gold/hour, and clear gear-upgrade notifications.
- Death locations, respawn intervals, and grinding-spot suggestions.
- Per-zone kill heatmap with a 16x16 density grid.
- 3D mob model, search, filters, sort modes, and multiple themes.
- Minimap icon, addon-compartment entry, and Ctrl+Shift+X keybind.

Tooltips
- Forever: XP estimates, percent of level, XP remaining, mob level,
  kills-to-level, rested bonus, XP bonuses, and kill counts.
- Midnight: kill count and target level only, with no XP claims.
- Optional level text above nameplates on Midnight, off by default.

Quality of life
- Per-character history is stored separately for Forever and Midnight.
- Settings use native section headers and a Tooltip subpage.
- Reads safely around restricted or secret game data.
- No external Ace3 install required; libraries are embedded.

_____________________________________________________________________________________

	FOREVER AND MIDNIGHT
_____________________________________________________________________________________

Forever 1.60.1 — full mode
- Full XP formula, tooltip estimates, calibration, and rested/buff models.
- XP rate, time-to-level, and grinding-spot suggestions.
- Well Fed XP Boost food, Well-Rested, and Camp Tent rested XP.
- Quest XP, leveling history, loot, gold, deaths, respawns, and heatmaps.

Midnight 12.1.5 — counts-focused mode
- Kill, area, level, and session tracking with the full Kill Story window.
- Heatmaps, death locations, respawns, dungeon activity, goals, splits,
  loot, gold, and gear upgrades without XP claims.
- Optional nameplate levels.
- No XP rate, grinding-spot, calibration, rested, or buff claims until the
  Midnight data is live-verified.

_____________________________________________________________________________________

	QUICK START
_____________________________________________________________________________________

1. Copy the `AceM2L2` folder into `Interface/AddOns/`.
2. Enable the addon and run `/reload`.
3. Open Kill Story with `/acem2l2 xpt ui`, `/acem2l2 history`, the minimap icon,
   the addon compartment, or Ctrl+Shift+X.
4. Open settings with `/acem2l2 config`.

Commands are discoverable in game:
- `/acem2l2 help` — core XP and reputation commands.
- `/acem2l2 xpt help` — Kill Story commands.

Kill Story is the display name. The internal folder, saved-variable namespace,
and `/xpt` command prefix keep their original names for compatibility.

_____________________________________________________________________________________

	WHAT YOU WILL SEE
_____________________________________________________________________________________

Chat:
- `[15] [Blind Bureaucrat] kills to level`
- `[23463] to go with [Darnassus] = [502] repeats (kills/quests)`

Window tabs:
- Overview — session totals, top mobs, level range, rate, dungeon, goal,
  economy, world data, and recent level history.
- Mobs — search, filter, sort, remove one mob, or clean Unknown rows.
- Areas — where you have been killing.
- Heatmap — switch zones, inspect a 16x16 kill-density grid, and see the zone
  total. Map art is optional; the grid works without it.
- Levels — kill and XP performance by player level.

Tips:
- Drag the window to move it; drag the 3D model to rotate it.
- Press Escape or the X button to close the window.
- Use `/acem2l2 xpt debug on` only when reporting a problem.
- Back up `WTF/Account/<account>/SavedVariables/AceM2L2*.lua` before major
  upgrades.

_____________________________________________________________________________________

	KNOWN LIMITATIONS
_____________________________________________________________________________________

- Heatmaps keep up to 40 zones; each zone is a 16x16 grid.
- Death history keeps 100 deaths; respawn tracking keeps 300 NPCs with up to
  20 samples each.
- Quest history keeps 200 quests; level history keeps 200 records; rate history
  keeps 240 samples; mob history keeps 2000 mobs per client.
- Heatmaps, death locations, respawns, and nameplate levels need the client's
  map-position and nameplate APIs. Missing or secret values limit those features
  without stopping normal kill tracking.
- Grinding spots need at least 5 kill-XP samples over 120 seconds, so short
  sessions may not produce a recommendation.
- Midnight XP estimates, calibration, kills-to-level, rested, and buffs stay
  off until its data is live-verified.
- Live verification of quest XP labels, group/dungeon XP, and Midnight behavior
  is still pending.

_____________________________________________________________________________________

	CHANGELOG
_____________________________________________________________________________________

2.1.0 — User-facing documentation refresh, Kill Story naming throughout, and
        reliability fixes for settings ranges, world/economy normalization,
        tooltip hooks, debug output, migration, and restricted API data.
2.0.0 — Major feature release: XP rate and time-to-level, dungeon XP, leveling
        goals, speedrun splits, loot value, gold/hour, gear upgrades, death
        locations, respawn tracking, grinding spots, optional nameplate levels,
        and per-zone kill heatmaps.
1.14.x — Tooltip, quest XP, leveling history, buff, and settings improvements.
1.13.0 — Internal refactor, normalization, and focused test suite.
1.12.0 — Midnight counts-focused support and per-client data.
1.11.x — Kill Story window, Aether theme, search, and tracking improvements.
Older   — Compatibility updates for Midnight, Dragonflight, BfA, and Legion.
