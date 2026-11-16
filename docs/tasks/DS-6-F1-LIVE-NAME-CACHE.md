# DS-6-F1 — Live name cache and optional spawn-locality index (superseded)

**Status:** superseded 2026-11-16  
**Superseded by:** `docs/tasks/DS-6-F1-MOB-METADATA-REGISTRY.md`  
**Result:** `docs/DS-6-F1-MOB-METADATA-REGISTRY-RESULT.md`

Review of the local `/mnt/r/AceM2L2.lua` save changed the design:

- a mob has at most 4 zone/instance refs (assumption) and one fixed level range;
- the useful object is a **per-character mob metadata registry**, not a separate
  name cache or a pre-kill spawn index;
- the registry stores name + level range + ≤4 zone refs once per mob;
- name-only mobs are common (58/158 in the local sample), so the existing F2
  scoped name index remains required;
- account-wide sharing and a pre-kill spawn index are deferred.

See the replacement task and result above.
