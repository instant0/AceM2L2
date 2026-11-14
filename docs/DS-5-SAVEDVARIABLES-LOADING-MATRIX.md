# DS-5 — SavedVariables/loading API matrix

**Status:** executed 2026-11-14; documentation/API review  
**Client basis:** retail 12.1.5, PTR 12.1.7, Forever 1.60.1  
**Scope:** what the client loads, when it loads it, and what can be deferred.
No live-client timing was performed; those items are marked V-2.

## Sources

- Warcraft Wiki, AddOn loading process:
  https://warcraft.wiki.gg/wiki/AddOn_loading_process
- Warcraft Wiki, Saving variables between game sessions:
  https://warcraft.wiki.gg/wiki/Saving_variables_between_game_sessions
- Warcraft Wiki, TOC format:
  https://warcraft.wiki.gg/wiki/TOC_format
- Warcraft Wiki, `C_AddOns.LoadAddOn`:
  https://warcraft.wiki.gg/wiki/API:C_AddOns.LoadAddOn
- Warcraft Wiki, `C_AddOns.IsAddOnLoaded`:
  https://warcraft.wiki.gg/wiki/API:C_AddOns.IsAddOnLoaded
- Warcraft Wiki, `C_AddOns.IsAddOnLoadOnDemand`:
  https://warcraft.wiki.gg/wiki/API:C_AddOns.IsAddOnLoadOnDemand
- Warcraft Wiki, `C_AddOns.IsAddOnLoadable`:
  https://warcraft.wiki.gg/wiki/API:C_AddOns.IsAddOnLoadable
- Warcraft Wiki, `C_AddOns.DoesAddOnExist`:
  https://warcraft.wiki.gg/wiki/API:C_AddOns.DoesAddOnExist
- Warcraft Wiki, `C_AddOns.SaveAddOns`:
  https://warcraft.wiki.gg/wiki/API:C_AddOns.SaveAddOns
- Warcraft Wiki, `SAVED_VARIABLES_TOO_LARGE`:
  https://warcraft.wiki.gg/wiki/Event:SAVED_VARIABLES_TOO_LARGE
- Warcraft Wiki, `ADDONS_UNLOADING`:
  https://warcraft.wiki.gg/wiki/Event:ADDONS_UNLOADING

## Matrix

| Mechanism | Scope / effect | Availability | Storage consequence |
|---|---|---|---|
| `SavedVariables` | Account-wide variables stored under `WTF\[account]\SavedVariables\AddOn.lua` | Loaded at login for a normal addon | Loads for every character; keep it small. Multiple names may be comma-separated. |
| `SavedVariablesPerCharacter` | Per-character variables stored under `WTF\[account]\[server]\[character]\SavedVariables\AddOn.lua` | Loaded for the active character only | Alts are not loaded. The active character's table still loads as a whole. |
| Multiple `SavedVariables` directives | Add more names; directives append rather than replace | All declared variables load together for a normal addon | Multiple variables do **not** defer loading by themselves. |
| `LoadSavedVariablesFirst: 1` | Loads the addon's saved-variable files before its script files | Added in 11.1.5; included in Forever 1.60.1. Cannot be turned off later in the TOC | Useful only if code needs globals at file-execution time. Otherwise initialize on `ADDON_LOADED`. |
| `LoadOnDemand: 1` | Delays the addon until `C_AddOns.LoadAddOn` is called | TOC directive | The only supported way to defer a companion's code and, subject to V-2, its variables. |
| `C_AddOns.LoadAddOn(name)` / legacy `LoadAddOn` | Loads a LoadOnDemand addon; returns `loaded, reason` | Requires `LoadOnDemand`; present on current retail/Forever/Classic clients; legacy alias exists | Use for a cold-data companion. `reason` can be `DISABLED` or another locale-independent failure. |
| `C_AddOns.IsAddOnLoaded(name)` / legacy | Returns `loadedOrLoading, loaded` | Current clients; legacy alias | Distinguish “loading” from “loaded”; do not assume one return value. |
| `C_AddOns.DoesAddOnExist(name)` / legacy | Returns whether the addon exists | Current clients; legacy alias | Missing-companion fallback check. |
| `C_AddOns.IsAddOnLoadOnDemand(name)` / legacy | Returns whether the addon is marked LoadOnDemand | Current clients; legacy alias | Verify the companion is actually deferrable before relying on it. |
| `C_AddOns.IsAddOnLoadable(name[, character[, demandLoaded]])` | Returns `loadable, reason` | Current clients | Preflight check before calling `LoadAddOn`; use `reason` for user-visible fallback. |
| `C_AddOns.SaveAddOns()` / legacy | Requests a save | Current clients; legacy alias | Checkpoint, not a per-kill write. No synchronous durability guarantee is documented. |
| `SAVED_VARIABLES_TOO_LARGE: addOnName` | Fires when saved variables cannot load due to an out-of-memory error | Added 5.4.0; available on current clients | Fires after `ADDON_LOADED`; can affect `SavedVariables` and/or `SavedVariablesPerCharacter`; **saved variables will not save on the next logout**. This is a failure path, not a normal size warning. |
| `ADDON_LOADED` | Addon files are loaded and saved variables are available | Normal addon timeline | Earliest reliable point to read saved variables unless `LoadSavedVariablesFirst` is used. |
| `ADDONS_UNLOADING: closingClient` | Fires before addons unload | Added 7.3.0; current clients | `closingClient` indicates whether the client is closing. Useful for a final checkpoint, but do not treat it as a guaranteed disk flush. |
| Logout / `/reload` | Normal save points | Client behavior | Expect saved variables to be written at logout/reload; exact timing remains V-2. |

