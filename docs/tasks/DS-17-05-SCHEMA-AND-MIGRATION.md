# DS-17.5 — Schema, migration, and storage format

**Status:** research/design task, not implemented  
**Parent:** DS-17  
**Depends on:** DS-17.1..DS-17.4, DS-4, DS-5, DS-9, DS-11  
**Blocks:** DS-11

## Scope

Turn the aggregation, mode, compression, and cross-character decisions into a
concrete schema and migration plan.

### DS-5 constraints

Use `docs/DS-5-SAVEDVARIABLES-LOADING-MATRIX.md` as a hard input:

- Normal SavedVariables load together. Account data loads for every character;
  per-character data loads only for the active character.
- Multiple variables do not defer. Only a LoadOnDemand companion can defer its
  code and, subject to V-2 timing proof, its variables.
- There are no per-zone SavedVariables files.
- `LoadSavedVariablesFirst` changes order only; it does not reduce load.
- `SaveAddOns` is a checkpoint, not a synchronous durability guarantee.
- `SAVED_VARIABLES_TOO_LARGE` is an out-of-memory load failure; the variables
  will not save on the next logout.
- Do not call `LoadAddOn` inside an `ADDON_LOADED` handler; the companion may
  miss its own `ADDON_LOADED`.

### Known high-level split

`docs/STORAGE-DIRECTION.md` has the current root/scope matrix:

- account `AceM2L2DB`: settings and small bounded aggregate knowledge;
- per-character `AceM2L2CharDB`: raw active-character history and archives;
- TOC/Lua static metadata, not SavedVariables;
- in-memory indexes, not saved;
- optional LoadOnDemand companion for cold archives only.

DS-17.5 finalizes field-level ownership, schema versions, migration, backup,
downgrade, and the companion decision. It must not duplicate a fact across
roots.

## Research questions

1. Where do the new roots live: account SavedVariables, character
   SavedVariables, or a LoadOnDemand companion? There are no per-zone files.
2. What is the schema version and downgrade behavior?
3. How are hot/warm/cold tiers represented on disk?
4. How are packed blocks versioned and decoded (DS-12)?
5. How are archives and endgame buckets separated?
6. How is shared knowledge rebuilt and invalidated?
7. What is the migration path for existing characters?
8. What backup is taken before compression/migration?
9. How does an older build avoid overwriting unknown roots?
10. What are the size/quota guards (DS-14)?
11. What is the save/checkpoint policy (DS-16)?
12. What queries need lazy decode (DS-15)?

## Proposed roots

```text
AceM2L2DB.profile.levelingKnowledge      -- account-wide aggregates
AceM2L2CharDB.xpTooltip.clients[project].character
  .mode
  .levelingArchives[generation]
  .endgame
AceM2L2ArchiveDB (optional companion)    -- one cold-archive variable;
                                         -- not per-zone files; timing is V-2
```

## Work items

- Choose file/root placement.
- Define schema versions and migration steps.
- Define archive/endgame/hot/warm/cold tables.
- Define packed block envelope and checksum.
- Define backup/restore and downgrade rules.
- Define lazy query boundaries.
- Define size/quota guard.
- Define save/checkpoint triggers.
- Write migration tests and fixture data.
- Feed DS-11.

## Deliverables

- Schema definition.
- Migration/backup plan.
- Downgrade behavior.
- Companion decision.
- Codec envelope.
- Query boundaries.
- Test plan.

## Acceptance criteria

- Existing characters migrate without data loss.
- Old builds cannot silently destroy new roots.
- Compression/migration has a backup and restore path.
- Hot/warm/cold/endgame/shared roots are unambiguous.
- No design assumes partial loading of a normal SavedVariables variable.
- DS-11 can make a final storage decision from this document.
- Tests cover migration, corruption, and downgrade.

## Risks

- Multiple SavedVariables files increase file/save complexity but do not defer
  normal loading by themselves.
- Companion loading order may cause data loss. Do not load it from inside
  `ADDON_LOADED`; verify its variable timing in V-2.
- `SAVED_VARIABLES_TOO_LARGE` is a load failure, not a warning; the next logout
  will not save. The backup/recovery path is mandatory.
- Packed archives may be opaque to manual repair.
- Downgrade overwrites are the highest-risk failure mode.
