# Ansagengenerator · Flutter

Eigenständiger Flutter-Port des manuellen InTrain-Ansagengenerators. Der unveränderte Android-Quellstand liegt als nachvollziehbarer Snapshot in [`source-android/`](source-android/); das ursprüngliche Projekt unter `../ansagengenerator-android-main-manual-intrain/` wurde nicht verändert.

## Funktionen

- Alle neun Ansagemodi: **Einfahrt**, **Ankunft**, **am Bahnsteig**, **Information**, **Anschluss**, **Abfertigung**, **Durchfahrt**, **Sonderansage** und **Im Zug**.
- Offline-Suche über **7.178 Stationen** und **24.218 RL100-Einträge** mit Umlaut-, `ß`- und Code-Normalisierung; Android nutzt einen separaten Isolate, Web einen entprellten, eingeplanten In-Process-Fallback ohne `ReceivePort`-Abhängigkeit.
- Deterministische Playlist-Erzeugung mit sicheren Optionalwerten (`0`, `-`, `9999` werden nie zu Audio-Dateien).
- Abfertigung und Durchfahrt folgen der Android-Referenz: reine Gleis-Ansagen ohne Zug-, Ziel-, Via- oder Zeitangaben.
- Im-Zug-Editor: frei sortierbare und wiederholbare Bausteine, kuratierte Stationsclips und Pausen sowohl nach Stationsnamen als auch vor dem Gong der folgenden Station.
- Lokale Vorlagen und Verlauf via `shared_preferences`.
- Android: gezielte Clip-Extraktion aus der 467-MB-ZIP64-Offlinebibliothek in den Cache, Audio-Wiedergabe und WAV-Export.
- Native (Windows, Linux, macOS und iOS): direkter, sicherer Zugriff auf einzelne ZIP64-Opus-Clips im ausgelieferten Flutter-Asset-Bundle – ohne Android-`MethodChannel`, Vollimport oder Netzverbindung. Opus-Clips werden einmal lokal nach 48-kHz-Mono-PCM-WAV normalisiert und gecacht, damit die Windows-Wiedergabe nicht von Ogg/Opus-Unterstützung in Media Foundation abhängt. Der WAV-Export verwendet dieselben normalisierten Dateien und schreibt die fertige Datei in den Dokumente-Ordner.
- Web: ZIP64-Index und einzelne Ogg/Opus-Clips werden progressiv über HTTP-Range geladen; Browser-Wiedergabe nutzt Blob-URLs, WAV-Export den Web-Audio-Decoder und einen lokalen Download. Der Browser lädt oder entpackt niemals die 467-MB-Bibliothek vollständig.

## Plattformstatus

| Ziel | Status | Offline-Audio |
|---|---|---|
| Android | **lokal gebaut und signaturgeprüft** | vollständig; ZIP64-Bridge und WAV-Export aktiv |
| Web | **vollständig funktionsfähig, Release und Chromium geprüft** | vollständige normale ZIP64-Offlinebibliothek, kuratierte Im-Zug-Assets, Blob-Wiedergabe und lokaler WAV-Download; benötigt einen Range-fähigen Webhost |
| Linux | GitHub-CI-Bundle | ZIP64; FFmpegKit Audio zu PCM-WAV; JSON-GLib und GStreamer erforderlich |
| Windows | GitHub-CI-Bundle mit Runtime-Gate | ZIP64; FFmpegKit Audio zu PCM-WAV; Wiedergabe mit audioplayers |
| macOS | GitHub-CI-App-Bundle | ZIP64; FFmpegKit Audio zu PCM-WAV; Wiedergabe mit audioplayers |
| iOS | unsigniertes GitHub-CI-Bundle (iOS 14+) | ZIP64; FFmpegKit Audio zu PCM-WAV; Apple-Signing nötig |

Die Web-Version liest den ZIP64-Endbereich (65.557 Byte), das 7.634.699-Byte-Zentralverzeichnis und anschließend ausschließlich die gerade benötigten Ogg/Opus-Clips. Blob-URLs werden als LRU bis 16 MiB im Arbeitsspeicher gehalten und beim Verdrängen beziehungsweise Beenden freigegeben. Damit gibt es keinen Vollimport, keine Entpackung und keinen unkontrollierten 467-MB-Speicherverbrauch.

