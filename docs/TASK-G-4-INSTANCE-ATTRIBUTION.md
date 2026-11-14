# G-4 — Instance identity, attribution, and heatmap collection gating

**Status:** phased task document, not implemented  
**Priority:** high — current data is misattributed  
**Scope:** Phase 1: tracking/storage/UI/migration for instance attribution. Phase 2: heatmap collection and event gating.  
**Depends on:** no external task; Phase 2 builds on the event/gating helpers from Phase 1. Storage caps must stay compatible with DS-1..DS-11.  
**Related:** G-1 (coordinate capture), DS-1 (consumer inventory), DS-9 (retention), V-2 (runtime storage)

## Phase map

| Phase | Task | Delivers |
|---|---|---|
| **G-4a** | Instance identity and attribution | `IsInInstance` detection, instance cache, `db.instances`, correct UI/labels, legacy 947 migration |
| **G-4b** | Heatmap collection gate | `heatmapEnabled`, event registration gating, disabled-tab state, clear action, diagnostics |

Phase 1 is independently shippable. Phase 2 must not change the instance
attribution rules; it only gates heatmap capture and event work.

---

## 1. Problem

Inside the Forever instance **Ruins of Lordaeron**, the client reports the world
map instead of a zone/dungeon map. `GetMapID()` therefore returns **947**, which
is **Azeroth** (`mapType = 1`, World). The addon trusts that ID and records:

- `db.areas["947"]`
- `mob.killsByMap["947"]`
- `mob.killsByAreaLevel["947"]`
- `db.areaLevels["947"]`
- `db.dungeon.lastInstance = 947`

The UI then labels the instance kills as **Azeroth**.

### Evidence from the captured SavedVariables file

`/mnt/r/AceM2L2.lua`, client `18`:

| Field | Value |
|---|---:|
| `areas["947"]` | 145 |
| `dungeon.kills` | 145 |
| `dungeon.xp` | 7,455 |
| `dungeon.lastInstance` | 947 |
| `areaLevels["947"]["20"]` | 145 |
| Heatmap entries | 1420, 1421 only |
| Sum of all `mob.killsByMap["947"]` | 145 |

The 26 mobs recorded under 947 are undead instance mobs (`Skeleton`, `Ghoul`,
`Spider`, `Ragged Ghoul`, `Broodling`, `The Baron`, `Viktor the Vile`, etc.).

The kill counts and dungeon totals are correct. Only the **map/area attribution**
and the displayed instance label are wrong.

### Root cause

1. `MapUtil.GetDisplayableMapForPlayer` / `C_Map.GetBestMapForUnit("player")`
   returns 947 in this custom instance.
2. `ResolveZoneMapID()` only replaces a World/Continent ID when
   `C_Map.GetMapInfoAtPosition()` returns a child of type Zone (3) or Dungeon
   (4). In the instance no child resolves, so 947 is returned.
3. `RecordKill()` writes `areas`, `killsByMap`, `areaLevels`, and
   `dungeon.lastInstance` from that unresolvable world ID.
4. `GetMapName(947)` returns `"Azeroth"`.

The heatmap already rejects world maps through `IsZoneMap()`, which is why no
947 heatmap entry exists.

---

## 2. Goals

- Never attribute instance kills to Azeroth or any world/continent map.
- Store instance kills under the **correct instance identity**: name, instance
  ID, difficulty, and optional real dungeon UiMap.
- Show the correct instance name in the Areas view, `/acem2l2 xpt`, and
  diagnostics.
- Preserve the existing dungeon aggregate (`db.dungeon`) and heatmap behavior.
- Do not destroy historical data.
- Keep storage bounded and compatible with the DS storage work.
- Read instance state on transitions, not on every kill; collapse duplicate
  events and avoid unnecessary API reads.
- Add a real heatmap collection switch: when disabled, do not register heatmap
  events, capture heatmap data, or save new heatmap entries.
- Keep the existing "show heatmap tab" setting separate from collection.
- Add offline tests; no live testing in this task (live checks stay in V-2).

## 3. Non-goals

- Recovering the name of a historical instance from a bare `947` record. That
  information is not in the saved data.
- A full per-run instance log or route history. That is Journey/DS work.
- Changing the 64×64 heatmap or its coordinate model.
- Live in-game validation.

---

## 4. Data model

### 4.1 New per-character/client bucket

```lua
db.instances = {
  ["id:1234:2"] = {
    instanceID = 1234,
    name = "Ruins of Lordaeron",
    instanceType = "party",       -- party | raid | scenario
    difficultyID = 2,
    mapID = 0,                    -- real Zone/Dungeon map only; 0 otherwise
    kills = 145,
    xp = 7455,
    sessionKills = 0,
    sessionXP = 0,
    killsAtLevel = { ["20"] = 145 },
    firstSeen = 1794588000,
    lastSeen = 1794589000,
    legacy = false,
  },
}
```

Rules:

- Key: `id:<instanceID>:<difficultyID>` when `instanceID > 0`.
- Fallback key: `name:<lowercased instance name>` when the ID is unavailable.
- Last-resort key: `unknown:<n>` is **not** allowed; use a single
  `"unknown"` record instead, so the store cannot grow unbounded.
- `name` is sanitized, trimmed, and capped at 80 characters.
- `mapID` is stored only when `C_Map.GetMapInfo(mapID).mapType` is 3 or 4.
- `killsAtLevel` is bounded by the client level range.
- `legacy = true` marks a migrated record whose real name is unknown.

### 4.2 Aggregate dungeon bucket

Keep the existing aggregate and extend it:

```lua
db.dungeon = {
  xp, kills, sessionXP, sessionKills,
  lastInstance = 0,              -- real Dungeon map ID only (mapType 4)
  lastInstanceKey = "id:1234:2",
  lastInstanceName = "Ruins of Lordaeron",
  lastInstanceID = 1234,
  lastDifficultyID = 2,
}
```

`lastInstance` must never be a World/Continent map. `lastInstanceName` is the
primary display value.

### 4.3 Per-mob attribution

Add two per-mob maps keyed by the same instance key:

```lua
mob.killsByInstance = { ["id:1234:2"] = 28 }
mob.killsByInstanceLevel = {
  ["id:1234:2"] = { ["20"] = 28 },
}
```

