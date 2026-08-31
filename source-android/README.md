# Ansagengenerator Android

Native Android-App für Ansagen mit Bahnhofssuche, aktueller RL100-/RIL-100-Liste, lokalem WAV-Export und einer vollständigen Offline-Audio-Bibliothek direkt in der APK.

## v1.20 – DB Regio/Westfalen Im-Zug-Ansagen

- **26 gelieferte Stationsansagen** sind im manuellen Im-Zug-Editor verfügbar: Ahlen (Westf), Bad Oeynhausen, Bielefeld Hbf, Bochum Hbf, Dormagen, Dortmund Hbf, Duisburg Hbf, Düsseldorf Flughafen/Hbf, Essen Hbf, Gütersloh Hbf, Hamm (Westf), Heessen, Herford, Kamen, Köln Hbf, Köln/Bonn Flughafen, Löhne (Westf), Minden (Westf), Mülheim (Ruhr) Hbf, Neubeckum, Neuss Hbf, Oelde, Porta Westfalica, Rheda-Wiedenbrück und Wattenscheid.
- Die gelieferten neuen Fassungen für **Düsseldorf Hbf** und **Neuss Hbf** ersetzen die bisherigen Im-Zug-Clips. 24 weitere Stationen wurden über ihre eindeutigen IBNR-Dateipfade ergänzt.
- **Hinweis · DB Regio Verabschiedung** steht zusätzlich als stationsunabhängiger, frei sortier- und wiederholbarer Baustein bereit.
- Die APK enthält nun **439** hashgeprüfte Im-Zug-Opus-Assets: 420 Stationen sowie 19 Text-/Hinweisbausteine. Die Opus-Assets belegen **2.798.589 Bytes** statt 23.094.278 Bytes privater Build-WAVs.
- Der bisher geteilte Endhalt-Hinweis ist als einzelner Baustein **„Dieser Zug endet dort · Fahrgäste bitte aussteigen“** mit dem gelieferten Originalclip ersetzt. Bestehende Vorlagen migrieren die beiden bisherigen, direkt aufeinanderfolgenden Bausteine zu einer Wiedergabe.
- Der stationsunabhängige Baustein **„Hinweis · Bauarbeiten und Fahrplanänderungen“** enthält den gelieferten dreiteiligen Hinweis mit seinen originalen Sprechpausen.
- Der ältere Baustein **„Höhenunterschied zur Bahnsteigkante“** ist vollständig durch **„Abstand zur Bahnsteigkante“** ersetzt; gespeicherte Vorlagen mit der alten ID werden beim Laden auf den neuen Clip migriert.
- Sieben weitere stationsunabhängige Originalclips ergänzen die frei sortierbare Im-Zug-Liste: **Trittstufen fahren nicht aus**, **Verspätung wegen Signalreparatur**, **Türbereich freihalten**, **außerplanmäßiger Halt**, **Abstand zur Bahnsteigkante**, **Weiterfahrt in die Abstellung** sowie **Corona · Abstand und medizinische Maske**.

## v1.19 – Im-Zug-Assets als Ogg/Opus

- Alle **73** Im-Zug-Audioassets – 61 Stationsclips und zwölf Text-/Hinweisbausteine – werden nun als **Ogg/Opus mit 32 kbit/s** direkt in der APK ausgeliefert.
- Die kompakten Im-Zug-Assets belegen **599.650 Bytes** statt 4.599.248 Bytes WAV; das spart **3.999.598 Bytes (86,96 %)** innerhalb der APK.
- Die unveränderten WAV-Originale liegen ausschließlich als private, nicht verpackte Build-Quellen unter `sources/inzug-wav/`. Der neue Builder normalisiert Ogg-Stream-IDs/CRC für reproduzierbare Ergebnisse und prüft jeden erzeugten Clip vollständig per Dekodierung.
- Wiedergabe bleibt nativ; **WAV exportieren** dekodiert Opus streamingfähig. Vorhandene gespeicherte Streckenlisten mit `station:…wav` werden automatisch auf den identischen `…opus`-Stationsclip umgestellt.

## v1.18 – Hagen Hbf in der Im-Zug-Streckenplaylist

