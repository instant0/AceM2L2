# HIST-1 — Historical/outleveled character value and relevance model

**Status:** HIST-1A executed 2026-11-17; HIST-1B next  
**Result:** `docs/HIST-1A-HISTORICAL-RELEVANCE-RESULT.md`  
**Harness:** `tests/historical_relevance.lua`  
**Depends on:** SC-4, SC-5, DS-17.4C, IMP-1B10  
**Related:** heatmap, deaths, respawns, quests, account Knowledge

## Why

The 120-day context expiry only removes exact XP calibration detail. It does not
remove kill totals, maps, heatmaps, deaths, or quest anchors. That is the right
boundary: an outleveled character usually wants **history and place**, not stale
XP advice.

The addon currently shows active-level information in tooltips and Detail. It
needs a relevance model so old/outleveled content shows:

- where the character was most active;
- what they killed;
- notable deaths;
- rares;
- journey/quest anchors;
- **not** XP estimates, kills-to-level, or context XP.

## Player scenarios

### 1. Active leveler

- Player level within the content band.
- Recent activity.
- Wants XP estimate, kills-to-level, best zone, context calibration.

### 2. Returning same character, outleveled

- Player level well above the zone/mob level.
- Last activity may be months old.
- Wants historic heatmap, kill counts, notable deaths, rares, quest journey.
- Does not want XP/hour, XP remaining, or context XP.

### 3. New alt on the same account

- No per-character history yet.
- May benefit from later account Knowledge.
- Must not inherit the old character's exact contexts as if they were current.

### 4. Completionist/explorer

- May be at any level.
- Wants zone coverage, rare sightings, deaths, and quest locations.
- XP may be irrelevant even at level.

### 5. Endgame/archived character

- Content is long outleveled.
- Wants counts, reputation/non-XP history, journey, and heatmap.
- No XP claims.

## Relevance rules

Proposed classification:

```text
active      = player level is within the content band (+ small grace)
historical  = player level above the content band + grace
archived    = old/outleveled and outside normal play
```

Age alone should not decide relevance. A level-60 character in a level-10 zone
is historical even if they were there yesterday. A level-15 character returning
after 120 days may still want XP information.

### Tooltip behavior

| Mode | Show |
|---|---|
| active | kills, level, XP estimate, kills-to-level, context XP |
| historical | kills, classification, rare flag, first/last seen, zones |
| historical | **omit** XP estimate, kills-to-level, context XP |
| unavailable | no false zero; show unavailable |

### Detail behavior

Historical Detail should prioritize:

- total kills;
- first/last seen;
- mob level range;
- zones/instances;
- rare classification;
- deaths in that zone;
- quest anchors in that zone;
- link/reminder for heatmap and `/xpt` commands.

## Data available today

- `db.mobs`: kills, classification, killsAtLevel, killsByMap,
  killsByInstance, first/last seen.
- `journey.zones` / `journey.levels`: kills, XP split, presence/engaged time.
- `db.heatmaps`: per-zone cells, total, lastSeen.
- `db.deaths`: last 100 death locations.
- `db.respawns`: NPC respawn intervals.
- `db.quests`: aggregate gains/XP, last map/level/timestamp.

## Data gaps

### Quest completion history
Current quest data keeps only the **last** turn-in anchor. To show a timestamped
quest journey, add a bounded sparse log, for example:

```text
journey.questAnchors = {
  { questID, mapID, x, y, at, playerLevel, xp },
  ...
}
```

- sparse, not per-kill;
- bounded by count and age;
- one record per turn-in;
- no quest text duplication;
- no full quest database.

### Rares
Classification already includes rare/rareelite/worldboss and is stored in
blocks. Historical views can filter by it; no new static rare DB is required.

### Deaths
The current 100-death recency cap may be too small for a historic “notable
deaths” view. Consider a larger cold death summary or a per-zone top-N.

### Heatmap time
Heatmaps currently store total cells and lastSeen, not per-kill timestamps.
That is sufficient for “where was I most active?” Do not add per-kill times.

## Proposed UI

- Historical badge/mode in tooltip and Detail.
- Zone history view:
  - heatmap;
  - top mobs;
  - notable deaths;
  - rares;
  - quest anchors.
- No XP claims in historical mode.
- Mouseover still shows the kill count for the mob type.

## Retention policy

- Context age expiry remains calibration-only.
- Aggregate zone/level/mob totals are retained.
- Historical mode reads summaries/hot data first; cold blocks only on demand.
- No per-kill timestamps.
- Account Knowledge remains future work and must use aggregates, not expired
  exact contexts.

## Phases

1. **HIST-1A — Relevance classifier and historical tooltip/Detail.**
2. **HIST-1B — Historical zone surfaces** (heatmap, deaths, rares).
3. **HIST-1C — Bounded quest-anchor log** (if approved).
4. **HIST-1D — Account Knowledge integration** later.

## Acceptance

- Outleveled mobs/zones show history, not stale XP.
- Active content keeps current tooltip behavior.
- No false XP or false zero.
- Quest-anchor log is bounded and sparse.
- Rare/death/heatmap history is visible.
- No per-kill timestamp log.
- No schema change until each phase is approved.

## Not required

- live client test;
- quest database copy;
- account Knowledge implementation;
- route recommendation.
