# Data model plan — Journey, account-wide Knowledge, storage, and retrieval

**Status:** authoritative working plan; documented 2026-11-16  
**Scope:** local SavedVariables only. No uploads, no external sharing, no privacy
layer. “Account-wide” means the same player’s characters on the same computer.  
**Primary asset:** the per-character Journey.  
**Future target:** derived account-wide Knowledge for the player’s own alts.

## 1. Do we need more broad storage analysis?

**No.** The broad storage-format question has enough evidence:

| Finding | Evidence |
|---|---|
| Current 2,000/40/100/12 caps are too small for long-term play | DS-1, DS-3B, DS-3C, DS-17.1 |
| A hybrid hot/cold model is required | DS-4P |
| Per-zone/instance/level blocks and selected-block decode work | DS-4P, DS-7/DS-12 |
| Packed varint/delta blocks beat plain Lua tables for cold data | DS-7/DS-12 |
| Adaptive sparse/bitset cells beat dense cells | DS-7/DS-12 |
| Per-block base64 is the right SavedVariables encoding for cold blocks | DS-7/DS-12 |
| No all-name list should be shipped; names/metadata are learned live | DS-6, DS-6-F1 |
| Mobs are localised; one fixed level range, at most 4 zone refs (assumed) | local `/mnt/r/AceM2L2.lua` + task assumption |
| Character Journey must remain per character | requirements + DS-17.2 |
| Account-wide data should be derived aggregates, not raw history | requirements + DS-17.4 |
| Danger needs combat context; best zone needs XP/hour and event-driven presence/engaged time | latest review |

The remaining work is **not another storage-medium bake-off**. It is targeted
validation of:

- the Journey schema;
- combat/XP context cardinality;
- danger outcomes;
- best-zone XP/hour;
- heatmap best-cell ranking;
- retention preserving aggregation inputs;
- schema shape (nested vs arrays vs packed);
- whether the required data is actually capturable on Forever/Midnight.

### What is settled

- Keep the character Journey in `AceM2L2CharDB`.
- Keep account-wide Knowledge as a future derived target in `AceM2L2DB`.
- Do not shrink the Journey to current caps.
- Use hot/warm/cold and packed blocks for size.
- Do not ship all names.
- Do not implement merge now.
- Do not put quest state in mob combat/XP context.
- Best zone = highest XP/hour at the current level.
- Danger = kills/deaths/health/time by comparable combat context.

## 2. Model summary

Full schemas are in `docs/DATA-MODEL-AND-TEST-MATRIX.md`.

### Per-character Journey

- Character context: project/interface, mode, level cap, class/race/faction,
  current level, playtime.
- Mob records: identity, name, level range, classification, kills/XP,
  byLevel/byMap/byInstance, combat outcomes, XP contexts, respawn summary.
- Zone records: kills, XP, presence/engaged time, deaths, sessions, unique mobs, per-level
  breakdown.
- Instance records: same, plus instance/difficulty/type.
- Level records: XP, kills, presence/engaged time, deaths, start/end.
- Sessions: enough to compute XP/hour.
- Heatmaps: 64×64 cells with kills, optional XP/time.
- Deaths: individual records with mob attribution, health, buffs, group,
  classification, instance difficulty, combat context.
- Quests: separate records; not part of mob context.
- No per-kill event log.

### Account-wide Knowledge target

Derived from Journey data later:

- stable mob metadata: name, level range, classification, ≤4 zones, respawn;
- danger aggregates by combat context;
- XP aggregates by XP context;
- zone/instance/level XP/hour aggregates;
- heatmap cell aggregates by zone/level band;
- quest XP summaries;
- confidence/sample/recency fields;
- no raw journey, no character identity, no session timeline.

## 3. Task plan

### Phase A — model validation (offline, now)

**A1. DS-17.4A — Journey/Knowledge model validation.** Done 2026-11-16.  
Result: `docs/DS-17-04A-JOURNEY-KNOWLEDGE-MODEL-RESULT.md`  
Document: `docs/tasks/DS-17-04A-JOURNEY-KNOWLEDGE-MODEL.md`

- field inventory from local save;
- combat/XP context cardinality;
- schema shape comparison;
- retention compatibility;
- account Knowledge field mapping;
- missing API/data list.

**A2. DS-17.4B — Danger and XP/hour prototypes.** Done 2026-11-16.  
Result: `docs/DS-17-04B-DANGER-AND-XP-HOUR-RESULT.md`  
Document: `docs/tasks/DS-17-04B-DANGER-AND-XP-HOUR.md`