- `mob.killsByMap` remains **open-world only**.
- `mob.killsByAreaLevel` remains **open-world only**.
- A mob that appears in both open world and an instance keeps both maps.
- `killsByInstanceLevel` preserves the level breakdown that would otherwise be
  lost when a historical world-map key is migrated.

### 4.4 Caps

- `MAX_INSTANCE_RECORDS = 100` per character/client.
- Prune the oldest `lastSeen`; tie-break on fewer kills, then key.
- `MAX_MOB_INSTANCES = 20` keys per mob. Prune the smallest kill count, then
  the lexicographically largest key, so the result is deterministic.
- Name cap: 80 bytes after trimming.
- Key cap: 120 bytes.
- Instance records and per-mob `killsByInstance` / `killsByInstanceLevel` keys
  must be pruned together.
- `killsByInstanceLevel` inherits the per-mob instance cap; each level map is
  bounded by the client's level range.

---

## 5. Instance detection and attribution

### 5.0 Detection contract

Instance state is authoritative from `IsInInstance()`, **not** from the map ID.
A map ID of 947 means only that the instance has no usable UiMap.

Add `GetInstanceState()` returning:

```lua
{
  inInstance = true,
  instanceType = "party",      -- none | party | raid | scenario | pvp | arena
  instanceID = 1234,
  name = "Ruins of Lordaeron",
  difficultyID = 2,
  mapID = 0,                   -- real Zone/Dungeon UiMap, or 0
  key = "id:1234:2",
}
```

Detection rules:

1. Call `IsInInstance()`. It returns `isInInstance, instanceType`. Some 1.12-era
   clients return `1/0` instead of a boolean; normalize both forms and filter
   secret values.
2. If `IsInInstance()` fails or is unavailable, use `GetInstanceInfo()` name
   and type as the fallback signal.
3. If both are unavailable, treat the player as **open world**. Never infer
   instance state from the map ID or map type.
4. `instanceType == "none"` means open world even if the map ID looks odd.
5. `party`, `raid`, and `scenario` are **PvE instances**: they use the instance
   structure and increment `db.dungeon`.
6. `pvp` and `arena` are **instances too**: they use the instance structure so
   they are never attributed to Azeroth, but they do **not** increment the PvE
   `db.dungeon` aggregate.
7. Capture the result when the death is recorded and freeze it in `info`
   (`inInstance`, `instanceType`, `instanceKey`, name, ID, difficulty, mapID).
8. On commit, use the frozen values. A pending death committed after leaving
   the instance must still be attributed to the instance where the mob died.
9. If detection flips between death and commit, the death-time value wins.

### 5.1 Correct storage by state

| State | Area structure | Instance structure | Dungeon aggregate |
|---|---|---|---|
| Open world | `db.areas`, `db.areaLevels`, `mob.killsByMap`, `mob.killsByAreaLevel` | no | no |
| PvE instance | no | `db.instances`, `mob.killsByInstance`, `mob.killsByInstanceLevel` | yes |
| PvP/arena instance | no | `db.instances`, `mob.killsByInstance`, `mob.killsByInstanceLevel` | no |
| Unknown instance type | no | `db.instances` (type `unknown`) | no |

A kill is written to **exactly one** of the area or instance structures, never
both.

### 5.2 Event-driven state cache

**Verdict: yes, cache the instance state and refresh it from zoning events.**
Do not call `GetInstanceInfo()` for every kill, and do not rely on a pure
event-only cache either. Use events for stable identity plus a cheap per-kill
consistency check and a live fallback.

#### Cache shape

```lua
self.instanceState = {
  inInstance = false,
  instanceType = "none",
  instanceID = 0,
  name = "",
  difficultyID = 0,
  mapID = 0,
  key = nil,
  updatedAt = 0,
  generation = 0,
}
```

The cache is transient and is not stored in SavedVariables. A reload or login
always rebuilds it.

#### Refresh triggers

| Event | Delay | Why |
|---|---:|---|
| `PLAYER_LOGIN` | 1.0s | Startup fallback if `PLAYER_ENTERING_WORLD` is late or absent. |
| `PLAYER_ENTERING_WORLD` | 0.75s | Primary startup and zone/instance transition trigger. Fires on login, `/reload`, and zoning. |
| `ZONE_CHANGED_NEW_AREA` | 0.75s | Covers zone/instance changes where entering-world timing is early. |
| `UPDATE_INSTANCE_INFO` | 0.5s | Optional; catches difficulty/instance-info changes. Registration failure must not break install. |

`PLAYERLOADED` does not exist as an event. The relevant events are
`PLAYER_LOGIN`, `PLAYER_ENTERING_WORLD`, and `ZONE_CHANGED_NEW_AREA`.

#### Why the delay

`GetInstanceInfo()` can briefly return the previous instance, an empty name, or
partially updated difficulty during a zoning transition. A short delay lets the
client settle. `PLAYER_ENTERING_WORLD` is the primary startup trigger because it
fires after the world is ready; `PLAYER_LOGIN` is only a fallback.

#### Debounce

- Every scheduled refresh gets a generation token.
- A newer schedule invalidates older timers; only the latest result is applied.
- `ZONE_CHANGED_NEW_AREA` and `PLAYER_ENTERING_WORLD` commonly fire together;
  the debounce must collapse them into one query.
- If `C_Timer.After` is unavailable, refresh immediately.

#### Per-kill use

1. `GetInstanceState()` returns the cached state when present.
2. Call `IsInInstance()` once per kill (cheap) and compare `inInstance` and
   `instanceType` with the cache.
3. If they match, use the cached name/ID/difficulty without calling
   `GetInstanceInfo()`.
4. If they differ, refresh immediately, update the cache, and use the new state.
5. If the cache is missing, refresh live.
6. If the cache has `inInstance = true` but no name/ID, retry
   `GetInstanceInfo()` at most once per 30 seconds until resolved. Do **not**
   refresh on a fixed timer when the cache is already complete; the per-kill
   consistency check plus zoning events are the recovery path.

This gives one cheap API call per kill instead of two, while still detecting a
missed transition. `GetInstanceInfo()` is called on transitions, a boolean/type
mismatch, and the missing-identity retry only.

