# SC-6 — Capacity self-assessment result

**Status:** executed 2026-11-17  
**Production modules:** `KillHistory/Module.lua`,
`KillHistory/UI/Diagnostics.lua`  
**Test:** `tests/capacity_assessment.lua`; `./tests/run_all.sh`  
**Scope:** self-measurement and bounded pressure reporting. No automatic cap
increase and no memory-based deletion.

## 1. What was added

`GetCapacityAssessment()` reports:

- highest current store/cap utilization;
- pressure: `low`, `normal`, `high`, `critical`;
- reason string naming the store and percentage;
- recommendation for high/critical states;
- Lua heap via `collectgarbage("count")` when available;
- addon memory via `C_AddOns.GetAddOnMemoryUsage` or legacy API when available;
- packed cold-block bytes;
- cache/zone counts from `GetCacheStats()`.

Diagnostics now shows:

- capacity pressure and reason;
- Lua heap;
- cold-block bytes.

## 2. Pressure model

Cap utilization is the primary signal because the engine cannot know the
client's free-memory ceiling.

| Pressure | Cap utilization |
|---|---:|
| low | < 65% |
| normal | 65–89% |
| high | 90–97% |
| critical | ≥ 98% |

Hysteresis prevents rapid oscillation:

- critical holds until below 90%;
- high holds until below 80%;
- normal holds until below 50%.

The assessment is advisory. It does **not**:

- auto-raise hard caps;
- delete data;
- treat a guessed MB number as truth;
- assume the addon-memory API exists.

## 3. Test result

`tests/capacity_assessment.lua` verifies:

- low/normal/high/critical thresholds;
- reason formatting;
- Lua heap availability;
- cold-block bytes;
- critical/high/normal hysteresis;
- diagnostics integration.

Passing output:

```text
Capacity assessment passed
```

`./tests/run_all.sh` passes.

## 4. Limitations

- Addon-memory API may be absent or client-specific.
- Lua heap is not total addon memory.
- Cap utilization is not the same as client memory pressure.
- No live calibration yet.
- The next step is to use this signal for bounded cache/context decisions, not
  to remove hard caps.

## 5. Next

**SC-4 — Context cap.**

## Artifacts

- `KillHistory/Module.lua`
- `KillHistory/UI/Diagnostics.lua`
- `tests/capacity_assessment.lua`
- `tests/run_all.sh`
- `docs/tasks/SC-6-CAPACITY-SELF-ASSESSMENT.md`
