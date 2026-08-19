#!/usr/bin/env python3
"""
Generate an exact byte-level patch manifest from the preserved Ricoh filter stages.

Run from the repository root:

    python patches/generate_patchset.py

The script compares:
    original -> patched -> test2 -> final -> final2 -> final3

and writes patches/patchset.json.

No disassembler is required. Every changed byte range records:
- file offset
- original bytes
- replacement bytes
- SHA256 before/after each stage
"""

from __future__ import annotations

import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
MACOS = ROOT / "payload/RicohAficioSPC240DNFilter.app/Contents/MacOS"
OUT = ROOT / "patches/patchset.json"

STAGES = [
    "RicohAficioSPC240DNFilter",
    "RicohAficioSPC240DNFilter-patched",
    "RicohAficioSPC240DNFilter-test2",
    "RicohAficioSPC240DNFilter-final",
    "RicohAficioSPC240DNFilter-final2",
    "RicohAficioSPC240DNFilter-final3",
]

DESCRIPTIONS = {
    "RicohAficioSPC240DNFilter-patched":
        "Bypass the Darling-incompatible NSCalendarDate/destinyDate path.",
    "RicohAficioSPC240DNFilter-test2":
        "Experimental end-of-page/control-flow compatibility stage.",
    "RicohAficioSPC240DNFilter-final":
        "Preserve endPage return state while bypassing incompatible cleanup/control flow.",
    "RicohAficioSPC240DNFilter-final2":
        "Bypass the insertBlankPage path that triggers SIGFPE under Darling.",
    "RicohAficioSPC240DNFilter-final3":
        "Set the successful run return state while retaining the insertBlankPage bypass.",
}

def sha256(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()

def diff_ranges(a: bytes, b: bytes):
    if len(a) != len(b):
        raise SystemExit(
            f"Binary size changed ({len(a)} -> {len(b)} bytes); "
            "this generator expects in-place patches."
        )

    ranges = []
    start = None

    for i, (x, y) in enumerate(zip(a, b)):
        if x != y and start is None:
            start = i
        elif x == y and start is not None:
            ranges.append((start, i))
            start = None

    if start is not None:
        ranges.append((start, len(a)))

    # Merge ranges separated by at most 8 unchanged bytes. This makes instruction-
    # sized patches easier to inspect while still recording exact old/new bytes.
    merged = []
    for s, e in ranges:
        if merged and s - merged[-1][1] <= 8:
            merged[-1] = (merged[-1][0], e)
        else:
            merged.append((s, e))

    return merged

missing = [name for name in STAGES if not (MACOS / name).is_file()]
if missing:
    raise SystemExit("Missing preserved binaries:\n  " + "\n  ".join(missing))

manifest = {
    "format": 1,
    "architecture": "Mach-O universal binary; patches describe file offsets",
    "source": STAGES[0],
    "final": STAGES[-1],
    "stages": [],
}

previous_name = STAGES[0]
previous = (MACOS / previous_name).read_bytes()

for current_name in STAGES[1:]:
    current = (MACOS / current_name).read_bytes()
    changes = []

    for start, end in diff_ranges(previous, current):
        changes.append({
            "offset": start,
            "offset_hex": f"0x{start:x}",
            "length": end - start,
            "before": previous[start:end].hex(),
            "after": current[start:end].hex(),
        })

    manifest["stages"].append({
        "from": previous_name,
        "to": current_name,
        "description": DESCRIPTIONS[current_name],
        "sha256_before": sha256(previous),
        "sha256_after": sha256(current),
        "size": len(current),
        "changes": changes,
    })

    previous_name = current_name
    previous = current

OUT.write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")

print(f"Wrote {OUT.relative_to(ROOT)}")
for stage in manifest["stages"]:
    changed = sum(c["length"] for c in stage["changes"])
    print(
        f"{stage['from']} -> {stage['to']}: "
        f"{len(stage['changes'])} range(s), {changed} changed byte(s)"
    )
