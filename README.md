# Ace Mobs 2 Level 2 (AceM2L2)

AceM2L2 is a World of Warcraft addon that reports XP and reputation progress
and provides a **Kill History** browser for Forever 1.60.1 and Midnight 12.1.5.
Forever gets the full XP/tooltip experience; Midnight gets counts-focused
history plus the non-XP features until its XP data is live-verified.

- **Version:** 2.0.0
- **Author:** faslkjd56
- **Interfaces:** Midnight `120105`, Forever `16001`
- **Clients:** Midnight 12.1.5 and Forever 1.60.1
- **License:** GNU GPL v3

The player-facing guide is [`README.txt`](README.txt). This document covers the
project structure, tracking model, development workflow, and release packaging.

## Overview

AceM2L2 has two layers:

1. **Core addon** (`ACEM2L2.lua` bootstrap plus `Core/`) — XP-to-level and
   reputation-to-next-rank messages for both Midnight and Forever.
2. **Kill History module** (`KillHistory/`) — per-character kill tracking on
   both clients, with tooltip estimates and calibration on Forever and
   counts-focused tracking on Midnight.

The Kill History module auto-disables for unknown clients or when the active
client's required APIs are unavailable. Forever requires its XP APIs; the
Midnight counts-focused profile needs only minimal identity/level APIs. A missing
tooltip hook disables tooltip lines without disabling the tracker or the
window.

## Compatibility

| Client | Project ID | Interface | Core addon | Kill History |
|---|---:|---:|---|---|
| Forever 1.60.1 | `18` | `16001` | Supported | Full |
| Midnight 12.1.5 | `1` | `120105` | Supported | Counts-focused |

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

### Kill History

Both clients share one window, list, detail panel, command surface, and data
model. Client-specific policy lives only in `KillHistory/Client.lua` and
`KillHistory/Clients/`.

**Forever 1.60.1 — full mode**

- Tooltip lines for estimated XP, percent of level, XP remaining, mob level,
  kills-to-level, rested bonus, XP bonuses, and per-mob kill counts.
- Forever XP formula with Well Fed XP Boost food (`1243969`, +5% kill XP),
  Well-Rested (`429959`, +1% per stack, up to +3%), and the rested total-pool
  model. The active bonus breakdown matches the multiplier actually applied.
  The Cozy Sleeping Bag uses the same Well-Rested aura; Camp Tent `1307230`
  tops up the rested pool and is shown through the rested line.
- Per-character tracking by mob, player level, and area.
- Quest XP ledger with totals, per-quest rewards, `/xpt quests`, and an Overview
  summary; quest XP never enters the kill average.
- Leveling history with per-level duration, XP, and kills, shown in the Overview
  and with `/xpt history [level]`.
- XP/hour, XP/minute, and time-to-level from measured gains.
- Dungeon XP, leveling goals, and speedrun splits.
- Session loot value, gold/hour, and clear gear-upgrade notifications.
- Death locations, respawn intervals, and grinding-spot recommendations.
- Overview, Mobs, Areas, Levels, and Heatmap tabs.
- Per-zone 16x16 kill heatmap with optional zone-map art.
- Search, filters, sort modes, relative bars, and a 3D model hero card.
- Aether Blue default theme plus dark, midnight, class-color, and
  high-contrast themes.
- Minimap launcher, addon-compartment entry, and `Ctrl+Shift+X` keybind.
- Single-entry deletion and Unknown-only cleanup.

**Midnight 12.1.5 — counts-focused mode**

- Tracks kills by mob, player level, area, and session.
- Shows kill counts, the mob list, areas, levels, and the 3D model or fallback.
- Tracks dungeon kills, leveling goals, duration/kill splits, loot, gold,
  death locations, respawns, and zone heatmaps without XP claims.
- Tooltips show the kill-count line and target level only; no XP, percent,
  kills-to-level, or XP-bonus claims.
- Formula estimates, calibration, rested/buff models, and group learning stay
  off until live probes prove the Midnight data is readable and attributable.
- `/acem2l2 xpt probe` prints the client capabilities and secret-value status
  for live verification.

Midnight and Forever data are stored separately per project ID. Forever
observations and calibration can never seed Midnight data.

### Settings layout

The Settings panel uses native section headers and a dedicated **Tooltip**
subpage:

- **Chat messages** — XP/reputation toggles, output frequency, rolling average,
  precision, and minimums.
- **Kill History** — module enable and minimap icon.
- **Diagnostics** — debug output.
- **Tooltip** subpage — XP lines, kill lines, rested/bonuses, and edge cases.

