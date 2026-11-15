# DS-3C — Long-term growth and cap pressure

**Status:** executed 2026-11-15; calculation/result  
**Purpose:** show what happens after weeks/months of normal play. The current
synthetic test was a single current-cap profile, not a long-term projection.

## Assumptions

- 100 kills/hour.
- 1, 2, 4, or 8 hours/day.
- 3, 6, or 12 months.
- 250 kills/level for leveling math.
- Unique mobs/kill = `85/762 = 0.1115`, capped at 2,000.
- No exact content census; use planning tiers.

These are planning assumptions, not measured live data.

## Kill and mob growth

| Hours/day | 3 months | 6 months | 12 months |
|---:|---:|---:|---:|
| 1 | 9,000 kills → ~1,004 mobs | 18,000 → 2,000 cap | 36,500 → 2,000 cap |
| 2 | 18,000 → 2,000 cap | 36,000 → 2,000 cap | 73,000 → 2,000 cap |
| 4 | 36,000 → 2,000 cap | 72,000 → 2,000 cap | 146,000 → 2,000 cap |
| 8 | 72,000 → 2,000 cap | 144,000 → 2,000 cap | 292,000 → 2,000 cap |

The 2,000-mob cap is reached at about **17,900 kills**. A player at 2 hours/day
hits it within roughly 3 months. A 1-hour/day player may hit it in 6 months.

## Current caps

| Store | Cap | What it means |
|---|---:|---|
| Rate samples | 240 | One sample per kill/quest. At 100 kills/hour, the buffer turns over in **2.4 hours**. |
| Mobs | 2,000 | Hit at ~17,900 kills at the measured discovery ratio. |
| Heatmap zones | 40 | Hit after visiting 40 tracked zones, not after 40 kills. |
| Instances | 100 | Hit after 100 instance records. |
| Quests | 200 | Unique quest-ledger entries. |
| Deaths | 100 | Last 100 death locations. |
| Respawn NPCs | 300 × 20 samples | Per character/client. |
| Level records | 200 | Level-up records. |
| Contexts | 12/mob | 24,000 at 2,000 mobs. |

The player observation is consistent: **rate samples at 87%** means the
240-sample rolling buffer is close to turnover. Most other stores at ~20% today
can reach their caps in months, not years.

## Findings

1. **The 23 MB DS-3B figure is a current-cap profile, not a 3-month state.**
   It says nothing about long-term growth beyond the current caps.
2. **Rate samples are a rolling buffer, not history.** 240 samples is 2.4 hours
   at 100 kills/hour. If the UI presents it as usage, label it as a rolling
   buffer. If long-term rate history is wanted, store aggregated buckets.
3. **The 2,000-mob cap is a data-loss boundary for ordinary play.** It is reached
   at ~18k kills; a 3-month, 2h/day player is already there.
4. **Heatmap/instance/quest/death caps are hit by breadth, not playtime.** A
   leveling character visiting many zones/instances will hit them.
5. **Current “20%” usage is not evidence of headroom.** It is early-life data.
6. **Capping rate samples is reasonable for a rolling calculation.** Capping raw
   history is not the same as capping the calculation; archive/aggregate instead.
7. **The storage method is not proven optimal.** DS-3B tested one layout at
   current caps; it did not compare alternative long-term layouts.

## What the design must do

- Do not rely on 2,000/40/100 as the design limit.
- Store long-term data in per-zone/level blocks with cold archives.
- Keep a dynamic hot cache; evict by measured value, not a fixed count.
- Treat rate samples as a rolling calculation buffer; store hourly/daily
  aggregates separately if history is needed.
- Archive/aggregate quests, deaths, level records, and rates instead of dropping
  them at hard caps.
- Test 3/6/12-month profiles, not only a single current-cap profile.
- Compare storage layouts under long-term profiles before declaring one optimal.

## Next work

1. DS-17.1: design for long-term and no artificial global cap.
2. DS-4P: test 3/6/12-month and beyond-cap profiles.
3. DS-17.3: rate aggregation, context collapse, cold archives.
4. DS-7/DS-12: packed cold-block benchmark.
5. DS-15/DS-16: retrieval and save policy for long-term data.
