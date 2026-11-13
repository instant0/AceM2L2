_____________________________________________________________________________________

Ace Mobs 2 Level 2 (AceM2L2)
XP, reputation, and Kill History

Author:     faslkjd56
Version:    1.12.0
GameVer.:   Midnight 12.1.5 (Retail) / Forever 1.60.1 (Classic+)
_____________________________________________________________________________________

This addon tells you how many of the current target you will need to kill
before you level up.

This will be displayed in the chat window in the format.

"[15] [Blind Bureaucrat] kills to level"


It also tells you how many more mobs or handins/quests you have to do
(with the current reward) to reach the next reputation rank.

This will be displayed in the format:

"[23463] to go with [Darnassus] = [502] repeats (kills/quests)"


It also includes Kill History on both clients. Forever 1.60.1 gets full XP
estimates on tooltips, a 3D mob viewer, calibration, and a record of what you
have killed. Midnight 12.1.5 gets counts-only kill, area, level, and session
history until its XP data is live-verified.


_____________________________________________________________________________________

	FEATURES
_____________________________________________________________________________________

- Shows how many mobs you still need for your next level.
- Shows how many kills or quest handins you need for your next reputation rank.
- Works with normal kills, unnamed kills, groups, raids, quests, and rested XP.
- Tracks reputation from kills, quests, bonuses, guild rep, paragon, and renown.
- Opens its settings from the addon options or with `/acem2l2 config`.
- Keeps the addon quiet and safe when game data is restricted.
- Works on Midnight and Forever, with modern settings on both.

Kill History:
- Includes a window with Overview, Mobs, Areas, and Levels tabs.
- Shows a 3D model of the selected mob and a clear list of your kills.
- Lets you search, filter, and sort your mob list.
- Uses the blue Aether Blue theme by default, with dark, midnight, class-color,
  and high-contrast themes available.
- Keeps duplicate mob rows together and cleans them up automatically.
- Lets you remove a single mob row, or all Unknown rows, without clearing your
  whole history.
- Has a minimap icon, an addon-compartment entry, and a Ctrl+Shift+X keybind.
- Remembers its position and sort order; the start tab is configurable.
- Can be turned off on its own and turns itself off on unknown clients.

Kill History on Forever 1.60.1 (full mode):
- Adds XP, percent of level, kills-to-level, and kill-count lines to mob
  tooltips.
- Uses Forever's XP rules, including Well Fed, Well-Rested, and rested XP.
- Learns from your kills so estimates improve over time.
- Tracks kills by mob, by your level, and by area.
- Shows each row clearly, such as "16 kills | avg 54 XP".

Kill History on Midnight 12.1.5 (counts only):
- Tracks kills by mob, by your level, by area, and per session.
- Shows kill counts in the window and on mob tooltips.
- Hides XP, percent, kills-to-level, calibration, rested, and buff claims until
  the Midnight data is verified.
- Stores Midnight and Forever history separately.

[ENGLISH]
_____________________________________________________________________________________

	USAGE
_____________________________________________________________________________________

- Install and enable. It automatically prints in chat when you kill an
  XP-rewarding mob or gain reputation.
- Open Kill History with `/acem2l2 xpt ui`, `/acem2l2 history`, the minimap
  icon, the addon compartment, or Ctrl+Shift+X.
- Most Kill History settings are in `/acem2l2 config`; theme, scale,
  start tab, minimap position, and resets are command-controlled.

Common commands:
  /acem2l2 or /am2
  /acem2l2 config
  /acem2l2 status
  /acem2l2 xp on|off
  /acem2l2 rep on|off
  /acem2l2 history
  /acem2l2 kills [name]
  /acem2l2 xpt help
  /acem2l2 xpt on|off
  /acem2l2 xpt ui
  /acem2l2 xpt status
  /acem2l2 xpt probe
  /acem2l2 xpt kills [name]
  /acem2l2 xpt areas
  /acem2l2 xpt levels
  /acem2l2 xpt session
  /acem2l2 xpt stats
  /acem2l2 xpt dump
  /acem2l2 xpt table
  /acem2l2 xpt starttab overview|mobs|areas|levels
  /acem2l2 xpt theme aether|dark|midnight|class|contrast
  /acem2l2 xpt scale 80-120
  /acem2l2 xpt minimap on|off|reset|status
  /acem2l2 xpt debug on|off
  /acem2l2 xpt delete <mob name>
  /acem2l2 xpt delete confirm <mob name>
  /acem2l2 xpt deleteunknown confirm
  /acem2l2 xpt recalibrate confirm
  /acem2l2 xpt reset confirm
  /acem2l2 xpt resetkills confirm
  /acem2l2 xpt config

