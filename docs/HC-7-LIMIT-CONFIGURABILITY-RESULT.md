# HC-7 — Tracking-limit configurability result

**Status:** decided 2026-11-18  
**Scope:** decision only. No production code changed.  
**Decision:** keep internal adaptive limits. Do not add player-facing cap
controls now.

## 1. Decision

**Option A — internal limits only.**

- No new settings for mobs, quests, respawns, heatmaps, deaths, rates,
  contexts, or quest anchors.
- Adaptive limits remain implementation policy.
- Diagnostics remains read-only visibility into usage and pressure.
- Revisit presets only after MEM-1 and live memory/pressure measurements.

## 2. Rationale

- SC-3 already accepted the 6× tier with adaptive mob/quest caps and explicitly
  avoided raising every cap.
- SC-6 added capacity self-assessment, but its own limitations say:
  - Lua heap is not total addon memory;
  - cap utilization is not client memory pressure;
  - there is no live calibration yet.
- MEM-1 has not produced a live client memory sample or guardrails.
- The caps interact: mobs, contexts, blocks, heatmaps, and respawn samples are
  not independent knobs.
- Presets would require trimming/migration semantics, a settings surface, and
  new tests before any measured client-memory guardrail exists.
- Diagnostics already shows:
  - tracked/limit counts for mobs, quests, deaths, respawns, heatmap zones;
  - heatmap bytes and cells;
  - block/heatmap/normalize cache usage;
  - capacity pressure, Lua heap, and cold-block bytes.

## 3. Rejected options

### Bounded presets

Deferred, not rejected forever.

Blocked by:

- no live memory guardrail;
- no defined profile values or bounds;
- no profile-switch trimming/migration policy;
- no evidence that players need lower retention rather than clearer
  diagnostics.

### Raw numeric caps

Rejected.

- Users can create oversized saves.
- Caps interact and cannot be tuned independently.
- No measured memory guardrail.
- Support burden is high.

## 4. What does not change

- Adaptive mob/quest caps.
- Respawn NPC cap of 4,000.
- Heatmap zone cap of 64 and 64×64 grid.
- Deaths 100, level records 200, rate samples 240.
- Instances 100, mob instances 20, contexts 12.
- Quest anchors 5,000.
- No new SavedVariables or settings.
- No schema or migration change.

## 5. Revisit trigger

Re-open presets only when all are true:

1. MEM-1 has a real main-character memory sample.
2. A live memory/pressure guardrail exists.
3. Profile values can be expressed as bounded internal policies, not raw caps.
4. Trimming/migration behavior is defined.
5. Diagnostics can show the active profile and current usage.

If reopened, split into:

- **HC-7A** profile design and bounds;
- **HC-7B** settings/implementation and migration tests.

## 6. Limitations

- No live client measurement in this decision.
- Diagnostics is informational, not a control surface.
- Players who want smaller saves still have manual reset/clear commands.
- The decision may change after MEM-1.

## 7. Next

**UI-5 — Heatmap zone/instance selector.**

## Artifacts

- `docs/tasks/HC-7-LIMIT-CONFIGURABILITY.md`
- `docs/HC-7-LIMIT-CONFIGURABILITY-RESULT.md`
- `docs/SC-3-TIER-DECISION-RESULT.md`
- `docs/SC-6-CAPACITY-SELF-ASSESSMENT-RESULT.md`
- `KillHistory/UI/Diagnostics.lua`
