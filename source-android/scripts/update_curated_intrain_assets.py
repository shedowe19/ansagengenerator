#!/usr/bin/env python3
"""Incrementally replace selected bundled Im-Zug assets from user-curated WAVs.

The importer preserves editorial boundaries. It normalizes only the selected
WAVs to PCM s16le / mono / 16 kHz under the private source tree, renders
reproducible 32-kbit/s Ogg/Opus, then transactionally replaces only the planned
APK assets and their manifest records. Unrelated curated assets are untouched.
"""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path, PurePosixPath
import shutil
import subprocess
import sys
import tempfile
from typing import Any, cast

from build_opus_intrain_assets import convert, probe, sha256

ALLOWED_TOP_LEVEL = {"station_name_only", "text"}
PLAN_SCHEMA_VERSION = 1


def load_json(path: Path) -> Any:
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as error:
        raise RuntimeError(f"JSON kann nicht gelesen werden: {path}") from error


def atomic_write_json(path: Path, data: Any) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_suffix(path.suffix + ".part")
    temporary.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    temporary.replace(path)


def safe_target(value: object) -> PurePosixPath:
    if not isinstance(value, str):
        raise RuntimeError("Im-Zug-Zielpfad fehlt.")
    path = PurePosixPath(value)
    if (
        path.is_absolute()
        or len(path.parts) != 2
        or path.parts[0] not in ALLOWED_TOP_LEVEL
        or path.parts[1] != path.name
        or not path.name.startswith("station_name_") and path.parts[0] == "station_name_only"
        or path.suffix != ".opus"
    ):
        raise RuntimeError(f"Nicht erlaubter Im-Zug-Zielpfad: {value}")
    return path


def load_plan(path: Path) -> list[dict[str, str]]:
    plan = load_json(path)
    if not isinstance(plan, dict) or plan.get("schema_version") != PLAN_SCHEMA_VERSION:
        raise RuntimeError("Importplan hat eine unbekannte Version.")
    entries = plan.get("entries")
    if not isinstance(entries, list) or not entries:
        raise RuntimeError("Importplan enthält keine Einträge.")
    targets: set[str] = set()
    sources: set[str] = set()
    normalized: list[dict[str, str]] = []
    for raw in entries:
        if not isinstance(raw, dict):
            raise RuntimeError("Importplan enthält einen ungültigen Eintrag.")
        source_value = raw.get("source")
        target_value = raw.get("target")
        role_value = raw.get("role")
        label_value = raw.get("label")
        if (
            not isinstance(source_value, str)
            or not isinstance(target_value, str)
            or not isinstance(role_value, str)
            or not isinstance(label_value, str)
            or not source_value.strip()
            or not target_value.strip()
            or not role_value.strip()
            or not label_value.strip()
        ):
            raise RuntimeError("Importplan-Eintrag ist unvollständig.")
        source: str = source_value
        target: str = target_value
        role: str = role_value
        label: str = label_value
        if Path(source).name != source or Path(source).suffix.lower() != ".wav":
            raise RuntimeError(f"Ungültiger Quellname im Importplan: {source}")
        target_path = safe_target(target)
        expected_role = "station" if target_path.parts[0] == "station_name_only" else "hinweis"
        if role != expected_role:
            raise RuntimeError(f"Rolle passt nicht zum Zielpfad: {source}")
        if target in targets or source in sources:
            raise RuntimeError(f"Doppelter Quell- oder Zielpfad im Importplan: {source}")
        targets.add(target)
        sources.add(source)
        normalized.append({"source": source, "target": target, "role": role, "label": label})
    return normalized


def command_error(command: list[str], output: subprocess.CompletedProcess[bytes]) -> RuntimeError:
    details = output.stderr.decode("utf-8", "replace").strip()
    return RuntimeError(f"Audio-Normalisierung fehlgeschlagen: {' '.join(command[:2])}: {details}")


def normalize(source: Path, target: Path) -> None:
    target.parent.mkdir(parents=True, exist_ok=True)
    temporary = target.with_suffix(target.suffix + ".part")
    temporary.unlink(missing_ok=True)
    command = [
        "ffmpeg", "-nostdin", "-hide_banner", "-loglevel", "error", "-y",
        "-i", str(source), "-map", "0:a:0", "-map_metadata", "-1",
        "-ac", "1", "-ar", "16000", "-c:a", "pcm_s16le", "-f", "wav", str(temporary),
    ]
    completed = subprocess.run(command, stdout=subprocess.DEVNULL, stderr=subprocess.PIPE, check=False)
    if completed.returncode != 0:
        temporary.unlink(missing_ok=True)
        raise command_error(command, completed)
    information = probe(temporary)
    required = {"codec": "pcm_s16le", "sample_rate": 16000, "channels": 1, "bits_per_sample": 16}
    if any(information[key] != value for key, value in required.items()):
        temporary.unlink(missing_ok=True)
        raise RuntimeError(f"Normalisierung hat ein falsches Zielformat erzeugt: {target.name}")
    temporary.replace(target)