- Der gelieferte Originalclip **Hagen Hauptbahnhof** ist als direkt auswählbare Station ergänzt und dauerhaft über IBNR `8000142` zugeordnet.
- Die Rhein-Ruhr-Auswahl umfasst nun **38 Stationsclips** und vier unabhängige Hinweisbausteine. Jede Station kann einzeln in die frei sortierbare Liste eingefügt, wiederholt, gespeichert und per „Nächster Halt“ ausgelöst werden.
- Der Build prüft 42 kuratierte Audioassets und 61 eindeutige Station-zu-Clip-Zuordnungen.

## v1.17 – Im-Zug-Erweiterung bis Hagen

- Elf weitere, vom Nutzer geschnittene Stationsansagen ergänzen die manuell sortierbare Streckenplaylist: **Gevelsberg Hbf**, Gevelsberg West, Gevelsberg-Kipp, Gevelsberg-Knapp, Hagen-Heubing, Hagen-Wehringhausen, Hagen-Westerbauer, Schwelm, Schwelm West, Wuppertal-Langerfeld und Wuppertal-Oberbarmen.
- Damit umfasst die geprüfte Rhein-Ruhr-Auswahl nun 37 Stationsclips und vier unabhängige Hinweisbausteine. Alle Stationen lassen sich einzeln suchen, einfügen, sortieren, wiederholen und nach Wunsch unter „Nächster Halt“ einzeln auslösen.
- Der Importer verarbeitet mehrere kuratierte Lieferordner reproduzierbar. Der Build prüft sowohl die Hashes aller 41 importierten WAV-Assets als auch jede Station-zu-Clip-Zuordnung.

## v1.16 – manuelle Im-Zug-Streckenplaylist

- Im Modus **Im Zug** lassen sich nun einzelne, kuratierte Stationen als feste Listeneinträge hinzufügen. Jede Station behält dabei ihren eigenen Clip, auch wenn danach oben ein anderer Bahnhof gesucht oder gewählt wird.
- Bausteine, Hinweise und Stationsclips dürfen beliebig gemischt, wiederholt, mit **↑/↓** sortiert und entfernt werden. Damit lässt sich eine Strecke wie Mönchengladbach → Düsseldorf → Wuppertal vollständig manuell aufbauen.
- Die Playlist wird zusammen mit der Pauseinstellung in Vorlagen und Verlauf gespeichert; der kombinierte WAV-Export verwendet exakt dieselbe Reihenfolge.
- Standardmäßig stoppt die Playerleiste nach jedem Stationsnamen. Sie zeigt dann **„▶ Nächster Halt“**; die Option lässt sich für eine durchgehende Wiedergabe deaktivieren. Die normale Pause mitten in einem Audio bleibt unverändert verfügbar.
- Ältere Vorlagen mit dem bisherigen globalen Baustein „Stationsname“ bleiben kompatibel und werden klar als alte Vorlage gekennzeichnet.

## v1.15 – kuratierte S8 Rhein-Ruhr Im-Zug-Ansagen

- 26 vom Nutzer kuratierte Stationsnamen für die S8-Relation wurden als eigenständige Im-Zug-Stationsclips ergänzt, darunter Wuppertal, Düsseldorf, Neuss, Mönchengladbach und die Zwischenhalte.
- Die Auswahl ist über die vorhandene Bahnhofssuche/IBNR-Zuordnung verfügbar; die Aufnahme **Haan-Gruiten** wird dem tatsächlich gesprochenen Ziel **Gruiten** zugeordnet.
- Vier unabhängig und frei sortierbar wählbare Hinweisbausteine wurden ergänzt: **Persönliche Gegenstände**, **Vielen Dank und auf Wiedersehen**, **Bis zum nächsten Mal · S-Bahn Rhein-Ruhr** und **Höhenunterschied zur Bahnsteigkante**.
- Sämtliche neuen WAV-Dateien sind nur formatvereinheitlicht (PCM-16, Mono, 16 kHz), nicht nachgeschnitten, und damit auch mit dem kombinierten WAV-Export kompatibel.
- Das mitgelieferte Importmanifest prüft 30 Assets (26 Stationen, 4 Hinweise) beim Build per SHA-256.

## v1.14 – Opus-Offlinebibliothek (85,4 % kleiner)

