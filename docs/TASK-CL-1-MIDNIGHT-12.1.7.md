# CL-1 — Midnight 12.1.7 client readiness

**Status:** interface added; 12.1.7 is PTR, API/map/live audit pending  
**Priority:** prepare now, ship only when the client is live or explicitly PTR-targeted  
**Scope:** TOC interface, client profile/version text, API audit, generated map data, tests  
**Depends on:** client availability  
**Related:** V-6 (release/client claims), R-4/R-5 (map overlays)

---

## 1. Verification

Checked against the wago.tools build feed on **2026-11-14**:

| Channel | Latest build | Created |
|---|---|---|
| Retail (`wow`) | **12.1.5.70783** | 2026-11-04 |
| PTR (`wowt`) | **12.1.7.70892** | 2026-11-12 |

Current conclusion:

- **Retail is still 12.1.5**, not 12.1.7.
- **12.1.7 is on the PTR** (builds since 2026-10-15). Public coverage still
  points to a December 2026 live window, not a live release.
- The addon now targets `## Interface: 120105, 120107, 16001`.
- `120107` was confirmed by another current TOC:
  `## Interface: 11509, 16001, 20506, 30405, 38002, 40402, 50504, 120105, 120107`.
  This confirms the 12.1.7 interface number and the dual-interface pattern.
- Retail 12.1.5 still uses `120105`; 12.1.7 PTR is expected to use `120107`.

No retail code update is required **today**. The task is to be ready for the
PTR/live transition without shipping a speculative interface change.

---

## 2. Goals

- Confirm the live vs PTR status and the exact 12.1.7 interface number.
- Keep `120105`, `120107`, and `16001` in the TOC; remove `120105` only when
  retail no longer uses it.
- Audit the 12.1.7 client for API changes that affect Kill Story.
- Update client profile labels/comments and documentation from 12.1.5 to
  12.1.7 or a version-neutral “Midnight 12.1.x” where appropriate.
- Regenerate official map overlay data from 12.1.7 only if the live client
  requires it and the DB2 source is available.
- Extend offline fixtures/tests for 120107 while keeping 120105 coverage.
- Ship a small compatibility release and verify with V-6.

## 3. Non-goals

- Guessing APIs from PTR notes without checking the client.
- Removing 120105 before retail moves.
- Copying third-party 12.1.7 data.
- Changing gameplay formulas just because the patch number changed.

---

## 4. API and behavior audit

Check these from the 12.1.7 client/source and official notes:

- `C_Map.GetBestMapForUnit`, `GetMapInfo`, `GetMapInfoAtPosition`
- `C_Map.GetPlayerMapPosition`
- `C_Map.GetMapArtLayers`, `GetMapArtLayerTextures`, `GetMapArtID`
- `C_MapExplorationInfo.GetExploredMapTextures`
- `GetInstanceInfo`, `IsInInstance`, `GetRealZoneText`
- `C_AddOns` loading/saving APIs and `SAVED_VARIABLES_TOO_LARGE`
- Nameplate APIs: `C_NamePlate`, `NAME_PLATE_UNIT_ADDED/REMOVED`
- Item/equipment APIs used by gear comparison
- Aura/rested/buff APIs
- Secret-value behavior on Midnight
- TOC metadata: `## Interface`, `## AddOnCompartmentFunc`, SavedVariables

Any removal or behavior change gets a dedicated implementation note before code
changes.

---

## 5. TOC and profile changes

When confirmed:

```toc
## Interface: 120105, 120107, 16001
```

- Done: `120107` was added while keeping `120105` and `16001`.
- This declares interface compatibility only; it does not claim the 12.1.7 API
  audit is complete.
- Do not remove `120105` before retail moves.
- Update `KillHistory/Clients/Midnight.lua` header from “12.1.5 profile” to
  “Midnight 12.1.x” or the confirmed version.
- Update README interface/client tables and the generated map-overlay build
  note only when the data is regenerated.

---

## 6. Generated map overlays

Current generated data:

- Midnight `12.1.5.69848`
- Forever `1.60.1.69913`

For 12.1.7:

1. Confirm `WorldMapOverlay` / `WorldMapOverlayTile` are available for the
   live build.
2. Regenerate with `tests/generate_map_overlays.py` only if art IDs or overlay
   data changed.
3. Verify the project/art-ID keys and overlay tuple format are unchanged.
4. Keep the 12.1.5 data until the new data is validated; do not mix builds.

---

## 7. Validation

- Add fixture coverage for interface 120107.
- Keep existing 120105 and 16001 coverage.
- Run `./tests/run_all.sh`.
- Build a release candidate with both interfaces.
- Verify installation and TOC status on the live/PTR client in V-6.
- Confirm no “out of date” flag on the target client.

---

## 8. Acceptance criteria

- Exact live/PTR status and interface number are recorded.
- TOC supports 120107 and 120105 when appropriate.
- No current-retail regression.
- API audit is complete and any required changes are implemented or explicitly
  dismissed.
- Client/docs/tests agree on the supported interfaces.
- Release check passes and V-6 confirms the target client.

---

## 9. Review log

### v1 — initial readiness task

- Verified retail 12.1.5.70783 vs PTR 12.1.7.70892.
- Recorded that 12.1.7 is not yet a retail release.
- Avoided a speculative TOC bump; defined the exact trigger and dual-interface
  approach.
- Added API, map-data, fixture, and release checks.

### v2 — interface confirmation

- A third-party TOC confirmed `120107`:
  `## Interface: 11509, 16001, 20506, 30405, 38002, 40402, 50504, 120105, 120107`.
- Added `120107` to our TOC while keeping `120105` and `16001`.
- Updated `check_layout.py` and README interface tables.
- Remaining work: API audit, map-overlay regeneration decision, PTR/live
  installation check, and V-6.
