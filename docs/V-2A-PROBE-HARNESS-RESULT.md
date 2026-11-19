# V-2A probe harness result

**Status:** executed 2026-11-18  
**Scope:** offline V-2A API/field probe and local evidence capture.  
**Test:** `tests/v2_probe_harness.lua`; full suite passes.

## 1. Command

```text
/acem2l2 xpt v2probe
```

Prints:

- API availability for health, buffs, group size, rested XP, map position,
  nameplates, and memory APIs;
- implemented/unimplemented V-2 field probes;
- current player health/group/map values;
- stores the V-2A probe under `journey.liveEvidence.v2a`.

## 2. Evidence behavior

- Evidence capture is local to the character.
- Capturing V-2A does not unlock retirement.
- `GetRetirementReadiness()` accepts the captured V-2A gate only.
- V-2B/C/D, legacy roots, dual writes, quest-name ledger, and backup state remain
  independent blockers.

## 3. Tests

- probe shape and unimplemented-field flags;
- evidence storage and lookup;
- readiness gate accepts V-2A only;
- capture alone cannot unlock S10C-2;
- `v2probe` command path.

Passing output:

```text
V-2A probe harness passed
...
All offline checks passed.
```

## 4. Limits

- This is not a live validation result.
- The user must run `/acem2l2 xpt v2probe` on a live client and capture the
  output.
- V-2B/C/D and S10C-2 remain blocked.

## Artifacts

- `KillHistory/V2Evidence.lua`
- `KillHistory/Retirement.lua`
- `KillHistory/Commands.lua`
- `AceM2L2.toc`
- `tests/v2_probe_harness.lua`
- `tests/run_all.sh`