- Die 87.902 Sprachclips wurden von 16-kHz-PCM-WAV zu **Ogg/Opus mit 32 kbit/s** neu kodiert.
- Ein einzelnes, direkt lesbares Offline-Archiv belegt **467.116.673 Bytes** statt der bisherigen 3.209.275.642 Bytes an eingebetteten WAV-Archivdaten.
- Das Archiv bleibt als `ZIP_STORED`-Asset im APK; daher gibt es weiterhin keinen Vollimport und keine zweite entpackte Bibliothek.
- Wiedergabe nutzt die nativen Android-Opus-Decoder. **WAV exportieren** bleibt verfügbar und dekodiert die ausgewählten Clips streamingfähig direkt in eine WAV-Datei.
- Die Opus-Bibliothek ist aus der verifizierten Originalquelle reproduzierbar gebaut: Original-Archiv `SHA-256: 2be282ad…ed0efc6`, Opus-Archiv `SHA-256: 80ada82a…e4214`.

## v1.13 – kompakte Arbeitsansicht

- Die Kopfzeile wurde auf Titel und kompakten Datenstatus reduziert; sie verbraucht nicht mehr mehrere große Blöcke.
- Die Suche startet leer. Erst beim Antippen oder Tippen erscheinen Vorschläge; nach einer Zielübernahme wird das Suchfeld wieder frei und nur das kleine grüne Ziel-Banner bleibt sichtbar.
- Modus und Sprache stehen nebeneinander. Die doppelte Schnellwahl und der wiederholte Ablaufhinweis wurden entfernt.
- **Abspielen** ist jetzt dauerhaft am unteren Rand erreichbar. Während einer Wiedergabe wird die primäre Aktion sinnvoll zu **Stop** bzw. **Weiter**; Pause bleibt als zweite Schaltfläche sichtbar.
- Export und Vorlagen speichern liegen hinter **⋯ Weitere Aktionen** statt als große dauerhafte Button-Matrix im Formular.
- Vorlagen und Verlauf zeigen standardmäßig höchstens drei kompakte Einträge; bei Bedarf lässt sich die vollständige Liste aufklappen. Leere Bereiche verschwinden vollständig.
- Datenprüfung und Verlauf löschen liegen platzsparend unter **App & Daten → Details**.
- Animationen bleiben lokal und kurz: Suchtreffer, Ein-/Ausklappen und Player-Status – keine dauerhaft animierte Deko.

## v1.12 – mobilefreundlichere Bedienung und native Bewegung

- Neue Kopfzeile mit klarer **Drei-Schritte-Führung**: Ziel wählen → Modus ausfüllen → abspielen.
- Kein still vorausgewählter Bahnhof mehr: Ein Ziel wird sichtbar gewählt und kann direkt wieder entfernt werden.
- Suchfeld mit Löschen-Schaltfläche, verständlichem Suchstatus und eindeutigem Ziel-Banner.
- Die Modus- und Sprachauswahl sind auf mobilen Bildschirmen nebeneinander angeordnet; doppelte Schnellwahl-Buttons wurden zugunsten einer klaren Auswahl entfernt.
- Fokusrahmen für Textfelder/Auswahllisten, Ripple-Feedback und dezente Press-Animationen für alle Schaltflächen.
- Modusbereiche, Suchtreffer, Vorlagen und Im-Zug-Bausteine erscheinen/wechseln mit kurzen nativen Android-Animationen.
- Große Auswahlkästchen statt gedrängter Checkbox-Zeilen; besser bedienbar auf kleinen Bildschirmen.
- Im-Zug-Vorlagen ohne Stationsbaustein können auch ohne Ziel gespeichert werden.

## v1.11 – native Suche, aktuelle RL100-Daten, ohne Legacy-Webseite

- Die frühere Offline-Webseite inklusive WebView, JavaScript-Bridge und lokalem Web-Origin ist entfernt.
- Die App bleibt vollständig offline: Sie liest die Audio-Bibliothek direkt aus den eingebetteten ZIP64-Archiven und verwendet nur den nativen Player.
- Die RIL-/RL100-Daten stammen aus der bereitgestellten **DB Internetliste, Stand 31.05.2026** (`SHA-256: 541f99fee2ca3b65baf9074265f61f229fc34c976476422801fa406ce5a348a5`). Für genau diesen Stichtag wurden 71.901 Quellzeilen nach Gültigkeitszeiträumen auf **24.218 eindeutige Codes** verdichtet.
- 6.897 Codes sind direkt über den aktuellen Betriebsstellennamen einem Audio-Clip zugeordnet; 280 weiterhin gültige Zuordnungen wurden als sicherer Code-Fallback übernommen.
- Die Suche ist entprellt (180 ms), läuft außerhalb des UI-Threads und verwirft überholte Ergebnisse. Damit blockiert Tippen nicht mehr.
- RIL-Codes in Großbuchstaben wie `KA`, `KASZ`, `MH` und `BL` werden vorrangig behandelt; Bahnhofsnamen wie `Cottbus`, `Köln`/`Koln` und `München`/`Muenchen` als Namen. Treffer werden nach Relevanz und normalisiertem Namen sortiert.
- „Im Zug“ ist ein manueller Baustein-Editor: Bausteine hinzufügen, mehrfach verwenden, mit ↑/↓ ordnen oder löschen.

