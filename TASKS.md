# XPTooltip module — implementation tasks

Target: **AceM2L2 1.11.0**, Forever 1.60.1 only, module auto-disabled elsewhere.

## Task review

Ordered by dependency:

- Schema, compatibility, and the module lifecycle must exist before any hook or
  UI can be safely enabled.
- Kill tracking and area/level aggregates must exist before the UI; the UI must
  read aggregates, not scan every context.
- The list/rows must exist before the 3D model pane, because the model follows
  the selected mob.
- Areas and Levels reuse the row pool and summary panel, so they follow Mobs.
- Polish, tests, and docs come last.

Rejected shortcuts:

- No chat-only “UI”.
- No 3D grid of every mob in the first release; one selected model only.
- No external web export.
- No per-frame database scans.
- No hard dependency on `PlayerModel`; fall back to text/icon.

## Tasks

### T1 — Module skeleton and lifecycle

- [x] Create `XPTooltip.lua`.
- [x] Register `AceM2L2:NewModule("XPTooltip", "AceEvent-3.0")`.
- [x] Implement `OnInitialize`, `OnEnable`, `OnDisable`, `Refresh`.
- [x] Add to `AceM2L2.toc` after `ACEM2L2.lua`.

### T2 — Version and schema migration

- [x] Bump addon version to `1.10.0`.
- [x] Bump profile schema to `3`.
- [x] Add `AceM2L2CharDB` (`SavedVariablesPerCharacter`, schema `1`).
- [x] Migrate 1.9.0 settings without loss.
- [x] Add `xpTooltip` defaults and sanitization.

### T3 — Compatibility gate and auto-disable

- [x] Forever/project check.
- [x] Required API check (`UnitXP`, `UnitXPMax`, `UnitLevel`, `UnitName`,
      `UnitGUID`).
- [x] Tooltip hook check (`TooltipDataProcessor` or `HookScript`).
- [x] Optional API handling (`GetXPExhaustion`, `issecretvalue`).
- [x] Separate user-enabled flag from auto-disable reason.
- [x] Circuit breaker after repeated handler errors.
- [x] Status output in `/acem2l2 status` and `/acem2l2 xpt status`.

### T4 — Formula and tooltip

- [x] Formula: `5 * min(pl, ml) + 45`.
- [x] Gray level and ZD tables.
- [x] Half-even rounding.
- [x] Elite/rareelite/worldboss multiplier.
- [x] Skull (`-1`) handling.
- [x] Tooltip hook with duplicate prevention.
- [x] Lines: XP, percent, kills-to-level, kill count, rested.
- [x] Buff/rested/group context.

### T5 — Observations and kill tracking

- [x] `CHAT_MSG_COMBAT_XP_GAIN` parsing.
- [x] `PLAYER_XP_UPDATE` state delta (not used for kill counting).
- [x] `UNIT_DIED` eligibility and pending queue.
- [x] Dedupe one kill across XP chat + death.
- [x] Per-mob counters.
- [x] Per-level counters.
- [x] Per-area counters.
- [x] Session and totals.
- [x] Pruning and persistence.

### T6 — Commands and settings

- [x] `/acem2l2 xpt on|off`.
- [x] `/acem2l2 xpt status`.
- [x] `/acem2l2 xpt ui`.
- [x] `/acem2l2 xpt kills [name]`.
- [x] `/acem2l2 xpt areas`.
- [x] `/acem2l2 xpt levels`.
- [x] `/acem2l2 xpt session`.
- [x] `/acem2l2 xpt reset` / `resetkills`.
- [x] Settings checkboxes/sliders.
- [x] Help/status integration.

### T7 — UI shell

- [x] Movable frame, title, close button.
- [x] Tabs: Mobs / Areas / Levels.
- [x] Position persistence.
- [x] Empty/disabled states.
- [x] Escape closes.

### T8 — Mobs tab and list

- [x] Pooled row list with scroll frame.
- [x] Sort: kills / name / last seen.
- [x] Search by name.
- [x] Selection state.
- [x] Details panel.

