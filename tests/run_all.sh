#!/usr/bin/env bash
# Run all offline AceM2L2 checks.
#
# Usage:
#   ./tests/run_all.sh
#   STRICT_ROOT=1 ./tests/run_all.sh
#   SKIP_RELEASE=1 ./tests/run_all.sh
#
# Set STRICT_ROOT=1 in CI/release staging when the checkout folder is named
# AceM2L2. Set SKIP_RELEASE=1 only while iterating before rebuilding a zip.

set -euo pipefail

LUA_BIN="${LUA_BIN:-lua}"
LUAC_BIN="${LUAC_BIN:-luac}"

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

echo "== Lua syntax =="
mapfile -t LUA_FILES < <(
  find ACEM2L2.lua Bindings.lua Core KillHistory tests -type f -name '*.lua' -print | sort
)
"$LUAC_BIN" -p "${LUA_FILES[@]}"

echo "== Test stats =="
python3 tests/test_stats.py

if [[ "${SNAPSHOT:-0}" == "1" ]]; then
  echo "== Behavior snapshot =="
  "$LUA_BIN" tests/snapshot.lua forever
fi

echo "== Smoke test (Forever) =="
"$LUA_BIN" tests/smoke.lua forever
for scenario in midnight midnight_missing midnight_secret_identity midnight_secret_booleans midnight_secret_name unknown; do
  echo "== Smoke test ($scenario) =="
  "$LUA_BIN" tests/smoke.lua "$scenario"
done

echo "== Journey instrumentation =="
"$LUA_BIN" tests/journey.lua forever

echo "== Journey queries =="
"$LUA_BIN" tests/journey_queries.lua forever

echo "== Journey block storage =="
"$LUA_BIN" tests/journey_storage.lua forever

echo "== Journey save guard =="
"$LUA_BIN" tests/journey_save_guard.lua forever

echo "== Tooltip/Detail fallback =="
"$LUA_BIN" tests/tooltip_fallback.lua forever

echo "== Journey mob index =="
"$LUA_BIN" tests/journey_index.lua forever

echo "== Mobs list/Overview index switch =="
"$LUA_BIN" tests/list_overview_index.lua forever

echo "== Command index switch =="
"$LUA_BIN" tests/commands_index.lua forever

echo "== Areas/Levels parity =="
"$LUA_BIN" tests/areas_levels_parity.lua forever

echo "== Heatmap bounded query =="
"$LUA_BIN" tests/heatmap_bounded.lua forever

echo "== Area/Level summaries =="
"$LUA_BIN" tests/area_level_summaries.lua forever

echo "== Heatmap render ops =="
"$LUA_BIN" tests/heatmap_render_ops.lua forever

echo "== Heatmap lazy zone =="
"$LUA_BIN" tests/heatmap_lazy_zone.lua forever

echo "== Map overlay audit =="
"$LUA_BIN" tests/map_overlay_audit.lua forever

echo "== History view =="
"$LUA_BIN" tests/history_view.lua forever

echo "== Quest ledger =="
"$LUA_BIN" tests/quest_ledger.lua forever

echo "== Memory policy =="
"$LUA_BIN" tests/mem_policy.lua forever

echo "== Rollback inventory =="
"$LUA_BIN" tests/rollback_inventory.lua forever

echo "== Schema decision =="
"$LUA_BIN" tests/schema_decision.lua forever

echo "== Limit tier =="
"$LUA_BIN" tests/limit_tier.lua forever

echo "== Capacity assessment =="
"$LUA_BIN" tests/capacity_assessment.lua forever

echo "== Context cap =="
"$LUA_BIN" tests/context_cap.lua forever

echo "== Cap boundaries =="
"$LUA_BIN" tests/cap_boundaries.lua forever

echo "== Historical relevance =="
"$LUA_BIN" tests/historical_relevance.lua forever

echo "== Embedded library smoke test =="
"$LUA_BIN" tests/libs_smoke.lua

if command -v luajit >/dev/null 2>&1; then
  echo "== Smoke test (LuaJIT, Forever) =="
  luajit tests/smoke.lua forever
  for scenario in midnight midnight_missing midnight_secret_identity midnight_secret_booleans midnight_secret_name unknown; do
    echo "== Smoke test (LuaJIT, $scenario) =="
    luajit tests/smoke.lua "$scenario"
  done
else
  echo "WARNING: luajit not found; skipped LuaJIT smoke test."
fi

echo "== XML validation =="
if command -v xmllint >/dev/null 2>&1; then
  xmllint --noout embeds.xml
else
  echo "WARNING: xmllint not found; skipped XML validation."
fi

echo "== Layout validation =="
LAYOUT_ARGS=()
if [[ "${STRICT_ROOT:-0}" == "1" ]]; then
  LAYOUT_ARGS+=(--strict-root)
fi
python3 tests/check_layout.py "${LAYOUT_ARGS[@]}"

if [[ "${BUILD_RELEASE:-0}" == "1" ]]; then
  echo "== Build release zip =="
  python3 tests/build_release.py
fi

if [[ "${CHECK_RELEASE:-0}" == "1" && "${SKIP_RELEASE:-0}" != "1" ]]; then
  echo "== Release validation =="
  python3 tests/check_release.py
else
  echo "Release validation skipped; set CHECK_RELEASE=1 when preparing a release."
fi

echo "All offline checks passed."
