# DS-6 — Static metadata feasibility result (revised)

**Status:** executed 2026-11-16; revised after review  
**Harness:** `tests/ds6_static_metadata.lua`  
**Example:** `lua tests/ds6_static_metadata.lua packed_block 350000 24 name`  
**Scope:** static NPC metadata only. This is an offline prototype; it is not
production schema and does not ship any third-party addon data.

## Review correction

The first revision proposed an optional shipped name table. That is rejected:

- **Do not ship a list of all names.** The addon can learn names while playing
  from the units it already sees (`UnitName` + `npcID`).
- **Mobs are localized.** They are tied to specific zones/instances and
  grid-refs, not spread across every grid of every zone/continent. The data
  model is per-zone/per-instance blocks with sparse mob/cell entries, not a
  global all-mob × all-grid matrix.
- **WoW databases already describe spawn locality.** They are a possible source
  for an optional spawn/locality index, not for a shipped all-name table, and
  the codec must not depend on them.

The measurements below are kept as the **rejected shipped-name alternative**.
They are useful evidence for why live capture + per-zone blocks is the right
direction.

## What the client provides

The public Retail/Midnight API does **not** expose an arbitrary creature name by
`npcID`. `C_CreatureInfo` exposes race, class, faction, family, and creature type
lookups; `GetCreatureID` goes from a unit to an ID, not from an ID to a name.
Third-party libraries such as `LibNPCInfo` resolve names by scanning a tooltip,
with rate limits and asynchronous behavior.

Capture at sighting is therefore the reliable name source. A private-server
client may add a name-by-ID helper; treat it as an optional resolver, not a
portable foundation.

## Revised source and storage decision

### Names

- Names are **learned live** when a mob is seen.
- Stable `npc:<id>` metadata is **account-wide**: name, fixed level range, and
  at most 4 zone/instance refs.
- Name-only `name:<lower>` metadata stays per character because the key is not a
  stable identity; the F2 scoped index handles ambiguity.
- Raw history and observed XP stay per character. The registry is metadata, not
  raw character history.
- Keep it bounded/evictable and separate per project/interface. A missing name
  is not guessed: display `NPC <id>`.
- Cold history blocks store IDs and counts only. They do not embed names.
- If the registry grows large, it can be packed with the same codec (DS-7/DS-12)
  or pruned by age/zone. That is a DS-15/DS-16 policy decision.

### Locality

- Store one block per zone/instance, with sparse mob IDs, sparse cells, and
  collapsed/summary context data.
- A mob appears only in the block(s) where it was actually seen. Do not model
  every mob in every grid of every zone.
- The core learns locality from live kills (`mapID`/instance + position).
- The registry learns locality from kills: at most 4 zone/instance refs per
  mob. A pre-kill spawn index is deferred; it is not required for storage.
- If a pre-kill spawn index is added later, it is separate from names and raw
  history, scoped by zone/instance/grid, and must not be copied from
  QuestieDB/ATT/Carbonite. Use the client's own DB or an authorized source.

### Why not ship the names

The shipped-name alternative was measured at 10k/100k/350k rows:

| Rows | Name-only map heap | Packed block heap | Packed blob |
|---:|---:|---:|---:|
| 10k | 1.21 MB | 0.31 MB | 0.26 MB |
| 100k | 10.67 MB | 3.51 MB | 2.60 MB |
| 350k | 40.35 MB | 12.80 MB | 9.10 MB |

Even the packed form is large, needs versioning/coverage/locale handling, and
adds no value over live capture for a character that has actually seen the mob.
Adding classification/level to the shipped table makes it worse (350k map:
97.77 MB; packed: 13.47 MB). **Reject shipping the all-name table.**

Live name measurements from the DS-7 harness (names only; the registry also stores level range and ≤4 zone refs):

| Seen names | Lua map heap | Lookup 10k |
|---:|---:|---:|
| 10k | 0.95 MB | 0.23 ms |
| 100k | 8.33 MB | 0.25 ms |

A realistic account will not see 350k unique NPCs; 10k is already a large
long-term registry. If 100k is reached, the packed registry is the fallback.

## Findings