#### Failure behavior

- If `GetInstanceInfo()` fails, keep the previous name/ID for the current
  instance, update `inInstance`/`instanceType` from `IsInInstance()`, and log in
  debug mode.
- If both calls fail, treat the kill as open world and use the map validation
  rules; do not invent an instance name.
- A failed optional `UPDATE_INSTANCE_INFO` registration must not mark the addon
  unhealthy.

### 5.3 Capture instance identity

- Add a defensive `GetInstanceInfoSafe()` helper returning:
  `name, instanceType, difficultyID, instanceID`.
- If `GetInstanceInfo` is unavailable, fall back to `GetRealZoneText()` or
  `GetZoneText()` for the name; ID and difficulty stay 0/nil.
- Secret values must be filtered with the existing `IsSecret`/`SafeString`
  helpers.
- The instance key is built from the frozen ID/difficulty, then the normalized
  name, then the single `"unknown"` fallback.
- Freeze a **copy** of the state into the death/kill `info`; do not keep a
  reference to the mutable cache.

### 5.4 Map validation

Add `IsAttributableMapID(mapID)`:

- `true` for `mapType == 3` (Zone) or `4` (Dungeon).
- `false` for `0`, `1` (World), `2` (Continent), and unknown/cosmetic types.
- When `C_Map` is unavailable, preserve the legacy permissive behavior.

Apply it to:

- `db.areas`
- `db.areaLevels`
- `mob.killsByMap`
- `mob.killsByAreaLevel`
- `dungeon.lastInstance`

`GetMapID()` should return **0** whenever the resolved map fails
`IsAttributableMapID`. In an instance this covers the 947/world-map fallback;
in open world it covers an unresolved world/continent map. A missing map must
never become an area name.

### 5.5 RecordKill decision table

`inInstance` is the primary switch. Map type only decides whether a real map is
also usable for heatmap/display.

| Detected state | Areas / killsByMap | Instances bucket | Dungeon aggregate | Heatmap |
|---|---|---|---|---|
| Open world, attributable Zone map | record map | no | no | record if position |
| Open world, world/continent/unresolved map | **no** | no | no | skip |
| PvE instance (party/raid/scenario), real Zone/Dungeon map | **no** | record | yes | record if position |
| PvE instance, world map 947 or no map | **no** | record | yes | skip |
| PvP/arena instance | **no** | record (type pvp/arena) | no | skip |
| Unknown instance type | **no** | record (`unknown`) | no | skip |

Rationale: instance kills are stored once, in `db.instances`, so the Areas view
cannot double-count a standard dungeon that also has a real map ID. PvP and
arena instances are still instances for attribution, but they are not PvE
dungeon progress.

### 5.6 Context keys

- Extend `ContextKey()` with an optional `instanceKey` argument.
- Append `-i<instanceKey>` only when `instanceKey` is non-empty.
- Open-world context keys stay byte-identical, so existing calibration remains
  valid.
- Store `context.instanceKey` for diagnostics and future migration.
- This prevents the same mob/level/group/buff combination in different
  instances from sharing one calibration context.

### 5.7 Session and reset behavior

- `ResetData()` clears `db.instances`.
- The session reset path in `KillHistory/Events.lua` must also zero
  `sessionKills`/`sessionXP` in every instance record, mirroring the existing
  mob and dungeon session reset.
- Instance records persist across sessions; `lastSeen` updates on every kill.

---

## 6. Collection, event, and feature gating

### 6.1 Principles

1. **One read per transition.** Instance state is read once when the player
   enters/leaves a world or instance, not once per kill.
2. **Gate at the source.** If a feature is disabled, do not register its event,
   schedule its timer, read its coordinates, or write its table.
3. **Debounce duplicate events.** `PLAYER_LOGIN`, `PLAYER_ENTERING_WORLD`, and
   `ZONE_CHANGED_NEW_AREA` can overlap; collapse them into one refresh.
4. **No polling.** No `OnUpdate` loop and no fixed-interval `GetInstanceInfo`
   calls.
5. **Capture once, pass through.** Death capture reads position once and passes
   `x`/`y` to the heatmap path; the heatmap must not re-query position.
6. **Transient cache only.** Instance state is rebuilt on login/reload and is
   never saved.

### 6.2 Settings model

Keep two separate concepts; do not overload the existing tab setting.

| Setting | Purpose | Default |
|---|---|---|
| `heatmapEnabled` (new) | Master switch for heatmap **collection and saving** | `true` |
| `showHeatmap` (existing) | Show/hide the Heatmap tab only | `true` |

Effective behavior:

- **Tab visibility is controlled only by `showHeatmap`.** Disabling collection
  does not hide the tab.
- `heatmapEnabled = false` with `showHeatmap = true`:
  - The Heatmap tab stays visible and shows a clear disabled state:
    "Heatmap collection is disabled. Enable it in Settings > Heatmap."
  - The grid, legend, art, and zone pager are hidden; no data is normalized or
    rendered.
  - `RecordHeatmapKill()` returns immediately, before any map/position work.
  - No `db.heatmaps` writes, no `NormalizeHeatmaps()` on load, no heatmap UI
    refresh, no map-art reads.
  - `MAP_EXPLORATION_UPDATED` is unregistered.
  - Heatmap-only settings (reveal, intensity, warm palette) are disabled in the
    options UI.
  - Existing heatmap data is **not silently deleted**; see 6.5.
  - The tab is not switched away from; it stays where the player put it.
- `showHeatmap = false` hides the tab regardless of collection state.
- `showHeatmap = true` and `heatmapEnabled = true` is the normal recording and
  display path.
- Re-enabling collection resumes recording, runs the normalizer on stored data,
  and re-renders the tab; previously stored data is used only if it was not
  cleared.
- The setting is account-wide and sanitized as a strict boolean.

### 6.3 Event registration and refresh gating

