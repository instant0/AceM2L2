# Ace Mobs 2 Level 2 (AceM2L2)

AceM2L2 is a World of Warcraft addon that reports XP and reputation progress
and provides a detailed **Kill History** browser for the Forever 1.60.1 client.

- **Version:** 1.11.3
- **Author:** faslkjd56
- **Interfaces:** Midnight `120105`, Forever `16001`
- **Clients:** Midnight 12.1.x and Forever 1.60.1
- **License:** GNU GPL v3

The player-facing guide is [`README.txt`](README.txt). This document covers the
project structure, tracking model, development workflow, and release packaging.

## Overview

AceM2L2 has two layers:

1. **Core addon** (`ACEM2L2.lua` bootstrap plus `Core/`) — XP-to-level and
   reputation-to-next-rank messages for both Midnight and Forever.
2. **Kill History module** (`KillHistory/`) — Forever-only per-character kill
   tracking, tooltip estimates, a 3D mob browser, and the Kill History window.

The Kill History module auto-disables outside Forever or when required client
APIs are unavailable. The core addon remains active.

## Compatibility

| Client | Project ID | Interface | Core addon | Kill History |
|---|---:|---:|---|---|
| Forever 1.60.1 | `18` | `16001` | Supported | Supported |
| Midnight 12.1.x | `1` | `120105` | Supported | Auto-disabled |

The TOC intentionally lists both interface versions:

```text
## Interface: 120105, 16001
```

## Installation

1. Copy the `AceM2L2` folder into your client's `Interface/AddOns/` directory.
2. The final path must be `Interface/AddOns/AceM2L2/AceM2L2.toc`.
3. Enable the addon and run `/reload`.

No external Ace3 installation is required. The required libraries are embedded
under `Libs/`.

## Core Features

### XP and reputation

- Prints kills-to-level and reputation repeats in chat.
- Handles named and unnamed kills, group/raid bonuses, quests, and rested XP
  through localized `COMBATLOG_XPGAIN_*` strings.
- Uses `PLAYER_XP_UPDATE` and `FACTION_STANDING_CHANGED` as the exact amount
  source instead of relying on parsed chat totals.
- Supports reputation from kills, quests, bonuses, guild rep, paragon, and
  renown factions.
- Uses the modern Settings API on both supported clients.
- Sanitizes saved variables, protects event handlers, and stores the last error
  for `/acem2l2 status`.

### Kill History (Forever only)

- Tooltip lines for estimated XP, percent of level, kills-to-level, rested
  bonus, and per-mob kill counts.
- Forever XP formula with Well Fed (+5%), Well-Rested (+3%), and the rested
  total-pool model.
- Per-character tracking by mob, player level, and area.
- Overview, Mobs, Areas, and Levels tabs.
- Search, filters, sort modes, relative bars, and a 3D model hero card.
- Aether Blue default theme plus dark, midnight, class-color, and
  high-contrast themes.
- Minimap launcher, addon-compartment entry, and `Ctrl+Shift+X` keybind.
- Single-entry deletion and Unknown-only cleanup.

## Kill Tracking Model

### Mob identity

Mobs are keyed by NPC ID when known:

```text
npc:<npcID>
```

If the NPC ID is unavailable, the module falls back to a lower-case name key:

```text
name:<lower-case mob name>
```

Name-only entries are temporary. The module resolves/merges them into the NPC
entry when the ID becomes available.

### Recorded data

Each mob entry stores:

- total and session kills,
- kills by player level,
- kills by map/area,
- XP observation samples,
- context samples for calibration,
- first and last seen timestamps,
- NPC ID and classification.

### XP formula

The base estimate is:

```text
base = 5 * min(playerLevel, mobLevel) + 45
```

The result is adjusted by the Forever level-difference multiplier, then doubled
for elite, rare-elite, and world-boss classifications. Gray mobs return `0`.

### Calibration

Clean solo observations feed context-specific correction ratios:

- mob,
- class,
- player level,
- zone.

The estimator applies **one** correction by specificity
(`mob > class > level > zone`). Ratios are not multiplied together.

Calibration version `2` automatically clears inflated ratios left by older
builds while preserving kill counts and observations.

Group XP is displayed as a share estimate, but group-ratio learning is disabled
until live chat amount semantics are verified.

### Duplicate and Unknown handling

Older builds could record the same kill twice:

- once from XP chat under a name-only key,
- once from `UNIT_DIED` under the NPC key.

The current module:

- defers unnamed XP messages briefly so `UNIT_DIED` can provide identity,
- retains the last valid target through target clearing,
- matches exact GUIDs even for long fights,
- merges name-only entries into NPC entries,
- deduplicates overlapping chat/death records,
- supports deleting one mob entry or all Unknown entries.

## Saved Variables

| Variable | Scope | Purpose |
|---|---|---|
| `AceM2L2DB` | Account | Core settings and Kill History settings |
| `AceM2L2CharDB` | Character | Kill history, observations, calibration |

Kill History data lives under:

```text
AceM2L2DB.profile.xpTooltip
AceM2L2CharDB.xpTooltip
```

Profile schema: `4`  
Calibration schema: `2`

## Commands

Use `/acem2l2` or `/am2`. The complete in-game list is available with:

```text
/acem2l2 xpt help
```

Common commands:

```text
/acem2l2 config
/acem2l2 status
/acem2l2 xp on|off
/acem2l2 rep on|off
/acem2l2 history
/acem2l2 kills [name]
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
```

`delete` previews the matching entry or entries. `delete confirm` removes exact
name matches. Destructive resets require `confirm`.

