# MEM-2 — Load/unload and eviction policy

**Status:** task document, not implemented  
**Priority:** high for long-lived characters and multiple alts  
**Owner:** storage/UI owner with MEM-1 measurement  
**Depends on:** MEM-1, DS-5, DS-15, DS-16, DS-17.3  
**Blocks:** DS-11, V-2  
**Related:** DS-3, SC-1, DS-17, `docs/DS-5-SAVEDVARIABLES-LOADING-MATRIX.md`

## Problem

AceM2L2 currently loads its SavedVariables at login and keeps the active
character, heatmap caches, UI cell pool, and supporting tables resident. Real
samples are small (3.2–3.85 MB), but the design must stay safe for:

- 18k–32.5k kills per character;
- 500–2,000 unique mobs;
- 40–200 zones and 50–200 instances;
- multiple alts/level-cap generations;
- dense 64×64 heatmaps;
- Midnight's larger data volume.

There is no single written load/unload policy today. DS-15 covers lazy
retrieval, DS-13 covers a companion, and DS-16 covers saves, but the eviction
and release rules need one owner.

## DS-5 constraints

`docs/DS-5-SAVEDVARIABLES-LOADING-MATRIX.md` fixes the boundary:

- A normal addon loads all declared SavedVariables together. Account data loads
  for every character; `SavedVariablesPerCharacter` loads only the active
  character.
- Multiple variables do not defer loading. Only a LoadOnDemand companion can
  defer its code and, subject to V-2 timing proof, its variables.
- There are no per-zone SavedVariables files.
- Eviction is for decoded/normalized tables, caches, UI cells/art, and optional
  companion blocks, not for part of an already-loaded normal variable.
- `SaveAddOns` is a checkpoint, not a per-kill write and not a synchronous
  durability guarantee.
- `SAVED_VARIABLES_TOO_LARGE` means saved variables failed to load due to an
  out-of-memory error and will not save on the next logout. Stop normal saving
  and use the backup/compaction path.

## Strategy

### Load

- Load the account DB and the active character's SavedVariables. Other
  characters and cold companion data are not loaded.
- Tooltip needs only the hovered mob: current-zone subset plus a compact global
  identity index; do not decode all zones.
- Heatmap loads the current zone, or the selected zone after a zone switch; old
  zones are evicted unless within the LRU budget.
- Other characters are already excluded by `SavedVariablesPerCharacter`; keep
  it that way.
- A normal addon still loads all of its account and active-character variables.
  Do not add variables expecting them to defer.
- A LoadOnDemand companion is the only file-level deferral; verify its variable
  timing in V-2.
- Do not normalize/decode all heatmap zones at login; defer to the selected zone
  or the first UI view that needs it.
- Keep shared leveling knowledge aggregate-only and small, because account data
  loads for every character.

### Cache and eviction

- LRU for decoded zone blocks and normalized heatmaps; default cache is the
  current zone plus a small previous-zone allowance.
- Tooltip lookup must not force a full-zone decode if a compact identity/index
  lookup can answer it; fall back to formula/summary if the subset is absent.
- Bound cache by zone count and memory estimate, not only by time.
- Evict on tab switch, window close, or explicit clear.
- Release UI cell/art textures when the heatmap tab/window is closed or after a
  short idle timeout; keep a small reusable pool only if measurements justify it.
- Do not retain per-zone decoded tables after the active zone changes unless the
  LRU budget allows it.
- Release old level-cap archive buffers after save/checkpoint.
- A missing zone subset must not display a false zero; show a clear fallback.

### UI

- Create cells lazily; current 4,096-cell pool is a display-detail decision.
- Release or shrink the pool when the Heatmap tab is hidden.
- Release art tiles/overlay tiles when the panel is hidden.
- Avoid repeated hide/show work when collection is disabled (H64-9-F2).

### Save/checkpoint

- No per-kill disk write.
- Use `SaveAddOns` only as a checkpoint at defined boundaries. Treat logout and
  `/reload` as the normal save points.
- A zone transition may request a checkpoint, but do not assume it flushes to
  disk. Actual timing is a V-2 check.
- `ADDONS_UNLOADING: closingClient` can trigger a final checkpoint, but is not a
  guaranteed flush.
- On `SAVED_VARIABLES_TOO_LARGE`, stop normal saving, keep the previous backup,
  and run the compaction/recovery path.
- Compress/archive only at defined boundaries; release buffers after save.
- Keep a backup before destructive compaction.

### Memory budget

- Use MEM-1 real-client measurements.
- Current samples: 3.2–3.85 MB with UI open, versus ATT ~51/65 MB and FLG ~48 MB.
- Define a soft budget for idle, UI-open, dense-heatmap, and multiple-alt states
  after measurement. Do not set it from fixture memory.
- Warn in diagnostics if the active cache exceeds the budget.

## Research questions

1. What exactly is resident at login today: all zones, all mobs, all heatmaps?
2. What is the memory cost of one decoded dense zone, one sparse zone, and the
   current UI cell pool?
3. Does closing the Heatmap tab release cells/art today?
4. How many zones are actually visited and how many are cold?
5. What is the cost of normalizing all 40/200 zones versus one zone?
6. Can a LoadOnDemand companion hold cold archives without loading them at
   login? Documented as deferrable; exact variable timing is V-2.
7. How do we measure per-addon memory on Forever and Midnight?
8. What is the safe budget for a long-lived, multi-alt account?
9. What is the eviction policy for active vs previous character data?
10. What should diagnostics expose about cache size and evictions?

## Work items

- Inventory current resident roots and caches.
- Add lazy zone normalize/decode boundaries.
- Define LRU/eviction and UI release behavior.
- Integrate companion/archive loading rules.
- Add memory instrumentation to diagnostics.
- Measure idle/UI/dense/multi-alt states with MEM-1.
- Define budget and alerts.
- Document downgrade/save behavior.
- Feed DS-11/V-2.

## Deliverables

- Written load/unload policy.
- Cache/eviction rules.
- UI release rules.
- Companion loading rules.
- Memory budget and diagnostics fields.
- Test plan for lazy load/evict/reload.
- DS-11/V-2 inputs.

## Acceptance criteria

- At login, only active roots and required caches are resident.
- Cold zones/archives/companions are not decoded until needed.
- Closing the heatmap releases or bounds its UI pool.
- Repeated tab/window open/close does not grow memory unboundedly.
- A multi-alt/long-lived profile remains within the measured budget.
- Diagnostics reports cache/zone counts and memory estimate.
- No data loss on save/evict/reload.
- Live verification remains V-2.

## Risks

- Evicting too aggressively adds decode cost to UI.
- Retaining caches improves speed but can hide growth.
- Companion loading can fail or load late.
- UI texture release may not return memory to the OS immediately.
- Budget numbers from one client may not fit the other.