### T9 — 3D model pane

- [x] `PlayerModel` frame.
- [x] `SetCreature(npcID)`.
- [x] Fallback icon/text when unknown.
- [x] Drag rotation.
- [x] Stop/hide on close or disable.

### T10 — Areas tab

- [x] Map rows sorted by kills.
- [x] Share bars.
- [x] Top mobs for selected area.
- [x] Level range for selected area.

### T11 — Levels tab

- [x] Level rows sorted ascending.
- [x] Histogram bars.
- [x] Range summary.
- [x] Selected-level details.

### T12 — Polish and hardening

- [x] Tooltips and color coding.
- [x] Resize-safe layout.
- [x] Error guards.
- [x] No per-frame DB scans.
- [x] No taint or protected-frame errors.

### T13 — Tests and release

- [x] Offline formula/data tests.
- [ ] In-game Forever test matrix.
- [x] Midnight auto-disable test (offline mock).
- [x] Update `Readme.txt`.
- [x] Update `UPGRADE_PLAN.md`.
- [x] Release 1.10.0 artifact (`AceM2L2-1.10.0.zip`).

Notes:

- `luac -p ACEM2L2.lua XPTooltip.lua` passes.
- `tests/xptooltip_smoke.lua` exercises the formula, tooltip, chat and death
  dedupe, gray kills, reset race, target copy, search, bars, commands, class and
  group calibration, UI creation, 3D model selection, user disable, and
  Midnight auto-disable with mocked WoW APIs. Run it with
  `lua tests/xptooltip_smoke.lua` from the repository root.
- In-game verification is still required for tooltip API behavior, chat text
  and rested split, secret GUIDs, `PlayerModel:SetCreature`, and private-server
  hotfix differences.

## Follow-up audit tasks

These are the gaps found after the first implementation pass. They are ordered
by risk and dependency.

### Review notes

- State-reset races and target-table mutation are correctness bugs; fix them
  before adding more UI.
- Command completeness and UI search/bars are low-risk and can be done offline.
- Class calibration is optional and should not block release.
- In-game verification cannot be completed without the client; release packaging
  is done offline as a zip with the correct folder casing.

### T14 — Async state and reset hardening

- [x] Add a data-generation token so pending `UNIT_DIED` timers cannot add
      kills after `resetkills`.
- [x] Copy target/mouseover info before mutating it for an observation.
- [x] Guard `ResetObservations` against corrupt non-table mob entries.
- [x] Wrap UI creation/Show in `pcall` and report failures.
- [x] Move `poolBeforeKill` assignment after the recent-chat dedupe.

### T15 — Complete the command surface

- [x] `/acem2l2 xpt stats` — status plus totals, areas, levels, DB counts.
- [x] `/acem2l2 xpt dump` — compact per-mob dump for debugging.
- [x] `/acem2l2 xpt table` — level table with XP-to-level and current-mob
      kills-to-level estimates.
- [x] Reset observations/kills remain commands (`reset confirm`,
      `resetkills confirm`). The current Settings API docs do not expose a
      supported `CreateButton`, so adding reset buttons would be an unsupported
      API risk.

### T16 — UI search

- [x] Add a search box to the Mobs tab.
- [x] Filter by case-insensitive name.
- [x] Clear search when switching tabs.
- [x] Keep the selected row valid after filtering.

### T17 — UI bars

- [x] Add a thin bar under each row.
- [x] Mobs: bar relative to the most-killed mob.
- [x] Areas: bar relative to total kills (share).
- [x] Levels: bar relative to the highest-kill level.

### T18 — Class calibration

- [x] Learn a per-class ratio for solo kills.
- [x] Store the `observed / formula` ratio so the hardcoded class multiplier is
      not double-counted.
- [x] Apply it only after at least 5 samples.

### T19 — Test expansion

- [x] Add reset-race test.
- [x] Add target-copy test.
- [x] Add search/filter test.
- [x] Add bar-width test.
- [x] Add command smoke tests for `stats`, `dump`, and `table`.

