#!/usr/bin/env python3
"""Regression test for reproducible curated Im-Zug Opus rendering."""
from __future__ import annotations

import hashlib
import json
from pathlib import Path
import subprocess
import tempfile
import unittest
import wave
from typing import Any


ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / "scripts" / "build_opus_intrain_assets.py"


def make_pcm16_wav(path: Path, frames: int) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with wave.open(str(path), "wb") as output:
        output.setnchannels(1)
        output.setsampwidth(2)
        output.setframerate(16_000)
        output.writeframes(b"\0\0" * frames)


def digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


class BuildOpusInTrainAssetsTest(unittest.TestCase):
    def test_renders_reproducible_opus_assets_and_manifest(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            source = root / "source"
            make_pcm16_wav(source / "station_name_only" / "station_name_test.wav", 4_000)
            make_pcm16_wav(source / "text" / "gong_start.wav", 2_000)

            outputs: list[Path] = []
            manifests: list[dict[str, Any]] = []
            for index in (1, 2):
                assets = root / f"assets-{index}"
                manifest = root / f"manifest-{index}.json"
                completed = subprocess.run(
                    ["python3", str(SCRIPT), "--source-dir", str(source), "--assets-dir", str(assets), "--manifest", str(manifest), "--bitrate", "32k"],
                    text=True,
                    stdout=subprocess.PIPE,
                    stderr=subprocess.PIPE,
                    check=False,
                )
                self.assertEqual(0, completed.returncode, completed.stderr)
                self.assertTrue((assets / "station_name_only" / "station_name_test.opus").is_file())
                self.assertTrue((assets / "text" / "gong_start.opus").is_file())
                self.assertFalse(any(assets.rglob("*.wav")))
                outputs.append(assets)
                manifests.append(json.loads(manifest.read_text(encoding="utf-8")))

            self.assertEqual("ogg-opus", manifests[0]["format"])
            self.assertEqual(2, manifests[0]["entry_count"])
            self.assertEqual(1, manifests[0]["station_count"])
            self.assertEqual(1, manifests[0]["text_count"])
            self.assertEqual(
                digest(outputs[0] / "station_name_only" / "station_name_test.opus"),
                digest(outputs[1] / "station_name_only" / "station_name_test.opus"),
            )
            self.assertEqual(
                digest(outputs[0] / "text" / "gong_start.opus"),
                digest(outputs[1] / "text" / "gong_start.opus"),
            )
            for entry in list(manifests[0]["entries"]):
                target = outputs[0] / str(entry["target"])
                self.assertEqual(b"OggS", target.read_bytes()[:4])
                self.assertEqual("opus", entry["target_audio"]["codec"])
                self.assertEqual(digest(target), entry["target_sha256"])


if __name__ == "__main__":
    unittest.main()
