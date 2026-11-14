# DS-17.5 — Schema, migration, and storage format

**Status:** research/design task, not implemented  
**Parent:** DS-17  
**Depends on:** DS-17.1..DS-17.4, DS-4, DS-9, DS-11  
**Blocks:** DS-11

## Scope

Turn the aggregation, mode, compression, and cross-character decisions into a
concrete schema and migration plan.

## Research questions

1. Where do the new roots live: account SavedVariables, character
   SavedVariables, or a LoadOnDemand companion?
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
AceM2L2ArchiveDB (optional companion)    -- cold archives if split
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
- DS-11 can make a final storage decision from this document.
- Tests cover migration, corruption, and downgrade.

## Risks

- Multiple SavedVariables files may increase load/save complexity.
- Companion loading order may cause data loss.
- Packed archives may be opaque to manual repair.
- Downgrade overwrites are the highest-risk failure mode.