Use `/acem2l2 help` for core commands and `/acem2l2 xpt help` for Kill History
commands.

Tooltip notes:
- On Midnight, tooltips show the kill count only; XP lines stay hidden.
- Midnight records kills, areas, levels, and sessions. It does not record XP
  observations, percent of level, kills-to-level, rested, or group XP. Those
  features stay off until live testing verifies the Midnight data.
- If Midnight cannot read a target/death identity, that kill is skipped rather
  than recorded as Unknown. This can make Midnight counts lower than expected.
- On Forever, the estimate may start with "~" until it has learned enough from
  your kills.
- In a group, the tooltip shows your share and the solo estimate.
- Gray mobs can still appear in Kill History even though they award no XP.
- `/acem2l2 xpt debug on` prints extra XP and kill-identification information
  if you need to report a problem.

Diagnostics and upgrades:
- `/acem2l2 xpt status` shows the active client and mode.
- `/acem2l2 xpt probe` prints a read-only diagnostic block: project/interface,
  profile, capabilities, API availability, a sample unit, map/group/XP/rested
  values, and secret markers. Secret values print as "<secret>".
- Include `/acem2l2 xpt status` and `/acem2l2 xpt probe` output in bug reports.
- Back up WTF/Account/<account>/SavedVariables/AceM2L2*.lua before upgrading.
  Existing 1.11.x Forever history migrates into the per-client Forever
  namespace. Midnight starts with separate, empty history.
- A 1.11.x client cannot read the per-client 1.12.x database after a downgrade.
- Midnight observed XP is not available in 1.12.0. No setting or command enables
  it.

Window controls:
- Overview, Mobs, Areas, and Levels tabs.
- Search and filter on the Mobs tab; Sort cycles Kills, Name, and Recent.
- Select a mob and choose Remove in the detail panel. Choose Confirm within five
  seconds to delete that one entry.
- Use `/acem2l2 xpt deleteunknown confirm` to remove only Unknown entries.
- Drag the window to move it; drag the 3D model to rotate it.
- Press Escape or the X button to close it.


_____________________________________________________________________________________

	TODO
_____________________________________________________________________________________

- More in-game testing on Forever 1.60.1 and Midnight 12.1.5.
- Fix quest XP occasionally being labelled as "Mob kills to level"; quest
  source detection depends on the localized combat-XP chat text.
- Confirm group and dungeon XP values.
- Future visual polish: larger layout, custom panel art, a full level chart, map
  thumbnails, and a reduce-motion option.

_____________________________________________________________________________________

	VERSION HISTORY
_____________________________________________________________________________________

[2026-11-13] v1.12.0 - Added Kill History counts-only support for Midnight
                     12.1.5, per-client data migration, client capability
                     profiles, a kill-count-first tooltip, and an xpt probe
                     diagnostic. Forever keeps the full XP experience.
[2026-11-12] v1.11.3 - Improved tracking when kills happen quickly or the target
                     clears, added ways to remove one kill-history entry or
                     just the Unknown entries, and split the addon into Core/
                     and KillHistory/ modules for maintainability.
[2026-11-12] v1.11.2 - New Aether Blue look with a larger model card, cleaner
                     tabs and buttons, improved search, and better merging of
                     duplicate mob entries.
[2026-11-12] v1.11.1 - Renamed the XPTooltip feature to Kill History and
                     improved XP estimate accuracy.
[2026-11-12] v1.11.0 - Added the XPTooltip/Kill History window, overview,
                     themes, scaling, minimap icon, addon-compartment entry, and
                     keybind.
[2026-11-11] v1.10.1 - Improved group-size display and XP estimate accuracy.
[2026-11-11] v1.10.0 - Added XPTooltip/Kill History, 3D mob models, searchable
                     lists, and area/level tracking for Forever.
[2026-11-09] v1.9.0 - Stability and compatibility improvements.
[2026-11-09] v1.8.0 - Added Midnight and Forever support and refreshed settings.
[2026-03-17] v1.7   - Updated for Midnight with improved XP parsing and
                     reputation fallback support.
[2026-03-17] v1.6   - Beta Midnight update.
[2023-01-15] v1.5   - Updated for Dragonflight and rewrote reputation for
                     Renown.
[2018-08-14] v1.4   - Updated for BfA.
[2016-09-13] v1.3   - Updated for Legion.
[2014-10-21] v1.2   - Updated for 6.0/Warlords and fixed a guild reputation bug.
