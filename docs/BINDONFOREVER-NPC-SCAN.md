# Bind on Forever NPC/zone scan

**Source:** `https://bindonforever.com/npcs`  
**Client build reported by source:** Forever `1.60.1.70938` (Nov 13, 2026)  
**Use:** aggregate counts only; no third-party data copied or bundled.

## 1. Totals

| Metric | Value |
|---|---:|
| Zones listed | **50** |
| People/NPCs | **5,530** |
| Creatures | **3,478** |
| Total NPC/creature entries | **9,008** |
| Pages including variants | 10,626 |
| Average entries per zone | 180.2 |
| Median entries per zone | 164 |
| Average creatures per zone | 69.6 |

## 2. Extremes

| Metric | Zone | Value |
|---|---|---:|
| Largest total | The Barrens | 379 |
| Largest creature count | Alterac Mountains | 162 |
| Largest people count | Stormwind City | 295 |
| Smallest total | Deadwind Pass | 27 |

Top zones by total entries:

| Zone | Level range | People | Creatures | Total |
|---|---|---:|---:|---:|
| The Barrens | 8–30 | 233 | 146 | 379 |
| Alterac Mountains | 28–44 | 159 | 162 | 321 |
| Stormwind City | — | 295 | 23 | 318 |
| Stranglethorn Vale | 28–50 | 160 | 150 | 310 |
| Zephras Isle | 1–14 | 245 | 57 | 302 |
| Ashenvale | 18–34 | 174 | 128 | 302 |
| Riverglades | 33–54 | 152 | 122 | 274 |
| Tirisfal Glades | 1–14 | 177 | 85 | 262 |
| Orgrimmar | — | 243 | 16 | 259 |
| Ironforge | — | 228 | 8 | 236 |

## 3. What this means for our limits

### Mobs
- Total game-wide Forever NPC/creature entries: **9,008**.
- Hard mob ceiling is **12,000**, so it covers the known total with headroom.
- Per-zone adaptive limit is **500**; max zone total is **379**, so 500 is
  already ~1.3× the largest zone’s *entire* NPC population and ~3× its creature
  population.
- A character only tracks killable/tracked mobs, not every townsperson.

### Quests
- The page supports the 50+ quests/zone observation.
- Adaptive quest limit: 100/zone, min 500, hard 10,000.
- 50 zones × 100 = 5,000, within the hard ceiling.

### Heatmaps
- The page lists **50 zones**, while the heatmap cap was **40**.
- Raised to **64** so the known zone set fits with headroom.
- No other heatmap change.

### Respawns
- The page lists **3,478 creatures**.
- The old 500-NPC cap covered only ~14% of known creatures across all zones.
- Raised to **4,000** so the known Forever creature count fits.
- Interval cap remains 20 per NPC.

### Deaths / levels / rates
- Deaths remain a recency store (last 100), not all-history.
- Level history, rate samples, and instances remain unchanged.
- Contexts remain 12/mob because they dominate cold size and need separate
  stress validation.

## 4. Changes made

| Store | Before | After | Reason |
|---|---:|---:|---|
| Heatmap zones | 40 | **64** | 50 known zones + headroom |
| Respawn NPCs | 500 | **4,000** | 3,478 known creatures + headroom |
| Mobs | 2,000 fixed | **2,000–12,000 adaptive** | 9,008 total entries; zone-derived |
| Quests | 200 fixed | **500–10,000 adaptive** | 50+ quests/zone |

## 5. Caveats

- The page is a fan-site aggregation, not a shipped data source.
- Counts include people and creatures, not just killable mobs.
- 10,626 pages include variants; 9,008 is the NPC/creature count.
- Midnight may differ from Forever.
- Totals do not imply one character encounters everything.

## 6. Next

**SC-6 — Capacity self-assessment.**
