#!/usr/bin/env python3
"""Regression test for Git-native offline archive split/reassembly."""
from __future__ import annotations

import hashlib
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
import zipfile

ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / "tool" / "offline_archive_parts.py"


class OfflineArchivePartsTest(unittest.TestCase):
    def test_split_assemble_and_tamper_rejection(self) -> None:
        with tempfile.TemporaryDirectory() as temporary_name:
            temporary = Path(temporary_name)
            archive = temporary / "input.zip"
            with zipfile.ZipFile(archive, "w", compression=zipfile.ZIP_STORED) as bundle:
                bundle.writestr("site/test.opus", bytes(range(251)) * 4)
                bundle.writestr("site/second.opus", b"OggS" + bytes(range(83)))
            parts_dir = temporary / "parts"
            manifest = parts_dir / "offline.parts.json"
            subprocess.run([
                sys.executable, str(SCRIPT), "split", "--input", str(archive),
                "--manifest", str(manifest), "--part-size", "100",
                "--archive-name", "offline.zip",
            ], check=True, capture_output=True, text=True)
            payload = json.loads(manifest.read_text(encoding="utf-8"))
            self.assertEqual(1, payload["schema_version"])
            self.assertEqual(hashlib.sha256(archive.read_bytes()).hexdigest(), payload["archive"]["sha256"])
            self.assertGreater(len(payload["parts"]), 1)
            archive.unlink()
            subprocess.run([
                sys.executable, str(SCRIPT), "assemble", "--manifest", str(manifest),
            ], check=True, capture_output=True, text=True)
            assembled = parts_dir / "offline.zip"
            self.assertEqual(hashlib.sha256(assembled.read_bytes()).hexdigest(), payload["archive"]["sha256"])
            subprocess.run([
                sys.executable, str(SCRIPT), "verify", "--manifest", str(manifest), "--archive", str(assembled),
            ], check=True, capture_output=True, text=True)
            first_part = parts_dir / payload["parts"][0]["name"]
            first_part.write_bytes(b"corrupted")
            rejected = subprocess.run([
                sys.executable, str(SCRIPT), "verify", "--manifest", str(manifest),
            ], capture_output=True, text=True, check=False)
            self.assertNotEqual(0, rejected.returncode)
            self.assertTrue(rejected.stderr.startswith("Fehler: Offline-Archivteil hat eine falsche"))


if __name__ == "__main__":
    unittest.main()