def replace_file(staged: Path, destination: Path) -> None:
    destination.parent.mkdir(parents=True, exist_ok=True)
    temporary = destination.with_suffix(destination.suffix + ".part")
    temporary.unlink(missing_ok=True)
    shutil.copyfile(staged, temporary)
    temporary.replace(destination)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    root = Path(__file__).resolve().parents[1]
    parser.add_argument("--plan", type=Path, required=True, help="JSON-Importplan mit Quelldatei, Zielasset und Rolle")
    parser.add_argument("--source-dir", type=Path, required=True, help="Ordner der unveränderten, vom Nutzer gelieferten WAVs")
    parser.add_argument("--source-root", type=Path, default=root / "sources" / "inzug-wav", help="Privater, nicht verpackter WAV-Quellbaum")
    parser.add_argument("--assets-dir", type=Path, default=root / "app" / "src" / "main" / "assets" / "inzug", help="APK-Assetordner")
    parser.add_argument("--manifest", type=Path, default=root / "app" / "src" / "main" / "assets" / "inzug" / "inzug_opus_manifest.json")
    parser.add_argument("--delivery-manifest", type=Path, default=None, help="Privates Prüfprotokoll dieser Lieferung")
    args = parser.parse_args()
    if (
        not isinstance(args.plan, Path)
        or not isinstance(args.source_dir, Path)
        or not isinstance(args.source_root, Path)
        or not isinstance(args.assets_dir, Path)
        or not isinstance(args.manifest, Path)
    ):
        raise RuntimeError("Importparameter haben einen ungültigen Pfad.")
    plan_path: Path = args.plan
    source_dir_arg: Path = args.source_dir
    source_root_arg: Path = args.source_root
    assets_dir_arg: Path = args.assets_dir
    manifest_arg: Path = args.manifest
    delivery_arg: Path | None = args.delivery_manifest if isinstance(args.delivery_manifest, Path) else None

    plan = load_plan(plan_path.resolve())
    source_dir = source_dir_arg.resolve()
    source_root = source_root_arg.resolve()
    assets_dir = assets_dir_arg.resolve()
    manifest_path = manifest_arg.resolve()
    delivery_path = (delivery_arg.resolve() if delivery_arg else source_root / "delivery_manifest_20260726.json")
    if not source_dir.is_dir() or not assets_dir.is_dir() or not manifest_path.is_file():
        raise RuntimeError("Importquelle, Im-Zug-Assetordner oder Opusmanifest fehlt.")

    existing_manifest = load_json(manifest_path)
    if not isinstance(existing_manifest, dict) or existing_manifest.get("schema_version") != 2:
        raise RuntimeError("Bestehendes Opusmanifest hat eine unbekannte Version.")
    existing_entries_raw = existing_manifest.get("entries")
    if not isinstance(existing_entries_raw, list):
        raise RuntimeError("Bestehendes Opusmanifest enthält keine Einträge.")
    existing_entries: list[dict[str, Any]] = []
    for raw_entry in existing_entries_raw:
        if not isinstance(raw_entry, dict):
            raise RuntimeError("Bestehendes Opusmanifest enthält einen ungültigen Eintrag.")
        entry = cast(dict[str, Any], raw_entry)
        if not isinstance(entry.get("target"), str) or not entry["target"].strip():
            raise RuntimeError("Bestehendes Opusmanifest enthält ein ungültiges Ziel.")
        existing_entries.append(entry)
    by_target = {str(entry["target"]): entry for entry in existing_entries}
    if len(by_target) != len(existing_entries):
        raise RuntimeError("Bestehendes Opusmanifest hat doppelte oder ungültige Ziele.")
    missing = [entry["target"] for entry in plan if entry["target"] not in by_target]
    if missing:
        raise RuntimeError("Die angeforderten Überschreibziele fehlen im aktuellen Manifest: " + ", ".join(missing))

    with tempfile.TemporaryDirectory(prefix="intrain-incremental-", dir=str(assets_dir.parent)) as temporary_name:
        temporary = Path(temporary_name)
        staged_sources = temporary / "sources"
        staged_opus = temporary / "opus"
        replacement_entries: dict[str, dict[str, Any]] = {}
        delivery_entries: list[dict[str, Any]] = []
        for entry in plan:
            source = source_dir / entry["source"]
            if not source.is_file():
                raise RuntimeError(f"Gelieferte WAV-Datei fehlt: {entry['source']}")
            source_audio = probe(source)
            if source_audio["codec"] != "pcm_s16le" or source_audio["bits_per_sample"] != 16:
                raise RuntimeError(f"Gelieferte Datei ist keine PCM-16-WAV: {entry['source']}")
            target = safe_target(entry["target"])
            normalized_relative = target.with_suffix(".wav")
            normalized = staged_sources / normalized_relative
            normalize(source, normalized)
            normalized_audio = probe(normalized)
            if abs(float(source_audio["duration_seconds"]) - float(normalized_audio["duration_seconds"])) > 0.003:
                raise RuntimeError(f"Normalisierung hat die Dauer verändert: {entry['source']}")
            rendered = staged_opus / target
            convert(normalized, rendered, target.as_posix(), "32k")
            opus_audio = probe(rendered)
            if opus_audio["codec"] != "opus" or opus_audio["channels"] != 1:
                raise RuntimeError(f"Keine valide Mono-Opusdatei erzeugt: {target}")
            if abs(float(normalized_audio["duration_seconds"]) - float(opus_audio["duration_seconds"])) > 0.030:
                raise RuntimeError(f"Opus-Konvertierung hat die Dauer verändert: {entry['source']}")
            kind = "station" if entry["role"] == "station" else "text"
            replacement_entries[target.as_posix()] = {
                "source": normalized_relative.as_posix(),
                "target": target.as_posix(),
                "kind": kind,
                "source_sha256": sha256(normalized),
                "source_audio": normalized_audio,
                "target_sha256": sha256(rendered),
                "target_audio": opus_audio,
            }
            delivery_entries.append({
                "source": entry["source"],
                "label": entry["label"],
                "role": entry["role"],
                "source_sha256": sha256(source),
                "source_audio": source_audio,
                "normalized_source": normalized_relative.as_posix(),
                "normalized_source_sha256": sha256(normalized),
                "normalized_source_audio": normalized_audio,
                "target": target.as_posix(),
                "target_sha256": sha256(rendered),
                "target_audio": opus_audio,
            })

        merged_entries = [
            replacement_entries.get(str(entry["target"]), entry)
            for entry in existing_entries
        ]
        merged_entries.sort(key=lambda entry: str(entry["target"]))
        updated_manifest = dict(existing_manifest)
        updated_manifest["entries"] = merged_entries
        updated_manifest["entry_count"] = len(merged_entries)
        updated_manifest["station_count"] = sum(entry.get("kind") == "station" for entry in merged_entries)
        updated_manifest["text_count"] = sum(entry.get("kind") == "text" for entry in merged_entries)
        staged_sizes = {target: (staged_opus / PurePosixPath(target)).stat().st_size for target in replacement_entries}
        updated_manifest["opus_bytes"] = sum(
            staged_sizes.get(str(entry["target"]), (assets_dir / PurePosixPath(str(entry["target"]))).stat().st_size)
            for entry in merged_entries
        )
        updated_manifest["last_incremental_update"] = {
            "plan": args.plan.name,
            "entry_count": len(plan),
            "station_count": sum(entry["role"] == "station" for entry in plan),
            "hinweis_count": sum(entry["role"] == "hinweis" for entry in plan),
            "processing": "Boundary-preserving PCM normalization followed by deterministic Ogg/Opus transcode; no trimming, denoising or loudness processing.",
        }

        operations: list[tuple[Path, Path]] = []
        for item in plan:
            target = safe_target(item["target"])
            operations.append((staged_sources / target.with_suffix(".wav"), source_root / target.with_suffix(".wav")))
            operations.append((staged_opus / target, assets_dir / target))
        backups: dict[Path, Path | None] = {}
        backup_root = temporary / "backup"
        manifest_before = manifest_path.read_bytes()
        try:
            for staged, destination in operations:
                if destination.exists():
                    backup = backup_root / str(len(backups))
                    backup.parent.mkdir(parents=True, exist_ok=True)
                    shutil.copyfile(destination, backup)
                    backups[destination] = backup
                else:
                    backups[destination] = None
                replace_file(staged, destination)
            atomic_write_json(manifest_path, updated_manifest)
        except Exception:
            for destination, backup in backups.items():
                if backup is None:
                    destination.unlink(missing_ok=True)
                else:
                    replace_file(backup, destination)
            manifest_path.write_bytes(manifest_before)
            raise

        delivery = {
            "schema_version": 1,
            "purpose": "Private provenance and integrity record for a partial user-curated Im-Zug asset replacement.",
            "plan": args.plan.name,
            "processing": "Boundary-preserving PCM s16le mono 16 kHz normalization followed by deterministic Ogg/Opus 32 kbit/s rendering; no trimming, denoising or loudness processing.",
            "entry_count": len(delivery_entries),
            "station_count": sum(entry["role"] == "station" for entry in delivery_entries),
            "hinweis_count": sum(entry["role"] == "hinweis" for entry in delivery_entries),
            "entries": delivery_entries,
        }
        atomic_write_json(delivery_path, delivery)

    print(json.dumps({
        "updated": len(plan),
        "stations": sum(entry["role"] == "station" for entry in plan),
        "hinweise": sum(entry["role"] == "hinweis" for entry in plan),
        "manifest": str(manifest_path),
        "delivery_manifest": str(delivery_path),
        "opus_bytes": updated_manifest["opus_bytes"],
    }, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except RuntimeError as error:
        print(f"Fehler: {error}", file=sys.stderr)
        raise SystemExit(1)