- danger outcomes: kills/deaths/health/time by context;
- confidence and sparse-data behavior;
- best-zone XP/hour ranking;
- heatmap best-cell ranking;
- group/rested/buff effects;
- no UI.

**A3. DS-17.4C — Retention and aggregation compatibility.** Done 2026-11-16.  
Result: `docs/DS-17-04C-RETENTION-MERGE-COMPATIBILITY-RESULT.md`  
Document: `docs/tasks/DS-17-04C-RETENTION-MERGE-COMPATIBILITY.md`

- cold archive preserves byLevel/byMap/byInstance, contexts, presence/engaged time,
  deaths, heatmap cells;
- verify Knowledge can be derived from cold data;
- schema shape final choice;
- no merge implementation.

### Phase B — schema and migration

**B1. DS-17.5 — Schema, field ownership, and migration.** Done 2026-11-16.  
Result: `docs/DS-17-05-SCHEMA-AND-MIGRATION-RESULT.md`  
Document: `docs/tasks/DS-17-05-SCHEMA-AND-MIGRATION.md`

- final Journey schema;
- account Knowledge target schema;
- field ownership and versions;
- migration/backup/downgrade;
- no merge implementation.

**B2. DS-16 — Save/checkpoint policy.** Done 2026-11-16.  
Result: `docs/DS-16-SAVE-CHECKPOINT-RESULT.md`  
Document: `docs/tasks/DS-16-SAVE-CHECKPOINT.md`

- no per-kill save;
- checkpoint triggers;
- account vs character writes;
- SAVED_VARIABLES_TOO_LARGE recovery;
- backup/restore;
- merge later.

### Phase C — retrieval

**C1. DS-15 — Lazy retrieval/cache.** Done 2026-11-16.  
Result: `docs/DS-15-LAZY-RETRIEVAL-CACHE-RESULT.md`  
Document: `docs/tasks/DS-15-LAZY-RETRIEVAL-CACHE.md`

- selected-block decode;
- base64 lazy decode;
- account metadata/Knowledge lookup;
- tooltip: current Journey → account Knowledge → fallback;
- danger tooltip;
- best-zone query;
- heatmap best-cell query;
- bounded block cache;
- no full scan.

### Phase D — account-wide Knowledge prototype (future)

**D1. DS-17.4D — Account Knowledge derivation prototype.**  
Document: `docs/tasks/DS-17-04D-ACCOUNT-KNOWLEDGE-PROTOTYPE.md`

- read character SavedVariables;
- derive account Knowledge;
- multiple characters/overlap;
- idempotence;
- size/load;
- no raw history copied;
- no production merge yet.

### Phase E — live verification

**E1. V-2 — Data/API availability.**  
- killer attribution;
- health before/after and time-to-kill;
- buff/group/rested capture;
- per-zone/level event-driven presence/engaged time;
- XP events/group unattributed XP;
- SavedVariables size/parse/save/migration;
- Forever vs Midnight differences.

### Phase F — UI/future features

- UI-3 death/respawn view;
- UI-4 quest XP ledger;
- tooltip danger;
- suggested zone;
- best heatmap part;
- route recommendation later.

### Phase G — decision

**G1. DS-11 — Decision record.** Done 2026-11-16.  
Result: `docs/DS-11-DECISION-RECORD.md`  
Next: IMP-1 integration, then V-2. DS-14 and CAP-1 are complete.

## 4. Dependencies

```text
DS-17.4A
  → DS-17.4B
  → DS-17.4C
  → DS-17.5
  → DS-16
  → DS-15
  → DS-17.4D (future)
  → UI features (future)
  → DS-11

V-2 can run after the schema is stable enough to test capture fields.
```

DS-15 must not proceed until DS-17.4A–C and DS-17.5 are complete.

## 5. Group-consensus task evaluation

Personas:

- **DS** — data scientist
- **LX** — Lua/SavedVariables expert
- **AA** — addon author
- **WD** — WoW/client/API developer
- **GD** — game designer
- **GP** — game player

Verdicts: **P** proceed, **R** revise/proceed with constraints, **D** defer.

