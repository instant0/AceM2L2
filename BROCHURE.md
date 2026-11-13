# Ace Mobs 2 Level 2 — Kill Story

![AceM2L2 logo](assets/AceM2L2-logo.png)

**Level faster with less guesswork.**

AceM2L2 turns WoW leveling into readable progress: kills-to-level, reputation
repeats, XP rate, kill history, quest XP, loot value, death locations, respawn
timers, and per-zone kill heatmaps. It works on **Forever 1.60.1** and
**Midnight 12.1.5**, with full XP estimates on Forever and a counts-focused
experience on Midnight.

![AceM2L2 brochure](assets/AceM2L2-brochure.png)

## Why install it?

- **Know the next level.** See kills remaining, XP remaining, XP/hour, and time
  to level.
- **Know what you killed.** Kill Story tracks mobs, levels, areas, sessions, and
  most-killed creatures.
- **Know where to grind.** Death locations, respawn intervals, and zone heatmaps
  show where your kills cluster. The heatmap uses static zone-map art beneath a
  kill-density grid, not a live map.
- **Make it yours.** Resizable window, multiple themes, scale control, and a
  minimap launcher.
- **Know what it is worth.** Track session loot value, gold/hour, and clear gear
  upgrades.
- **Keep quests separate.** Quest XP has its own ledger and never pollutes kill
  averages.

## Feature highlights

| Progress | History | World | Economy |
|---|---|---|---|
| Kills-to-level | Kill Story window | Death locations | Loot value |
| XP remaining | Mob/area/level history | Respawn intervals | Gold/hour |
| XP/hour and XP/minute | Quest XP ledger | Grinding spots | Gear upgrades |
| Time-to-level | Leveling history | Zone heatmaps | Session totals |
| Reputation repeats | Dungeon XP, goals, splits | Optional nameplate levels | Clear-upgrade alerts |

## Built for both clients

**Forever 1.60.1 — full mode**

- Full XP formula, tooltip estimates, calibration, and 3D mob browser.
- XP rate, time-to-level, and grinding-spot suggestions.
- Well Fed XP Boost, Well-Rested, Camp Tent rested XP, and active XP bonuses.
- Quest XP, leveling history, loot, gold, deaths, respawns, and heatmaps.

**Midnight 12.1.5 — counts-focused mode**

- Kill, area, level, session, dungeon, goal, split, loot, gold, death, respawn,
  and heatmap features without XP claims.
- Optional level text above nameplates.
- Same Kill Story window, themes, search, and minimap launcher.

## A quick look

- Open the window with `/acem2l2 xpt ui`, `/acem2l2 history`, the minimap icon,
  the addon compartment, or `Ctrl+Shift+X`.
- Open settings with `/acem2l2 config`.
- Discover commands in game with `/acem2l2 help` and `/acem2l2 xpt help`.
- Tabs: **Overview, Mobs, Areas, Heatmap, Levels**.
- The Heatmap tab can be hidden in Settings while data still records.

## Install

1. Copy the `AceM2L2` folder into `Interface/AddOns/`.
2. Enable the addon and run `/reload`.
3. No external Ace3 install is required; libraries are embedded.

## Good to know

- Heatmaps keep up to 40 zones; death history keeps 100 deaths; respawn tracking
  keeps 300 NPCs with 20 samples each.
- Mob history keeps 2000 mobs per client; quest and level history keep 200
  records each; rate history keeps 240 samples.
- Heatmaps, death locations, respawns, and nameplate levels depend on the
  client's map-position and nameplate APIs.
- Grinding spots need at least 5 kill-XP samples over 120 seconds.
- Midnight XP estimates, calibration, kills-to-level, rested, and buffs remain
  off until its data is live-verified.

## Changelog

### 2.1.6

- Zone-map art now renders above the grid backdrop at full opacity, removing the
  faded blue tint.

### 2.1.5

- Heatmap upgraded to a 32x32 grid with legacy 16x16 data migration and
  stronger heat colors.

### 2.1.4

- Cached the tiled zone-map art and capped layer/tile work so refreshes and
  resizing stay responsive.

### 2.1.3

- Heatmaps now resolve the correct zone map ID and render Blizzard's tiled zone
  map art, not a continent/world-map background.

### 2.1.2

- Zone-map art is now visible beneath the heatmap grid; empty cells no longer
  cover the map.
- The default window is about 15% larger, and the window supports safe resizing
  with heatmap reflow.

### 2.1.1

- Added the Kill Story logo to the addon icon, minimap launcher, window header,
  and Settings branding.

### 2.1.0

- User-facing documentation refresh and Kill Story naming throughout.
- Reliability fixes for settings ranges, world/economy normalization, tooltip
  hooks, debug output, migration, and restricted API data.

### 2.0.0

- Major feature release: XP rate and time-to-level, dungeon XP, leveling goals,
  speedrun splits, loot value, gold/hour, gear upgrades, death locations,
  respawn tracking, grinding spots, optional nameplate levels, and per-zone
  kill heatmaps.

See `README.txt` in the addon for the player guide and condensed changelog.

## Links

- Player guide: [README.txt](README.txt)
- Developer reference: [README.md](README.md)
- License: [LICENSE](LICENSE)