The **Show mob level** checkbox in the Tooltip page controls the `Level: <n>`
line on eligible unit tooltips. It is enabled by default and can be turned off
without disabling Kill History.

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
- XP observation samples (Forever only),
- context samples for calibration (Forever only),
- first and last seen timestamps,
- NPC ID and classification.

Midnight counts-focused entries store the same kill/level/area fields without XP
samples or calibration contexts.

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
builds. It preserves kill counts and aggregate XP samples, but discards learned
ratios and exact per-context snapshots (`mob.contexts`) because those may be
stale.

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

Kill History settings live under `AceM2L2DB.profile.xpTooltip`. Per-client
character data lives under:

```text
AceM2L2CharDB.xpTooltip = {
  storageSchema = 2,
  clients = {
    [18] = { dataSchema = 1, ... },  -- Forever
    [1]  = { dataSchema = 1, ... },  -- Midnight
  },
}
```

Existing 1.11.x root-scoped data is migrated into `clients[18]` on first load.
The migration is idempotent and never merges root data into an existing
per-client table. Midnight starts with an empty `clients[1]` namespace; Forever
observations and calibration never seed Midnight.

The first migration also keeps a one-time recoverable snapshot at
`AceM2L2CharDB.xpTooltip.migrationBackup`. It is outside normal accounting and
is reported by `/acem2l2 xpt status` and `/acem2l2 xpt probe`.

Back up `WTF/Account/<account>/SavedVariables/AceM2L2*.lua` before upgrading.
A 1.11.x client cannot read the per-client 1.12.x database after a downgrade.

Profile schema: `4`  
Storage schema: `2`  
Per-client data schema: `1`  
Calibration schema: `2`

## Commands

Use `/acem2l2` or `/am2`. The complete core command list is available with:

```text
/acem2l2 help
```

Use `/acem2l2 xpt help` for the Kill History command list.

Common commands:

```text
/acem2l2 config
/acem2l2 status
/acem2l2 xp on|off
/acem2l2 rep on|off
/acem2l2 history
/acem2l2 kills [name]
/acem2l2 xpt on|off
/acem2l2 xpt ui
/acem2l2 xpt status
/acem2l2 xpt probe
/acem2l2 xpt kills [name]
/acem2l2 xpt quests
/acem2l2 xpt history [level]
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
```

`delete` previews the matching entry or entries. `delete confirm` removes exact
name matches. Destructive resets require `confirm`. Theme, scale, start tab,
and minimap are command-controlled; the Settings panel covers enable, tooltip
flags, debug, and minimap visibility.

`/acem2l2 xpt probe` is a read-only diagnostic. It prints the project ID,
interface, active profile/mode, capability summary, API availability, a sample
target/mouseover identity, map/group/XP/rested values, and marks secret values
as `<secret>`. Include `/acem2l2 xpt status` and `/acem2l2 xpt probe` output in
bug reports.

## Project Layout

```text
AceM2L2.toc          Addon metadata and load order
ACEM2L2.lua          AceAddon bootstrap and binding metadata
Core/                Defaults, utilities, settings, XP, reputation, options, commands, events
KillHistory/         Module, client profiles, data, formula, calibration, tracking, world data, heatmaps, tooltip, commands, events
KillHistory/Clients/ Forever and Midnight profile policy
KillHistory/UI/      Theme, widgets, list, detail, overview, heatmap, nameplates, window, minimap
Bindings.lua         Keybind and addon-compartment entry points
Bindings.xml         Ctrl+Shift+X binding definition
embeds.xml           Embedded library load order
Libs/                LibStub, CallbackHandler, Ace3, LibDataBroker, LibDBIcon
tests/               Offline smoke tests, layout checker, release validator, and build script
README.txt           Player-facing readme
README.md            Project/developer readme (this file)
```

`README.txt` is the in-game/player guide; this file is the developer reference.

## Development

### Requirements

- Lua 5.1-compatible interpreter for offline tests
- `luac` for syntax checks
- `xmllint` for XML validation
- Python 3 for reproducible zip packaging
- A Forever 1.60.1 or Midnight 12.1.5 client for live verification

### Offline checks

From the repository root:

```bash
./tests/run_all.sh
```

The runner covers syntax, all seven client scenarios (`forever`, `midnight`,
`midnight_missing`, `midnight_secret_identity`, `midnight_secret_booleans`,
`midnight_secret_name`, and `unknown`), the real embedded-library load test,
XML validation, and layout validation. Release zip validation is opt-in with
`CHECK_RELEASE=1` and should be used only when preparing a release.