| Event | Register when | Action | Must not do |
|---|---|---|---|
| `PLAYER_LOGIN` | Tracking installed | Schedule startup refresh (1.0s) | Query before the delay |
| `PLAYER_ENTERING_WORLD` | Tracking installed | Schedule refresh (0.75s); primary startup trigger | Query twice with login |
| `ZONE_CHANGED_NEW_AREA` | Tracking installed | Schedule refresh (0.75s) | Duplicate the entering-world query |
| `UPDATE_INSTANCE_INFO` | `hasInstanceInfo` and optional registration succeeds | Schedule refresh (0.5s) | Break install if unavailable |
| `MAP_EXPLORATION_UPDATED` | `heatmapEnabled` and `hasMapPosition` | `OnMapExplorationUpdated` | Register when heatmap is off |
| `UNIT_DIED`, chat, target, money, loot | Unchanged | Existing handlers | Add instance/map reads here |

Rules:

- Every new handler checks `self:IsActive()` first.
- The instance refresh is a single debounced function. A generation token makes
  only the newest timer eligible to apply its result.
- `PLAYER_ENTERING_WORLD` is the primary startup trigger. `PLAYER_LOGIN` is a
  fallback for clients/orderings where entering-world is late or absent.
- Registering and unregistering `MAP_EXPLORATION_UPDATED` happens through one
  helper, `RefreshHeatmapEventRegistration()`, called on install and whenever
  `heatmapEnabled` changes.
- Do not call `GetInstanceInfo()` from `UNIT_DIED`, chat handlers, or any
  high-frequency event.

### 6.4 Per-kill gating

Read ownership:

| Data | Owner | When read |
|---|---|---|
| Instance state | Event cache + `IsInInstance` check | Transitions, mismatch, missing identity |
| Map position | `CaptureUnit` | Once at death/target/mouseover capture; passed through |
| Map ID | `RecordKill` | Once per kill for area/instance attribution |
| Heatmap cells | `RecordHeatmapKill` | Only when `heatmapEnabled` |
| Exploration art | `MAP_EXPLORATION_UPDATED` | Only when `heatmapEnabled` |
| Heatmap UI refresh | `RefreshHeatmap` | Only when collection is on and the UI needs it |

At the kill/death point:

1. Read the cached instance state.
2. Call `IsInInstance()` once (cheap) and compare with the cache.
3. On mismatch, refresh once and continue; otherwise use the cache.
4. If the cache has `inInstance = true` but no name/ID, retry
   `GetInstanceInfo()` at most once per 30 seconds until resolved. Do **not**
   refresh on a fixed timer when the cache is already complete.
5. If `heatmapEnabled` is false, do not call `RecordHeatmapKill()` and do not
   do heatmap-specific position/art work. Death-location capture keeps its own
   position needs.
6. Open-world area attribution still needs the map ID; do not skip it just
   because the heatmap is off.

`RecordHeatmapKill()` itself also returns early when:

- `heatmapEnabled` is false;
- `hasMapPosition` is unsupported;
- the map is not an attributable Zone/Dungeon map;
- the coordinates are missing or invalid.

`RefreshHeatmap()` shows the disabled tab state and returns before
normalization/art when the collection setting is off. `OnMapExplorationUpdated()`
returns early. `PrintHeatmap()`/`GetHeatmapZones()` report "heatmap collection
disabled" rather than normalizing stored data.

### 6.5 Disable and clear semantics

- Turning collection off **stops new collection and saving**. It does not
  silently delete existing history.
- Provide an explicit **Clear heatmap data** action:
  - Settings button and `/acem2l2 xpt heatmap clear`.
  - Requires confirmation.
  - Clears `db.heatmaps`, `heatmapZoneKey`, the normalized cache, and rendered
    cells/art.
  - Diagnostics then shows zero zones/cells.
- If the player wants zero heatmap bytes in SavedVariables, they disable
  collection **and** clear the data.
- The disable checkbox tooltip states: "Stops recording new heatmap data.
  Existing data is kept until you clear it."
- Do not show a popup on every login for a disabled feature.

### 6.6 Diagnostics and documentation

- Data diagnostics adds:
  - `Heatmap collection: On/Off`
  - stored heatmap zones/cells
  - estimated heatmap bytes
  - instance count/capacity
- README.txt and README.md explain the difference between hiding the tab and
  disabling collection.
- BROCHURE changelog records the new setting.

### 6.7 Evaluation

**Benefits**

- Non-heatmap users stop paying the storage, normalization, art-tile, and
  refresh cost.
- Fewer SavedVariables writes and smaller future growth.
- Event registration is reduced to features that are actually enabled.
- Instance identity is read on transitions instead of every kill.
- Duplicate `PLAYER_ENTERING_WORLD` / `ZONE_CHANGED_NEW_AREA` work is collapsed.

**Risks**

- Two similar settings can confuse players. Mitigation: explicit labels and
  tooltips; `showHeatmap` is "tab only", `heatmapEnabled` is "collection".
- Clearing data is destructive. Mitigation: explicit confirmation and separate
  action; disabling alone is non-destructive.
- Event gating can leave a stale cache if an event is missed. Mitigation: cheap
  per-kill `IsInInstance` check and a 30s retry only when identity is missing.
- Event registration changes can affect other features. Mitigation: gate only
  `MAP_EXPLORATION_UPDATED`; leave nameplate/respawn events alone.
- Existing 2.4.x users have no `heatmapEnabled` key. Mitigation: default true
  and sanitize on load.
- Disabling while inside an instance must not erase the current instance state
  needed for kill attribution. Mitigation: collection setting is independent of
  instance detection.
- Players may expect disabling collection to hide the tab. Mitigation: keep the
  tab visible and state clearly that collection is disabled; only
  `showHeatmap` hides it.

**Verdict**

The gating is implementable without new storage architecture work. It should be
delivered as **G-4b**, after G-4a, because it builds on the shared event/gating
helpers and should not change instance attribution. The main design constraint
is keeping the two heatmap settings distinct and making clear-on-disable
explicit, not automatic.

## 7. Migration

Historical `areas`/`killsByMap` keys that are World/Continent maps cannot be
attributed to a named dungeon. Do not invent a name.

### 7.1 Areas migration

On load, for each `db.areas[mapID]` where `IsAttributableMapID(mapID)` is false:

1. Create or merge `db.instances["legacy:" .. mapID]`:
   - `name = "Unattributed instance (map " .. mapID .. ")"`
   - `legacy = true`, `instanceID = 0`, `mapID = 0`
   - `kills = area count`, `xp = 0`
   - `killsAtLevel = db.areaLevels[mapID]` when present
   - `firstSeen = 0`, `lastSeen = 0`
