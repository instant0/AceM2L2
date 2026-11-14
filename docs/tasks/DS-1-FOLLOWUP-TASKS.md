# DS-1 follow-up tasks

Source: `docs/tasks/DS-1-CONSUMER-CONTRACT.md`  
Purpose: turn the quality-pass findings into bounded tasks.

## DS-1-F1 — Canonical versus derived ownership

**Priority:** high  
**Depends on:** DS-1  
**Blocks:** DS-4, DS-17.1

Decide whether these remain stored or are rebuilt on demand:

- `areas`
- `levels`
- `areaLevels`
- `dungeon` aggregate
- `calibration` ratios

Required output: a field-ownership table with canonical source, derived cache,
rebuild cost, and migration impact.

Acceptance:

- no stored field is an unexplained duplicate;
- derived views have a rebuild path and fallback;
- totals and invariants remain correct;
- DS-4 can prototype without duplicate ambiguity.

## DS-1-F2 — Zone-scoped identity and query index

**Priority:** high  
**Depends on:** DS-1  
**Blocks:** DS-15, MEM-2, DS-4

Define the compact indexes needed for on-demand loading:

- NPC ID → mob key;
- normalized name → unique NPC/mob key (ambiguity handling);
- zone/instance → mob keys, many-to-many;
- heatmap zone key → stored block.

A mob can appear in several zones and instances. The zone index must contain the
same mob key in multiple sets; it must not force one zone per mob. Zone lists must
use `killsByMap[mapID]` for the row count, not the global mob total.

Acceptance:

- tooltip lookup does not scan all mobs;
- name-only fallback is bounded, reports ambiguity, and does not merge
  same-name mobs across zones without an NPC ID;
- current-zone mob list is possible without global decode;
- a mob can appear in multiple zone/instance index sets;
- zone rows show per-zone counts;
- missing indexes have a defined fallback.

## DS-1-F3 — Instance/area separation and count rules

**Priority:** high  
**Depends on:** DS-1  
**Blocks:** DS-4, Areas UI work

Formalize:

- open-world kills go to `areas`/`killsByMap`;
- instance kills go to `instances`/`killsByInstance`;
- instance kills are not counted again in `areas`;
- PvP/arena instance records do not increment PvE dungeon totals;
- Areas UI shows one row per zone or instance.

Acceptance:

- no double counting in totals, lists, or diagnostics;
- legacy world-map records remain unattributed instances;
- tests cover open-world, PvE instance, and PvP instance.

## DS-1-F4 — Missing-subset and archive fallback

**Priority:** medium  
**Depends on:** DS-1, DS-15, MEM-2  
**Blocks:** DS-4

Define behavior when a zone, mob, or archive is not loaded:

- tooltip fallback to formula/global summary;
- heatmap disabled/unloaded state;
- list “not loaded” vs “no data” distinction;
- archive lazy-load state and errors;
- diagnostics count-only fallback.

Acceptance:

- no consumer displays a false zero for an unloaded subset;
- every fallback has user-visible wording;
- tests simulate missing subsets.

## DS-1-F5 — Diagnostics count-only access

**Priority:** low/medium  
**Depends on:** DS-1, MEM-2  
**Blocks:** DS-16, V-2

Define count/size diagnostics that do not decode every zone/archive:

- stored zone/instance/mob counts;
- raw bytes or table counts without normalization;
- collection on/off state;
- estimate truncation;
- cache/eviction counters.

Acceptance:

- diagnostics can report without fully loading all data;
- partial estimates are labeled;
- no diagnostic forces archive decode.

## Sequencing

1. F1 ownership.
2. F2 indexes.
3. F3 instance/area rules.
4. F4 fallback.
5. F5 diagnostics.

These feed DS-4 and DS-17.1; they do not authorize schema implementation before
DS-11.
