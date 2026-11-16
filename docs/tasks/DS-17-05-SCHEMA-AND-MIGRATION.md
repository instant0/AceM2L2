# DS-17.5 — Schema, field ownership, and migration

**Status:** ready; after DS-17.4A/B/C  
**Depends on:** DS-17.1..DS-17.4C, DS-4, DS-5, DS-7/DS-12, DS-9  
**Blocks:** DS-15, DS-16, DS-11

## Scope

Turn the Journey/Knowledge model into a concrete schema:

- per-character Journey;
- account-wide Knowledge target;
- field ownership and versions;
- migration/backup/downgrade;
- no merge implementation.

The model is documented in:

- `docs/DATA-MODEL-AND-TEST-MATRIX.md`
- `docs/DATA-MODEL-PLAN.md`

## Roots

```text
AceM2L2DB.profile.knowledge              -- future account-wide Knowledge target
AceM2L2DB.profile.settings               -- current settings/UI
AceM2L2CharDB.xpTooltip.clients[project] -- per-character Journey
  .character
  .journey.mobs
  .journey.zones
  .journey.instances
  .journey.levels
  .journey.sessions
  .journey.heatmaps
  .journey.deaths
  .journey.quests
```

No upload, network, privacy, or cross-account roots.

## Field ownership

| Field | Scope | Notes |
|---|---|---|
| Settings/UI | Account | Current |
| Static mob name/level/classification/zones | Journey now; account Knowledge later | Learned live; no all-name payload |
| Mob kills/XP/byLevel/byMap/byInstance | Character Journey | Add active time/deaths |
| Combat contexts | Character Journey | Danger; health/buffs/group/level/classification/difficulty |
| XP contexts | Character Journey | Player/mob level, group, rested, buffs, classification |
| Zone/instance/level XP/time/deaths | Character Journey | Best-zone XP/hour |
| Sessions | Character Journey | Active time source |
| Heatmap cells | Character Journey | Kills/XP/time, 64×64 |
| Deaths | Character Journey | Mob attribution/context |
| Respawns | Character Journey | Aggregate summary |
| Quests | Character Journey | Separate from mob context |
| Account Knowledge aggregates | Account | Derived later; no raw history |

## Schema versions

- `journeySchema`
- `knowledgeSchema`
- `projectID`/`interface`
- `mode` (leveling/endgame)
- `levelCap`
- `schema` per nested root
- `migrationBackup`
- downgrade: unknown newer schema is read-only/blocked, never overwritten.

## Migration

- Existing characters migrate without data loss.
- Preserve old fields in a backup until the new schema is validated.
- Migrate current mob names/levels/zones into the Journey fields.
- Do not require account Knowledge migration now.
- Do not merge character data now.
- Tests cover:
  - legacy/current character;
  - missing fields;
  - corrupt/partial data;
  - downgrade;
  - backup/restore.

## Work items

- Final Journey schema and field names.
- Final account Knowledge target.
- Field ownership table.
- Versioning/downgrade.
- Migration steps and backup.
- Query boundaries for DS-15.
- Save boundaries for DS-16.
- Size guards for DS-14.
- Test fixtures/migration tests.
- Feed DS-11.

## Acceptance

- Journey/Knowledge split is unambiguous.
- No field is duplicated across roots without a reason.
- Existing characters migrate safely.
- Old builds cannot silently destroy new roots.
- Backup/restore works.
- No merge implementation.
- DS-15/DS-16/DS-11 can proceed.

## Risks

- Packed archives may be opaque to manual repair.
- Downgrade overwrite is the highest-risk failure.
- Account Knowledge can grow; pack/limit by measured cost.
- `SAVED_VARIABLES_TOO_LARGE` is a load failure, not a warning.
