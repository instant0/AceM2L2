# DS-6-F1 — Mob metadata registry result

**Status:** executed 2026-11-16; revised for account-wide stable metadata  
**Harness:** `tests/ds6f1_registry.lua`  
**Local source:** `/mnt/r/AceM2L2.lua` (one character save, client/project 18)  
**Scope:** mob metadata registry; offline prototype only.

This result uses only the local save. Online verification is deferred until
explicit permission is given.

## Core finding

Mob metadata is **game/static data**, not character history:

- the same stable `npcID` has the same name, level range, and locality for every
  character on the same client/project;
- a mob seen by Character 1 in Thunder Bluff is normally the same mob for
  Character 2;
- kills, XP observations, session data, and per-character counts are still
  character history and must stay per character.

Therefore the design split is:

```text
account-wide metadata:  npc:<id> -> name, levelMin, levelMax, zones (<=4)
per-character history:  kills, XP, contexts, session, zones/levels counts
per-character name-only: name:<lower> -> name/level/zones + scoped index
```

Name-only entries stay per character because `name:<lower>` is not a stable
identity. The F2 scoped name index resolves ambiguity; it never merges two
name-only mobs into one.

## Local sample

The local save is a **single character’s observed history**, not a game-wide
census.

The harness reads it in an isolated Lua environment and counts:

- `killsByMap` keys as open-world map refs;
- `killsByInstance` keys as instance refs;
- level keys under `killsByAreaLevel`/`killsByInstanceLevel` as the fixed level
  range;
- `npcID` presence vs name-only identity.

Observed mobs: **158**.

| Property | Result |
|---|---:|
| Mob entries | 158 |
| With stable `npcID` | 100 |
| Name-only | 58 |
| Open-world only | 106 |
| Instance only | 52 |
| Mixed open-world + instance | 0 |
| Total zone/instance refs | 181 |
| Average refs per mob | 1.15 |

### Zones/instances per mob

| Distinct zones/instances | Mobs |
|---:|---:|
| 1 | 135 |
| 2 | 23 |
| 3 | 0 |
| 4 | 0 |
| >4 | **0** |

The sample reaches **2**. The task assumption is **at most 4**; the sample does
not violate it.

### Fixed level range

All 158 mobs have a level range. Width = `levelMax - levelMin`:

| Level-range width | Mobs |
|---:|---:|
| 0 | 68 |
| 1 | 17 |
| 2 | 55 |
| 3 | 11 |
| 4 | 7 |
| >4 | 0 |

Average width is about 1.19 levels; maximum observed is 4. One fixed
`levelMin`/`levelMax` per mob is sufficient for this sample.

### Identity and locality

| Locality | `npcID` | Name-only |
|---|---:|---:|
| Open world | 100 | 6 |
| Instance | 0 | 52 |
| Mixed | 0 | 0 |

All 52 instance mobs in this save are name-only. The registry therefore needs:

- an **account-wide** stable-ID branch for `npc:<id>`;
- a **per-character** name-only branch for `name:<lower>`;
- the F2 scoped name index for ambiguous/name-only names.

## Registry model

### Account-wide stable metadata

```lua
accountMetadata = {
  schema = 1,
  projectID = 18,
  interface = 16001,
  entries = {
    ["npc:<id>"] = {
      npcID = ...,
      name = "...",
      levelMin = ...,
      levelMax = ...,
      zones = { "map:<id>", "instance:<key>", ... }, -- 1..4
      classification = "...", -- optional
    },
  },
}
```

- Shared by all characters on the same project/interface.
- One entry per `npcID`.
- One fixed level range.
- At most 4 zone/instance refs.
- Loaded for every character, so size matters.
- No raw counts/XP/kills/session data.

### Per-character name-only metadata

```lua
characterNameOnly = {
  entries = {
    ["name:<lower>"] = {
      name = "...",
      levelMin = ...,
      levelMax = ...,
      zones = { ... }, -- 1..4
    },
  },
  scopedNameIndex = { ... }, -- F2; ambiguous names stay ambiguous
}
```

- Not merged across characters.
- Cold blocks store the local mob key/reference.
- Ambiguous names are not resolved to a single ID.

### Per-character history

Still per character:

- kills, session kills;
- total/session XP and XP samples;
- contexts;
- per-level/map/instance counts;
- deaths, rate samples, quests, heatmaps.

No raw history is copied to the account registry.

## What about XP?

There are two different things:

1. **Base mob XP metadata** — driven by mob level/classification and the player
   level formula. This can be derived from the shared `levelMin`/`levelMax` and
   classification, so it does not require sharing character observations.
2. **Observed XP history** — actual XP gained depends on player level, group,
   rest, buffs, and other context. It is per-character history and must not be
   copied between characters.

The registry should store level range/classification, not another character's
observed XP totals. The existing XP formulas can compute the base expectation.

## Measured registry size

Production-style string keys, 1–4 zone refs, fixed level range.

### Local sample

| Registry part | Entries | Lua heap | Packed |
|---|---:|---:|---:|
| Account-wide `npc:<id>` metadata | 100 | **0.02 MB** | **3.8 KB** |
| Per-character name-only | 58 | **0.01 MB** | **3.7 KB** |
| Combined local registry | 158 | 0.05 MB | 7.5 KB |

