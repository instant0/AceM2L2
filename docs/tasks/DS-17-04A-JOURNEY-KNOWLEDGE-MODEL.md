# DS-17.4A — Journey/Knowledge model validation

**Status:** executed 2026-11-16  
**Result:** `docs/DS-17-04A-JOURNEY-KNOWLEDGE-MODEL-RESULT.md`  
**Harness:** `tests/ds17_4a_model.lua`  
**Depends on:** DS-17.1, DS-17.3, DS-6-F1, DS-7/DS-12  
**Blocks:** DS-17.4, DS-17.5, DS-15, DS-16, DS-9, DS-11

## Why

The latest review changed the model:

- the per-character Journey is the primary asset and must not be shrunk to the
  current caps;
- account-wide Knowledge is a future derived target; merge is not implemented
  now;
- danger needs kills/deaths by comparable combat context;
- quest state is excluded from mob combat/XP context;
- best zone is highest XP/hour at the current level;
- best heatmap part must be density/XP/time based, not raw count alone.

The model is documented in `docs/DATA-MODEL-AND-TEST-MATRIX.md`. This task
validates it offline before schema/migration or retrieval work.

## Scope

Use the local save `/mnt/r/AceM2L2.lua` and synthetic profiles. Do not use online
sources. Do not change production code.

### Tests

1. **Journey field inventory**
   - what the local save contains;
   - which fields are missing for danger, XP/hour, heatmap ranking, and future
     aggregation;
   - current field sizes/cardinality.

2. **Context cardinality**
   - combat context: player level, mob level, health band, buff signature,
     group size, classification, instance difficulty;
   - XP context: player level, mob level, group size, rested, buff signature,
     classification;
   - full vs top-N vs collapsed context storage;
   - size, lookup, information loss;
   - verify quest state is excluded.

3. **Danger model**
   - synthetic kills/deaths by context;
   - death rate, slaughter rate, health lost, time-to-kill;
   - sample/confidence behavior;
   - sparse data and “not enough data” state;
   - killer attribution requirement.

4. **Best-zone XP/hour**
   - synthetic zones/levels/sessions with varied active time, XP, group, rested,
     buffs, deaths;
   - rank by XP/hour at the current level;
   - show confidence and fallback;
   - verify kills/hour alone can disagree.

5. **Heatmap best part**
   - per-cell kills, XP, active time;
   - top-N ranking and downsampling;
   - compare raw count vs kills/hour vs XP/hour.

6. **Retention/aggregation compatibility**
   - cold archive preserves byLevel/byMap/byInstance, combat/XP context, active
     time, deaths, heatmap cells;
   - verify future aggregation dimensions survive retention.

7. **Schema shape comparison**
   - current nested records;
   - normalized parallel arrays;
   - packed cold blocks;
   - measure size, update cost, query cost, migration safety.

8. **Account-wide target**
   - define the derived Knowledge schema only;
   - verify each Journey field maps to an aggregate or is explicitly excluded;
   - do not implement merge.

## Output

- `docs/DS-17-04A-JOURNEY-KNOWLEDGE-MODEL-RESULT.md`
- measured field/context/schema tables;
- recommended per-character schema;
- recommended account Knowledge target;
- list of missing API/data requirements for V-2;
- revised task inputs for DS-17.4/DS-17.5/DS-15/DS-16.

## Acceptance

- Per-character Journey retains all useful dimensions.
- Danger and best-zone queries are computable without a per-kill event log.
- Quest state is excluded from mob context.
- Full/top-N context trade-offs are measured.
- Retention does not silently destroy aggregation inputs.
- The account Knowledge target is defined but merge is not implemented.
- No online source used.
- No production code changed.

## Not required

- merge implementation;
- account-wide writes;
- UI work;
- live client test (V-2);
- route recommendation;
- online verification.
