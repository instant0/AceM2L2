# DS-17.15 — S4B instance time/death/session coverage

**Status:** executed 2026-11-18.  
**Result:** `docs/DS-17-15-S4B-INSTANCE-TIME-RESULT.md`  
**Depends on:** DS-17.14  
**Blocks:** S5 deaths  
**Source:** `docs/DS-17-14-S4-INSTANCE-OWNERSHIP-RESULT.md`

## Goal

Add per-instance time, deaths, and session coverage to `journey.instances`, and
stop new non-attributable instance events from collapsing into
`journey.zones["0"]`.

## Scope

- Track instance presence/engaged time on Journey events:
  - use the existing event-driven clock;
  - no timer/OnUpdate;
  - attribute to `journey.instances[instanceKey]`.
- Add instance death/session counters where events identify the instance.
- Route new non-attributable instance kills/time to the instance record, not
  `zones["0"]`.
- Preserve existing historical `zones["0"]` as `unassigned`; do not invent a
  per-instance split.
- Keep `db.instances` as compatibility projection.
- No block payload/UI/retirement.

## Tests

`tests/s4b_instance_time.lua`:

- per-instance presence/engaged time;
- instance death/session counters;
- non-attributable event does not add to `zones["0"]`;
- historical unassigned aggregate is labeled, not split;
- no timer/OnUpdate;
- parity for exact totals;
- idempotence;
- v2-only reads;
- no block/UI/retirement.

## Acceptance

- `journey.instances` carries time/deaths/sessions with explicit coverage.
- New non-attributable instance events do not go to `zones["0"]`.
- Historical `zones["0"]` remains explicitly unassigned.
- No invented per-instance split.
- Full suite passes.

## Not required

- death record attribution/health (S5/V-2);
- quest/respawn migration;
- block payload v2 completeness;
- legacy retirement;
- live client test.