The actual account-wide metadata for this character is tiny. The account
registry grows with **unique stable npcIDs across the account**, not with the
number of characters: a mob seen by every alt is still one entry.

### Synthetic scale

| Registry | Entries | Lua heap | Packed |
|---|---:|---:|---:|
| Mixed (account + name-only) | 1,000 | 0.37 MB | 0.04 MB |
| Mixed | 10,000 | 4.11 MB | 0.43 MB |
| Mixed | 100,000 | 38.25 MB | 4.32 MB |
| **Account-wide `npc:` only** | **10,000** | **2.38 MB** | **0.42 MB** |
| **Account-wide `npc:` only** | **100,000** | **35.97 MB** | **4.16 MB** |

Account-wide metadata at 10k stable NPCs is **2.38 MB map / 0.42 MB packed**.
At 100k it is 35.97 MB map / 4.16 MB packed. A realistic account is much closer
to the local sample than to 100k stable NPCs.

Lookup 10k: local ~0.02 ms; 10k ~1.2 ms; 100k ~2.4 ms.

## Storage recommendation

- **Account-wide map** for stable `npc:<id>` metadata at normal sizes.
- **Pack** when the account registry crosses a measured threshold (roughly
  10k–20k entries); at 10k, map is 2.38 MB and packed 0.42 MB.
- **Per-character map** for name-only entries; they are small in the local
  sample (58 entries, 0.01 MB).
- Load the account registry once per character; it is shared metadata.
- Keep the account registry separate per `projectID`/`interface`; never merge
  Forever and Midnight.
- Locale changes need a separate locale key or a refresh rule; names are
  localized.

## Findings

1. **Stable NPC metadata is shared, not character-specific.** The account-wide
   `npc:<id>` branch is the correct default.
2. **Raw history stays per character.** Kills, observed XP, contexts, counts,
   and heatmaps are not shared.
3. **Name-only entries stay per character.** 58/158 in the local sample, and all
   52 instance mobs are name-only. `name:<lower>` is not a stable cross-character
   identity.
4. **The local sample supports the ≤4-zone assumption.** 135 mobs have one
   zone/instance ref; 23 have two; none exceed two.
5. **Fixed level ranges hold in the sample.** All 158 have a range; maximum
   width 4.
6. **The account metadata is small at realistic scale.** 100 stable NPCs =
   0.02 MB / 3.8 KB packed.
7. **Account load is the trade-off.** 10k stable NPCs = 2.38 MB map /
   0.42 MB packed; pack if the account grows large.
8. **No pre-kill spawn index is required.** Locality is learned from kills and
   bounded to 4 refs per mob.
9. **No shipped all-name list and no global name index.** Direct key lookup plus
   the F2 scoped name index.
10. **No production code changed.** Offline design/measurement only.

## Decision

Adopt:

- **Account-wide stable metadata registry** keyed by `npc:<id>`:
  - name;
  - fixed `levelMin`/`levelMax`;
  - at most 4 zone/instance refs;
  - optional classification.
- **Per-character history** for kills/XP/contexts/counts/heatmaps.
- **Per-character name-only registry** keyed by `name:<lower>` plus the F2
  scoped name index.
- **Account map normally; pack at high entry counts.**
- **Separate account registries by project/interface/locale.**
- **`NPC <id>` fallback** for missing names.
- **No shipped all-name list.**
- **No pre-kill spawn index** unless a UI feature later proves it is needed.
- **No observed XP sharing.** Base XP can be computed from level/classification.

## Acceptance

- Stable `npcID` metadata is account-wide: **yes**.
- Name-only metadata stays per-character: **yes** (local data proves it matters).
- Raw history/observed XP stays per-character: **yes**.
- Each entry: one name, fixed level range, ≤4 zones: **yes**.
- Account registry size measured: **yes**.
- No shipped all-name list/global name index/fake identity: **yes**.
- No third-party database copied: **yes**.
- No online verification used: **yes** for this result.
- DS-15/DS-17.5 can proceed: **yes**.

## Follow-ups

- **DS-15 — Lazy retrieval/cache.** Load the account metadata registry; resolve
  cold mob keys; decode selected blocks; keep per-character name-only entries in
  the character scope.
- **DS-17.5 — Schema/migration.** Define the account/character split, registry
  version, and migration from current per-mob name/level/zone data.
- **Locale rule.** Decide separate locale registries vs refresh-on-sighting.
- **Optional name-only sharing.** Deferred; only if identity can be made stable.
- **Optional pre-kill spawn index.** Deferred; not required for storage.
- **Online verification.** Deferred until explicit permission; use
  Wowhead/official client data, not emulator databases.

## Artifacts

- `tests/ds6f1_registry.lua`
- `/mnt/r/AceM2L2.lua` local sample (read-only)
- `docs/DS-6-STATIC-METADATA-RESULT.md`
- `docs/DS-7-12-PACKED-BLOCK-CODEC-RESULT.md`
- `docs/DS-4P-F2-SCOPED-NAME-INDEX-RESULT.md`

No production code changed.
