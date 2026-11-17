# SC-6 — Capacity self-assessment

**Status:** executed 2026-11-17  
**Result:** `docs/SC-6-CAPACITY-SELF-ASSESSMENT-RESULT.md`  
**Harness:** `tests/capacity_assessment.lua`  
**Depends on:** SC-3, MEM-1, MEM-2  
**Blocks:** adaptive retention/eviction, later limit tuning

## Why

The client does not expose a reliable “is this too much?” answer. A fixed MB
target is also wrong. The engine can still measure its own footprint and make
bounded decisions.

## What can be measured

- own counts and cap utilization;
- estimated/serialized bytes;
- block bytes and cache counts;
- `collectgarbage("count")` Lua heap;
- `C_AddOns.GetAddOnMemoryUsage` / legacy API when available;
- operation timing (`debugprofilestop`, `GetTime`) around decode/encode/build;
- `SAVED_VARIABLES_TOO_LARGE` as a failure signal.

## What cannot be known

- the client’s free memory ceiling;
- other addons’ future footprint;
- a universal safe MB target;
- exactly how much the client can handle before failure.

## Design

1. Add `GetCapacityAssessment()`:
   - counts vs caps;
   - bytes by major store where cheap;
   - Lua heap;
   - addon memory if available;
   - cache pressure;
   - current pressure: `low`, `normal`, `high`, `critical`.
2. Keep hard caps as safety rails.
3. Allow soft adaptation only inside hard caps:
   - cache size/eviction;
   - pruning aggressiveness;
   - heatmap display/downsample choices;
   - no automatic deletion of unique user records.
4. Add hysteresis so pressure does not oscillate.
5. Expose pressure/reasons in diagnostics.
6. Test unavailable APIs and deterministic pressure transitions.

## Non-goals

- removing hard caps;
- auto-raising caps without limit;
- using a guessed MB target;
- deleting user data based on memory alone.

## Acceptance

- Self-assessment works with and without memory APIs.
- Pressure is explainable, not a magic number.
- Hard caps remain.
- Tests cover low/normal/high/critical and hysteresis.
- No data loss.

## Not required

- live client calibration;
- schema change;
- account Knowledge/merge.
