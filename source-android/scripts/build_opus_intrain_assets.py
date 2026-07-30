#!/usr/bin/env python3
"""Build compact, reproducible Ogg/Opus assets for the native Im-Zug playlist.

The WAV source tree is intentionally separate from the packaged APK assets. Each
already-cut source is rendered independently; no trimming, denoising or loudness
processing is applied. Output clips use 32-kbit/s Ogg/Opus and retain their
relative `station_name_only/` or `text/` asset path.
"""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import shutil
import struct
import subprocess
import tempfile
from typing import Any


OGG_CRC_TABLE: tuple[int, ...] | None = None
ALLOWED_TOP_LEVEL = {"station_name_only", "text"}


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as source:
        for chunk in iter(lambda: source.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def probe(path: Path) -> dict[str, Any]:
    completed = subprocess.run(
        [
            "ffprobe", "-v", "error", "-select_streams", "a:0",
            "-show_entries", "stream=codec_name,sample_rate,channels,bits_per_sample:format=duration",
            "-of", "json", str(path),
        ],
        check=True,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )
    data = json.loads(completed.stdout)
    streams = data.get("streams", [])
    if len(streams) != 1:
        raise RuntimeError(f"Genau eine Audiospur erwartet: {path}")
    stream = streams[0]
    return {
        "codec": stream.get("codec_name"),
        "sample_rate": int(stream.get("sample_rate", 0)),
        "channels": int(stream.get("channels", 0)),
        "bits_per_sample": int(stream.get("bits_per_sample", 0)),
        "duration_seconds": round(float(data.get("format", {}).get("duration", 0)), 6),
    }


def ogg_crc(data: bytes | bytearray) -> int:
    global OGG_CRC_TABLE
    if OGG_CRC_TABLE is None:
        table = []
        for value in range(256):
            remainder = value << 24
            for _ in range(8):
                remainder = ((remainder << 1) ^ 0x04C11DB7) & 0xffffffff if remainder & 0x80000000 else (remainder << 1) & 0xffffffff
            table.append(remainder)
        OGG_CRC_TABLE = tuple(table)
    checksum = 0
    for value in data:
        checksum = ((checksum << 8) & 0xffffffff) ^ OGG_CRC_TABLE[((checksum >> 24) & 0xff) ^ value]
    return checksum


def canonicalize_ogg(path: Path, asset_path: str) -> None:
    """Makes FFmpeg's random Ogg stream serial deterministic and fixes CRCs."""
    data = bytearray(path.read_bytes())
    serial = int.from_bytes(hashlib.sha256(asset_path.encode("utf-8")).digest()[:4], "little") or 1
    cursor = 0
    pages = 0
    while cursor < len(data):
        if cursor + 27 > len(data) or data[cursor:cursor + 4] != b"OggS" or data[cursor + 4] != 0:
            raise RuntimeError(f"Ungültige Ogg-Seite: {path}")
        segment_count = data[cursor + 26]
        header_end = cursor + 27 + segment_count
        if header_end > len(data):
            raise RuntimeError(f"Abgeschnittene Ogg-Segmenttabelle: {path}")
        body_end = header_end + sum(data[cursor + 27:header_end])
        if body_end > len(data):
            raise RuntimeError(f"Abgeschnittener Ogg-Datenbereich: {path}")
        data[cursor + 14:cursor + 18] = struct.pack("<I", serial)
        data[cursor + 22:cursor + 26] = b"\x00\x00\x00\x00"
        data[cursor + 22:cursor + 26] = struct.pack("<I", ogg_crc(data[cursor:body_end]))
        cursor = body_end
        pages += 1
    if pages == 0 or cursor != len(data):
        raise RuntimeError(f"Unvollständiger Ogg-Stream: {path}")
    path.write_bytes(data)


def opus_target_path(relative_wav: Path) -> Path:
    if relative_wav.suffix.lower() != ".wav" or len(relative_wav.parts) < 2 or relative_wav.parts[0] not in ALLOWED_TOP_LEVEL:
        raise ValueError(f"Nicht erlaubter Im-Zug-WAV-Pfad: {relative_wav}")
    return relative_wav.with_suffix(".opus")


def discover_sources(source_dir: Path) -> list[Path]:
    wavs = sorted(path for path in source_dir.rglob("*.wav") if path.is_file())
    if not wavs:
        raise RuntimeError(f"Keine WAV-Quellen gefunden: {source_dir}")
    relative = [path.relative_to(source_dir) for path in wavs]
    targets = [opus_target_path(path) for path in relative]
    if len(set(targets)) != len(targets):
        raise RuntimeError("Doppelte Zielpfade im Im-Zug-Quellbaum.")
    return relative


def convert(source: Path, target: Path, asset_path: str, bitrate: str) -> None:
    target.parent.mkdir(parents=True, exist_ok=True)
    temporary = target.with_suffix(target.suffix + ".part")
    temporary.unlink(missing_ok=True)
    completed = subprocess.run(
        [
            "ffmpeg", "-nostdin", "-hide_banner", "-loglevel", "error", "-y",
            "-i", str(source), "-map", "0:a:0", "-map_metadata", "-1",
            "-c:a", "libopus", "-application", "voip", "-b:a", bitrate, "-vbr", "on",
            "-ar", "16000", "-ac", "1", "-f", "ogg", str(temporary),
        ],
        check=False,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.PIPE,
    )
    if completed.returncode != 0:
        temporary.unlink(missing_ok=True)
        raise RuntimeError(f"Opus-Konvertierung fehlgeschlagen ({source.name}): {completed.stderr.decode('utf-8', 'replace').strip()}")
    canonicalize_ogg(temporary, asset_path)
    subprocess.run(["ffmpeg", "-nostdin", "-v", "error", "-i", str(temporary), "-f", "null", "-"], check=True, stdout=subprocess.DEVNULL, stderr=subprocess.PIPE)
    temporary.replace(target)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source-dir", type=Path, required=True, help="Privater WAV-Quellbaum mit station_name_only/ und text/")
    parser.add_argument("--assets-dir", type=Path, required=True, help="APK-Assetordner inzug/")
    parser.add_argument("--manifest", type=Path, required=True, help="Zu schreibendes Opus-Importmanifest")
    parser.add_argument("--bitrate", choices=("16k", "24k", "32k"), default="32k")
    args = parser.parse_args()

    source_dir = args.source_dir.resolve()
    assets_dir = args.assets_dir.resolve()
    manifest_path = args.manifest.resolve()
    if not source_dir.is_dir():
        raise SystemExit(f"WAV-Quellbaum fehlt: {source_dir}")
    sources = discover_sources(source_dir)

    with tempfile.TemporaryDirectory(prefix="inzug-opus-", dir=str(assets_dir.parent)) as temporary_dir:
        rendered_root = Path(temporary_dir) / "rendered"
        entries: list[dict[str, Any]] = []
        for relative_wav in sources:
            source = source_dir / relative_wav
            source_audio = probe(source)
            if source_audio["codec"] != "pcm_s16le" or source_audio["bits_per_sample"] != 16:
                raise RuntimeError(f"Keine PCM-16-WAV-Quelle: {relative_wav}")
            relative_opus = opus_target_path(relative_wav)
            output = rendered_root / relative_opus
            convert(source, output, relative_opus.as_posix(), args.bitrate)
            target_audio = probe(output)
            if target_audio["codec"] != "opus" or target_audio["channels"] != 1:
                raise RuntimeError(f"Falsches Opus-Zielformat: {relative_opus} -> {target_audio}")
            if abs(float(source_audio["duration_seconds"]) - float(target_audio["duration_seconds"])) > 0.030:
                raise RuntimeError(f"Unerwartet abweichende Dauer nach Opus-Konvertierung: {relative_wav}")
            entries.append({
                "source": relative_wav.as_posix(),
                "target": relative_opus.as_posix(),
                "kind": "station" if relative_opus.parts[0] == "station_name_only" else "text",
                "source_sha256": sha256(source),
                "source_audio": source_audio,
                "target_sha256": sha256(output),
                "target_audio": target_audio,
            })

        for old_wav in assets_dir.rglob("*.wav"):
            old_wav.unlink()
        for old_opus in assets_dir.rglob("*.opus"):
            old_opus.unlink()
        for entry in entries:
            rendered = rendered_root / entry["target"]
            target = assets_dir / entry["target"]
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(rendered, target)
            if sha256(target) != entry["target_sha256"]:
                raise RuntimeError(f"Kopierprüfung fehlgeschlagen: {entry['target']}")

    station_count = sum(entry["kind"] == "station" for entry in entries)
    text_count = sum(entry["kind"] == "text" for entry in entries)
    source_wav_bytes = sum((source_dir / Path(entry["source"])).stat().st_size for entry in entries)
    opus_bytes = sum((assets_dir / Path(entry["target"])).stat().st_size for entry in entries)
    manifest = {
        "schema_version": 2,
        "purpose": "Curated Rhein-Ruhr original-voice in-train assets for the native playlist.",
        "format": "ogg-opus",
        "bitrate": args.bitrate,
        "processing": "Boundary-preserving Ogg/Opus transcode only: 16 kHz mono input, no trimming, denoising or loudness processing.",
        "entry_count": len(entries),
        "station_count": station_count,
        "text_count": text_count,
        "source_wav_bytes": source_wav_bytes,
        "opus_bytes": opus_bytes,
        "entries": entries,
    }
    manifest_path.parent.mkdir(parents=True, exist_ok=True)
    manifest_path.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({
        "entries": len(entries), "stations": station_count, "text": text_count,
        "source_wav_bytes": source_wav_bytes, "opus_bytes": opus_bytes,
        "saved_bytes": source_wav_bytes - opus_bytes, "manifest": str(manifest_path),
    }, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
