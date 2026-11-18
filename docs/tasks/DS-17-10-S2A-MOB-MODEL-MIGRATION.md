# DS-17.10 — S2A mob model migration

**Status:** executed 2026-11-18; kill/backfill path done; mutation parity next.  
**Result:** `docs/DS-17-10-S2A-MOB-MODEL-RESULT.md`  
**Simulation result:** `docs/DS-17-10-S2A-MIGRATION-SIM-RESULT.md`  
**Depends on:** DS-17.9  
**Blocks:** S2B contexts, S3 zone/level ownership  
**Source:** `docs/DS-17-07-DATA-MODEL-RECONCILIATION-RESULT.md`

## Goal

Make `journey.mobs` the canonical v2 owner for mob identity, counts, XP, and
player-level/zone/instance subcounts.

Legacy `db.mobs` is a **migration input and temporary compatibility projection**,
not a second authority. The fallback is removed once parity passes.

## Parity is a gate, not a permanent fallback

The fallback exists only to avoid data loss during the ownership switch. It must
be:

- explicit (`source = "legacy"` / `"v2"`);
- observable (fallback hit counter/diagnostic);
- tested against a pre-migration snapshot;
- removed when parity passes.

Parity criteria:

- same mob identity set;
- same kills and XP;
- same player-level counts;
- same zone and instance counts;
- same first/last seen;
- no double counting;
- idempotent migration;
- no legacy mutation from v2-only operations.

If parity fails, fix v2 and keep the fallback only for the failing field. If parity
passes, switch `JourneyModel` to **v2-first** and remove the legacy fallback for
mob fields.

## Migration shape

1. **Backfill once**
   - read `db.mobs`;
   - build `journey.mobs`;
   - mark migration complete/idempotent.
2. **V2 canonical writes**
   - new kill/sighting updates `journey.mobs` first;
   - update `db.mobs` only as a compatibility projection for current readers;
   - do not independently mutate both stores.
3. **Parity gate**
   - compare v2 against the pre-migration snapshot and current legacy projection;
   - record fallback hits;
   - switch helper order to v2-first only after pass.
4. **Remove fallback**
   - delete legacy fallback for mob fields;
   - add a test that removes `db.mobs` and still reads mob data from v2;
   - keep legacy tables for other domains until their slices.

## Scope

- Write a v2 mob record on kill/sighting:
  - `npcID`, name, classification;
  - `kills`, `xp`;
  - `mobLevelMin`, `mobLevelMax`, `mobLevelSamples`;
  - `byPlayerLevel`;
  - `byZone[map].kills/playerLevels`;
  - `byInstance[key].kills/playerLevels`;
  - `firstSeen`, `lastSeen`.
- Backfill existing `db.mobs` into `journey.mobs`.
- Keep `db.mobs` as a compatibility projection until S3/retirement.
- Preserve `totalXP`/`mob.xp` semantics: v2 `xp` is scalar; observation
  statistics remain separate (`xpStats`).
- No contexts-array change; that is S2B.
- No block payload v2 change; that is S8.

## Simulation gate

`tests/s2a_migration_sim.lua` is already passing:

- legacy mobs -> new v2 file;
- file round-trip;
- parity vs legacy snapshot;
- v2-only reads with `db.mobs` removed;
- idempotence.

Production S2A must keep this green before and after the writer switch. The
simulation does not replace the production writer/backfill tests.

## Required tests

`tests/s2a_mob_model.lua`:

- new kill writes v2 and projects legacy;
- legacy backfill creates equivalent v2 records;
- parity for kills/XP/player-level/zone/instance;
- duplicate/name-only identity behavior;
- migration idempotence and re-run;
- no double counting;
- fallback hit count is zero after the v2-first switch;
- deleting `db.mobs` still reads mob data from v2;
- no change to contexts/blocks.

## Acceptance

- `journey.mobs` is populated and canonical for the listed fields.
- `db.mobs` is a compatibility projection, not an independent authority.
- `JourneyModel:GetModelMob` is v2-first for migrated mobs after parity.
- Legacy fallback for mobs is removed; a test proves v2-only reads.
- Parity tests pass; full suite passes.
- No legacy retirement, block payload change, or UI switch.
- No account Knowledge/ALT work.

## Not required

- context array/top-8;
- death/quest/respawn migration;
- block payload v2 completeness;
- legacy retirement;
- live client test.
