# DS-6-F1 — Static metadata generator/provenance (superseded)

**Status:** superseded 2026-11-16  
**Superseded by:** `docs/tasks/DS-6-F1-MOB-METADATA-REGISTRY.md`

The shipped-name generator was rejected after review:

- do not ship a list of all names;
- names are learned live while playing;
- mobs are zone/instance/grid-localized, so storage is per-zone/per-instance;
- optional spawn/locality data comes from the client's own DB, not a shipped
  all-name table.

The replacement task defines the per-character mob metadata registry (name,
fixed level range, at most 4 zone/instance refs). The DS-6 measurements remain as the rejected
shipped-name alternative in `docs/DS-6-STATIC-METADATA-RESULT.md`.