### Web-Hosting-Anforderung

Der Host für `build/web/` muss für die Archiv-Asset-URL `GET` mit `Range: bytes=…` als **HTTP 206** beantworten und `Content-Range` bereitstellen. Übliche statische Webserver/CDNs können dies; ein Minimalserver ohne Range-Support wird bewusst mit einer verständlichen Wiedergabemeldung abgewiesen, statt die komplette Bibliothek zu laden.

Für einen lokalen Testserver mit korrektem Range-Verhalten liegt `tool/serve_web_with_ranges.py` bereit:

```bash
python3 tool/serve_web_with_ranges.py --directory build/web --port 8765
```

Der reproduzierbare Browser-Regressionstest baut den Web-Release, prüft reale ZIP64-Range-Abrufe, Ogg/Opus-Decodierung und den WAV-Downloadpfad:

```bash
bash tool/test_web_offline_audio.sh
```

## Lokales Bauen

```bash
flutter pub get
flutter analyze
flutter test
flutter build apk --debug
flutter build web --release
```

Die Android-APK liegt anschließend unter:

```text
build/app/outputs/flutter-apk/app-debug.apk
```

Die Web-Ausgabe liegt unter `build/web/`.

## GitHub-Auslieferung

Der private GitHub-Quellstand versioniert die kompakte ZIP64-Offlinebibliothek gezielt mit **Git LFS**. Lokale Flutter-/Gradle-Caches, IDE-Dateien, maschinenbezogene SDK-Pfade, historische Debug-Builds sowie die privaten WAV-Rohschnitte bleiben ausgeschlossen.

Die aktuelle APK und das gebaute Webpaket werden als Release-Artefakte bereitgestellt. Jeder Push auf `main` und jeder manuelle Lauf von `.github/workflows/windows-exe.yml` startet den zentralen Workflow **Build all targets** auf GitHub. Er baut und archiviert nach derselben gemeinsamen Analyse/Test-Gate:

- Web-Release inklusive Chromium-Range-/Ogg-/WAV-Regressionstest,
- Android-Debug-APK mit Signaturprüfung,
- Linux-x64-Bundle mit SHA-256-geprüftem FFmpegKit-Audio und GStreamer/JSON-GLib-Voraussetzungen,
- Windows-x64-Distribution inklusive nativer Runtime-Prüfung: ZIP64-Clip extrahieren, Medienquelle öffnen und echte PCM-WAV exportieren,
- macOS-App-Bundle der jeweils aktuellen GitHub-macOS-Runner-Architektur sowie ein unsigniertes iOS-Release-Bundle.

Die GitHub-Artefakte bleiben 14 Tage abrufbar. Die Windows-Anwendung besteht aus der `Ansagengenerator.exe` **und** den begleitenden DLLs/Assets; daher ist stets der komplette Artefaktordner zu verwenden. Das iOS-Bundle wird ohne Codesignatur gebaut und benötigt für eine Installation später ein separat autorisiertes Apple-Signing.

## Verifizierter Stand

- `flutter analyze`: ohne Befund
- 32 Unit-/Widget- und ZIP64-Regressionstests: grün, einschließlich eines echten Zugriffs auf das ZIP64-LFS-Archiv
- Chromium-Browsertest: reale HTTP-Range-Abrufe, Blob-Quelle, Ogg/Opus-Decodierung und WAV-Downloadpfad grün
- Android SDK 36 / JDK 21: geprüft
- Debug-APK: Paket `de.shedowe.ansagengenerator`, Version `1.20.7` (Build 30), Android API 24–36, v2-signiert
- Offlinearchiv: SHA-256 `80ada82a559fa5a40085cfd7c10aeae483991be68ec4ca0073150755489e4214`; im APK und Web-Release genau einmal unkomprimiert abgelegt
- Web-Release: erfolgreich gebaut; Browseroberfläche, Suche und vollständiger Offline-Audio-/WAV-Pfad verifiziert
- Die finale Windows-Medienquellen- und WAV-Exportprüfung ist als GitHub-Windows-Integrationstest Teil des zentralen Workflows und wird pro Push erneut ausgeführt.

> Die APK ist absichtlich eine **Debug**-APK mit Android-Debugsignatur. Für Veröffentlichung braucht es einen separat autorisierten Release-Keystore und Signaturprozess.
