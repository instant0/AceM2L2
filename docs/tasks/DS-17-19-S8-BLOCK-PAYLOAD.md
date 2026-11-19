# DS-17.19 — S8 block payload v2 completeness

**Status:** executed 2026-11-18.  
**Result:** `docs/DS-17-19-S8-BLOCK-PAYLOAD-RESULT.md`  
**Depends on:** DS-17.18  
**Blocks:** S9 caps/archive, S10 legacy retirement  
**Source:** `docs/DS-17-07-DATA-MODEL-RECONCILIATION-RESULT.md`, P0-2

## Goal

Make the serialized Journey block payload complete enough to represent the v2
records that legacy retirement will remove.

Today a block stores eight mob fields and five heatmap-cell fields. That is not
enough to preserve level splits, contexts, zone/instance totals, coverage flags,
or time data after retirement.

## Schema boundary

`journey.schema` remains the v2 data-model revision. The block payload gets its
own bump: `journey.storageSchema = 3`, with header schema `3` inside each block.
The SavedVariables root `storageSchema` is unchanged.

## Payload source

- Encode only from `journey.mobs`, `journey.zones`, `journey.instances`, and
  `journey.heatmaps`.
- `db.mobs`, `db.areas`, `db.instances`, and `db.heatmaps` are not read while a
  block is being encoded.
- If a v2 root is empty, run the existing one-time legacy sync before building
  the block index. Once the root has data, flush never consults legacy.

## Block contents

Each block owns one zone key and contains:

- its v2 zone or instance summary, including totals, time, deaths/sessions, and
  coverage flags;
- only the mobs that belong to that zone/instance, with identity, global
  kills/XP, first/last seen, mob level range/samples, global player-level
  records, zone/instance kills/XP, and zone/instance player-level records;
- the owned context array, with combat/XP views and top-8 plus `other` derived
  on decode rather than duplicated in the payload;
- heatmap cells as measured kills only, plus map total/lastSeen/gridSize and
  XP/time coverage flags.

No per-kill timestamps, no all-mob list, and no second copy of global `byZone` or
`byInstance` maps.

## Decode and index rules

- Schema 1 and 2 blocks keep their current decode behavior.
- Schema 3 decodes the zone summary, mob records, contexts, and heatmap cells;
  absent payload fields stay absent, not zero-filled.
- `GetJourneyBlockData` returns the decoded zone summary alongside records and
  cells; existing record/cell callers keep working.
- `blockIndex` gains zone kind/kills/XP and a `hasZone` flag. Heatmap stale-prune
  must retain blocks that still carry mobs or a zone summary.
- Checksum and format failures still fall back safely without deleting the block.

## Required payload

- Mob identity, name, classification, NPC ID.
- Global kills/XP and first/last seen.
- Per-player-level kills/XP for the block's zone or instance.
- Mob level range and observed level records.
- Contexts in owned order, including combat/XP context splits and `other`.
- Zone/instance totals, time fields, deaths/sessions, and coverage flags.
- Heatmap cells with kills and explicit XP/time coverage; absent data stays
  absent.
- No per-kill timestamps, per-kill logs, or all-mob duplication.

## Storage rules

- Bump the block schema and decode schema 1/2 for compatibility.
- Encode from the v2 model, not from legacy tables.
- Keep checksum validation, lazy decode, bounded caches, and oversize handling.
- Keep block writes dirty-zone scoped.
- Preserve rollback: old readers must reject the new schema safely.
- Do not add unmeasured MB caps.

## Not in S8

- 32/16 cold archive (S9);
- legacy retirement (S10);
- UI reader switch;
- live client validation (V-2C).

## Tests

`tests/s8_block_payload.lua`:

- schema 1/2 decode compatibility;
- schema 3 round-trip of zone/instance summary and coverage flags;
- mob identity/totals/level/context parity;
- context views derived without duplicate payload arrays;
- heatmap kills and absent XP/time parity;
- no legacy table reads during encode;
- dirty-zone rebuild and lazy decode;
- zone-only blocks retained after heatmap clear;
- checksum/corrupt-block rejection;
- no root storage-schema or cap changes.

## Acceptance

- A block round-trips every required v2 field.
- Decode of existing schema 1/2 still works.
- Legacy tables are not required to reconstruct the block.
- Full suite passes.