### T20 — In-game verification (blocked, no client)

Checklist: `IN_GAME_VERIFICATION.md`.

- [ ] Confirm `TooltipDataProcessor` and `GameTooltip:GetUnit` behavior.
- [ ] Confirm `CHAT_MSG_COMBAT_XP_GAIN` text and rested split.
- [ ] Confirm `UNIT_DIED` GUID secrecy and target fallback.
- [ ] Confirm `PlayerModel:SetCreature` renders selected mobs.
- [ ] Confirm well-fed/well-rested aura names and stacking.
- [ ] Confirm group XP and dungeon hotfix values.
- [ ] Verify whether `CHAT_MSG_COMBAT_XP_GAIN` reports the player's share or the
      full kill value in a party. If it reports the share, enable group-ratio
      learning again.
- [ ] Reconcile the observed level-9 Greater Duskbat 36 XP and grouped farmhand
      32/22+2 data against the formula.
- [ ] Confirm no taint and no duplicate tooltip lines.

### T21 — Release packaging (offline part done)

- [x] Package as `AceM2L2/AceM2L2.toc` with matching folder casing.
- [x] Include `XPTooltip.lua`, `ACEM2L2.lua`, `embeds.xml`, and `Libs/`.
- [ ] Verify a clean install from the zip in the live client.

Artifact: `AceM2L2-1.10.0.zip` in the repository root. The archive contains
16 files under `AceM2L2/`, excludes `Libs/LibStub/tests`, and includes the TOC,
Lua files, embeds, Readme, LICENSE, and the Ace3 libraries.

## Proposed UI polish tasks (1.11.0, not started)

Plan: `UI_POLISH_PLAN.md`.

### U1 — Design audit and tokens

- [ ] Capture BetterBags / Ding! / BoF / Guidelime reference patterns.
- [ ] Freeze color, font, spacing, and texture tokens.
- [ ] Decide built-in textures vs. custom media.

### U2 — Component kit

- [ ] Panel, button, checkbox, slider, dropdown, search, chip, stat card, row,
      bar, badge, empty state, divider.
- [ ] Verify at 100%, 110%, and 120% UI scale.

### U3 — Window shell and Overview

- [ ] Header, left rail, footer, resize, min-size, position persistence.
- [ ] Overview dashboard with stat cards and quick actions.
- [ ] Start-tab setting.

### U4 — Mobs tab and model pane

- [ ] Search with magnifier/clear.
- [ ] Filter chips and sort dropdown.
- [ ] Rows with crest/icon, kills, avg XP, last seen, bars.
- [ ] Model gradient/pedestal/rotation and stat cards.
- [ ] Quick links to Areas and Levels.

### U5 — Areas and Levels

- [ ] Area ranking, share bars, top-mob detail.
- [ ] Level bar chart with current-level marker and hover tooltips.
- [ ] Selected area/level details.

### U6 — Minimap icon

- [ ] Embed LibDataBroker-1.1 and LibDBIcon-1.0.
- [ ] Register LDB launcher and tooltip.
- [ ] Left-click toggle, right-click settings.
- [ ] Persist position/hide/lock.
- [ ] Settings checkbox and `/acem2l2 xpt minimap` command.

### U7 — Keybind and addon compartment

- [ ] Add `Bindings.xml` and global toggle.
- [ ] Add `AddonCompartmentFunc`.
- [ ] Verify Forever compatibility; keep slash fallback.

### U8 — Themes, settings, accessibility

- [ ] Theme picker: Dark Forester / Midnight / Class / High Contrast.
- [ ] Scale and compact mode.
- [ ] Reset position/size.
- [ ] Localization string table.

### U9 — Animations and polish

- [ ] Fade/slide transitions.
- [ ] Bar fill and row hover.
- [ ] Model idle/fade.
- [ ] Empty/disabled/auto-disabled states.
- [ ] Sound toggle.

### U10 — Performance and localization

