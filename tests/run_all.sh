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

echo "== Smoke test (Forever) =="
"$LUA_BIN" tests/xptooltip_smoke.lua forever
for scenario in midnight midnight_missing midnight_secret_identity midnight_secret_booleans midnight_secret_name unknown; do
  echo "== Smoke test ($scenario) =="
  "$LUA_BIN" tests/xptooltip_smoke.lua "$scenario"
done

echo "== Embedded library smoke test =="
"$LUA_BIN" tests/libs_smoke.lua

if command -v luajit >/dev/null 2>&1; then
  echo "== Smoke test (LuaJIT, Forever) =="
  luajit tests/xptooltip_smoke.lua forever
  for scenario in midnight midnight_missing midnight_secret_identity midnight_secret_booleans midnight_secret_name unknown; do
    echo "== Smoke test (LuaJIT, $scenario) =="
    luajit tests/xptooltip_smoke.lua "$scenario"
  done
else
  echo "WARNING: luajit not found; skipped LuaJIT smoke test."
fi

echo "== XML validation =="
if command -v xmllint >/dev/null 2>&1; then
  xmllint --noout embeds.xml Bindings.xml
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

if [[ "${SKIP_RELEASE:-0}" != "1" ]]; then
  echo "== Release validation =="
  python3 tests/check_release.py
else
  echo "WARNING: SKIP_RELEASE=1; skipped release zip validation."
fi

echo "All offline checks passed."