2. Remove the world/continent key from `db.areas` and `db.areaLevels`.
3. If `db.dungeon.lastInstance` is a world/continent map, clear the numeric
   field and set:
   - `lastInstanceKey = "legacy:" .. mapID`
   - `lastInstanceName = "Unattributed instance (map " .. mapID .. ")"`
   - `lastInstanceID = 0`

The user's existing 145 kills become **"Unattributed instance (map 947)"**,
not "Azeroth". The dungeon aggregate still shows 145 kills and 7,455 XP, and
the level-20 breakdown is preserved.

### 7.2 Per-mob migration

- Move world/continent `mob.killsByMap` keys into
  `mob.killsByInstance["legacy:" .. mapID]`.
- Move the matching `mob.killsByAreaLevel["legacy:" .. mapID]` into
  `mob.killsByInstanceLevel["legacy:" .. mapID]`.
- Remove the world/continent keys from `killsByMap` and `killsByAreaLevel`.
- This preserves per-mob kill totals and level breakdowns while removing 947
  from map breakdowns.

### 7.3 Idempotence

- Migration runs once per character/client and must be safe to run again.
- Use a dedicated flag such as `db.instanceMigration = 1`; do not bump
  `dataSchema` just for this migration.
- A second run must not duplicate counts.
- Back up the pre-migration payload through the existing migration-backup path.

---

## 8. UI changes

### 8.1 Areas tab

- Exclude every map key that fails `IsAttributableMapID`.
- Append `db.instances` rows:
  - label: instance `name` (append difficulty label when known)
  - value: kills
  - `kind = "instance"`
  - sort by kills
  - bar relative to `db.totals.kills`
- A legacy row is labeled "Unattributed instance (map 947)".
- If an instance has both a record and a real map area (should not happen after
  5.5), show only the instance row.

### 8.2 Overview / detail

- Overview "Top area" remains open-world zones only.
- `/acem2l2 xpt` prints:
  - `Last instance: Ruins of Lordaeron` from `lastInstanceName`
  - fall back to `GetMapName(lastInstance)` only when `lastInstance` is a real
    Dungeon map
- Detail panel for an instance row shows kills, XP, level spread, and last seen.
- Generalize the "top mobs by field" helper so it can read `killsByInstance`
  as well as `killsByMap`.
- Mob detail may show `killsByInstance` as a secondary breakdown; keep this
  out of the first implementation if it delays the fix.

### 8.3 Diagnostics

- Add `instances`, `instanceKills`, `instanceCapacity`, `heatmapEnabled`,
  `heatmapZones`, `heatmapCells`, and `estimatedHeatmapBytes` to
  `GetDataStats()`.
- Show `Instances: N / 100` and `Heatmap collection: On/Off` in the Data
  diagnostics panel.
- When collection is off, count raw stored heatmap keys without running the
  normalizer/migration; label the row as stored data so it is not mistaken for
  active recording.
- Keep the existing dungeon aggregate row.

### 8.4 Settings > Heatmap

- Add **Enable heatmap collection** (`heatmapEnabled`, default on).
  - Tooltip: "Records new heatmap data. Turning this off stops collection and
    saving; existing data stays until you clear it."
  - Disabling does not pop a confirmation by itself; the clear action does.
- Keep **Show heatmap tab** (`showHeatmap`) as the tab-only control.
- Add **Clear heatmap data** with a confirmation dialog.
- Disable reveal/intensity/warm controls when collection is off.
- If collection is off, the Heatmap tab stays visible when `showHeatmap` is
  true and shows its disabled state; it is not switched away from.
- If `showHeatmap` is false, the tab is hidden regardless of collection state.

### 8.5 Heatmap tab disabled state

- Reuse the existing `noData` area for the message:
  "Heatmap collection is disabled. Enable it in Settings > Heatmap."
- Hide the zone selector, grid, legend, and map-art caption.
- Do not show stale cells or art.
- The tab remains selectable from the tab bar; paging and refresh are no-ops.
- When collection is re-enabled, `RefreshHeatmap()` re-renders normally.
- `PrintHeatmap()` prints "heatmap collection disabled" instead of a zone list.

---

## 9. Validation

### 9.1 Unit tests

- `GetInstanceState`: `IsInInstance` true/false, each instance type, missing
  APIs, and a world-map ID with `inInstance = false`.
- `GetInstanceState` cache: a matching `IsInInstance` result does **not** call
  `GetInstanceInfo`; a mismatch does; a missing name/ID retries at most once
  per 30 seconds; a complete cache is never refreshed on a timer.
- Event refresh: `PLAYER_LOGIN`, `PLAYER_ENTERING_WORLD`, and
  `ZONE_CHANGED_NEW_AREA` schedule a refresh; multiple schedules collapse into
  one query; the newest generation wins.
- Delay: a kill before the delayed refresh still gets the correct state through
  the per-kill `IsInInstance` mismatch check.
- No `C_Timer.After`: refresh runs immediately.
- Optional `UPDATE_INSTANCE_INFO` registration failure does not break install.
- Cache is transient and is not written to SavedVariables.
- `heatmapEnabled` defaults to true, sanitizes as a strict boolean, and is
  independent of `showHeatmap`.
- `MAP_EXPLORATION_UPDATED` is registered only when `heatmapEnabled` and
  `hasMapPosition`; toggling collection updates registration exactly once.
- `RecordHeatmapKill` returns before map/position work when collection is off.
- Disabling collection does not delete stored data; the explicit clear action
  does.
- `showHeatmap = false` still collects data; only the tab is hidden.
- Event handlers call `IsActive()` and do not run when tracking is inactive.
- `InstanceKey`: ID/difficulty, name fallback, unknown fallback, length caps.
- `IsAttributableMapID`: types 0/1/2 false; 3/4 true; missing `C_Map` legacy.
- `ContextKey`: open-world string unchanged; instance key appended; empty key
  ignored.
- Migration: 947 area/per-mob keys move once, counts and level breakdowns are
  preserved, second run is a no-op.