- [ ] Preload textures and cache map names.
- [ ] No per-frame DB scans.
- [ ] Localize UI strings.
- [ ] Test multiple resolutions/scales.

### U11 — Tests, docs, release 1.11.0

- [ ] Extend `tests/xptooltip_smoke.lua` with widget/theme/minimap mocks.
- [ ] Update Readme, UPGRADE_PLAN, TASKS.
- [ ] Bump to 1.11.0 and profile schema 4.
- [ ] Rebuild the release zip.

### U12 — Live visual verification

- [ ] Layout at multiple UI scales.
- [ ] Minimap icon with ElvUI/Leatrix/SexyMap.
- [ ] Keybind and compartment on Forever.
- [ ] No taint, no Lua errors, no duplicate tooltip lines.

## Review pass — grouping and calibration

Fixed after the first live observations:

- [x] Read group size from `GetNumGroupMembers()` directly instead of gating on
      `IsInGroup()`.
- [x] Show the group share and the solo comparison in the tooltip:
      `~22 (group share; solo ~32)`.
- [x] Disable group-ratio learning until the live chat amount is verified; use
      the classic group prior for display.
- [x] Replace multiplicative zone/level/class/mob calibration with one
      correction chosen by specificity. This removes the 1.46x over-correction
      risk.
- [x] Use one clean exact observation for the plain (no `~`) tooltip value, so
      a live 36 XP kill replaces the 38 XP formula estimate immediately.
- [x] Skip observations when rested state or aura detection is unavailable.
- [x] Treat mob level 0 as unknown instead of gray/no-XP.
- [x] Expand the offline tests for group display and calibration behavior.

Still needs live data:

- [ ] Verify whether `CHAT_MSG_COMBAT_XP_GAIN` reports the personal share or a
      base-plus-party-bonus total.
- [ ] Verify dungeon/raid group XP before enabling dungeon calibration.
- [ ] Confirm lower-level rounding against more kills; the observed 36 vs
      formula 38 is now handled by the exact context after one kill.

## Execution pass — 1.11.0 UI polish

- [x] Embed LibDataBroker-1.1 and LibDBIcon-1.0.
- [x] Bump to 1.11.0 and profile schema 4.
- [x] Add theme tokens: Dark Forester, Midnight, Class, High Contrast.
- [x] Add theme/scale/start-tab slash commands.
- [x] Add Overview tab with stat cards, top mobs, and level summary.
- [x] Add Mobs filter chips: All, This level, This session, Elite.
- [x] Add row crests with classification colors.
- [x] Add minimap icon with left-click toggle, right-click settings, tooltip.
- [x] Add minimap show/hide/reset/status commands and Settings checkbox.
- [x] Add addon-compartment entry.
- [x] Add Bindings.lua and Bindings.xml (Ctrl+Shift+X).
- [x] Add fade-in and optional open/close sound.
- [x] Expand offline tests for overview, filters, themes, scale, minimap, and
      keybind toggle.
- [ ] Live minimap/icon/compartment/keybind verification on Forever.
- [ ] Live visual verification at 100/110/120% UI scale.
- [ ] Live check with ElvUI/Leatrix/SexyMap minimap-button addons.
- [x] Rebuild `/mnt/r/AceM2L2-1.11.0` and zip (this pass).

## Execution pass — 1.11.1 calibration and branding

- [x] Bump calibration version to 2.
- [x] Clear legacy 1.10.x/1.11.0 multiplicative calibration on first load
      without deleting kill counts or exact observations.
- [x] Add `/acem2l2 xpt recalibrate confirm`.
- [x] Rename user-facing XPTooltip text to **Kill History**.
- [x] Rename addon title to **Ace Mobs 2 Level 2**.
- [x] Update settings category to **Ace Mobs 2 Level 2**.
- [x] Add `/acem2l2 history` / `/acem2l2 window` and `/acem2l2 kills [name]`.
- [x] Update binding name to **Toggle Kill History**.
- [x] Rebuild 1.11.1 zip and `/mnt/r/AceM2L2-1.11.1`.
- [ ] Live verification of the 49/64 XP cases against the tooltip after a clean
      kill and `/acem2l2 xpt recalibrate confirm`.

