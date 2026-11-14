# DS-17.3 — Retention, compression, and heatmap downsampling

**Status:** research/design task, not implemented  
**Parent:** DS-17  
**Depends on:** DS-17.1, DS-17.2  
**Blocks:** DS-17.4, DS-17.5, DS-9

## Scope

Define how earlier leveling state is compressed while remaining useful.

Tiers:

- **Hot:** current + recent 5 levels; full detail; 64×64.
- **Warm:** previous 5–20 levels; per-level/zone/instance counts, top mobs,
  32×32.
- **Cold:** older levels; level/zone summaries, top mobs, 16×16.
- **Shared:** account-wide aggregates (DS-17.4).

## Research questions

1. What is the exact hot/warm/cold boundary in levels and age?
2. What detail can be dropped without breaking:
   - level history/splits;
   - mob list/area list;
   - route/heatmap;
   - Journey;
   - cell inspector;
   - cross-character knowledge?
3. How much does heatmap downsampling 64→32→16 save per zone, and what is the
   quantization error?
4. How many contexts can be collapsed per mob, and which contexts matter most?
5. What is the best compression method per store:
   - packed blocks (DS-12);
   - varints/delta counts;
   - mob/zone dictionaries;
   - level bands;
   - text blobs?
6. What is the CPU cost of compression at login, at mode switch, and at save?
7. What is the restore/backup path before destructive compression?
8. How do caps apply per tier and per client?
9. What happens when a compressed archive is loaded by an older build?

## Proposed retention sketch

```text
hot:    level >= maxLevel - 5       detail, 64x64
warm:   level >= maxLevel - 20      counts, top mobs, 32x32
cold:   older                       summary, top mobs, 16x16
shared: account-wide bands          aggregates only
```

Exact numbers come from DS-2/DS-3/SC measurements.

## Work items

- Define retention windows and archive boundaries.
- Measure downsample size/error at 64/32/16.
- Define context collapse/top-N rules.
- Select compression mechanisms before implementation.
- Define backup/restore and downgrade behavior.
- Feed DS-12 codec requirements.
- Feed DS-9 pruning/migration.
- Feed DS-17.4 shared aggregates.

## Deliverables

- Tier specification.
- Compression ratio table.
- Downsampling error table.
- Context-collapse rules.
- Backup/restore plan.
- DS-12 codec input.
- DS-9 pruning/migration input.

## Acceptance criteria

- Each tier has a defined field set and cap.
- Compression saves a measured amount versus hot/warm data.
- Historical heatmaps remain readable at the chosen downsample.
- No destructive compression occurs without backup.
- Downgrade behavior is documented.
- DS-12 and DS-9 can implement without re-deciding policy.

## Risks

- Over-compression makes old routes meaningless.
- Context collapse may bias XP/level estimates.
- Downsampling can hide narrow high-activity cells.
- Compression CPU may hurt login/save.
