# DS-3B — Massive synthetic store result

**Status:** executed 2026-11-15  
**Harness:** `tests/ds3b_massive.lua`  
**Profile:** 2,000 mobs, 24,000 contexts, 40 zones × 4,096 cells, 100 instances,
other stores at caps.  
**Verdict:** the file loads and passes invariants, but the memory cost is much
higher than the old 3.7 MB sample. The capacity model overestimated the file size
and underestimated the Lua heap pressure.

## Profile

- 2,000 mobs
- 12 contexts per mob = 24,000 contexts
- 40 zones × 4,096 cells = 163,840 cells
- 100 instance records
- 200 quests
- 100 deaths
- 300 respawn NPCs × 20 interval samples
- 200 level-history records
- 240 rate samples
- 24,000 kills total: 12,000 open-world + 12,000 instance
- 2,280,000 XP

All derived summaries were populated from the canonical data. Timestamps were
recent so pruning did not shrink the profile.

## Results

### Write path

| Metric | Value |
|---|---:|
| Compact serialized bytes | **8,689,981** |
| Compact size | **8.29 MiB / 8.69 MB** |
| Client-format estimate | **9,938,701 bytes / 9.48 MiB** |
| Lua heap before | 1,786.5 KB |
| Lua heap after build/normalize | 29,425.0 KB |
| Lua heap delta before GC | **26.99 MB** |
| Lua heap stable after GC | **23.07 MB** |
| Build | 44.1 ms |
| Normalize | 116.7 ms |
| Serialize | 1,068.3 ms |
| Write | 4.1 ms |

### Fresh-process reload

| Metric | Value |
|---|---:|
| Lua heap before load | 1,786.5 KB |
| Lua heap after load/normalize | 39,200.3 KB |
| Lua heap delta before GC | **36.54 MB** |
| Lua heap stable after GC | **23.07 MB** |
| Load | 119.6 ms |
| Normalize | 105.0 ms |

The fresh-process heap includes the loaded store and the expected-data file. After
a full collection, both paths settle at **23.07 MB**. The 27–37 MB figures are
transient pre-GC measures, not the retained heap.

### Correctness

Verified after reload:

- mobs = 2,000
- kills = 24,000
- XP = 2,280,000
- open-world = 12,000
- instance = 12,000
- contexts = 24,000
- levels = total kills
- areas = open-world kills
- areaLevels = open-world kills
- instance summaries = 12,000
- instance levels = 12,000
- heatmap zones = 40
- heatmap cells = 163,840
- heatmap total = 163,840

No double count and no invented data. The file loaded in a fresh Lua process
without a constant-table/parser failure.

## Interpretation

### File size

The actual compact file is **8.69 MB**, and the client-format estimate is
**9.94 MB**. The prior structural range was 11–14 MB, so it overestimated this
profile by roughly 20–40%.

Revised file planning range for this profile:

- compact: **8–9 MB**;
- client-format estimate: **9–10 MB**.

Do not present this as an exact client file size. The client serializer is not the
offline serializer.

### Memory

The important result is the Lua heap:

- **~23 MB stable** after garbage collection;
- **~27 MB transient** after build/normalize;
- **~37 MB transient** in the fresh reload process before GC.

That is far above the 3.85 MB small-store sample, but it is below AllTheThings’
the 51–686 MB ATT reference range. It is not a problem by itself and it is **not a target ceiling**. It
is also **not a long-term state**: DS-3C shows the current caps are reached in
months. The goal is the most efficient storage/retrieval method, not fitting a
pre-set MB number. At 12 contexts and 40 dense zones, the measured current-cap
cost is 23 MB stable and 27–37 MB transient.

### Timing

Offline:

- normalize ~0.1 s;
- load ~0.12 s;
- serialize ~1.07 s.

The client's C serializer/parser may be faster, but serialize time is high enough
to matter. Do not claim live save/load numbers; V-2 must measure them.

### Contexts and cells

The file and heap confirm that the growth drivers are contexts and dense cells,
not kill count. A 24,000-kill profile and a 15,000-kill profile with the same
2,000 mobs/contexts/cells would be nearly the same size.

## What this changes

- **File estimate corrected:** 8–10 MB for the 2k/40/24k/163k profile, not
  11–14 MB.
- **Measured heap:** ~23 MB stable, 27–37 MB transient at 12 contexts.
- **No fixed MB target.** 23 MB stable is acceptable relative to the ATT 51–686 MB reference range;
  optimize only where measurements show a real cost.
- **Not a long-term result.** See `docs/DS-3C-LONG-TERM-GROWTH.md`; 2h/day
  reaches the 2,000-mob cap in ~3 months and rate samples turn over in 2.4h.
- **4/8-context variants are not yet measured.** They are an efficiency option,
  not a mandatory target.
- **200 zones were not tested.** The current normalizer caps at 40; that is a
  cold-tier/DS-4P question, not a reason to cap the design at 40.
- **Load/save are usable offline**, but serialize time and heap are real
  concerns.

## Decision

The current hot profile is technically loadable at 2,000 mobs / 24,000 contexts /
163,840 cells / 100 instances, with no parser failure and correct invariants.

At 12 contexts and 40 dense zones, the measured cost is **23 MB stable /
27–37 MB transient Lua heap** and **8–10 MB file**. These are measurements, not
targets or caps.

DS-17.1 must now decide, using DS-3C for long-term pressure:

- what context policy is efficient, not what arbitrary cap to use;
- how many zones/instances stay hot versus archived, based on measured retrieval
  and memory;
- whether 12 contexts is worth its cost versus 4/8;
- how to remove the 2,000/40/100 implementation caps as design limits;
- what cold/block format scales without an artificial element ceiling.

## Artifacts

- `tests/ds3b_massive.lua`
- `/tmp/opencode/ds3b-massive.lua`
- `/tmp/opencode/ds3b-expected.lua`
- `docs/PERFORMANCE-REVIEW.md`
- `docs/DS-17-1-CAPACITY-AND-STRATEGY.md`

No production code changed.