## Proposed “Aether Blue” visual redesign (1.12.0)

Full plan: `BLUE_UI_REDESIGN_PLAN.md`.

- [ ] B1 — Freeze Aether Blue palette; generate original rounded panel,
      border, shadow, glow, bar, crest, emblem, and minimap textures.
- [ ] B2 — Build the blue component kit (panel, card, pill tab, button, search,
      chip, stat card, row, bar, badge, empty state).
- [ ] B3 — Rebuild the shell: 1080×720, header wordmark, pill tabs, left hero
      column, right content, footer.
- [ ] B4 — Bento Overview: kill/session/tracked/top-area cards, most-killed
      list, level-range strip, session/XP card.
- [ ] B5 — Mobs tab: toolbar, filter/sort, crest rows, model hero card.
- [ ] B6 — Areas and Levels: ranking/share bars, area hero, level chart.
- [ ] B7 — Ambience and motion: navy gradient, vignette, glow, fades,
      bar-fill, hover states.
- [ ] B8 — Themes, scale, reduce-motion, contrast/accessibility.
- [ ] B9 — Blue minimap icon and Ace Mobs 2 Level 2 branding.
- [ ] B10 — Performance, preloading, localization, secret/taint guards.
- [ ] B11 — Tests, docs, 1.12.0/schema 5, release zip.
- [ ] B12 — Live visual verification at multiple scales and minimap setups.

## Execution pass — 1.11.2 “Aether Blue” visual pass

- [x] Add Aether Blue as the default palette.
- [x] Add navy canvas, blue panels, luminous borders, and themed text.
- [x] Move the model/detail panel to a left hero card and the list to the right.
- [x] Add hero name, classification/NPC subtitle, and adaptive detail layout.
- [x] Add header wordmark, “KILL HISTORY” subtitle, status text, settings and
      close buttons.
- [x] Replace template buttons with themed pill buttons/tabs/filters.
- [x] Add a themed blue search box with placeholder.
- [x] Add ambient navy gradient, vignette, and model glow.
- [x] Add blue accent lines to overview cards.
- [x] Tint the minimap icon blue.
- [x] Migrate old default dark profiles to Aether Blue once.
- [x] Fix tab/filter selection highlighting and responsive search placement.
- [x] Merge name-only chat kills into NPC-ID entries to remove duplicate rows.
- [x] Label mob rows as `kills | avg XP` instead of bare numbers.
- [x] Defer unnamed XP messages until death/GUID identity is available and
      retain the last target through target clearing.
- [x] Add single-row Remove/Confirm in the detail panel and
      `/acem2l2 xpt delete` / `deleteunknown` cleanup commands.
- [x] Update theme commands to include `aether`.
- [x] Expand offline tests for hero layout, area/level modes, and theme changes.
- [x] Bump to 1.11.2 and rebuild `/mnt/r/AceM2L2-1.11.2`.
- [ ] Live visual verification at 100/110/120% scale.
- [ ] Deferred to 1.12.0: 1080×720 layout, rounded 9-slice textures, custom
      fonts, full 1–60 chart, map thumbnails, reduce-motion.

## Release 1.11.3 — kill identification and cleanup

- [x] Defer unnamed XP chat until death/GUID identity is available.
- [x] Retain the last valid target through target clearing.
- [x] Add single-row Remove/Confirm.
- [x] Add `delete`, `delete confirm`, and `deleteunknown confirm` commands.
- [x] Adjust totals, session, level/area, unique-mob, and calibration data on delete.
- [x] Bump TOC/readme to 1.11.3.
- [x] Rebuild `AceM2L2-1.11.3.zip` and `/mnt/r/AceM2L2-1.11.3`.
- [ ] Live verification of unnamed-kill attribution and entry deletion.
