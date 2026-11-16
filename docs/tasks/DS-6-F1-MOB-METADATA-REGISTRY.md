# DS-6-F1 — Mob metadata registry

**Status:** executed 2026-11-16; revised for account-wide stable metadata  
**Result:** `docs/DS-6-F1-MOB-METADATA-REGISTRY-RESULT.md`  
**Harness:** `tests/ds6f1_registry.lua`  
**Depends on:** DS-6, DS-1-F2, DS-17.1  
**Blocks:** DS-15 retrieval, DS-17.5 schema

## Why

Mob metadata is game/static data, not character history:

- the same stable `npcID` has the same name, fixed level range, and locality for
  every character on the same client/project;
- kills, observed XP, contexts, counts, and heatmaps are per-character history.

Review also rejected a shipped all-name list and a pre-kill spawn database. The
local save shows the locality bound:

- 158 observed mobs;
- 135 in one zone/instance, 23 in two;
- assumed maximum: 4 zones/instances;
- one fixed level range per mob.

## Scope

### Account-wide stable metadata

```lua
accountMetadata.entries["npc:<id>"] = {
  npcID = ...,
  name = "...",
  levelMin = ...,
  levelMax = ...,
  zones = { "map:<id>", "instance:<key>", ... }, -- 1..4
  classification = "...", -- optional
}
```

- Shared by all characters on the same `projectID`/interface.
- One entry per stable `npcID`.
- One fixed level range.
- At most 4 zone/instance refs.
- No kills/XP/context/session/history data.
- Loaded for every character; size matters.
- Pack when the account registry grows large.

### Per-character name-only metadata

```lua
characterNameOnly.entries["name:<lower>"] = {
  name = "...",
  levelMin = ...,
  levelMax = ...,
  zones = { ... }, -- 1..4
}
```

- Not merged across characters; `name:<lower>` is not a stable identity.
- Keep the F2 scoped name index for name-only/ambiguous names.
- No global name index.

### Per-character history

Kills, session kills, observed XP/samples, contexts, per-level/map/instance
counts, deaths, rates, quests, and heatmaps remain per character.

### XP

- Base mob XP can be derived from level range/classification and the player-level
  formula; it does not require sharing observations.
- Observed XP is per-character history and must not be copied across characters.

## Tests

- local `/mnt/r/AceM2L2.lua` observed distribution;
- account-wide `npc:` registry at 10k/100k;
- per-character name-only registry at the local count;
- map vs packed size;
- lookup by mob key, name, level range, zone count;
- rename, missing name, duplicate/ambiguous name;
- project/interface mismatch;
- first-alt account metadata reuse with isolated raw history;
- ≤4 zones and one level range per mob.

## Acceptance

- Stable `npcID` metadata is account-wide.
- Name-only metadata remains per-character.
- Raw history and observed XP remain per-character.
- Each entry has one name, one fixed level range, and at most 4 zone refs.
- Account-wide size and load are measured.
- No shipped all-name list, no global name index, no fake identity.
- No third-party database is copied.
- DS-15/DS-17.5 can proceed.

## Not required

- live client test (V-2);
- online verification (requires explicit permission);
- UI work;
- production schema/migration;
- sharing name-only entries;
- a pre-kill spawn census.