1. **No shipped name list.** Live capture is sufficient and avoids the 10.67 MB
   (100k) / 40.35 MB (350k) shipped-map cost.
2. **Names/levels/zones are static metadata, not raw history.** Stable
   `npc:<id>` metadata is shared account-wide; name-only metadata stays
   per-character. Raw kills/XP remain isolated.
3. **Locality is the natural index.** Per-zone/instance blocks mean a tooltip or
   zone view touches only the relevant block, not a global mob list.
4. **Spawn metadata is optional.** WoW DBs can describe where NPCs live, but the
   core can learn this from kills; the codec must not depend on a shipped spawn
   list.
5. **Missing names stay missing.** The fallback is `NPC <id>`; no fake identity
   and no guessed name.
6. **Name-only/ambiguous lookups still need a scoped index.** Keep the F2
   design: a name→ID index only for captured name-only/ambiguous entries, never
   a global index for every NPC.
7. **Per-client separation remains.** Forever and Midnight may have different
   IDs/names/spawns; never merge their registries or indexes.
8. **No arbitrary MB target.** The numbers are measurements, not caps.

## Revised decision

Adopt:

- **No shipped all-name table.**
- **Account-wide stable `npc:<id>` metadata** holding name, fixed level range,
  and at most 4 zone/instance refs; plus **per-character name-only metadata**.
  `NPC <id>` fallback for missing names.
- **Per-zone/per-instance cold blocks** with sparse mob/cell entries; no global
  all-mob/all-grid matrix.
- **Learned locality in the registry**: at most 4 zone/instance refs per mob.
  A pre-kill spawn index is deferred and is not required for correctness.
- **No global name index.** Direct `npcID` lookup; F2 scoped name index only for
  name-only/ambiguous captured names.
- **No third-party database copy.** Do not use QuestieDB/ATT/Carbonite data.
- **Versioning** for the metadata registry: schema, project, interface, source,
  count, hash; reject mismatches.

## Regeneration and diff behavior

- There is no shipped name payload to regenerate.
- The optional spawn/locality index is generated at build time from the
  supported client's own data, deterministically, with a coverage report and
  hash; it is not required at runtime.
- The account-wide stable metadata and per-character name-only metadata are
  updated incrementally on sighting; a rename updates the entry. No full rebuild
  is needed.
- Diff size for the optional spawn index is proportional to changed spawn rows,
  not to every name in the game.

## Acceptance

- No shipped all-name table: **yes**.
- Names learned live; account-wide stable metadata + per-character name-only
  measured: **yes** (DS-6-F1).
- Missing/ambiguous fallback: **tested**.
- Locality represented by per-zone/instance blocks: **yes** (DS-4P/DS-7).
- Optional spawn index scoped, not global: **yes**.
- No copied QuestieDB/ATT/Carbonite data: **yes**.
- Per-client separation explicit: **yes**.
- DS-7/DS-12 and DS-15 can proceed: **yes**.

## Follow-up tasks

- **DS-6-F1 — Mob metadata registry.** Executed 2026-11-16. Result:
  `docs/DS-6-F1-MOB-METADATA-REGISTRY-RESULT.md`.
- **DS-7 + DS-12 — Packed block codec.** Per-zone/instance blocks, sparse IDs/
  cells, no inline names, checksums.
  `docs/tasks/DS-7-12-PACKED-BLOCK-CODEC.md`.
- **DS-15 — Lazy retrieval/cache.** Registry lookup, selected-block decode,
  and block cache.
- **V-2 — Live check.** Verify registry coverage and `NPC <id>` fallback on
  Forever/Midnight. A pre-kill spawn index is deferred.
- **DS-17.5 — Schema/migration.** Include the registry version.

## Artifacts

- `tests/ds6_static_metadata.lua` (rejected shipped-name alternative)
- `tests/ds7_codec.lua` (name-only size and cold-block codec)
- `docs/DS-4P-F2-SCOPED-NAME-INDEX-RESULT.md`
- `docs/DS-4P-F1-HOT-INDEX-RESULT.md`
- `docs/DS-5-SAVEDVARIABLES-LOADING-MATRIX.md`

No production code changed.
