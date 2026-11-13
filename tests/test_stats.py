#!/usr/bin/env python3
"""Print focused-test size statistics for the offline runner."""
from __future__ import annotations

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
FILES = (ROOT / "tests" / "smoke.lua", ROOT / "tests" / "fixtures.lua")
ASSERT_RE = re.compile(r"\bassert\s*\(")

total_asserts = 0
total_lines = 0
for path in FILES:
    if not path.is_file():
        print(f"missing {path.relative_to(ROOT)}")
        continue
    text = path.read_text(encoding="utf-8")
    asserts = len(ASSERT_RE.findall(text))
    lines = len(text.splitlines())
    total_asserts += asserts
    total_lines += lines
    print(f"{path.relative_to(ROOT)}: {asserts} assertions, {lines} lines")
print(f"total: {total_asserts} static assertions, {total_lines} lines")
