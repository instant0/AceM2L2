_____________________________________________________________________________________

Ace Mobs 2 Level 2 (AceM2L2)
XP, reputation, and Kill History

Author:     faslkjd56
Version:    1.11.3
GameVer.:   Midnight 12.1.x / Forever 1.60.1 (Retail and Classic+)
_____________________________________________________________________________________

This addon tells you how many of the current target you will need to kill
before you level up.

This will be displayed in the chat window in the format.

"[15] [Blind Bureaucrat] kills to level"


It also tells you how many more mobs or handins/quests you have to do
(with the current reward) to reach the next reputation rank.

This will be displayed in the format:

"[23463] to go with [Darnassus] = [502] repeats (kills/quests)"


On Forever 1.60.1 it also includes Kill History: helpful mob XP estimates on
tooltips, a 3D mob viewer, and a record of what you have killed.


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

Kill History (Forever 1.60.1 only):
- Adds XP, percent of level, kills-to-level, and kill-count lines to mob
  tooltips.
- Uses Forever's XP rules, including Well Fed, Well-Rested, and rested XP.
- Learns from your kills so estimates improve over time.
- Tracks kills by mob, by your level, and by area.
- Includes a Kill History window with Overview, Mobs, Areas, and Levels tabs.
- Shows a 3D model of the selected mob and a clear list of your kills.
- Lets you search, filter, and sort your mob list.
- Uses the blue Aether Blue theme by default, with dark, midnight, class-color,
  and high-contrast themes available.
- Shows each row clearly, such as "16 kills | avg 54 XP", so the numbers are
  easy to understand.
- Keeps duplicate mob rows together and cleans them up automatically.
- Lets you remove a single mob row, or all Unknown rows, without clearing your
  whole history.
- Has a minimap icon, an addon-compartment entry, and a Ctrl+Shift+X keybind.
- Remembers its position, size, sort order, and last-used tab.
- Can be turned off on its own and turns itself off outside Forever.

[ENGLISH]
_____________________________________________________________________________________

	USAGE
_____________________________________________________________________________________

- Install and enable. It automatically prints in chat when you kill an
  XP-rewarding mob or gain reputation.
- Open Kill History with `/acem2l2 xpt ui`, `/acem2l2 history`, the minimap
  icon, the addon compartment, or Ctrl+Shift+X.
- Kill History settings are in `/acem2l2 config`.

Common commands:
  /acem2l2 or /am2
  /acem2l2 config
  /acem2l2 status
  /acem2l2 xp on|off
  /acem2l2 rep on|off
  /acem2l2 history
  /acem2l2 kills [name]
  /acem2l2 xpt help
  /acem2l2 xpt ui
  /acem2l2 xpt kills [name]
  /acem2l2 xpt areas
  /acem2l2 xpt levels
  /acem2l2 xpt session
  /acem2l2 xpt theme aether|dark|midnight|class|contrast
  /acem2l2 xpt scale 80-120
  /acem2l2 xpt minimap on|off|reset|status
  /acem2l2 xpt delete <mob name>
  /acem2l2 xpt delete confirm <mob name>
  /acem2l2 xpt deleteunknown confirm
  /acem2l2 xpt resetkills confirm
  /acem2l2 xpt config

Use `/acem2l2 xpt help` for the full command list.

Tooltip notes:
- The estimate may start with "~" until it has learned enough from your kills.
- In a group, the tooltip shows your share and the solo estimate.
- Gray mobs can still appear in Kill History even though they award no XP.
- `/acem2l2 xpt debug on` prints extra XP information if you need to report a
  problem.

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
- Confirm group and dungeon XP values.
- Future visual polish: larger layout, custom panel art, a full level chart, map
  thumbnails, and a reduce-motion option.

_____________________________________________________________________________________

	VERSION HISTORY
_____________________________________________________________________________________

[2026-11-12] v1.11.3 - Improved tracking when kills happen quickly or the target
                     clears, and added ways to remove one kill-history entry or
                     just the Unknown entries.
[2026-11-12] v1.11.2 - New Aether Blue look with a larger model card, cleaner
                     tabs and buttons, improved search, and better merging of
                     duplicate mob entries.
[2026-11-12] v1.11.1 - Renamed the feature to Kill History and improved XP
                     estimate accuracy.
[2026-11-12] v1.11.0 - Added the Kill History window, overview, themes, scaling,
                     minimap icon, addon-compartment entry, and keybind.
[2026-11-11] v1.10.1 - Improved group-size display and XP estimate accuracy.
[2026-11-11] v1.10.0 - Added Kill History, 3D mob models, searchable lists, and
                     area/level tracking for Forever.
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
