# DS-17.2 — Leveling/endgame modes and archive lifecycle

**Status:** research/design task, not implemented  
**Parent:** DS-17  
**Depends on:** DS-17.1  
**Blocks:** DS-17.3, DS-9, DS-11

## Scope

Define what the addon stores at different character-life stages:

- **Leveling mode:** detailed current/recent levels, zones, instances, mobs,
  contexts, and 64×64 heatmaps.
- **Endgame mode:** current endgame content remains detailed; leveling history
  becomes a read-only archive.
- **New level-cap generation:** a new leveling archive starts when the cap
  rises; old generation remains read-only.

## Research questions

1. When should the addon switch mode: at max level, after the last level-up,
   on login, or by manual prompt?
2. Should the switch be automatic, prompted once, or always manual?
3. What must remain visible at max level: full mob detail, top mobs, level
   summaries, zone summaries, heatmap downsample, route summary?
4. How many level-cap generations must be retained?
5. Should a leveling archive be per character or shared after retention?
6. How are endgame kills kept separate from leveling route statistics?
7. What happens if a character is deleted or a new expansion raises the cap?
8. What user-facing controls are needed (archive/restore/delete/compare)?
9. How does the mode interact with `heatmapEnabled`, instances, and Journey?

## Proposed model

```text
character.mode = "leveling" | "endgame"
character.levelingArchives = {
  [generation] = {
    startedAt, archivedAt, maxLevel,
    mode = "leveling",
    summary = ...,
    archive = ...,
  }
}
```

Endgame buckets must not feed leveling route stats. Leveling archives may feed
account-wide knowledge.

## Work items

- Define the mode state machine.
- Define archive boundaries and generation numbering.
- Define the one-time prompt and manual override.
- Define what moves from hot to archive at the switch.
- Define endgame vs leveling counters.
- Define UI/commands for archive visibility and deletion.
- Write migration rules for existing max-level characters.
- Coordinate with DS-9 migration and DS-11 decision.

## Deliverables

- Mode/lifecycle specification.
- State-transition table.
- Archive generation format.
- UI/command behavior.
- Migration rules for current max-level characters.
- Inputs for DS-17.3 and DS-9.

## Acceptance criteria

- Leveling and endgame data cannot pollute each other's route stats.
- Switching mode does not delete raw data without confirmation/backup.
- A level-cap increase creates a new generation without overwriting the old one.
- The switch is understandable and reversible.
- DS-17.3 knows exactly which data is hot/warm/cold.
- DS-9 has migration rules.

## Risks

- Auto-switching can surprise players.
- A prompt on every login is unacceptable.
- Archive generations can multiply across expansions; caps are needed.
- Endgame users may still want leveling history for alts.