- Caps: 101 records prune to 100; tie-break deterministic; per-mob keys prune
  with instance records.
- Mob merge: `killsByInstance` and `killsByInstanceLevel` combine like the
  existing map maps.

### 9.2 Integration tests

Use a `GetInstanceInfo` mock in `tests/fixtures.lua`.

1. **Open world:** `IsInInstance` false, map 1421; kill writes
   `areas["1421"]`, `killsByMap["1421"]`, no instance record.
2. **World-map instance:** `IsInInstance` true, type `party`, map 947, name
   "Ruins of Lordaeron", ID 1234, difficulty 2:
   - no `areas["947"]`
   - no `killsByMap["947"]`
   - `instances["id:1234:2"].kills == 1`
   - `mob.killsByInstance["id:1234:2"] == 1`
   - `dungeon.kills` increments
   - `dungeon.lastInstanceName == "Ruins of Lordaeron"`
   - `dungeon.lastInstance == 0`
   - `lastInstanceKey` matches
3. **World-map, not in instance:** `IsInInstance` false with map 947 must **not**
   create an instance record and must not create `areas["947"]`.
4. **Real dungeon map:** map type 4; instance record gets the kill; heatmap
   records under the real map; `areas` does not double-count.
5. **PvP/arena:** instance record is written, but `dungeon.kills` and
   `dungeon.xp` do not increment.
6. **Detection flip:** death captured in an instance, commit after leaving still
   attributes to the instance; death captured outside, commit inside, stays in
   the open-world area.
7. **Startup delay:** `PLAYER_LOGIN` / `PLAYER_ENTERING_WORLD` schedules a
   refresh; before the delay a kill falls back to the per-kill consistency
   check; after the delay the cache holds the instance name/ID.
8. **Transition debounce:** firing `ZONE_CHANGED_NEW_AREA` and
   `PLAYER_ENTERING_WORLD` together queries `GetInstanceInfo` once after the
   delay, not twice.
9. **Missed event:** cache says open world, `IsInInstance` says instance at kill
   time; the kill is attributed to the instance and the cache is corrected.
10. **Name fallback:** no instance ID; key uses normalized name; same instance
    on a later kill merges into one record.
11. **Missing instance info:** `GetInstanceInfo` nil; zone text fallback; one
    `"unknown"` record, never unbounded.
12. **Migration:** seed `areas["947"] = 145` and `areaLevels["947"]["20"] = 145`;
    after load, `areas["947"]` is gone, `instances["legacy:947"].kills == 145`,
    its `killsAtLevel["20"] == 145`, dungeon aggregate unchanged, and a second
    load does not duplicate.
13. **Session reset:** the Events session reset zeroes instance session counters;
    lifetime counters stay.
14. **ResetData:** instance bucket is emptied.
15. **UI:** Areas list has no "Azeroth"; instance row shows the correct name;
    `/acem2l2 xpt` shows `Last instance: Ruins of Lordaeron`.
16. **Diagnostics:** instance count/capacity appears and stays within the cap.
17. **Heatmap collection off:** a kill still updates area or instance stats but
    writes no `db.heatmaps` entry, calls no heatmap position/art path, and
    `MAP_EXPLORATION_UPDATED` is not registered.
18. **Heatmap tab only:** `showHeatmap = false` with collection on still records
    heatmap data; the tab is hidden.
19. **Disable and clear:** the explicit clear action empties `db.heatmaps`,
    resets rendered cells/art, and diagnostics reports zero zones/cells.
20. **Disable while on the tab:** switching collection off while the Heatmap tab
    is active keeps the tab open and shows the disabled message; it does not
    move to Overview or leave stale cells/art.
21. **Read count:** a single kill with a complete cache calls `IsInInstance`
    once and `GetInstanceInfo` zero times; overlapping transition events call
    `GetInstanceInfo` once.

### 9.3 Commands and snapshots

- Update `tests/smoke.lua` options/diagnostics coverage.
- Add a snapshot assertion for the Areas list and `/acem2l2 xpt` output if the
  harness supports command capture.

---

## 10. Acceptance criteria

### 10.1 G-4a — instance attribution

- `IsInInstance()` alone decides whether a kill belongs to an instance; the map
  ID never decides that.
- Instance identity is cached from zoning events and refreshed on startup after
  a short delay; the per-kill path calls only the cheap `IsInInstance()` check
  and falls back to a live query on mismatch or missing identity.
- A kill inside Ruins of Lordaeron is stored under an instance record named
  `Ruins of Lordaeron`, not under `areas["947"]` or "Azeroth".
- A kill is written to exactly one of the open-world structures or the instance
  structures, never both.
- `/acem2l2 xpt` prints the instance name, never "Azeroth".
- The Areas view has no World/Continent map rows.
- `dungeon.kills` and `dungeon.xp` remain correct.
- Heatmap behavior is unchanged for real maps and skipped for map-less
  instances.
- A complete instance cache costs one `IsInInstance()` read per kill and zero
  `GetInstanceInfo()` reads; overlapping transition events produce one query.
- Historical 947 data is preserved as an "Unattributed instance" record, with
  no fabricated dungeon name.
- Instance records and per-mob keys are capped and normalized on load.

### 10.2 G-4b — heatmap collection gate

- `heatmapEnabled = false` stops heatmap collection and saving, unregisters the
  exploration event, and performs no heatmap normalization/art work.
- The Heatmap tab remains visible when `showHeatmap` is true and shows the
  disabled message. It is not switched to Overview and does not show stale
  cells or art.
- `showHeatmap = false` hides the tab regardless of collection state and still
  does not stop collection when collection is enabled.
- Disabling collection is non-destructive; the explicit clear action removes
  stored heatmap data after confirmation.
- Diagnostics shows collection on/off and reports raw stored heatmap keys
  without normalizing them while collection is off.
- No duplicate `GetInstanceInfo` or exploration reads are added by the gate.

### 10.3 Shared

- All existing offline tests plus the new phase-specific tests pass.
- No live testing is required for either phase; V-2 covers runtime persistence.

---

## 11. Code touchpoints

### Tracking and data (G-4a)

- `KillHistory/Util.lua` — `GetMapID`, `ResolveZoneMapID`, `GetMapName`,
  `IsInDungeon`; add `GetInstanceState`, `GetInstanceInfoSafe`,
  `IsAttributableMapID`.
