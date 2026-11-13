# AceM2L2 plan

Updated: 2026-11-13  
Current release: **2.1.0**

## Active work

None. The P1 remediation pass and Kill Story rebranding are complete.

## Deferred

### KillStory as a separate addon

Deferred until explicitly approved. When revisited, decide:

- Data ownership and SavedVariables location.
- Public AceM2L2 API, callbacks, capabilities, and version handshake.
- Tooltip ownership between AceM2L2 text and KillStory GUI.
- Two-addon packaging, dependency/load order, and missing-dependency behavior.
- Migration and downgrade behavior.
- Tests for the API contract and load order.

Do not implement the split before those decisions are accepted.
