#!/usr/bin/env python3
"""Build the compact, direct-readable Ogg/Opus offline library.

The source is the verified official ZIP, already joined from its two release
parts. Each WAV is transcoded independently to 16 kHz mono Ogg/Opus and then
stored (not deflated again) in a single ZIP asset. Storing Ogg entries keeps
Android's direct ZIP reader fast and avoids useless nested compression.
"""

from __future__ import annotations

import argparse
import concurrent.futures
import hashlib
import json
import os
from pathlib import Path
import shutil
import struct
import subprocess
import sys
import time
import zipfile

_SOURCE_ZIP: zipfile.ZipFile | None = None
_STAGING_ROOT: Path | None = None
_BITRATE: str = "32k"
_OGG_CRC_TABLE: tuple[int, ...] | None = None


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as source:
        for chunk in iter(lambda: source.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def init_worker(source_zip: str, staging_root: str, bitrate: str) -> None:
    global _SOURCE_ZIP, _STAGING_ROOT, _BITRATE
    _SOURCE_ZIP = zipfile.ZipFile(source_zip, "r")
    _STAGING_ROOT = Path(staging_root)
    _BITRATE = bitrate


def opus_relative_path(wav_entry: str) -> str:
    if not wav_entry.startswith("site/") or not wav_entry.lower().endswith(".wav"):
        raise ValueError(f"Unexpected source entry: {wav_entry}")
    return wav_entry[:-4] + ".opus"


def ogg_crc(data: bytes | bytearray) -> int:
    global _OGG_CRC_TABLE
    if _OGG_CRC_TABLE is None:
        table = []
        for value in range(256):
            remainder = value << 24
            for _ in range(8):
                remainder = ((remainder << 1) ^ 0x04C11DB7) & 0xffffffff if remainder & 0x80000000 else (remainder << 1) & 0xffffffff
            table.append(remainder)
        _OGG_CRC_TABLE = tuple(table)
    checksum = 0
    for value in data:
        checksum = ((checksum << 8) & 0xffffffff) ^ _OGG_CRC_TABLE[((checksum >> 24) & 0xff) ^ value]
    return checksum


def canonicalize_ogg(path: Path, archive_name: str) -> None:
    """Replace ffmpeg's random Ogg serial with a stable per-entry value."""
    data = bytearray(path.read_bytes())
    serial = int.from_bytes(hashlib.sha256(archive_name.encode("utf-8")).digest()[:4], "little") or 1
    cursor = 0
    pages = 0
    while cursor < len(data):
        if cursor + 27 > len(data) or data[cursor:cursor + 4] != b"OggS" or data[cursor + 4] != 0:
            raise ValueError(f"Invalid Ogg page in {path}")
        segments = data[cursor + 26]
        header_end = cursor + 27 + segments
        if header_end > len(data):
            raise ValueError(f"Truncated Ogg lacing table in {path}")
        body_end = header_end + sum(data[cursor + 27:header_end])
        if body_end > len(data):
            raise ValueError(f"Truncated Ogg body in {path}")
        data[cursor + 14:cursor + 18] = struct.pack("<I", serial)
        data[cursor + 22:cursor + 26] = b"\x00\x00\x00\x00"
        data[cursor + 22:cursor + 26] = struct.pack("<I", ogg_crc(data[cursor:body_end]))
        cursor = body_end
        pages += 1
    if cursor != len(data) or pages == 0:
        raise ValueError(f"Ogg stream has no complete pages: {path}")
    path.write_bytes(data)


def transcode_entry(wav_entry: str) -> tuple[str, int]:
    if _SOURCE_ZIP is None or _STAGING_ROOT is None:
        raise RuntimeError("Worker is not initialized")
    opus_relative = opus_relative_path(wav_entry)
    output = _STAGING_ROOT / opus_relative
    output.parent.mkdir(parents=True, exist_ok=True)
    temporary = output.with_suffix(output.suffix + ".part")
    if output.is_file() and output.stat().st_size > 0:
        return opus_relative, output.stat().st_size
    wav = _SOURCE_ZIP.read(wav_entry)
    result = subprocess.run(
        [
            "ffmpeg", "-nostdin", "-hide_banner", "-loglevel", "error", "-y",
            "-f", "wav", "-i", "pipe:0",
            "-map_metadata", "-1",
            "-c:a", "libopus", "-application", "voip",
            "-b:a", _BITRATE, "-vbr", "on",
            "-ar", "16000", "-ac", "1",
            "-f", "ogg", str(temporary),
        ],
        input=wav,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.PIPE,
        check=False,
    )
    if result.returncode != 0:
        temporary.unlink(missing_ok=True)
        raise RuntimeError(f"ffmpeg failed for {wav_entry}: {result.stderr.decode('utf-8', 'replace').strip()}")
    temporary.replace(output)
    return opus_relative, output.stat().st_size


def archive_opus(staging_root: Path, output_zip: Path) -> int:
    temporary = output_zip.with_suffix(output_zip.suffix + ".part")
    temporary.unlink(missing_ok=True)
    entries = sorted(path for path in staging_root.rglob("*.opus") if path.is_file())
    # Fixed ZIP metadata keeps the generated library byte-reproducible for a
    # fixed source ZIP, encoder version and bitrate. Ogg is already compressed,
    # so entries deliberately use ZIP_STORED.
    with zipfile.ZipFile(temporary, "w", compression=zipfile.ZIP_STORED, allowZip64=True) as archive:
        for index, path in enumerate(entries, start=1):
            archive_name = path.relative_to(staging_root).as_posix()
            canonicalize_ogg(path, archive_name)
            info = zipfile.ZipInfo(archive_name, date_time=(2026, 7, 14, 0, 0, 0))
            info.compress_type = zipfile.ZIP_STORED
            info.create_system = 3
            info.external_attr = 0o100644 << 16
            info.file_size = path.stat().st_size
            with path.open("rb") as source, archive.open(info, "w") as target:
                shutil.copyfileobj(source, target, 1024 * 1024)
            if index % 5000 == 0:
                print(f"archive: {index}/{len(entries)}", flush=True)
    temporary.replace(output_zip)
    return len(entries)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--source-zip", type=Path, required=True, help="Combined official WAV ZIP")
    parser.add_argument("--staging", type=Path, required=True, help="Directory for generated Ogg/Opus entries")
    parser.add_argument("--output", type=Path, required=True, help="Single stored ZIP asset to create")
    parser.add_argument("--manifest", type=Path, required=True, help="JSON build manifest")
    parser.add_argument("--bitrate", default="32k", choices=("16k", "24k", "32k"))
    parser.add_argument("--workers", type=int, default=max(1, min(12, os.cpu_count() or 1)))
    parser.add_argument("--limit", type=int, default=0, help="Only encode N entries (smoke test)")
    parser.add_argument("--archive-only", action="store_true", help="Package an already complete staging directory without encoding")
    parser.add_argument("--clean", action="store_true", help="Delete staging before conversion")
    args = parser.parse_args()

    if not args.source_zip.is_file():
        raise SystemExit(f"Source ZIP is missing: {args.source_zip}")
    if args.clean and args.archive_only:
        raise SystemExit("--clean and --archive-only cannot be combined")
    if args.clean:
        shutil.rmtree(args.staging, ignore_errors=True)
    args.staging.mkdir(parents=True, exist_ok=True)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.manifest.parent.mkdir(parents=True, exist_ok=True)

    with zipfile.ZipFile(args.source_zip, "r") as source:
        wav_entries = sorted(item.filename for item in source.infolist() if not item.is_dir() and item.filename.startswith("site/") and item.filename.lower().endswith(".wav"))
    if not wav_entries:
        raise SystemExit("No WAV entries found in source ZIP")
    if args.limit > 0:
        wav_entries = wav_entries[:args.limit]

    started = time.monotonic()
    if args.archive_only:
        opus_paths = sorted(path for path in args.staging.rglob("*.opus") if path.is_file())
        if len(opus_paths) != len(wav_entries):
            raise SystemExit(f"Staging is incomplete: expected {len(wav_entries)} Opus files, found {len(opus_paths)}")
        output_bytes = sum(path.stat().st_size for path in opus_paths)
    else:
        output_bytes = 0
        completed = 0
        with concurrent.futures.ProcessPoolExecutor(
            max_workers=args.workers,
            initializer=init_worker,
            initargs=(str(args.source_zip), str(args.staging), args.bitrate),
        ) as executor:
            futures = [executor.submit(transcode_entry, entry) for entry in wav_entries]
            for future in concurrent.futures.as_completed(futures):
                _, size = future.result()
                output_bytes += size
                completed += 1
                if completed % 500 == 0 or completed == len(wav_entries):
                    elapsed = max(0.001, time.monotonic() - started)
                    rate = completed / elapsed
                    remaining = (len(wav_entries) - completed) / rate
                    print(f"encode: {completed}/{len(wav_entries)} · {rate:.1f} files/s · eta {remaining / 60:.1f} min", flush=True)

    entry_count = archive_opus(args.staging, args.output)
    manifest = {
        "format": "ogg-opus",
        "bitrate": args.bitrate,
        "source_zip": str(args.source_zip),
        "source_zip_sha256": sha256(args.source_zip),
        "source_wav_count": len(wav_entries),
        "opus_entry_count": entry_count,
        "opus_staging_bytes": output_bytes,
        "archive": str(args.output),
        "archive_bytes": args.output.stat().st_size,
        "archive_sha256": sha256(args.output),
        "elapsed_seconds": round(time.monotonic() - started, 3),
    }
    args.manifest.write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(json.dumps(manifest, indent=2, sort_keys=True), flush=True)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
