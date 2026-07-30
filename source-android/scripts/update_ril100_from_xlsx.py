#!/usr/bin/env python3
"""Generate Android's compact RIL-100 asset from a DB Internetliste XLSX.

The workbook is read as OOXML using only Python's standard library. A current
code is selected per normalized RL100 code using Datum-Ab/Datum-Bis, then
matched to the bundled stations by normalized name. Existing code-to-audio
mappings are retained only as a fallback when a direct station-name match does
not exist.
"""

from __future__ import annotations

import argparse
import datetime as dt
import hashlib
import json
import re
import sys
import unicodedata
import zipfile
from collections import Counter
from pathlib import Path
from typing import Any
import xml.etree.ElementTree as ET

MAIN_NS = "{http://schemas.openxmlformats.org/spreadsheetml/2006/main}"
REL_NS = "{http://schemas.openxmlformats.org/officeDocument/2006/relationships}"


def text(value: Any) -> str:
    return re.sub(r"\s+", " ", str(value or "").strip())


def norm(value: Any, transliterate_umlauts: bool = False) -> str:
    raw = text(value).casefold()
    if transliterate_umlauts:
        raw = raw.replace("ä", "ae").replace("ö", "oe").replace("ü", "ue").replace("ß", "ss")
    raw = unicodedata.normalize("NFD", raw)
    raw = "".join(char for char in raw if unicodedata.category(char) != "Mn")
    raw = raw.replace("ß", "ss")
    return re.sub(r"[^a-z0-9]+", " ", raw).strip()


def code_norm(value: Any) -> str:
    return re.sub(r"\s+", " ", text(value).upper())


def date_value(value: Any) -> int | None:
    match = re.search(r"(\d{8})", text(value))
    return int(match.group(1)) if match else None


def infer_as_of(workbook: Path, explicit: str | None) -> int:
    if explicit:
        value = date_value(explicit)
        if value is None:
            raise ValueError("--as-of muss das Format YYYYMMDD haben.")
        return value
    match = re.search(r"Stand[-_ ](\d{2})[-_ ](\d{2})[-_ ](\d{4})", workbook.name, re.IGNORECASE)
    if match:
        day, month, year = match.groups()
        return int(year + month + day)
    return int(dt.date.today().strftime("%Y%m%d"))


