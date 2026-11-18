# HC-7 — Tracking-limit configurability decision

**Status:** executed 2026-11-18; decision only.  
**Result:** `docs/HC-7-LIMIT-CONFIGURABILITY-RESULT.md`  
**Depends on:** SC-1, SC-2, SC-3, SC-4, SC-6, G-1B  
**Blocks:** any settings/UI implementation (separate task if approved)

## Why

The 6× tier is accepted, but the caps are internal adaptive values:

- mobs: `min(12,000, max(2,000, visitedZones * 500))`;
- quests: `min(10,000, max(500, visitedZones * 100))`;
- respawn NPCs: `4,000`;
- heatmap zones: `64`;
- deaths: `100`;
- level records: `200`;
- rate samples: `240`;
- instances: `100`;
- mob instances: `20`;
- contexts: `12`;
- quest anchors: `5,000`.

Exposing raw caps would invite unsafe values and a confusing settings page.
HC-7 decides whether players get any control at all, and if so, at what level of
abstraction.

## Evidence

- SC-3 accepted the 6× tier with adaptive mob/quest caps and did not raise every
  cap.
- SC-6 added capacity self-assessment, but the result explicitly says Lua heap
  is not total addon memory and cap utilization is not client memory pressure.
- MEM-1 has not produced a live client memory sample or guardrails.
- Diagnostics already shows tracked/limit counts, heatmap bytes, cache usage,
  capacity pressure, Lua heap, and cold-block bytes.
- Presets would need trimming/migration semantics and a settings surface before
  any measured client-memory guardrail exists.

## Recommendation

**Keep internal adaptive limits. Do not add player-facing cap controls now.**

This is Option A. Diagnostics already gives read-only visibility. Revisit
presets only after MEM-1 and live V-1/V-2 measurements exist.

## Options

### A. Keep internal limits only

- No new setting.
- Adaptive values remain implementation policy.
- Safest and smallest.

### B. Expose bounded presets

Example profiles:

- **Compact** — lower history retention for small saves;
- **Balanced** — current defaults;
- **Large** — higher retention within measured ceilings.

The player never enters raw numbers. Presets map to validated internal values.

### C. Expose raw numeric caps

Rejected for now:

- users can create oversized saves;
- caps interact (mobs, contexts, blocks, heatmaps);
- no measured memory guardrail yet;
- support burden is high.

## Decision questions

Answered by this task:

1. Is any player-facing control justified after SC-3/SC-6?
   **No, not before a live memory guardrail.**
2. If yes, presets or raw caps?
   **Neither now.**
3. Which stores are included?
   **Not applicable; keep the existing adaptive limits.**
4. Default profile and allowed bounds?
   **Not applicable.**
5. Settings location?
   **Not applicable. Diagnostics remains read-only.**
6. Migration behavior when switching profiles?
   **Not applicable.**
7. What diagnostics explain active limits and usage?
   **Existing Diagnostics already shows counts/limits and pressure.**
8. What tests cover bounds/migration?
   **Existing limit-tier and capacity tests; no new setting tests.**

## Constraints

- no arbitrary MB cap;
- use measured pressure and hard safety ceilings;
- per-character Journey remains primary;
- no account-wide Knowledge setting here;
- no exposing raw 6× caps without a guardrail;
- no new per-kill storage.

## Output

- decision table with rationale;
- if presets are approved, exact profile values and bounds;
- migration/trimming behavior;
- test plan;
- separate implementation task if code is approved.

## Acceptance

- Decision is explicit: no control, presets, or raw caps.
- If no control: record why the adaptive limits are sufficient.
- Revisit trigger is named: MEM-1 plus live memory/pressure measurements.
- No production code in HC-7.

## Not required

- settings UI implementation;
- live client test;
- account Knowledge;
- per-kill storage;
- grid changes.
