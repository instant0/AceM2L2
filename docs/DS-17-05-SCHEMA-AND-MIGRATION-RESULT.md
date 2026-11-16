# DS-17.5 — Schema, field ownership, and migration result

**Status:** executed 2026-11-16  
**Harness:** `tests/ds17_5_schema.lua`  
**Local source:** `/mnt/r/AceM2L2.lua` (one character, project 18)  
**Scope:** offline schema/migration prototype; no production code, no merge.

## 1. Schema decisions

### Per-character Journey

The v2 Journey uses unambiguous names:

```text
journey.mobs[key]
  npcID, name, classification
  mobLevelMin, mobLevelMax, mobLevelSamples
  kills, xp, sessionKills, sessionXP, sessionXPKnown
  byPlayerLevel          -- player level at kill
  byZone[map].playerLevels
  byInstance[key].playerLevels
  zones                  -- <=4 refs
  contexts               -- array/list, not a keyed map
  combat                 -- combat contexts (danger)
  xpContexts             -- XP contexts
  presenceSeconds        -- event-driven wall-clock
  engagedSeconds         -- event-driven capped kill/XP time
  firstSeen, lastSeen
  respawn

journey.zones[map]
  kills, killXP, questXP, otherXP, xp
  presenceSeconds, engagedSeconds, deaths, sessions, uniqueMobs
  playerLevels

journey.instances[key]
  kills, killXP, questXP, otherXP, xp
  presenceSeconds, engagedSeconds, deaths, sessions, uniqueMobs
  playerLevels

journey.levels[playerLevel]
  kills, killXP, questXP, otherXP, xp
  presenceSeconds, engagedSeconds, deaths, startedAt, endedAt

journey.sessions, heatmaps, deaths, quests (lastTurnInAt/mapID/playerLevel), respawns
```

### Critical naming fix

The current field `killsAtLevel` means **player level**, not mob level.

The v2 schema renames it to `byPlayerLevel`. Similarly:

- `killsByAreaLevel` → `byZone[...].playerLevels`
- `killsByInstanceLevel` → `byInstance[...].playerLevels`

Mob level range is separate: `mobLevelMin`/`mobLevelMax`.

This avoids a serious future bug where player level and mob level are confused.

### Context storage

- `contexts` is an **array/list**, not a string-keyed map.
- Cold retention: top-8 contexts + `other` aggregate from DS-17.4C.
- Packed cold records.
- No per-kill log.

### Account-wide Knowledge target

Defined but empty; no merge implemented:

```text
knowledge.schema, projectID, interface, levelCap, mode
knowledge.mobs
knowledge.zones
knowledge.instances
knowledge.heatmaps
knowledge.quests
```

### Heatmap

- 64×64 hot.
- 32/16 cold.
- Top-N hotspot summary retained separately.
- Sparse normal density 0.5–5%; 15–30% stress only.

## 2. Migration mapping

| Current v1 | v2 Journey |
|---|---|
| `clients[project].mobs` | `journey.mobs` |
| `mob.killsAtLevel` | `mob.byPlayerLevel` |
| `mob.killsByMap` | `mob.byZone[map].kills` |
| `mob.killsByAreaLevel` | `mob.byZone[map].playerLevels` |
| `mob.killsByInstance` | `mob.byInstance[key].kills` |
| `mob.killsByInstanceLevel` | `mob.byInstance[key].playerLevels` |
| `mob.contexts` keyed map | `mob.contexts` array |
| `mob.totalXP` | `mob.xp` |
| `areas` | `journey.zones` |
| `areaLevels` | `journey.zones[map].playerLevels` |
| `instances` | `journey.instances` |
| `levels` | `journey.levels[level].kills` |
| `levelHistory` | `journey.levels[level].xp/presenceSeconds/startedAt/endedAt`; `engagedSeconds=0` |
| `heatmaps.cells[cell] = count` | `cells[cell] = { kills = count, xp = 0, presenceSeconds = 0, engagedSeconds = 0 }` |
| `deaths` | `journey.deaths` with missing attribution/health defaults |
| `quests` | `journey.quests`; add `lastTurnInAt`, `mapID`, `playerLevel` |
| `respawns` | `journey.respawns` |
| `session` | one `journey.sessions` record |
| `totals` | `totals` |

