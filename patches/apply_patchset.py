#!/usr/bin/env python3
"""
Rebuild every preserved patched Ricoh filter stage from the untouched original.

Usage from repository root:

    python patches/apply_patchset.py

Generated files are placed in:
    build/patched-filters/

The script refuses to patch an unexpected source binary and validates SHA256
after every stage.
"""

from __future__ import annotations

import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
MACOS = ROOT / "payload/RicohAficioSPC240DNFilter.app/Contents/MacOS"
MANIFEST = ROOT / "patches/patchset.json"
BUILD = ROOT / "build/patched-filters"

def sha256(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()

if not MANIFEST.is_file():
    raise SystemExit(
        "patches/patchset.json is missing.\n"
        "Generate it first with: python patches/generate_patchset.py"
    )

m = json.loads(MANIFEST.read_text(encoding="utf-8"))
source_path = MACOS / m["source"]

if not source_path.is_file():
    raise SystemExit(f"Original binary not found: {source_path}")

data = bytearray(source_path.read_bytes())
expected_source_hash = m["stages"][0]["sha256_before"]

if sha256(data) != expected_source_hash:
    raise SystemExit(
        "Original binary SHA256 does not match patchset.json.\n"
        f"Expected: {expected_source_hash}\n"
        f"Actual:   {sha256(data)}"
    )

BUILD.mkdir(parents=True, exist_ok=True)

for stage in m["stages"]:
    if sha256(data) != stage["sha256_before"]:
        raise SystemExit(f"Pre-patch SHA256 mismatch before {stage['to']}")

    for change in stage["changes"]:
        off = int(change["offset"])
        before = bytes.fromhex(change["before"])
        after = bytes.fromhex(change["after"])

        actual = bytes(data[off:off + len(before)])
        if actual != before:
            raise SystemExit(
                f"Byte mismatch at {change['offset_hex']} while creating "
                f"{stage['to']}.\nExpected: {before.hex()}\nActual:   {actual.hex()}"
            )

        data[off:off + len(after)] = after

    actual_hash = sha256(data)
    if actual_hash != stage["sha256_after"]:
        raise SystemExit(
            f"Post-patch SHA256 mismatch for {stage['to']}.\n"
            f"Expected: {stage['sha256_after']}\nActual:   {actual_hash}"
        )

    target = BUILD / stage["to"]
    target.write_bytes(data)
    target.chmod(0o755)
    print(f"OK  {target.relative_to(ROOT)}  {actual_hash}")

print("\nAll stages reproduced byte-for-byte.")