def file_sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as source:
        for chunk in iter(lambda: source.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def column_index(cell_ref: str) -> int:
    letters = "".join(char for char in cell_ref if char.isalpha())
    index = 0
    for char in letters:
        index = index * 26 + ord(char.upper()) - ord("A") + 1
    return index - 1


def shared_strings(package: zipfile.ZipFile) -> list[str]:
    try:
        root = ET.fromstring(package.read("xl/sharedStrings.xml"))
    except KeyError:
        return []
    values: list[str] = []
    for item in root.findall(f"{MAIN_NS}si"):
        values.append("".join(node.text or "" for node in item.iter(f"{MAIN_NS}t")))
    return values


def first_sheet_path(package: zipfile.ZipFile) -> str:
    workbook = ET.fromstring(package.read("xl/workbook.xml"))
    sheet = workbook.find(f"{MAIN_NS}sheets/{MAIN_NS}sheet")
    if sheet is None:
        raise ValueError("Die Arbeitsmappe enthält kein Tabellenblatt.")
    relation_id = sheet.attrib.get(f"{REL_NS}id")
    relationships = ET.fromstring(package.read("xl/_rels/workbook.xml.rels"))
    for relation in relationships:
        if relation.attrib.get("Id") == relation_id:
            target = relation.attrib["Target"].lstrip("/")
            return target if target.startswith("xl/") else "xl/" + target
    raise ValueError("Das erste Tabellenblatt konnte nicht aufgelöst werden.")


def read_rows(path: Path) -> list[dict[str, str]]:
    with zipfile.ZipFile(path) as package:
        shared = shared_strings(package)
        root = ET.fromstring(package.read(first_sheet_path(package)))
    matrix: list[list[str]] = []
    for row in root.findall(f".//{MAIN_NS}sheetData/{MAIN_NS}row"):
        values: list[str] = []
        for cell in row.findall(f"{MAIN_NS}c"):
            index = column_index(cell.attrib.get("r", "A1"))
            while len(values) <= index:
                values.append("")
            cell_type = cell.attrib.get("t")
            if cell_type == "inlineStr":
                value = "".join(node.text or "" for node in cell.iter(f"{MAIN_NS}t"))
            else:
                raw = cell.findtext(f"{MAIN_NS}v", default="")
                value = shared[int(raw)] if cell_type == "s" and raw else raw
            values[index] = text(value)
        matrix.append(values)
    if not matrix:
        raise ValueError("Die Arbeitsmappe enthält keine Zeilen.")
    headers = matrix[0]
    if "RL100-Code" not in headers or "RL100-Langname" not in headers:
        raise ValueError("Erwartete Spalten RL100-Code/RL100-Langname fehlen.")
    return [
        {headers[index]: row[index] if index < len(row) else "" for index in range(len(headers)) if headers[index]}
        for row in matrix[1:]
    ]


def record_rank(row: dict[str, str], as_of: int) -> tuple[int, int, int, int, int]:
    starts = date_value(row.get("Datum-Ab"))
    ends = date_value(row.get("Datum-Bis"))
    started = starts is None or starts <= as_of
    not_expired = ends is None or ends >= as_of
    active = started and not_expired
    operational = text(row.get("Betriebszustand")).casefold() == "betrieb"
    return (
        1 if active else 0,
        1 if started else 0,
        1 if operational else 0,
        starts or 0,
        1 if ends is None else 0,
    )


def station_lookup(stations: list[dict[str, str]]) -> tuple[dict[str, dict[str, str]], dict[str, dict[str, str]]]:
    direct: dict[str, dict[str, str]] = {}
    expanded: dict[str, dict[str, str]] = {}
    for station in stations:
        name = text(station.get("station"))
        if not name or not text(station.get("filepath")):
            continue
        direct.setdefault(norm(name), station)
        expanded.setdefault(norm(name, True), station)
    return direct, expanded


def find_station(row: dict[str, str], direct: dict[str, dict[str, str]], expanded: dict[str, dict[str, str]]) -> dict[str, str] | None:
    candidates = [
        row.get("RL100-Langname", ""),
        row.get("RL100-Langname-ohne-Umlaute", ""),
        row.get("RL100-Kurzname", ""),
    ]
    for candidate in candidates:
        match = direct.get(norm(candidate))
        if match:
            return match
    for candidate in candidates:
        match = expanded.get(norm(candidate, True))
        if match:
            return match
    return None


def load_json(path: Path) -> list[dict[str, str]]:
    loaded = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(loaded, list):
        raise ValueError(f"{path} enthält kein JSON-Array.")
    return loaded


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("workbook", type=Path)
    parser.add_argument("--stations", type=Path, required=True)
    parser.add_argument("--previous-ril", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--as-of", help="YYYYMMDD; default: Stichtag aus „Stand-DD-MM-YYYY“ im Dateinamen, sonst heute")
    parser.add_argument("--report", type=Path)
    args = parser.parse_args()

    as_of = infer_as_of(args.workbook, args.as_of)
    rows = read_rows(args.workbook)
    grouped: dict[str, list[dict[str, str]]] = {}
    for row in rows:
        code = code_norm(row.get("RL100-Code"))
        if code:
            grouped.setdefault(code, []).append(row)

    selected: list[dict[str, str]] = []
    future_only = 0
    for code, candidates in grouped.items():
        best = max(candidates, key=lambda row: record_rank(row, as_of))
        best = dict(best)
        best["RL100-Code"] = code
        starts = date_value(best.get("Datum-Ab"))
        if starts is not None and starts > as_of:
            future_only += 1
        selected.append(best)

    stations = load_json(args.stations)
    previous = load_json(args.previous_ril)
    direct, expanded = station_lookup(stations)
    previous_by_code = {code_norm(item.get("code")): item for item in previous if code_norm(item.get("code"))}

    output: list[dict[str, str]] = []
    direct_matches = 0
    fallback_matches = 0
    no_audio = 0
    status_counts: Counter[str] = Counter()
    for row in selected:
        code = row["RL100-Code"]
        name = text(row.get("RL100-Langname")) or text(row.get("RL100-Kurzname")) or code
        item: dict[str, str] = {"code": code, "name": name}
        station = find_station(row, direct, expanded)
        if station is not None:
            item.update({"station": text(station.get("station")), "filepath": text(station.get("filepath")), "ibnr": text(station.get("ibnr"))})
            direct_matches += 1
        else:
            fallback = previous_by_code.get(code)
            if fallback and text(fallback.get("filepath")):
                item.update({
                    "station": text(fallback.get("station")) or name,
                    "filepath": text(fallback.get("filepath")),
                    "ibnr": text(fallback.get("ibnr")),
                })
                fallback_matches += 1
            else:
                no_audio += 1
        status_counts[text(row.get("Betriebszustand")) or "(leer)"] += 1
        output.append(item)

    output.sort(key=lambda item: (norm(item["name"]), item["code"]))
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(output, ensure_ascii=False, separators=(",", ":")), encoding="utf-8")

    report = {
        "workbook": str(args.workbook),
        "workbook_sha256": file_sha256(args.workbook),
        "as_of": as_of,
        "source_rows": len(rows),
        "unique_codes": len(selected),
        "duplicate_source_rows_removed": sum(len(items) - 1 for items in grouped.values()),
        "future_only_codes": future_only,
        "name_matched_audio": direct_matches,
        "previous_code_fallback_audio": fallback_matches,
        "without_audio": no_audio,
        "output_rows": len(output),
        "status_counts": dict(sorted(status_counts.items())),
        "samples": {code: next((item for item in output if item["code"] == code), None) for code in ("KA", "KASZ", "MH", "BL", "ABCH")},
    }
    report_text = json.dumps(report, ensure_ascii=False, indent=2, sort_keys=True) + "\n"
    if args.report:
        args.report.parent.mkdir(parents=True, exist_ok=True)
        args.report.write_text(report_text, encoding="utf-8")
    print(report_text, end="")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