## Load timeline

Normal addon:

```text
addon files execute
  -> saved variables load
  -> ADDON_LOADED
  -> addon can read saved variables
```

With `LoadSavedVariablesFirst: 1`:

```text
saved variables load
  -> addon files execute
  -> ADDON_LOADED
```

LoadOnDemand companion:

```text
main addon loads
  -> companion is not loaded
  -> C_AddOns.LoadAddOn("Companion")
  -> companion files execute
  -> companion saved variables load
  -> companion ADDON_LOADED
```

The last two steps are the documented normal pattern, but the exact ordering of
the companion's variables versus its files is a V-2 runtime check, not an
assumption.

## Critical API details

### `LoadAddOn` inside `ADDON_LOADED`

The wiki warns that calling `C_AddOns.LoadAddOn` inside an `ADDON_LOADED`
handler may cause the loaded addon to never receive its own `ADDON_LOADED`,
because new event registrations do not take effect until the current dispatch
finishes.

**Design rule:** do not load the companion from inside the main addon's
`ADDON_LOADED` handler. Use `PLAYER_LOGIN`, a user action, or a timer/event after
login.

### `SAVED_VARIABLES_TOO_LARGE` is not a warning

It fires when saved variables cannot be loaded because of an out-of-memory
error. It can affect account and/or per-character variables, and the client will
not save them on the next logout. The design needs a previous backup and a
recovery/compaction path, not just a “data is large” message.

### Multiple variables do not defer

Declaring `AceM2L2DB`, `AceM2L2CharDB`, and a hypothetical
`AceM2L2ColdDB` in the same addon still loads all three for a normal addon.
Only a separate LoadOnDemand addon can defer its variables.

### No per-zone SavedVariables files

SavedVariables are account-scoped or character-scoped files. There is no
per-zone file mechanism. Zone-level laziness must be implemented as:

- packed blocks decoded in memory; or
- a LoadOnDemand companion that holds cold blocks; or
- both.

## Client notes

| Client | `C_AddOns` | `LoadSavedVariablesFirst` | `LoadOnDemand` | `SAVED_VARIABLES_TOO_LARGE` | `ADDONS_UNLOADING` |
|---|---|---|---|---|---|
| Retail 12.1.5 | Yes | Yes | Yes | Yes | Yes |
| PTR 12.1.7 | Yes* | Yes* | Yes* | Yes* | Yes* |
| Forever 1.60.1 | Yes | Yes (includes Modern changes up to 12.1.5) | Yes | Yes | Yes |

`*` PTR 12.1.7 is expected to match 12.1.5, but it is not live retail yet;
confirm the marked cells in V-2.

Legacy globals (`LoadAddOn`, `IsAddOnLoaded`, `IsAddOnLoadOnDemand`,
`DoesAddOnExist`, `SaveAddOns`) remain available as aliases on the targeted
clients. Prefer `C_AddOns` with a fallback for older/unknown clients.

## Conclusions for AceM2L2

1. The current `AceM2L2DB` account / `AceM2L2CharDB` per-character split is
   correct. Account settings load for every character; the active character's
   history is the only per-character store loaded.
2. Adding more variables to the main addon does not reduce login load. It only
   separates files/scopes.
3. The only real file-level deferral is a LoadOnDemand companion. Its variable
   timing must be confirmed in V-2 before the design depends on it.
4. Zone-level laziness is an in-memory decode/normalize/UI policy, not a file
   policy, unless a companion is used.
5. `SaveAddOns` is a checkpoint. Do not call it per kill. Do not assume it
   guarantees an immediate disk flush.
6. `SAVED_VARIABLES_TOO_LARGE` must be handled as a load-failure/recovery path:
   keep a previous backup, detect the event, stop normal saving, and compact or
   reset with explicit user-visible wording.
7. `ADDONS_UNLOADING` is useful for a final checkpoint but is not a durability
   guarantee. Normal logout/reload saving still matters.
8. `LoadOnDemand` companion loading should start from `PLAYER_LOGIN` or a user
   action, not from the main addon's `ADDON_LOADED` handler.

## Task impacts

- **DS-17.1:** account data is always loaded; cold data must be packed, in a
  companion, or both. No per-zone files.
- **MEM-2:** active-character scope is already provided by
  `SavedVariablesPerCharacter`; eviction is an in-memory policy.
- **DS-13:** companion needs existence/loadable/LoadOnDemand checks, a load call
  outside `ADDON_LOADED`, a missing-companion fallback, and V-2 timing proof.
- **DS-15:** retrieval laziness is decode/normalize/UI, not partial file loading.
- **DS-16:** use `SaveAddOns` as a checkpoint, handle logout/reload and
  `ADDONS_UNLOADING`, and do not promise synchronous durability.
- **DS-14:** treat `SAVED_VARIABLES_TOO_LARGE` as a load failure; keep a backup
  and a compaction/reset path.

## V-2 checks

- Exact LoadOnDemand companion variable-load timing versus its files and
  `ADDON_LOADED` on retail, PTR, and Forever.
- Whether loading a companion from `PLAYER_LOGIN` reliably delivers its
  `ADDON_LOADED`.
- Whether `SaveAddOns` has flushed before an immediate logout/crash; otherwise
  rely on normal logout/reload save.
- Forever 1.60.1 persistence and historical saved-variable read/write behavior.
- Actual `SAVED_VARIABLES_TOO_LARGE` threshold/behavior and recovery on each
  client.

## Decision

No production change. The current two-variable split stays. A LoadOnDemand
companion remains a later option, gated by V-2 timing proof. Zone laziness stays
an in-memory policy for now.
