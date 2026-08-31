#!/usr/bin/env python3
"""Split and reconstruct the tracked offline ZIP library without Git LFS.

The repository stores regular Git blobs below GitHub's 100 MB per-file limit.
The app and its assets still use one byte-identical ZIP archive, reconstructed
atomically from a checked manifest before a build or runtime archive test.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import sys
import tempfile
import zipfile
from typing import Any

SCHEMA_VERSION = 1
DEFAULT_PART_SIZE = 95_000_000
BUFFER_SIZE = 1024 * 1024


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for block in iter(lambda: handle.read(BUFFER_SIZE), b""):
            digest.update(block)
    return digest.hexdigest()


def safe_name(value: object, field: str) -> str:
    if not isinstance(value, str) or not value or Path(value).name != value:
        raise ValueError(f"Ungültiger {field}-Dateiname: {value!r}")
    return value


def exact_int(value: object, field: str) -> int:
    if not isinstance(value, int) or isinstance(value, bool) or value < 0:
        raise ValueError(f"Ungültiger {field}-Wert: {value!r}")
    return value


def load_manifest(path: Path) -> dict[str, Any]:
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as error:
        raise ValueError(f"Teilmanifest kann nicht gelesen werden: {path}") from error
    if not isinstance(value, dict) or value.get("schema_version") != SCHEMA_VERSION:
        raise ValueError("Teilmanifest hat eine unbekannte Version.")
    archive = value.get("archive")
    parts = value.get("parts")
    if not isinstance(archive, dict) or not isinstance(parts, list) or not parts:
        raise ValueError("Teilmanifest enthält kein Archiv oder keine Teile.")
    safe_name(archive.get("name"), "Archiv")
    exact_int(archive.get("size"), "Archivgröße")
    if not isinstance(archive.get("sha256"), str) or len(archive["sha256"]) != 64:
        raise ValueError("Teilmanifest enthält keine gültige Archiv-Prüfsumme.")
    exact_int(archive.get("entry_count"), "Archiv-Eintraganzahl")
    seen: set[str] = set()
    size_sum = 0
    for index, part in enumerate(parts):
        if not isinstance(part, dict):
            raise ValueError(f"Teilmanifest enthält einen ungültigen Teil bei Index {index}.")
        name = safe_name(part.get("name"), "Teil")
        if not name.startswith(f"{archive['name']}.part-") or name in seen:
            raise ValueError(f"Teilmanifest enthält einen ungültigen oder doppelten Teil: {name}")
        seen.add(name)
        size_sum += exact_int(part.get("size"), "Teilgröße")
        if not isinstance(part.get("sha256"), str) or len(part["sha256"]) != 64:
            raise ValueError(f"Teilmanifest enthält keine gültige Teil-Prüfsumme: {name}")
    if size_sum != archive["size"]:
        raise ValueError("Teilgrößen ergeben nicht die deklarierte Archivgröße.")
    return value


def verify_parts(manifest: dict[str, Any], root: Path) -> None:
    for part in manifest["parts"]:
        path = root / str(part["name"])
        if not path.is_file():
            raise ValueError(f"Offline-Archivteil fehlt: {path}")
        if path.stat().st_size != part["size"]:
            raise ValueError(f"Offline-Archivteil hat eine falsche Größe: {path.name}")
        if sha256(path) != part["sha256"]:
            raise ValueError(f"Offline-Archivteil hat eine falsche Prüfsumme: {path.name}")


def verify_archive(path: Path, archive: dict[str, Any]) -> None:
    if not path.is_file():
        raise ValueError(f"Offline-Archiv fehlt: {path}")
    if path.stat().st_size != archive["size"]:
        raise ValueError("Offline-Archiv hat nicht die deklarierte Größe.")
    if sha256(path) != archive["sha256"]:
        raise ValueError("Offline-Archiv hat nicht die deklarierte Prüfsumme.")
    try:
        with zipfile.ZipFile(path) as bundle:
            if len(bundle.infolist()) != archive["entry_count"]:
                raise ValueError("Offline-Archiv hat nicht die deklarierte Eintraganzahl.")
    except zipfile.BadZipFile as error:
        raise ValueError("Offline-Archiv ist keine valide ZIP-Datei.") from error


def atomic_json(path: Path, payload: dict[str, Any]) -> None:
    temporary = path.with_name(path.name + ".part")
    temporary.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    os.replace(temporary, path)


def split_archive(input_path: Path, manifest_path: Path, part_size: int, archive_name: str | None) -> None:
    if not input_path.is_file():
        raise ValueError(f"Offline-Archivquelle fehlt: {input_path}")
    if part_size <= 0 or part_size >= 100_000_000:
        raise ValueError("Teilgröße muss positiv und kleiner als 100.000.000 Byte sein.")
    try:
        with zipfile.ZipFile(input_path) as bundle:
            entry_count = len(bundle.infolist())
    except zipfile.BadZipFile as error:
        raise ValueError("Offline-Archivquelle ist keine valide ZIP-Datei.") from error
    archive_name = safe_name(archive_name or input_path.name, "Archiv")
    manifest_path.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix="offline-archive-parts-", dir=str(manifest_path.parent)) as temporary_name:
        temporary = Path(temporary_name)
        part_entries: list[dict[str, Any]] = []
        with input_path.open("rb") as source:
            index = 0
            while True:
                name = f"{archive_name}.part-{index:03d}"
                staged = temporary / name
                written = 0
                with staged.open("wb") as output:
                    while written < part_size:
                        block = source.read(min(BUFFER_SIZE, part_size - written))
                        if not block:
                            break
                        output.write(block)
                        written += len(block)
                if written == 0:
                    staged.unlink()
                    break
                part_entries.append({"name": name, "size": written, "sha256": sha256(staged)})
                index += 1
        payload = {
            "schema_version": SCHEMA_VERSION,
            "purpose": "Git-native split source for the byte-identical offline Ogg/Opus ZIP library; no Git LFS required.",
            "archive": {
                "name": archive_name,
                "size": input_path.stat().st_size,
                "sha256": sha256(input_path),
                "entry_count": entry_count,
            },
            "part_size_bytes": part_size,
            "parts": part_entries,
        }
        validated = load_manifest_from_value(payload)
        for part in validated["parts"]:
            staged = temporary / str(part["name"])
            destination = manifest_path.parent / str(part["name"])
            replacement = destination.with_name(destination.name + ".part")
            shutil.copyfile(staged, replacement)
            os.replace(replacement, destination)
        expected = {str(part["name"]) for part in validated["parts"]}
        for old in manifest_path.parent.glob(f"{archive_name}.part-*"):
            if old.name not in expected:
                old.unlink()
        atomic_json(manifest_path, payload)
    print(json.dumps({"mode": "split", "manifest": str(manifest_path), "archive": payload["archive"], "parts": len(part_entries)}, ensure_ascii=False))


def load_manifest_from_value(value: dict[str, Any]) -> dict[str, Any]:
    with tempfile.TemporaryDirectory(prefix="offline-archive-manifest-") as temporary_name:
        path = Path(temporary_name) / "manifest.json"
        path.write_text(json.dumps(value), encoding="utf-8")
        return load_manifest(path)


def assemble_archive(manifest_path: Path, output_path: Path | None) -> None:
    manifest = load_manifest(manifest_path)
    archive = manifest["archive"]
    root = manifest_path.parent
    output = output_path or root / str(archive["name"])
    verify_parts(manifest, root)
    try:
        verify_archive(output, archive)
        print(json.dumps({"mode": "assemble", "archive": str(output), "status": "already_valid", "parts": len(manifest["parts"])}, ensure_ascii=False))
        return
    except ValueError:
        pass
    output.parent.mkdir(parents=True, exist_ok=True)
    temporary = output.with_name(output.name + ".part")
    temporary.unlink(missing_ok=True)
    try:
        with temporary.open("wb") as destination:
            for part in manifest["parts"]:
                with (root / str(part["name"])).open("rb") as source:
                    shutil.copyfileobj(source, destination, length=BUFFER_SIZE)
        verify_archive(temporary, archive)
        os.replace(temporary, output)
    except Exception:
        temporary.unlink(missing_ok=True)
        raise
    print(json.dumps({"mode": "assemble", "archive": str(output), "status": "assembled", "parts": len(manifest["parts"])}, ensure_ascii=False))


def verify(manifest_path: Path, archive_path: Path | None) -> None:
    manifest = load_manifest(manifest_path)
    verify_parts(manifest, manifest_path.parent)
    if archive_path is not None:
        verify_archive(archive_path, manifest["archive"])
    print(json.dumps({"mode": "verify", "parts": len(manifest["parts"]), "archive_verified": archive_path is not None}, ensure_ascii=False))


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    subparsers = parser.add_subparsers(dest="command", required=True)
    split = subparsers.add_parser("split", help="Split a verified archive into tracked regular Git blobs")
    split.add_argument("--input", required=True, type=Path)
    split.add_argument("--manifest", required=True, type=Path)
    split.add_argument("--part-size", type=int, default=DEFAULT_PART_SIZE)
    split.add_argument("--archive-name", default=None)
    assemble = subparsers.add_parser("assemble", help="Atomically reconstruct the ignored archive from tracked parts")
    assemble.add_argument("--manifest", required=True, type=Path)
    assemble.add_argument("--output", type=Path, default=None)
    verify_parser = subparsers.add_parser("verify", help="Verify parts and optionally a reconstructed archive")
    verify_parser.add_argument("--manifest", required=True, type=Path)
    verify_parser.add_argument("--archive", type=Path, default=None)
    args = parser.parse_args()
    try:
        if args.command == "split":
            split_archive(args.input.resolve(), args.manifest.resolve(), args.part_size, args.archive_name)
        elif args.command == "assemble":
            assemble_archive(args.manifest.resolve(), args.output.resolve() if args.output else None)
        else:
            verify(args.manifest.resolve(), args.archive.resolve() if args.archive else None)
    except ValueError as error:
        print(f"Fehler: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
