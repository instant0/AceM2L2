_____________________________________________________________________________________

Ace Mobs 2 Level 2 (AceM2L2)
XP, reputation, and Kill Story

Author:     faslkjd56
Version:    2.5.0
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
- Forever: normal kills, unnamed kills, groups, raids, quests, and rested XP.

Kill Story window
- Overview, Mobs, Areas, Heatmap, and Levels tabs.
- Kill history by mob, player level, area, and session.
- Quest XP ledger (Forever) and per-level leveling history.
- Dungeon XP (Forever), leveling goals, and level-time splits.
- Loot value, gold/hour, and gear-upgrade notifications.
- Death locations, respawn intervals, and grinding-spot suggestions (Forever).
- Resizable window, search, filters, sort modes, multiple themes, and a 3D mob
  model.

Heatmap
- Per-zone 64x64 kill-density grid with static zone-map art underneath.
- Full zone art, including a "Reveal unexplored areas" option that is on by
  default.
- A multi-stop heat gradient (theme accent to gold to red) so the busiest
  cells are the hottest, with adjustable contrast and an optional fire palette
  in Settings > Heatmap.
- Zone paging, map-art fallback, and a Low-to-High gradient legend with the
  zone total.
- Heatmap collection can be disabled in Settings > Heatmap. The tab stays
  visible with a disabled message, and existing data can be cleared separately.

Data insights
- Kill counts by mob, area, level, and session.
- Dungeon kills are attributed to the instance name instead of a world map.
- Data diagnostics: middle-click the minimap icon or use
  `/acem2l2 xpt data` to see tracked counts, limits, heatmap cells, and an
  estimated store size.

Tooltips
- Forever: XP estimates, percent of level, XP remaining, mob level,
  kills-to-level, rested bonus, XP bonuses, and kill counts.
- Midnight: kill count and target level only, with no XP claims.
- Optional level text above nameplates on Midnight, off by default.

Quality of life
- Per-character history is stored separately for Forever and Midnight.
- Native Settings sections with dedicated Tooltip and Heatmap subpages.
- Reads safely around restricted or secret game data.
- Minimap icon, addon-compartment entry, and Ctrl+Shift+X keybind.
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
- Heatmaps, death locations, respawns, dungeon activity, goals, splits, loot,
  gold, and gear upgrades without XP claims.
- Optional nameplate levels.
- XP rate, grinding spots, calibration, rested, and buff claims stay off until
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
- Heatmap — switch zones, inspect a 64x64 kill-density grid, and see the zone
  total. Map art is optional; the grid works without it.
- Levels — kill and XP performance by player level.

Tips:
- Drag the window to move it; drag the 3D model to rotate it.
- Press Escape or the X button to close the window.
- Middle-click the minimap icon (or run `/acem2l2 xpt data`) to inspect tracked
  counts and the approximate store size.
- Use `/acem2l2 xpt debug on` only when reporting a problem.

_____________________________________________________________________________________

	GOOD TO KNOW
_____________________________________________________________________________________

- Forever gets the full XP and tooltip experience. Midnight runs in
  counts-focused mode for XP-related features.
- Heatmaps use stored kill records and static zone art, not a live map or
  minimap. The "Reveal unexplored areas" option uses generated official client
  map-overlay data.
- Heatmaps, death locations, and respawns need the client's map-position APIs.
  Nameplate levels need the client's nameplate API.
- History is stored per character and per client. Safety caps keep the window
  responsive; the Data diagnostics panel shows current usage and estimated size.
- Keeping a modest history is intentional: it keeps login, save, and the
  window responsive. Use the diagnostics panel if you want to see how much is
  currently tracked.
