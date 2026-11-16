# DS-11 — Decision record

**Status:** executed 2026-11-16  
**Scope:** final data-model/storage/retrieval decision; no new storage study  
**Predecessors:** DS-1..DS-17.5, DS-16, DS-15  
**Remaining:** implementation, V-2 live checks, future UI/account features

## 1. Scope

- Everything is local on the player's computer.
- Account-wide means the player's own characters in `AceM2L2DB`.
- Character Journey is in `AceM2L2CharDB`.
- No uploads, network sharing, privacy layer, or cross-account data.
- No merge implementation in this phase.

## 2. Settled decisions

### 2.1 Data layers

| Layer | Scope | Role |
|---|---|---|
| Static mob metadata | Account-wide (stable `npcID`); name-only per character | Name, level range, classification, ≤4 zone refs |
| Character Journey | Per character | Kills, XP, levels, contexts, deaths, quests, heatmaps, respawns, sessions |
| Account Knowledge | Account-wide, future | Derived aggregates for the player's alts |

The Journey is the source of truth. Account Knowledge is derived later from
character SavedVariables. No raw Journey is copied to the account.

### 2.2 Storage

- Dynamic hot/warm/cold movement.
- No 2,000/40/100/12 design caps.
- Per-zone/instance/level blocks.
- 64×64 heatmap hot; 32/16 cold; top-N hotspot summary.
- Sparse heatmaps are normal: 0.5–5% occupancy; 15–30% is stress only.
- Contexts are array/list records, not string-keyed maps.
- Cold: top-8 contexts + `other` aggregate.
- Preserve kill XP, quest XP, other XP separately; kills, event-driven presence/engaged time, deaths, samples, totals.
- No per-kill event log.

### 2.3 Codec

- Packed varint/delta blocks.
- Adaptive sparse/bitset cells.
- Per-block checksum.
- Per-block base64 for SavedVariables.
- Packed cold metadata/context records.
- No checksum identity, no Base64 hot path, no JSON hot path.

### 2.4 Names and metadata

- No shipped all-name list.
- Metadata learned live from `UnitName` + `npcID`.
- Stable `npc:<id>` metadata can be account-wide.
- Name-only `name:<lower>` metadata stays per character.
- F2 scoped name index remains for name-only/ambiguous names.
- No global name index.
- Missing name → `NPC <id>`.

### 2.5 Journey schema

- Separate `byPlayerLevel` from `mobLevelMin`/`mobLevelMax`.
- `byZone`/`byInstance` carry player-level subcounts.
- `presenceSeconds`/`engagedSeconds` per zone/level/instance, updated on events only (no timer/OnUpdate).
- Quest turn-in uses the existing `QUEST_TURNED_IN` event as a sparse presence anchor and adds `questXP`/`questCount`; it does not add engaged kill time and does not enter mob context.
- Separate `combat` and `xpContexts`.
- Death records: mob attribution, health, buffs, group, classification,
  difficulty.
- Heatmap cells support optional XP/time.
- Zone/level XP is split into `killXP`, `questXP`, and `otherXP`.
- Quests are separate from mob combat/XP context; `lastTurnInAt` is an anchor.
- Account Knowledge target is defined, not populated.

### 2.6 Retrieval

- Login decodes **zero** cold blocks.
- Selected-block lazy decode.
- Bounded LRU for active blocks.
- Selected-zone tooltip: current hot mob → metadata → selected cold block →
  `NPC <id>`.
- Best zone: XP/hour at current level from summaries.
- Heatmap: top-N summary; no block decode.
- Random global cold tooltip must not scan/decode arbitrary blocks; use hot/
  registry/summary.
- Missing/corrupt blocks fail safely.

### 2.7 Save/checkpoint

- No per-kill save.
- Dirty-block incremental encode.
- Checksum during encode.
- Full encode only for migration/compaction.
- Previous generation backup/restore.
- `SAVED_VARIABLES_TOO_LARGE` is a load failure:
  stop normal saving, preserve backup, compact/reset explicitly.
- Account Knowledge writes deferred.

### 2.8 Deferred

- Account Knowledge derivation/merge.
- LoadOnDemand companion variable timing.
- Route recommendation.
- Tooltip danger UI.
- Suggested-zone UI.
- Heatmap best-part UI.
- UI-3/UI-4.
- Cross-character route features.

## 3. Evidence retained