| Task | DS | LX | AA | WD | GD | GP | Consensus |
|---|---|---|---|---|---|---|---|
| A1 Journey/Knowledge validation | P | P | P | P | P | P | **Proceed now** |
| A2 context cardinality | P | R | P | R | P | P | Proceed; keep top-N/collapse measurement |
| A2 danger outcomes | P | P | P | R | P | P | Proceed; verify killer attribution |
| A2 best-zone XP/hour | P | R | P | R | P | P | Proceed; event-driven time and confidence required |
| A2 heatmap best-cell | P | R | P | P | P | P | Proceed; per-cell time/XP must earn its cost |
| A3 retention/aggregation compatibility | P | P | P | P | P | P | **Proceed now** |
| A3 schema-shape comparison | P | P | P | P | R | P | Proceed; choose simplest correct shape |
| B1 DS-17.5 schema/migration | P | P | P | R | P | P | Proceed after A |
| B2 DS-16 save/checkpoint | P | P | P | R | P | P | Proceed after schema |
| C1 DS-15 retrieval | R | P | P | P | P | P | Proceed after schema; no UI assumptions |
| D1 account Knowledge prototype | P | R | R | R | P | P | **Defer** until schema is stable |
| E1 V-2 API/data availability | P | P | P | P | R | P | Proceed when live access is permitted |
| F UI features | R | R | R | R | P | P | Defer until data model is stable |
| G DS-11 decision | P | P | P | P | P | P | After A–E |

### Persona notes

**Data scientist**
- Demand aggregation keys, sample counts, variance, recency, confidence.
- Do not treat one character as representative.
- Separate base XP from observed XP.
- Danger rates need denominators and context buckets.

**Lua expert**
- Account SavedVariables load for every character; keep Knowledge small/packed.
- Character Journey can be larger; use cold blocks.
- Avoid per-kill writes; checkpoint and migration must be explicit.
- Top-N/collapse must be measured, not guessed.

**Addon author**
- Extend current `mobs`/`zones`/`heatmaps` structures; do not rewrite blindly.
- Preserve current tooltips and smoke behavior.
- Keep schema migration/backups safe.
- Do not block storage work on future UI.

**WoW developer**
- Killer attribution, health, time-to-kill, buffs, group, rested, and active
  time availability vary by client.
- Forever and Midnight must be treated separately.
- Current data may not have all fields; verify before promising danger/XP/hour.
- Quest state is not part of mob combat/XP context.

**Game designer**
- Journey is personal; Knowledge is advice.
- Danger and best-zone answers must show confidence and not invent data.
- Best zone is XP/hour, not raw kills.
- Heatmap “best part” is density/XP/hour, not count alone.
- Keep future UI simple and explainable.

**Game player**
- “Is this mob dangerous?”
- “Do I kill it easily?”
- “Where should I level?”
- “Where is the best spot?”
- Show simple answers first; details behind the scenes.

### Consensus outcome

- **Proceed now:** A1, A2, A3.
- **Proceed after A:** B1, B2, C1.
- **Defer:** D1 (account Knowledge prototype), F (UI), route recommendation.
- **Critical:** E1 (live/API availability) before promising danger/XP-hour.
- **Final gate:** DS-11 after A–E.

## 6. What this means for earlier work

| Earlier work | Status |
|---|---|
| DS-1 / DS-1-F2 | Valid; index/identity contract remains |
| DS-2 / DS-3 / DS-3B / DS-3C | Valid; current caps and size pressure established |
| DS-4P / F1 / F2 | Valid for Journey hot/cold and scoped name index |
| DS-5 | Valid; account/character loading constraints |
| DS-6 / DS-6-F1 | Revised: no shipped names; metadata learned live; Journey primary |
| DS-7 / DS-12 | Valid; codec remains for Journey and future Knowledge blocks |
| DS-17.1 | Needs Journey/Knowledge split and active-time/context fields |
| DS-17.2 | Valid lifecycle; add Knowledge target |
| DS-17.3 | Retention must preserve aggregation dimensions |
| DS-17.4 | Replaced by this plan + A/B/C/D tasks |
| DS-17.5 | Needs the new schema/migration |
| DS-15 | Blocked until A–C and B1 |
| UI-3 / UI-4 | Future; not blocking data model |

## 7. Non-goals

- No uploads or external sharing.
- No privacy/clearance layer.
- No merge implementation now.
- No per-kill event log.
- No global all-name list.
- No global mob × zone × grid matrix.
- No route recommendation now.
- No UI work now.

## 8. Success criteria

- Per-character Journey supports current tooltips and future danger/best-zone/
  heatmap analysis without per-kill logs.
- Current caps are not treated as design limits.
- Account Knowledge target is derivable from Journey data later.
- Danger and best-zone queries have confidence/sample counts.
- Retention does not destroy aggregation inputs.
- No full scan at query time.
- Storage/load/save remains within measured budgets.