- `KillHistory/World.lua` — `GetPlayerMapPosition`, death capture.
- `KillHistory/Tracking.lua` — `RecordKill`, `CaptureUnit`,
  `QueueUnidentifiedKill`, `CommitPendingDeath`, `HandleUnitDied`, all
  `ContextKey` call sites.
- `KillHistory/Formula.lua` — `ContextKey` optional instance segment.
- `KillHistory/Calibration.lua` — context storage and diagnostics.
- `KillHistory/Data.lua` — `CreateCharData`, `NormalizeData`,
  `NormalizeDungeon`, `NormalizeMobFields`, `EnsureMob`, `MergeMobEntries`,
  `ConsolidateNameOnlyMobs`, mob removal/reconstruction paths, migration backup.
- `KillHistory/Events.lua` — `OnLogin`, `OnEnteringWorld`, `OnZoneChanged`,
  `StartSession` (session reset), scheduled refresh.
- `KillHistory/Module.lua` — event table in `Install`, debounced refresh,
  optional `UPDATE_INSTANCE_INFO`, exploration-event registration helper.

### Heatmap and settings (G-4b)

- `KillHistory/Heatmap.lua` — `RecordHeatmapKill`, `NormalizeHeatmaps`,
  `ResetHeatmaps`, `PrintHeatmap`; add collection early returns and clear path.
- `KillHistory/UI/Heatmap.lua` — `RefreshHeatmap`,
  `OnMapExplorationUpdated`, art/legend gating when collection is off.
- `Core/Defaults.lua` — `heatmapEnabled` default.
- `Core/Settings.lua` — boolean sanitization.
- `Core/Options.lua` — Settings > Heatmap collection toggle, clear button,
  disabled heatmap-only controls, and the disabled-tab state hint.
- `KillHistory/UI/List.lua`, `KillHistory/UI/Overview.lua`,
  `KillHistory/UI/Detail.lua`, `KillHistory/UI/Window.lua`,
  `KillHistory/UI/Minimap.lua` — open-world vs instance labels and top-area
  handling.
- `KillHistory/UI/Diagnostics.lua` — instance and heatmap-collection stats.
- `KillHistory/Commands.lua` — reset, last-instance output, area summaries,
  heatmap clear command.

### Tests and docs (both phases)

- `tests/fixtures.lua` — `GetInstanceInfo`, event simulation, timer advance,
  position-call counters.
- `tests/smoke.lua` — G-4 unit/integration tests and existing assertions.
- `README.txt`, `README.md`, `BROCHURE.md`, `PLAN.md` — setting semantics,
  instance attribution, limits, changelog.

## 12. Implementation checklist

### 12.1 G-4a — instance identity and attribution

- [ ] Add `GetInstanceState()`, `GetInstanceInfoSafe()`, and
  `IsAttributableMapID()` helpers.
- [ ] Add a transient `self.instanceState` cache and a debounced
  `ScheduleInstanceStateRefresh(delay)` using `C_Timer.After`.
- [ ] Hook `PLAYER_LOGIN`, `PLAYER_ENTERING_WORLD`, and `ZONE_CHANGED_NEW_AREA`;
  register `UPDATE_INSTANCE_INFO` optionally.
- [ ] Add the per-kill `IsInInstance` consistency check and the missing-identity
  retry/backoff fallback.
- [ ] Capture instance state and identity in death info; freeze a copy for
  pending commits.
- [ ] Validate/zero world/continent map IDs in `GetMapID()` and `RecordKill()`.
- [ ] Add `db.instances`, `mob.killsByInstance`,
  `mob.killsByInstanceLevel`, and dungeon last-instance fields.
- [ ] Add `NormalizeInstances()` and extend `NormalizeDungeon()`.
- [ ] Add pruning/caps and session/reset handling.
- [ ] Update `CreateCharData`, `EnsureMob`, `NormalizeMobFields`,
  `MergeMobEntries`, `ConsolidateNameOnlyMobs`, and the mob removal/
  reconstruction paths for the new fields.
- [ ] Extend `ContextKey()` and calibration context storage.
- [ ] Add the one-time legacy migration.
- [ ] Update Areas list, `/acem2l2 xpt`, detail, and diagnostics.
- [ ] Update README/PLAN limits and storage docs.
- [ ] Add fixtures for `GetInstanceInfo`, instance events, timer advance, and
  read-count checks.
- [ ] Add the G-4a tests from section 9.
- [ ] Run `./tests/run_all.sh` and release-check before shipping G-4a.

### 12.2 G-4b — heatmap collection gate

- [ ] Add `heatmapEnabled` to defaults, sanitization, and Settings > Heatmap;
  keep `showHeatmap` as tab-only.
- [ ] Gate `RecordHeatmapKill`, `NormalizeHeatmaps`, `PrintHeatmap`, and
  `OnMapExplorationUpdated` on `heatmapEnabled`.
- [ ] Update `RefreshHeatmap` to show the disabled tab state and hide
  cells/legend/art without normalizing or switching tabs.
- [ ] Add `RefreshHeatmapEventRegistration()` and gate
  `MAP_EXPLORATION_UPDATED`.
- [ ] Add the explicit clear-heatmap action, confirmation, and command.
- [ ] Disable heatmap-only option controls when collection is off.
- [ ] Update diagnostics with collection state, raw stored counts, and estimated
  heatmap bytes.
- [ ] Update README/BROCHURE text for the difference between hiding the tab and
  disabling collection.
- [ ] Add fixtures for event registration and heatmap-position call counts.
- [ ] Add the G-4b tests from section 9.
- [ ] Run `./tests/run_all.sh` and `CHECK_RELEASE=1` before shipping G-4b.

---

## 13. Open questions

1. Does Forever 1.60.1 `GetInstanceInfo()` return a stable `instanceID` for
   custom instances, or only a name? The implementation must fall back cleanly
   either way.
2. Should difficulty be part of the key for party dungeons, or only raids?
   Decision: include it for both; it is the only way to separate normal and
   heroic records without collisions.
3. Should legacy `areas[947]` be visible as "Unattributed instance" or hidden
   entirely? Decision: visible, so the user can see that 145 kills are still
   accounted for.
