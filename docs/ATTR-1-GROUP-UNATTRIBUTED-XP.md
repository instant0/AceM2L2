# ATTR-1 — Group/remote XP without kill identity

**Status:** executed 2026-11-16; tested  
**Trigger:** a group member killed something far away; the addon recorded a
`mob` kill with group XP but no identity of what died.

## Finding

`CommitUnidentifiedKill` waited for `UNIT_DIED`, then committed anyway when no
death identity arrived. With no name it used `GetMobKey(nil, nil)`, which
created `name:unknown`, incremented a fake mob/area/heatmap kill, and attached
the group XP to it.

That is wrong:

- the player gained XP;
- the player did not necessarily kill the mob;
- no mob identity was available;
- an `Unknown` mob pollutes unique-mob counts, mob lists, area/level/heatmap
  totals, and deletion cleanup.

## Decision

Identity-less kill XP is stored as a separate aggregate:

```text
character.unattributed = {
  events, xp, byLevel, byMap, lastSeen
}
```

It:

- contributes to `totals.xp` and `session.xp`;
- contributes to level-history XP and the rolling rate sample;
- does **not** create a mob entry;
- does **not** increment `totals.kills`, `uniqueMobs`, `areas`, `levels`,
  instances, or heatmaps;
- never uses a checksum or `Unknown` name as identity.

The Overview shows:

```text
Unattributed group XP: <xp> from <events> gains
```

when the bucket is non-empty.

## Implementation

- Added `unattributed` to new character data and `EnsureDB` normalization.
- Added `RecordUnattributedXP(info, totalXP, source)`.
- `CommitUnidentifiedKill` now routes no-name XP to the unattributed bucket
  instead of `RecordKill`.
- `ResetKills` clears the bucket.
- `RecordUnattributedXP` adds level-history XP and a rate sample, but not a kill.
- Overview displays the aggregate.
- Existing `name:unknown` entries from older builds can still be removed with
  `/acem2l2 xpt deleteunknown confirm`; no automatic destructive migration.

## Tests

Added a group-unnamed XP smoke case:

- group size 2;
- unnamed group XP format;
- no target/death identity;
- commit timer runs;
- asserts no mob entry, no kill count;
- asserts `totals.xp`, `unattributed.events`, `unattributed.xp`, and a rate
  sample;
- asserts aggregate invariants.

Full `./tests/run_all.sh` passes.

## Contract update

`docs/tasks/DS-1-CONSUMER-CONTRACT.md` now treats `unattributed` as a canonical
aggregate and defines:

```text
totals.xp = sum(mob.totalXP) + unattributed.xp
session.xp = sum(mob.sessionXP) + unattributed.xp
```

Kills, levels, areas, instances, and heatmaps remain identity-based and exclude
the unattributed bucket.

## Remaining

- Decide whether to expose unattributed XP by map/level in diagnostics.
- Old `name:unknown` cleanup remains manual.
- No per-kill event or fake mob is introduced.
