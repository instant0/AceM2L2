# DS-17.23 — S10C live-gated retirement

**Status:** S10C-1 and V-2A harness executed; S10C-2 blocked on live evidence.  
**Results:** `docs/DS-17-23-S10C1-RETIREMENT-READINESS-RESULT.md`,
`docs/V-2A-PROBE-HARNESS-RESULT.md`  
**Depends on:** DS-17.22, V-2  
**Blocks:** IMP-1B11 final rollback retirement  
**Source:** `docs/DS-17-21-S10A-QUERY-RETIREMENT-RESULT.md`,
`docs/DS-17-22-S10B-UI-READS-RESULT.md`

## S10C split

- **S10C-1 (executed):** offline readiness inventory, live-gate blockers, v2-only
  replay checks, and restore-path reporting.
- **S10C-2 (blocked):** stop dual writes and remove legacy aggregates,
  normalizers, sync paths, fallbacks, and rollback insurance.

## S10C-1 scope

- Inventory legacy and v2 roots.
- Report live V-2 gate status.
- Report dual-write and quest-name-ledger blockers.
- Report migration-backup restore state.
- Expose readiness through diagnostics.
- Prove v2-only query/read replay while the retirement gate stays closed.
- Provide `/acem2l2 xpt v2probe` to capture V-2A API/field availability locally.

## S10C-2 goal

Stop dual writes and remove the remaining legacy aggregates, normalizers, sync
paths, fallbacks, and rollback insurance after live validation.

## Preconditions

- V-2A field probes pass.
- V-2B implemented capture validates new fields.
- V-2C save/load/oversize/companion checks pass.
- V-2D visual checks pass.
- No open P0 data-loss issue.
- Migration backup and documented restore path are in place.

## S10C-2 work

1. Stop dual-writing legacy mobs/zones/levels/instances/deaths/quests/respawns/
   heatmaps.
2. Remove legacy normalizers and sync calls.
3. Remove legacy compatibility projections and total fallbacks.
4. Retire block/index and mob-index legacy fallbacks.
5. Replace the quest-name ledger or preserve a dedicated name source.
6. Remove IMP-1B11 rollback insurance after the release gate.
7. Verify v2-only replay from schema 3 blocks.

## S10C-1 tests

`tests/v2_probe_harness.lua`:

- probe shape and unimplemented-field flags;
- local evidence capture and lookup;
- V-2A gate acceptance without unlocking retirement;
- command path.

`tests/s10c_retirement_readiness.lua`:

- legacy/v2 root inventory;
- live gate blockers;
- dual-write and quest-ledger blockers;
- restore-path reporting;
- v2-only replay while the gate stays closed;
- diagnostics readiness.

## S10C-2 tests

`tests/s10c_legacy_removal.lua`:

- save/load with all legacy roots absent;
- schema 3 block replay;
- mob/zone/instance/death/quest/respawn/heatmap reads;
- no dual-write path remains;
- rollback backup/restore before final removal;
- full offline suite.

## Acceptance

S10C-1:

- readiness is explicitly false until live gates, writes, quest names, and backup
  are cleared;
- v2-only reads replay with legacy roots absent;
- diagnostics expose the blockers.

S10C-2:

- no production read/write depends on retired legacy aggregates;
- live V-2 evidence is recorded;
- restore path is documented for the release window;
- full suite passes with legacy roots removed.

## Not in S10C

- account Knowledge/ALT production writes;
- route recommendations;
- new storage-format study.