Use `SNAPSHOT=1 ./tests/run_all.sh` to print the deterministic behavior
snapshot, or run it directly with `lua tests/snapshot.lua forever`.

Individual checks can also be run directly:

```bash
luac -p ACEM2L2.lua Bindings.lua Core/*.lua KillHistory/*.lua KillHistory/Clients/*.lua KillHistory/UI/*.lua
lua tests/snapshot.lua forever
lua tests/smoke.lua forever
lua tests/smoke.lua midnight
lua tests/smoke.lua midnight_missing
lua tests/smoke.lua midnight_secret_identity
lua tests/smoke.lua midnight_secret_booleans
lua tests/smoke.lua midnight_secret_name
lua tests/smoke.lua unknown
lua tests/libs_smoke.lua
xmllint --noout embeds.xml Bindings.xml
python3 tests/check_layout.py
python3 tests/check_release.py   # release-time only
```

The focused smoke suite (`tests/smoke.lua` + `tests/fixtures.lua`) is not a WoW
client. It catches Lua errors, nil-method calls, formula/quest regressions,
project-ID selection, per-client data migration and isolation, counts-focused
behavior, secret-value fallbacks, missing-API behavior, reconciliation, group
handling, UI behavior, minimap registration, merge/prune/delete accounting, and
schema blocking.

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

The main outstanding areas are:

- tooltip hook availability and `GameTooltip:GetUnit`,
- exact XP chat semantics for groups and dungeons,
- rested pool behavior,
- 3D model rotation and fallback,
- theme/scale rendering at 80/100/120%,
- minimap compatibility with ElvUI/Leatrix/SexyMap,
- Midnight counts-focused tracking, secret-value behavior, and tooltip/model
  fallbacks,
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

`Libs/LibStub/tests/` is excluded from release archives. The project README,
offline tests, `dist/`, and the exact-case checker are not packaged.

Build the release zip directly from the workspace with the checked-in script:

```bash
python3 tests/build_release.py
```

The script derives the version from `AceM2L2.toc`, writes
`dist/AceM2L2-<version>.zip`, and enforces the packaged allowlist. Do not rebuild
the zip for normal code changes; build only when preparing a release. Offline
checks skip release validation unless `CHECK_RELEASE=1`.

Current release artifacts:

```text
dist/AceM2L2-2.0.0.zip
/mnt/r/AceM2L2-2.0.0.zip
SHA-256: d29c3d607b186a2ea2f7ce53a36af1458ad01408dea76fbca8f0257db67d0c82
```

Both copies are validated when present. Copy the `dist/` zip to `/mnt/r/` when
preparing a local release; the release checker validates the `/mnt/r` copy only
when it exists.

Older zips may remain in `dist/` as local archives; do not ship them. An
unzipped `/mnt/r/` test folder may exist locally for testing, but it is not a
release artifact.

Documentation-only changes to `README.md` do not require rebuilding the
release zip. Rebuild only when a packaged file changes (Lua, TOC, embeds,
Bindings, Libs, `README.txt`, or `LICENSE`).

## Known Limitations

- Unnamed XP that never receives a readable death event can still fall back to
  an Unknown entry after the short identity wait.
- Quest XP is disambiguated by `QUEST_TURNED_IN` when the client exposes it.
  If the source remains ambiguous, the estimate is suppressed rather than
  reported as a mob kill.
- Group and dungeon XP chat amounts are not yet verified live, so group-ratio
  learning remains disabled.
- Midnight runs in counts-focused mode. XP estimates, calibration,
  kills-to-level, rested/buff models, and observed XP remain off until live
  probes validate the Midnight data. Non-XP features still work.
  `/acem2l2 xpt probe` exists for that verification.
- If Midnight hides target/death identity, the kill is skipped rather than
  recorded as a fake Unknown entry.
- Area and level rows are derived views; deletion is offered only for mob rows.
- Kill History keeps at most 2000 mob entries per client. Older entries can be
  pruned in long sessions; re-check totals after very large histories.
- Well Fed XP Boost (`1243969`), Well-Rested/Cozy Sleeping Bag (`429959`), and
  Camp Tent (`1307230`) are mapped to the existing bonus/rested display.
  Camp Tent is a rested-pool top-up, not a separate XP multiplier.
- Midnight observed XP, calibrated estimates, kills-to-level, rested/buffs, and
  group learning are **not available in 2.0.0**. No setting or command enables
  them; they stay behind the live probe gates.

## License

AceM2L2 is distributed under the GNU General Public License v3. See
[`LICENSE`](LICENSE).
