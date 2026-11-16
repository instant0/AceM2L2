# DS-4P-F2 — Scoped/lazy name index

**Status:** executed 2026-11-16  
**Result:** `docs/DS-4P-F2-SCOPED-NAME-INDEX-RESULT.md`  
**Depends on:** DS-4P-F1, DS-1-F2, DS-6 (static metadata feasibility)  
**Blocks:** DS-15 retrieval, DS-17.5 schema

## Why

DS-4P-F1 showed:

- per-character hot names + global name index: 20.67 MB at 100k mobs;
- static names + numeric hot arrays: 7.67 MB hot, but shared name index adds
  ~8 MB;
- static names without a name index: 6.83 MB hot / 6.00 MB shared, but no name
  fallback.

A global name→ID index is not needed for NPC-ID tooltip lookup. It is needed
only for name-only/ambiguous mobs.

## Scope

- Resolve static NPC names by `npcID` from a shared dictionary.
- Build/hold a name→ID index only for:
  - name-only mobs;
  - ambiguous names;
  - IDs missing from static metadata.
- Keep the static dictionary versioned and shared across characters.
- Do not scan all mobs for a tooltip name fallback.
- Keep ambiguous names explicit; do not guess.

## Tests

- 10k/100k mobs;
- 10% name-only mix;
- ambiguous duplicate names;
- static metadata missing an ID;
- tooltip by NPC ID;
- tooltip by name-only;
- no full scan;
- hot/shared heap and lookup latency.

## Acceptance

- Name fallback works for name-only/ambiguous mobs.
- NPC-ID lookup is direct.
- No global name index for all static mobs.
- No full scan.
- No fake identity or checksum identity.
- Hot/shared heap is measured; no arbitrary MB target.
- Feeds DS-15/DS-17.5.

## Not required

- live client test;
- final codec;
- production schema;
- UI changes.
