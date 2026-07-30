#!/usr/bin/env python3
"""Stage user-curated Rhein-Ruhr WAVs as private sources for the Opus build.

The supplied cuts remain authoritative. This helper only normalizes new source
clips to PCM s16le / mono / 16 kHz under `sources/inzug-wav/`; it never writes
packaged APK assets. Run `build_opus_intrain_assets.py` afterwards to produce
and verify the Ogg/Opus files used by the app.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import subprocess
from pathlib import Path
from typing import TypedDict


class Asset(TypedDict):
    source: str
    target: str
    kind: str
    label: str


class AudioInfo(TypedDict):
    codec: str | None
    sample_rate: int
    channels: int
    bits_per_sample: int
    duration_seconds: float


ASSETS: tuple[Asset, ...] = (
    {"source": "Büttgen.wav", "target": "station_name_only/station_name_buettgen.wav", "kind": "station", "label": "Büttgen"},
    {"source": "Düsseldorf_Hauptbahnhof.wav", "target": "station_name_only/station_name_duesseldorf_hbf.wav", "kind": "station", "label": "Düsseldorf Hbf"},
    {"source": "Düsseldorf-Bilk.wav", "target": "station_name_only/station_name_duesseldorf_bilk.wav", "kind": "station", "label": "Düsseldorf-Bilk"},
    {"source": "Düsseldorf-Flingern.wav", "target": "station_name_only/station_name_duesseldorf_flingern.wav", "kind": "station", "label": "Düsseldorf-Flingern"},
    {"source": "Düsseldorf-Friedrichstadt.wav", "target": "station_name_only/station_name_duesseldorf_friedrichstadt.wav", "kind": "station", "label": "Düsseldorf Friedrichstadt"},
    {"source": "Düsseldorf-Gerresheim.wav", "target": "station_name_only/station_name_duesseldorf_gerresheim.wav", "kind": "station", "label": "Düsseldorf-Gerresheim"},
    {"source": "Düsseldorf-Hamm.wav", "target": "station_name_only/station_name_duesseldorf_hamm.wav", "kind": "station", "label": "Düsseldorf-Hamm"},
    {"source": "Düsseldorf-Völklinger_Straße.wav", "target": "station_name_only/station_name_duesseldorf_voelklinger_strasse.wav", "kind": "station", "label": "Düsseldorf Völklinger Straße"},
    {"source": "Erkrath_Erkrath.wav", "target": "station_name_only/station_name_erkrath.wav", "kind": "station", "label": "Erkrath"},
    {"source": "Erkrath_Hochdahl.wav", "target": "station_name_only/station_name_hochdahl.wav", "kind": "station", "label": "Hochdahl"},
    {"source": "Erkrath_Millrath.wav", "target": "station_name_only/station_name_hochdahl_millrath.wav", "kind": "station", "label": "Hochdahl-Millrath"},
    {"source": "Haan-Gruiten.wav", "target": "station_name_only/station_name_haan_gruiten.wav", "kind": "station", "label": "Haan-Gruiten"},
    {"source": "Kleinenbroich.wav", "target": "station_name_only/station_name_kleinenbroich.wav", "kind": "station", "label": "Kleinenbroich"},
    {"source": "Korschenbroich.wav", "target": "station_name_only/station_name_korschenbroich.wav", "kind": "station", "label": "Korschenbroich"},
    {"source": "Mönchengladbach_Hauptbahnhof.wav", "target": "station_name_only/station_name_moenchengladbach_hbf.wav", "kind": "station", "label": "Mönchengladbach Hbf"},
    {"source": "Mönchengladbach-Lürrip.wav", "target": "station_name_only/station_name_moenchengladbach_luerrip.wav", "kind": "station", "label": "Mönchengladbach-Lürrip"},
    {"source": "Neuss_Am_Kaiser.wav", "target": "station_name_only/station_name_neuss_am_kaiser.wav", "kind": "station", "label": "Neuss Am Kaiser"},
    {"source": "Neuss_Hauptbahnhof.wav", "target": "station_name_only/station_name_neuss_hbf.wav", "kind": "station", "label": "Neuss Hbf"},
    {"source": "Neuss_Rheinpark-Center.wav", "target": "station_name_only/station_name_neuss_rheinparkcenter.wav", "kind": "station", "label": "Neuss Rheinparkcenter"},
    {"source": "Wuppertal_Hauptbahnhof.wav", "target": "station_name_only/station_name_wuppertal_hbf.wav", "kind": "station", "label": "Wuppertal Hbf"},
    {"source": "Wuppertal_Sonnborn.wav", "target": "station_name_only/station_name_wuppertal_sonnborn.wav", "kind": "station", "label": "Wuppertal-Sonnborn"},
    {"source": "Wuppertal_Steinbeck.wav", "target": "station_name_only/station_name_wuppertal_steinbeck.wav", "kind": "station", "label": "Wuppertal-Steinbeck"},
    {"source": "Wuppertal_Zoologischer_Garten.wav", "target": "station_name_only/station_name_wuppertal_zoologischer_garten.wav", "kind": "station", "label": "Wuppertal Zoologischer Garten"},
    {"source": "Wuppertal-Barmen.wav", "target": "station_name_only/station_name_wuppertal_barmen.wav", "kind": "station", "label": "Wuppertal-Barmen"},
    {"source": "Wuppertal-Unterbarmen.wav", "target": "station_name_only/station_name_wuppertal_unterbarmen.wav", "kind": "station", "label": "Wuppertal-Unterbarmen"},
    {"source": "Wuppertal-Vohwinkel.wav", "target": "station_name_only/station_name_wuppertal_vohwinkel.wav", "kind": "station", "label": "Wuppertal-Vohwinkel"},
    {"source": "Gevelsberg_Hauptbahnhof.wav", "target": "station_name_only/station_name_gevelsberg_hbf.wav", "kind": "station", "label": "Gevelsberg Hbf"},
    {"source": "Gevelsberg_West.wav", "target": "station_name_only/station_name_gevelsberg_west.wav", "kind": "station", "label": "Gevelsberg West"},
    {"source": "Gevelsberg-Kipp.wav", "target": "station_name_only/station_name_gevelsberg_kipp.wav", "kind": "station", "label": "Gevelsberg-Kipp"},
    {"source": "Gevelsberg-Knapp.wav", "target": "station_name_only/station_name_gevelsberg_knapp.wav", "kind": "station", "label": "Gevelsberg-Knapp"},
    {"source": "Hagen_Heubing.wav", "target": "station_name_only/station_name_hagen_heubing.wav", "kind": "station", "label": "Hagen-Heubing"},
    {"source": "Hagen_Wehringhausen.wav", "target": "station_name_only/station_name_hagen_wehringhausen.wav", "kind": "station", "label": "Hagen-Wehringhausen"},
    {"source": "Hagen_Westerbauer.wav", "target": "station_name_only/station_name_hagen_westerbauer.wav", "kind": "station", "label": "Hagen-Westerbauer"},
    {"source": "Hagen_Hauptbahnhof.wav", "target": "station_name_only/station_name_hagen_hbf.wav", "kind": "station", "label": "Hagen Hbf"},
    {"source": "Schwelm.wav", "target": "station_name_only/station_name_schwelm.wav", "kind": "station", "label": "Schwelm"},
    {"source": "Schwelm_West.wav", "target": "station_name_only/station_name_schwelm_west.wav", "kind": "station", "label": "Schwelm West"},
    {"source": "Wuppertal-Langerfeld.wav", "target": "station_name_only/station_name_wuppertal_langerfeld.wav", "kind": "station", "label": "Wuppertal-Langerfeld"},
    {"source": "Wuppertal-Oberbarmen.wav", "target": "station_name_only/station_name_wuppertal_oberbarmen.wav", "kind": "station", "label": "Wuppertal-Oberbarmen"},
    {"source": "Bahnsteigkante__Hinweis_.wav", "target": "text/hinweis_bahnsteigkante.wav", "kind": "hinweis", "label": "Höhenunterschied zur Bahnsteigkante"},
    {"source": "Bis_zum_Nächsten_Mal_S-Bahn_Rhein-Ruhr__Hinweis_.wav", "target": "text/hinweis_bis_zum_naechsten_mal_s_bahn_rhein_ruhr.wav", "kind": "hinweis", "label": "Bis zum nächsten Mal · S-Bahn Rhein-Ruhr"},
    {"source": "Persönliche_Gegenstände__Hinweis_.wav", "target": "text/hinweis_persoenliche_gegenstaende.wav", "kind": "hinweis", "label": "Persönliche Gegenstände"},
    {"source": "Vielen_Dank__Hinweis_.wav", "target": "text/hinweis_vielen_dank_und_auf_wiedersehen.wav", "kind": "hinweis", "label": "Vielen Dank und auf Wiedersehen"},
)


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for block in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def probe(path: Path) -> AudioInfo:
    command = [
        "ffprobe", "-v", "error", "-select_streams", "a:0",
        "-show_entries", "stream=codec_name,sample_rate,channels,bits_per_sample:format=duration",
        "-of", "json", str(path),
    ]
    data = json.loads(subprocess.run(command, check=True, capture_output=True, text=True).stdout)
    streams = data.get("streams", [])
    if len(streams) != 1:
        raise RuntimeError(f"Genau eine Audiospur erwartet: {path.name}")
    stream = streams[0]
    return {
        "codec": stream.get("codec_name"),
        "sample_rate": int(stream.get("sample_rate", 0)),
        "channels": int(stream.get("channels", 0)),
        "bits_per_sample": int(stream.get("bits_per_sample", 0)),
        "duration_seconds": round(float(data.get("format", {}).get("duration", 0)), 6),
    }


def convert(source: Path, target: Path) -> None:
    temporary = target.with_suffix(target.suffix + ".part")
    target.parent.mkdir(parents=True, exist_ok=True)
    if temporary.exists():
        temporary.unlink()
    subprocess.run([
        "ffmpeg", "-hide_banner", "-loglevel", "error", "-y", "-i", str(source),
        "-map", "0:a:0", "-ac", "1", "-ar", "16000", "-c:a", "pcm_s16le", "-f", "wav", str(temporary),
    ], check=True)
    rendered = probe(temporary)
    required = {"codec": "pcm_s16le", "sample_rate": 16000, "channels": 1, "bits_per_sample": 16}
    if any(rendered[key] != value for key, value in required.items()):
        temporary.unlink(missing_ok=True)
        raise RuntimeError(f"Falsches Zielformat für {target.name}: {rendered}")
    temporary.replace(target)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source-dir", required=True, type=Path, action="append", metavar="DIR", help="Ordner mit kuratierten WAV-Dateien; für mehrere Lieferungen wiederholen")
    parser.add_argument("--source-root", type=Path, default=Path(__file__).resolve().parents[1] / "sources/inzug-wav", help="Privater WAV-Quellbaum; wird nicht als APK-Asset verpackt")
    parser.add_argument("--manifest", type=Path, default=None)
    args = parser.parse_args()

    source_dirs = [source_dir.resolve() for source_dir in args.source_dir]
    source_root = args.source_root.resolve()
    manifest_path = args.manifest.resolve() if args.manifest else source_root / "user_curated_intrain_source_manifest.json"

    def source_for(asset: Asset) -> Path:
        matches = [source_dir / asset["source"] for source_dir in source_dirs if (source_dir / asset["source"]).is_file()]
        if not matches:
            raise SystemExit("Fehlende kuratierte WAV-Datei: " + asset["source"])
        if len(matches) != 1:
            raise SystemExit("Mehrdeutige kuratierte WAV-Datei: " + asset["source"])
        return matches[0]
    if len({asset["target"] for asset in ASSETS}) != len(ASSETS):
        raise SystemExit("Importplan enthält doppelte Zielpfade.")

    imported: list[dict[str, object]] = []
    for asset in ASSETS:
        source = source_for(asset)
        source_info = probe(source)
        if source_info["codec"] != "pcm_s16le" or source_info["bits_per_sample"] != 16:
            raise SystemExit(f"Lieferung ist kein PCM-16-WAV: {source.name}")
        target = source_root / asset["target"]
        convert(source, target)
        target_info = probe(target)
        if abs(float(source_info["duration_seconds"]) - float(target_info["duration_seconds"])) > 0.003:
            raise SystemExit(f"Unerwartet abweichende Dauer nach Konvertierung: {source.name}")
        imported.append({
            **asset,
            "source_sha256": sha256(source),
            "source_audio": source_info,
            "target_audio": target_info,
            "target_sha256": sha256(target),
        })
    manifest_path.parent.mkdir(parents=True, exist_ok=True)
    manifest_path.write_text(json.dumps({
        "schema_version": 1,
        "purpose": "Private normalized user-curated Rhein-Ruhr WAV sources for the Opus builder.",
        "processing": "Boundary-preserving resample only: PCM s16le, mono, 16 kHz.",
        "entry_count": len(imported),
        "station_count": sum(item["kind"] == "station" for item in imported),
        "hinweis_count": sum(item["kind"] == "hinweis" for item in imported),
        "entries": imported,
    }, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({
        "staged_sources": len(imported),
        "manifest": str(manifest_path),
        "next": "python3 scripts/build_opus_intrain_assets.py --source-dir sources/inzug-wav --assets-dir app/src/main/assets/inzug --manifest app/src/main/assets/inzug/inzug_opus_manifest.json --bitrate 32k",
    }, ensure_ascii=False))


if __name__ == "__main__":
    main()