## Offline-Audio ohne doppelte Datenhaltung

Die Bibliothek wird **nicht** beim ersten Start entpackt:

- ein verifiziertes Ogg/Opus-ZIP-Asset liegt in der APK,
- die Archivstruktur wird einmalig indiziert,
- einzelne Opus-Dateien werden erst beim Abspielen kurz in den Cache geschrieben,
- WAV-Export dekodiert nur die aktuelle Auswahl streamingfähig; die vollständige Bibliothek wird nie extrahiert,

Damit entsteht keine dauerhafte zweite Kopie der vollständigen Offline-Audiodaten im App-Speicher.

## RIL-/RL100-Daten aktualisieren

Der Importer nutzt nur Python-Standardbibliothek und kann daher ohne zusätzliche Python-Pakete laufen:

```bash
./scripts/update_ril100_from_xlsx.py \
  /pfad/Betriebsstellencodes-DB-Internetliste.xlsx \
  --stations app/src/main/assets/stations.json \
  --previous-ril app/src/main/assets/ril100.json \
  --output app/src/main/assets/ril100.json \
  --as-of YYYYMMDD
```

Er wählt pro Code anhand von `Datum-Ab` und `Datum-Bis` den gültigsten Eintrag, ordnet ihn zuerst über normalisierte Namen einem vorhandenen Audio-Clip zu und bewahrt bisherige Code-zu-Audio-Zuordnungen nur als Fallback.

## Im-Zug-Opus neu erzeugen

Die privaten, bewusst **nicht in Git und nicht in der APK** enthaltenen Original-WAVs liegen unter `sources/inzug-wav/`. Nach der Aufnahme zusätzlicher kuratierter Clips erst diese Quellen ergänzen und anschließend die ausgelieferten Assets reproduzierbar erzeugen:

```bash
python3 scripts/build_opus_intrain_assets.py \
  --source-dir sources/inzug-wav \
  --assets-dir app/src/main/assets/inzug \
  --manifest app/src/main/assets/inzug/inzug_opus_manifest.json \
  --bitrate 32k
```

Das Skript konvertiert ausschließlich Audioformat und Ogg-Metadaten. Schnittgrenzen, Stimme und Inhalt bleiben unverändert. Es prüft jeden Opus-Clip durch vollständiges Dekodieren; `verifyBundledInTrainAssets` validiert beim Android-Build danach jede Asset-Prüfsumme, alle 420 Stationszuordnungen und das Fehlen von WAV-Dateien im APK-Assetbaum.

## Build

```bash
export JAVA_HOME=/usr/lib/jvm/java-21-openjdk-amd64
export ANDROID_HOME=/root/android-sdk
export ANDROID_SDK_ROOT=/root/android-sdk
./gradlew clean testDebugUnitTest assembleDebug lintDebug --no-daemon \
  --max-workers=1 -Dorg.gradle.jvmargs='-Xmx8g -Dfile.encoding=UTF-8'
```

Das eingebettete Opus-Archiv wird bewusst nicht als einzelner Git-Blob gespeichert: Fünf reguläre, jeweils maximal 95-MB große Teile und `app/src/main/assets/offline/ansagengenerator-offline-opus-data.parts.json` liegen im Repository. Vor Build oder Test wird das byte-identische ZIP ohne Git LFS rekonstruiert:

```bash
python3 ../tool/offline_archive_parts.py assemble \
  --manifest app/src/main/assets/offline/ansagengenerator-offline-opus-data.parts.json
```

`verifyBundledOfflineArchive` führt dieselbe Rekonstruktion vor dem nativen Android-Build aus und prüft danach Größe sowie SHA-256. `scripts/prepare-embedded-offline-assets.sh` bleibt der Autorenweg zum Neubau aus der verifizierten Originalquelle und schreibt anschließend ebenfalls die regulären Git-Teile.
