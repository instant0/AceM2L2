# DS-17.2 — Leveling/endgame modes and archive lifecycle decision

**Status:** executed 2026-11-16  
**Task:** `docs/tasks/DS-17-02-MODES-AND-LIFECYCLE.md`  
**Inputs:** DS-17.1 aggregation decision, DS-3C long-term pressure, DS-5 loading
constraints, DS-11 future.

## Decision

Use an explicit per-character lifecycle:

```text
leveling -> endgame -> new leveling generation on a level-cap increase
```

The leveling archive is created automatically at max level, but no raw data is
deleted. A one-time notice explains the switch; commands allow inspection and
manual control. Endgame data is tracked separately and never feeds leveling route
statistics.

## State model

```text
character = {
  mode = "leveling" | "endgame",
  generation = 0,
  levelCap = 60/70/80/90/...,
  levelingArchives = {
    [generation] = {
      startedAt, archivedAt, levelCap, projectID,
      state = "hot" | "warm" | "cold",
      summary = { kills, xp, uniqueMobs, zones, instances },
      archive = { zone blocks, level bands, top-N, heatmaps },
      legacy = true/false,
    },
  },
  endgame = {
    startedAt,
    totals = { kills, xp, sessions },
    zones, instances, heatmaps, economy, reputation summaries,
  },
}
```

The archive is read-only. The active mode owns writes. `totals` remains a
lifetime counter; route/leveling stats read the generation summary, not endgame
counters.

## State transitions

| From | Trigger | Action | Data |
|---|---|---|---|
| leveling | reaches max level | archive current leveling generation; set `endgame`; one-time notice | leveling detail → archive; endgame starts empty |
| leveling | manual endgame command | same, with confirmation | no deletion; archive created |
| endgame | manual leveling command | new generation only if level cap allows; otherwise view archive | old archive read-only |
| endgame | max level rises | start new leveling generation; keep old archive | old generation stays cold/read-only |
| any | new alt | new per-character lifecycle; main raw archive not loaded | account aggregates only |
| any | delete archive | explicit confirmation + backup | only that generation |

The switch is **non-destructive**. It moves detail to archive; it does not drop
history.

## Hot/warm/cold movement

At the endgame switch:

- current/recent level band → archive hot/warm summary;
- old zones/levels → cold packed zone/level blocks;
- heatmaps: 64×64 hot → 32×32 warm → 16×16 or summary cold;
- contexts: keep recent/active, collapse stale into mob/zone/class aggregates;
- rates: keep rolling buffer, archive hourly/daily aggregates;
- deaths/quests/level records: keep summaries and top-N; archive raw lists.

At a new level-cap generation:

- old endgame/leveling generation becomes cold/read-only;
- new generation starts at the new cap;
- no old generation is overwritten;
- account-wide aggregates remain separable by generation/level band.

## First-alt rule

A new alt:

- loads only its own per-character data;
- does not load the main’s raw history/archive;
- may read account-wide aggregate leveling knowledge from completed
  generations;
- gets its own mode/generation state when it reaches max level.

The main’s archive is not copied into the alt. Shared knowledge is aggregate,
confidence-scored, and project-separated.

## Endgame separation

Endgame tracks:

- current zones/instances/mobs;
- endgame heatmaps;
- reputation progress and non-XP history;
- endgame economy/activity.

It does not feed:

- leveling route statistics;
- leveling XP/hour or zone recommendations;
- leveling archive counters.

Lifetime totals may include both, but route data must select the generation.

## Commands/UI

Proposed commands:

```text
/acem2l2 xpt mode
/acem2l2 xpt mode leveling|endgame
/acem2l2 xpt archive list
/acem2l2 xpt archive show <generation>
/acem2l2 xpt archive delete <generation> confirm
```

Rules:

- `mode` is inspect-only by default;
- switching requires confirmation;
- archive list shows generation, level cap, dates, size/tier;
- archive show is read-only;
- delete requires explicit confirmation and a backup;
- one-time notice at automatic max-level switch.

## Migration

Existing characters:

- if `mode` is missing and level >= current max: create `generation 0` archive
  from current leveling data, set `endgame`, mark `legacy=true`;
- if below max: set `mode=leveling`, `generation=0`;
- if a level cap increased and mode was endgame: create a new generation;
- never overwrite an existing archive on downgrade; older builds preserve unknown
  roots.

## Interactions

- `heatmapEnabled`: archives keep stored data even when collection is off.
- Instances: endgame instance records separate from leveling archives.
- Journey: reads selected generation/zone; archive is read-only.
- Shared knowledge: derived from completed generations; no raw player identity.
- Retention: DS-17.3 chooses hot/warm/cold block boundaries; DS-9 owns migration.

## Acceptance

- Leveling and endgame route stats cannot mix.
- Max-level switch archives without deleting raw data.
- A level-cap increase creates a new generation.
- First alt never loads the main’s raw archive.
- Archive delete requires confirmation and backup.
- DS-17.3 can define hot/warm/cold movement.
- DS-9 can migrate existing max-level characters.

## Risks

- Automatic switch wording could confuse; one-time notice and `mode` command
  required.
- Archive size may grow with many level-cap generations; cold packing/retention
  from DS-17.3.
- Legacy max-level migration may create a large first archive; backup and
  tiering required.
- Shared knowledge confidence/generation weighting remains DS-17.4.