## Project Layout

```text
AceM2L2.toc          Addon metadata and load order
ACEM2L2.lua          AceAddon bootstrap and binding metadata
Core/                Defaults, utilities, settings, XP, reputation, options, commands, events
KillHistory/         Module, data, formula, calibration, tracking, tooltip, commands, events
KillHistory/UI/      Theme, widgets, list, detail, overview, window, minimap
Bindings.lua         Keybind and addon-compartment entry points
Bindings.xml         Ctrl+Shift+X binding definition
embeds.xml           Embedded library load order
Libs/                LibStub, CallbackHandler, Ace3, LibDataBroker, LibDBIcon
tests/               Offline Lua smoke tests and exact-case layout checker
README.txt           Player-facing readme
README.md            Project/developer readme (this file)
dev/IN_GAME_VERIFICATION.md  Live-client verification checklist
dev/UPGRADE_PLAN.md  Release notes and upgrade history
dev/TASKS.md        Implementation and release task log (ignored by Git)
dev/BLUE_UI_REDESIGN_PLAN.md  Aether Blue design notes
dev/FILENAME_COMPLIANCE_AND_REFACTOR_PLAN.md  Naming audit and Lua split plan
dev/UI_EXECUTION_PLAN.md / dev/UI_POLISH_PLAN.md / dev/XPTTOOLTIP_PLAN.md  Planning docs
```

Development-only documents under `dev/` are ignored by Git (see `.gitignore`).

## Development

### Requirements

- Lua 5.1-compatible interpreter for offline tests
- `luac` for syntax checks
- `xmllint` for XML validation
- Python 3 for reproducible zip packaging
- A Forever 1.60.1 or Midnight 12.1.x client for live verification

### Offline checks

From the repository root:

```bash
luac -p ACEM2L2.lua Bindings.lua Core/*.lua KillHistory/*.lua KillHistory/UI/*.lua
lua tests/xptooltip_smoke.lua
xmllint --noout embeds.xml Bindings.xml
python3 tests/check_layout.py
```

The smoke test is not a WoW client. It catches Lua errors, nil-method calls,
formula regressions, group handling, UI behavior, theme switching, minimap
registration, duplicate merging, and delete accounting.

`tests/check_layout.py` validates the shipping layout:

- every non-comment line in `AceM2L2.toc` resolves to an existing file,
- every `<Script file="...">` and `<Include file="...">` in referenced XML
  resolves with exact filename case,
- every root-level Lua file is loaded by the TOC,
- `Bindings.xml` is loaded when it exists,
- the checkout folder name matches the TOC basename.

It prints a warning for a local checkout named `acem2l2` because the release
archive must contain `AceM2L2/`. Use `--strict-root` in release/CI checks.

### Live checks

Use [`dev/IN_GAME_VERIFICATION.md`](dev/IN_GAME_VERIFICATION.md). The main outstanding
areas are:

- tooltip hook availability and `GameTooltip:GetUnit`,
- exact XP chat semantics for groups and dungeons,
- rested pool behavior,
- 3D model rotation and fallback,
- theme/scale rendering at 80/100/120%,
- minimap compatibility with ElvUI/Leatrix/SexyMap,
- Midnight auto-disable,
- clean install from the release zip.

## Release Packaging

The release zip has a single top-level `AceM2L2/` directory containing:

- `AceM2L2.toc`
- `ACEM2L2.lua`
- `Core/`
- `KillHistory/`
- `Bindings.lua`
- `Bindings.xml`
- `embeds.xml`
- `README.txt`
- `LICENSE`
- the required folders under `Libs/`

`Libs/LibStub/tests/` is excluded from release archives. Developer docs, the
offline tests, `dev/`, `dist/`, and the exact-case checker are not packaged.

Build the release zip directly from the workspace. No staging folder copy is
needed:

```bash
python3 - <<'EOF'
import os
import zipfile

out = "/mnt/r/AceM2L2-1.11.3.zip"
root_files = [
    "AceM2L2.toc", "ACEM2L2.lua",
    "Bindings.lua", "Bindings.xml", "embeds.xml",
    "README.txt", "LICENSE",
]

with zipfile.ZipFile(out, "w", zipfile.ZIP_DEFLATED) as z:
    for name in root_files:
        z.write(name, f"AceM2L2/{name}")
    for tree in ("Core", "KillHistory", "Libs"):
        for dirpath, dirnames, filenames in os.walk(tree):
            dirnames[:] = sorted(d for d in dirnames if d != "tests")
            for name in sorted(filenames):
                path = os.path.join(dirpath, name)
                z.write(path, os.path.join("AceM2L2", path))
EOF
```

Only these release artifacts are kept:

```text
dist/AceM2L2-1.11.3.zip
/mnt/r/AceM2L2-1.11.3.zip
```

No unzipped `/mnt/r/AceM2L2-1.11.3/` folder copy is maintained.

## Known Limitations

- Unnamed XP that never receives a readable death event can still fall back to
  an Unknown entry after the short identity wait.
- Group and dungeon XP chat amounts are not yet verified live, so group-ratio
  learning remains disabled.
- Kill History is intentionally unavailable outside Forever.
- Area and level rows are derived views; deletion is offered only for mob rows.
- Deleting a mob adjusts total/session/level/area/unique counts, known XP, and
  mob calibration. Per-area level-range counters are not retroactively adjusted.

## License

AceM2L2 is distributed under the GNU General Public License v3. See
[`LICENSE`](LICENSE).