## 3. Migration result

Local save migration:

```text
migrated_schema=2
project=18
migration_ms=1.2
v2_heap_mb=0.55
```

Counts:

| Item | Source | Target |
|---|---:|---:|
| Mobs | 158 | 158 |
| Zones | 4 | 4 |
| Instances | 3 | 3 |
| Deaths | 16 | 16 |
| Quests | 38 | 38 |
| Respawns | 69 | 69 |
| Heatmap cells | 385 | 385 |
| Mob kills | 1,993 | 1,993 |
| Mob XP | 152,816 | 152,816 |

Validation:

- idempotent migration: **yes**;
- schema 2 accepted: **yes**;
- schema 3 rejected by current build: **yes**;
- no zone overflow in the local sample: **yes**;
- mob level range known: **1 / 158** (only one context).

## 4. Missing data after migration

The migration cannot invent fields the current save does not have:

- `presenceSeconds`/`engagedSeconds` per zone/level/instance;
- kill/quest/other XP split per zone/level/instance;
- combat contexts (danger);
- XP contexts;
- death mob attribution;
- death health/buffs/group/difficulty;
- heatmap cell XP/time;
- character class/race/faction context.

These must be filled by future capture/API work, not by migration.

## 5. Backup and downgrade

- Backup is required before destructive migration.
- A newer schema must be rejected/read-only; it must not be overwritten.
- Migration is idempotent.
- Unknown fields must be preserved or backed up, not silently dropped.
- Packed archives need a plain fallback.

## 6. Findings

1. **The schema is now explicit about player level vs mob level.** This was a real ambiguity in v1.
2. **Migration preserves all existing counts and totals.**
3. **The local save can migrate without data loss**, but it cannot provide the new danger/XP-hour data.
4. **Only 1/158 mobs has a known mob level range.** Future capture must store mob level at sighting.
5. **Contexts must be arrays for cold storage.**
6. **Account Knowledge is defined but not populated.**
7. **No merge implementation.**
8. **No production code changed.**
9. **No online source used.**

## 7. Decisions

- Adopt v2 Journey schema with:
  - `byPlayerLevel`;
  - `mobLevelMin`/`mobLevelMax`;
  - array contexts;
  - combat/XP contexts;
  - `presenceSeconds`/`engagedSeconds` (event-driven, no timer);
  - `killXP`/`questXP`/`otherXP` split;
  - death attribution/health/buffs/group fields;
  - heatmap cell XP/time optional;
  - top-8+other cold retention;
  - 64×64 hot / 32/16 cold + top-N hotspot.
- Account Knowledge target remains derived and empty.
- Migration is versioned, idempotent, backed up, and downgrade-safe.
- No merge now.
- No UI now.

## 8. Required follow-ups

- **DS-16** — save/checkpoint policy for the v2 Journey.
- **DS-15** — retrieval using v2 fields, top-8+other, top-N hotspots.
- **V-2** — capture killer, health, buffs, group, event-driven time, mob level, cell XP/time.
- **DS-17.4D** — account Knowledge prototype later.
- **DS-11** — final decision.

## Acceptance

- Schema and field ownership defined: **yes**.
- Migration preserves counts/totals: **yes**.
- Idempotent: **yes**.
- Backup/downgrade rules defined: **yes**.
- Account Knowledge target defined: **yes**.
- No merge implemented: **yes**.
- No production code/online: **yes**.

## Artifacts

- `tests/ds17_5_schema.lua`
- `docs/DATA-MODEL-AND-TEST-MATRIX.md`
- `docs/DATA-MODEL-PLAN.md`
- `docs/tasks/DS-17-05-SCHEMA-AND-MIGRATION.md`
