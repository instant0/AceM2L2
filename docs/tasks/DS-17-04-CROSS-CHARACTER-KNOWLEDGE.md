# DS-17.4 — Cross-character leveling knowledge and route recommendations

**Status:** research/design task, not implemented  
**Parent:** DS-17  
**Depends on:** DS-17.1, DS-17.2, DS-17.3  
**Blocks:** DS-17.5, DS-17.6

## Purpose

Let a level-1 character use aggregate data from the player's own prior
characters for two related goals:

1. **Knowledge:** expected XP/kill, kills/hour, time-to-level, best zones and
   instances, top mobs, and instance value by level band.
2. **Route recommendation:** when enough data exists, propose an efficient
   leveling route from level 1 to max level.

The route is a **plan**, not a claim of absolute best. It must show expected
value, confidence, and alternatives, and must fall back gracefully when the
sample is too small.

## Scope

Account-wide, local-only, aggregate knowledge. It belongs in the account
SavedVariables root, kept small because that root loads for every character;
raw history stays in the per-character root. See the root/scope matrix in
`docs/STORAGE-DIRECTION.md`.

- XP/kill by level band and zone;
- kills/hour / time-to-level;
- best zones and instances for a band;
- top mobs by zone;
- instance XP/time;
- confidence and sample counts;
- derived route candidates and their expected value.

## Route recommendation goal

### Route granularity

A route is an ordered sequence of level bands, zones, and optional instances,
for example:

```text
1–10  Zone A (grind/quest mix)
10–15 Zone B
15–20 Instance C + Zone D
...
```

It is **not** turn-by-turn navigation. The first version should recommend
“what to do next at this level,” not a GPS path.

### Inputs and constraints

- current character level;
- faction and class/role, if available;
- max level and client/project;
- XP buffs, rested state, and group size;
- preference: questing, grinding, instances, or balanced;
- risk tolerance: deaths/elite density;
- time budget;
- travel tolerance;
- optional: “avoid this zone/instance.”

### Outputs

- recommended next zone/instance and level range;
- expected XP/hour or time-to-level;
- expected kills and mob mix;
- confidence and sample count;
- alternatives with trade-offs;
- “why” summary: data source count, recency, variance;
- explicit “not enough data” state with fallback to the character's own history
  or generic guidance.

### Candidate scoring research

Evaluate a small, explainable model before anything complex:

- zone/instance score = weighted XP/kill × kills/hour × level-fit ×
  sample-confidence × recency;
- penalties for travel, deaths, elite density, and poor sample coverage;
- class/faction/gear adjustments only if data is sufficient;
- smoothing/shrinkage so one lucky character does not dominate;
- route selection over level bands using a greedy/beam search or constrained
  shortest path;
- compare with a simple “best zone per band” baseline.

Do not use a black-box model that cannot explain its recommendation.

### Data sufficiency

The route must be gated by explicit thresholds, for example:

- minimum source characters per band;
- minimum samples per zone/instance;
- minimum time coverage;
- maximum age;
- variance/confidence threshold;
- class/faction coverage warning.

Exact thresholds are research outputs, not guesses. If the threshold is not
met, show “insufficient data” and do not present the route as authoritative.

### Backtesting

- Hold out one character’s leveling history.
- Build knowledge from the others.
- Compare the recommended route’s predicted XP/hour/time with the held-out
  character’s actual result.
- Test 1/3/5 source characters.
- Record prediction error and confidence calibration.
- Test sparse, dense, and class-mismatched profiles.

## Research questions

1. Which fields can be shared without exposing raw player history?
2. Should the unit be level bands (1–10, 11–20, …) or exact levels?
3. How should confidence be computed from sample count, source-character count,
   variance, recency, and class/faction coverage?
4. How are Forever and Midnight kept separate?
5. How are level-cap generations separated (pre/post expansion)?
6. Should knowledge be rebuilt from archives or stored as a derived cache?
7. What happens when a source character/archive is deleted?
8. How many alts/samples are needed before a route recommendation is meaningful?
9. Should shared knowledge include mob names/NPC IDs or only zone-level stats?
10. What query APIs/UI does a new character need?
11. What privacy/clearance controls are required?
12. How stale is too stale?
13. What exactly is “efficient” for the route: XP/hour, time-to-level, deaths,
    travel, fun/preference, or a weighted combination?
14. Can the current `rates`, `levelHistory`, instances, and zone data estimate
    time and XP/hour without per-kill records?
15. Do we need travel/downtime/quest-completion observations that the current
    schema does not store?
16. How should class, faction, gear, rested, buffs, and group size affect the
    recommendation or the confidence?
17. How do we prevent overfitting to one route or one character?
18. How should the UI explain uncertainty and missing data?

## Schema sketch

```lua
levelingKnowledge = {
  version = 1,
  projectID = 1,
  maxLevel = 90,
  updatedAt = 0,
  bands = {
    ["1-10"] = {
      sampleCharacters = 3,
      zones = {
        [mapID] = {
          kills = 0, xp = 0, samples = 0, timeSeconds = 0,
          deaths = 0, confidence = 0, lastUpdated = 0,
        },
      },
      instances = {
        [instanceKey] = {
          kills = 0, xp = 0, samples = 0, timeSeconds = 0,
          deaths = 0, confidence = 0,
        },
      },
      mobs = {
        [npcID or nameKey] = { name = "Mob", kills = 0, xp = 0, samples = 0 },
      },
    },
  },
  -- Optional aggregate transitions, never raw kill timestamps.
  routeObservations = {
    version = 1,
    transitions = {
      [fromMapOrInstanceKey] = {
        [toMapOrInstanceKey] = {
          samples = 0, timeSeconds = 0, lastUpdated = 0,
        },
      },
    },
  },
}
```

Route candidates themselves should be **derived at query time** and cached
separately; they are not player history.

## Work items

- Define the shared field set and exclusion list.
- Define confidence, staleness, and minimum-sample thresholds.
- Define client/level-cap separation.
- Define rebuild vs cache strategy.
- Define source-character deletion behavior.
- Define query APIs/UI.
- Define privacy/clear controls.
- Define route granularity and scoring model.
- Identify missing observations (travel, downtime, quest completion, deaths).
- Build a route-recommendation prototype from synthetic aggregates.
- Backtest with held-out characters.
- Coordinate with DS-9 retention and DS-11 decision.

## Deliverables

- Shared-knowledge schema.
- Confidence/staleness rules and sufficiency thresholds.
- Privacy/exclusion list.
- Query/UI specification.
- Route recommendation specification.
- Prototype and backtest report.
- Rebuild and deletion behavior.
- Inputs for DS-17.5, DS-17.6, and DS-11.

## Acceptance criteria

- No raw player names, GUIDs, timestamps, or private session data are shared.
- Forever/Midnight and level-cap generations cannot mix.
- A new character can query useful summaries.
- When data is insufficient, the UI says so and does not present a confident
  route.
- When data is sufficient, the route shows expected value, confidence,
  alternatives, and data basis.
- The route model is explainable and backtested against held-out characters.
- Removing a source archive has a defined effect.
- Shared data is optional and clearable.
- The schema is separable from per-character raw data.

## Risks

- Aggregates from one character may be misleading for another class/route.
- Sparse data can produce confident-looking but wrong routes.
- Survivorship bias: only completed routes are represented.
- Travel/downtime/quest data may be missing, making XP/hour estimates optimistic.
- Class/faction/gear differences may dominate zone choice.
- Route recommendations can become stale after class or content changes.
- Mob identity may be unstable across clients.
- Shared data could grow unbounded if every band/zone/mob is stored.
- Privacy expectations may require opt-out.