4. Should a future command let the user rename an unattributed legacy record?
   Out of scope for G-4; note it as a possible follow-up.
5. Does any other consumer read `db.areas` for dungeon rows? Audit `DS-1` before
   implementation.
6. Should disabling collection clear existing heatmap data automatically?
   Decision: no. Keep the disable action non-destructive and require the
   explicit clear action, so a settings toggle cannot destroy history.
7. Should the collection setting be account-wide or per-character? Decision:
   account-wide, matching the existing heatmap tab/intensity settings; the
   stored data remains per character/client.
8. Should disabling collection hide the Heatmap tab? Decision: no. Keep the tab
   visible when `showHeatmap` is true and show a disabled message; only
   `showHeatmap` hides the tab.
9. Should G-4a and G-4b ship together? Decision: no. Ship G-4a first, then
   G-4b after the instance attribution tests are stable.

---

## 14. Review log

### v1 — initial draft

- Proposed reusing `db.areas` with synthetic keys for instances.
- Proposed deriving historical instance names from `dungeon.lastInstance`.
- Proposed live verification in the same task.

### v2 — revised after review

- **Rejected synthetic keys in `db.areas`.** Instance identity gets its own
  `db.instances` bucket, keyed by instance ID + difficulty, with a name
  fallback. This avoids collisions and double counting.
- **Rejected guessing historical names.** A bare 947 cannot identify Ruins of
  Lordaeron. Migration creates an honest "Unattributed instance (map 947)" row
  instead of fabricating a dungeon.
- **Added context-key separation.** Without it, different instances would share
  calibration contexts because they all resolve to map 0.
- **Froze instance identity at death time**, so a delayed commit after leaving
  the instance cannot relabel the kill.
- **Added storage caps and per-mob key pruning** so the fix cannot grow the
  SavedVariables without bound.
- **Removed live testing from the task.** Runtime checks stay in V-2.
- **Added a decision table** for open world / real dungeon map / world-map
  instance / no-map instance, to prevent double counting.

### v3 — final review

- Confirmed the evidence sums: 145 dungeon kills = 145 area kills = 145
  per-mob instance kills.
- Confirmed `lastInstance` keeps its numeric map meaning; display moves to
  `lastInstanceName`.
- Confirmed heatmap exclusion for world maps already works and needs no change.
- Confirmed the migration must be idempotent and backed up.
- Confirmed no live testing is required to close G-4; V-2 validates runtime
  persistence and the real Forever instance.

### v4 — revised for explicit dungeon detection

- **`IsInInstance()` is now the primary state switch**, not the map ID. A world
  map ID only means the instance has no usable UiMap.
- Added `GetInstanceState()` with an explicit contract for open world, PvE
  instances, PvP/arena, and unknown types.
- Added the "exactly one structure" rule: open-world kills use `areas`/`killsByMap`;
  instance kills use `instances`/`killsByInstance`; never both.
- Added death-time freezing so an instance→open-world or open-world→instance
  transition cannot relabel a pending kill.
- Added PvP/arena attribution without incrementing PvE dungeon stats.
- Preserved historical level breakdowns during migration instead of dropping
  them.
- Added mob-merge and session-reset touchpoints to the implementation checklist.
- Confirmed `ResetSession()` does not exist; the task now names the actual
  Events session-reset path.

### v5 — event-driven state cache

- **Verdict: cache the state and refresh on zoning events.**
- Added a transient cache with `PLAYER_LOGIN`, `PLAYER_ENTERING_WORLD`,
  `ZONE_CHANGED_NEW_AREA`, and optional `UPDATE_INSTANCE_INFO` triggers.
- Added a 0.5–1.0s delay because instance info is not always settled during a
  transition; `PLAYER_ENTERING_WORLD` is the primary startup trigger, not
  `PLAYER_LOGIN`.
- Kept a cheap per-kill `IsInInstance()` consistency check so a missed event
  cannot misattribute a kill, and a missing-identity retry/backoff fallback.
- Added debounce/generation rules so entering-world and zone-changed do not
  query twice.
- Clarified that `PLAYERLOADED` is not an event; the relevant names are
  `PLAYER_LOGIN` and `PLAYER_ENTERING_WORLD`.
- Added event-order, delayed-startup, missed-event, and no-`C_Timer` tests.

### v6 — collection and event gating

- **Added a master `heatmapEnabled` collection setting**, separate from the
  existing `showHeatmap` tab setting.
- Defined that disabling collection stops new heatmap capture **and saving**,
  unregisters `MAP_EXPLORATION_UPDATED`, and skips normalization/art work.
- Kept disable non-destructive; added an explicit confirmed clear action for
  players who want zero heatmap bytes.
- Added an event gating matrix so `PLAYER_LOGIN`,
  `PLAYER_ENTERING_WORLD`, and `ZONE_CHANGED_NEW_AREA` do not duplicate reads,
  and so disabled features do not register events.
- Replaced the 300s periodic cache refresh with a per-kill consistency check
  plus a 30s missing-identity retry; a complete cache is never refreshed on a
  timer.
- Documented capture-once/pass-through for positions and the distinction
  between heatmap collection and death-location capture.
- Added collection-off, tab-only, clear, duplicate-read, and registration
  tests.
- Evaluated the trade-offs: storage/CPU savings versus two-setting confusion
  and accidental deletion; resolved both with separate labels and explicit
  confirmation.

### v7 — two phases and disabled-tab state

- **Split the task into G-4a (instance attribution) and G-4b (heatmap
  collection gate)** so each phase can be tested and shipped independently.
- **Removed the hide-tab/switch-to-Overview behavior.** When collection is off,
  the Heatmap tab stays visible and shows "Heatmap collection is disabled.
  Enable it in Settings > Heatmap." Only `showHeatmap` hides the tab.
- Added an explicit disabled-tab state section covering noData, hidden grid/
  legend/art, no stale cells, paging/refresh no-ops, and re-enable behavior.
- Reassigned acceptance criteria and implementation checklists to G-4a/G-4b.
- Added Phase 1/Phase 2 labels to the code touchpoints.
- Recorded the phase order and tab-visibility decisions in the open questions.