| Finding | Number |
|---|---|
| Current real store | 70,661 bytes; 85 mobs; 762 kills |
| Current-cap synthetic | 8.69 MB compact / 9.94 MB client estimate; 23 MB stable / 27–37 MB transient |
| Hybrid tier C | 100k/200/200: 38.5 MB hot / 8.07 MB cold; selected-zone 3.7 ms |
| Hot index | 100k: 20.67 MB baseline; 7.67 MB with static names |
| Scoped index | 100k: 7.73 MB hot + 5.97 MB shared |
| Cold codec | 100k/4ctx: 3.90 MB cold / 4.03 MB heap; 350k sub-blocks 13.22 MB / 2.55 ms |
| Context arrays | 10k×12: 4.37 MB array vs 70.70 MB keyed map |
| Cold context | top-8 93.8% kills/92.2% XP; top-8+other 100% totals; packed 1.43 MB |
| Local mobility | 158 mobs; 135 one zone/instance, 23 two; fixed level width ≤4 |
| Save | dirty 1 block 2.1 ms; full 400 blocks 795 ms; full decode 1.15 s |
| Retrieval | login 8 ms / 0 decoded; selected block 1.7 ms; selected 10k tooltip 1.2 ms |
| Global cold tooltip | 16.2 s uncached; 5.8 s with 256-block cache — use hot/registry/summary |

## 4. Rejected alternatives

- Keeping the current 2,000/40/100/12 caps as the design.
- Plain Lua tables for cold data.
- Dense 64×64 cells as the normal case.
- Shipped all-name list.
- String-keyed context maps for cold storage.
- Full base64 decode at login.
- Per-kill disk save.
- Decoding arbitrary cold blocks for global tooltips.
- Account-wide raw history.
- Merge implementation before alt features.

## 5. Implementation order

1. **DS-14 — Oversize guard implementation.**
   - constant-table/oversize handling;
   - stop-save/recovery;
   - backup/restore.
2. **CAP-1 — Journey capture fields.**
   - mob level at sighting;
   - presence/engaged time on events;
   - combat health/buffs/group;
   - death attribution;
   - cell XP/time.
3. **IMP-1 — Journey schema/retrieval integration slice.** Done 2026-11-16.
   **IMP-1A — Production Journey instrumentation.** Done 2026-11-16.
   **IMP-1B — Production Journey query API.** Done 2026-11-16.
   **IMP-1B2 — Production block storage core.** Done 2026-11-16.
   **IMP-1B3 — Block retrieval integration.** Done 2026-11-16.
   **IMP-1B4 — Block backup/save guard.** Done 2026-11-16.
   **IMP-1B5 — Tooltip/UI retirement.** Next.
   - v2 schema in production code;
   - dirty-block save;
   - selected-block decode;
   - cache;
   - tooltip/best-zone/heatmap queries.
4. **V-2 — live verification.**
   - API availability;
   - SavedVariables timing/size;
   - companion timing;
   - oversize behavior.
5. **UI work.**
   - tooltip danger;
   - suggested zone;
   - heatmap best part;
   - UI-3/UI-4.
6. **DS-17.4D — account Knowledge prototype** when alt features are scheduled.

## 6. V-2 checklist

- Killer attribution for player deaths.
- Player health before/after and time-to-kill.
- Buff signature and group size reliability.
- Per-zone/level event-driven presence/engaged time.
- Heatmap cell XP/time capture.
- Quest turn-in timestamp/reward reliability.
- Mob level at sighting.
- `SaveAddOns` durability before logout.
- Logout/reload save behavior.
- `ADDONS_UNLOADING` final checkpoint.
- `SAVED_VARIABLES_TOO_LARGE` threshold/recovery.
- LoadOnDemand companion variable timing.
- Selected-block decode latency on live client.
- Forever/Midnight differences.

## 7. What we learned

- The data model is now more important than the storage medium.
- The Journey must remain rich; account Knowledge is derived.
- Player level and mob level must be separate fields.
- Contexts must be arrays for cold storage.
- Sparse heatmaps are normal.
- On-demand decode works; full decode at login does not.
- Global cold access must use summaries, not block scans.
- The current caps are not the design.
- No new storage-format study is needed.

## 8. Acceptance

- Settled vs deferred decisions recorded: **yes**.
- Evidence and rejected alternatives recorded: **yes**.
- Implementation order defined: **yes**.
- V-2 checklist defined: **yes**.
- No new storage study opened: **yes**.
- No production code changed: **yes**.

## 9. Artifacts

- `docs/tasks/DS-11-DECISION-RECORD.md`
- `docs/DATA-MODEL-PLAN.md`
- `docs/DATA-MODEL-AND-TEST-MATRIX.md`
- `docs/DS-17-05-SCHEMA-AND-MIGRATION-RESULT.md`
- `docs/DS-15-LAZY-RETRIEVAL-CACHE-RESULT.md`
- `docs/DS-16-SAVE-CHECKPOINT-RESULT.md`
- `docs/DS-17-04A/B/C` results
- `docs/DS-7-12-PACKED-BLOCK-CODEC-RESULT.md`
