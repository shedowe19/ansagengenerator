# Release Notes – v1.20

## DB Regio/Westfalen Im-Zug-Lieferung

- 26 vorhandene Original-Stationsclips der manuellen Im-Zug-Streckenplaylist wurden über ihre bestehenden IBNR-Dateipfade vollständig durch die gelieferten Fassungen ersetzt.
- Der zusätzliche stationsunabhängige Baustein **Hinweis · DB Regio Verabschiedung** lässt sich frei zwischen Stationen und anderen Hinweisen einfügen, wiederholen und sortieren.
- Die Verarbeitung erhielt Schnittgrenzen, Stimme und Inhalt unverändert: vollständiger Decode, SHA-256-Prüfung und ausschließlich PCM-16/Mono/16-kHz-Normalisierung der privaten Build-Quellen vor der reproduzierbaren Opus-Konvertierung.
- Der Build prüft jetzt 98 Opus-Hashes, 85 eindeutige Stationzuordnungen und 13 Text-/Hinweisbausteine. Die kuratierten APK-Audioassets belegen 771.891 Bytes.

# Release Notes – v1.19

## Kompakte Im-Zug-Audioassets

- Alle 73 kuratierten Im-Zug-Assets wurden von PCM-16-WAV zu **Ogg/Opus 32 kbit/s** transkodiert: 61 Stationsclips sowie zwölf Text- und Hinweisbausteine.
- APK-Assetgröße: **599.650 Bytes** statt 4.599.248 Bytes – **3.999.598 Bytes / 86,96 %** kleiner.
- Die App verwendet bei Wiedergabe und bei gespeicherten Streckenlisten nun Opus-Pfade. Alte Stationslisten mit WAV-Tokens bleiben kompatibel und werden beim Auflösen auf den passenden Opus-Clip abgebildet.
- Das Opus-Importmanifest enthält Quelle, Ziel, Audioformat und SHA-256 jedes Clips. Der Build verbietet verbliebene Im-Zug-WAV-Assets und prüft alle 73 Opus-Hashes plus 61 Stationzuordnungen.
- Original-WAVs liegen nur als private, nicht verpackte Build-Quelle unter `sources/inzug-wav/`; die Konvertierung normalisiert Ogg-Stream-ID und CRC für reproduzierbare Artefakte.

# Release Notes – v1.18

## Hagen Hbf

- Der gelieferte, bereits geschnittene Clip **Hagen Hauptbahnhof** ergänzt die Im-Zug-Streckenplaylist als fester Stationseintrag.
- Zuordnung: **Hagen Hbf**, IBNR `8000142`, Clip `station_name_hagen_hbf.wav`.
- Die Aufnahme wurde per ASR gegen „Hagen Hauptbahnhof“ geprüft, nur nach PCM-16/Mono/16 kHz gewandelt und nicht nachgeschnitten.
- Das Importmanifest umfasst nun 42 Assets (38 Stationen, vier Hinweise); die Stationzuordnung 61 eindeutige Einträge.

# Release Notes – v1.17

## Im-Zug-Erweiterung bis Hagen

- Elf neue Original-Stationsclips stehen in der manuellen Streckenplaylist zur Verfügung: Gevelsberg Hbf/West/Kipp/Knapp, Hagen-Heubing/Wehringhausen/Westerbauer, Schwelm/West sowie Wuppertal-Langerfeld/Oberbarmen.
- Alle neuen Clips sind per ASR gegen ihre gelieferten Namen geprüft, als PCM-16/Mono/16 kHz eingebettet und unverändert in ihrer Schnittlänge.
- Die kuratierte Rhein-Ruhr-Sammlung umfasst jetzt 41 eingebettete Assets: 37 Stationen und vier Hinweise.
- Build-Gates prüfen die Asset-Prüfsummen, alle 60 Stationszuordnungen, vorhandene Clipdateien und die vollständige Zuordnung jedes kuratierten Stationsassets.

# Release Notes – v1.16

## Manuelle Im-Zug-Streckenplaylist

- Die Im-Zug-Liste nimmt neben Textbausteinen nun **feste Stationsclips** auf. Ein Eintrag enthält den geprüften, konkreten Clip und hängt nicht mehr von der späteren globalen Bahnhofsauswahl ab.
- Stationen, Gong, „Nächste Station“ und Hinweise können frei gemischt, wiederholt, umsortiert und aus Vorlagen wiederhergestellt werden.
- Nach einem Stationsclip hält die Wiedergabe standardmäßig an und bietet **„Nächster Halt“** an. Diese Haltestellensteuerung ist bewusst optional; mit deaktivierter Einstellung läuft die gesamte Liste durch. Manuelles Pausieren/Fortsetzen innerhalb eines Clips bleibt erhalten.
- Vorlage, Verlauf und WAV-Export verwenden die exakt gespeicherte Reihenfolge einschließlich der Pausenpräferenz.
- Bestehende Vorlagen mit dem früheren dynamischen „Stationsname“-Baustein bleiben lesbar und funktionieren weiterhin mit einer oben ausgewählten Station.

# Release Notes – v1.15

## Kuratierte S8 Rhein-Ruhr Im-Zug-Ansagen

- 26 vom Nutzer bereits geschnittene Stationclips sind als direkt wählbare Stationsnamen eingebettet: Wuppertal, Düsseldorf, Neuss, Mönchengladbach und die gelieferten Zwischenhalte.
- Die vollständige Zuordnung erfolgt über 26 Stationseinträge. Der Clip **Haan-Gruiten** enthält hörbar das Ziel Gruiten und wird daher ausschließlich diesem Katalogziel zugeordnet.
- Die vier gelieferten Hinweisdateien sind als eigenständige, frei sortierbare Im-Zug-Bausteine verfügbar:
  - Persönliche Gegenstände
  - Vielen Dank und auf Wiedersehen
  - Bis zum nächsten Mal · S-Bahn Rhein-Ruhr
  - Höhenunterschied zur Bahnsteigkante
- Kein Umstiegsbaustein aus der früheren S8-Sichtung wurde übernommen.
- Importierte Audiodaten sind unverändert in ihrer Schnittlänge und nur auf das gemeinsame App- und WAV-Exportformat PCM-16, Mono, 16 kHz gewandelt.
- Der Build prüft das Importmanifest auf genau 30 Dateien, Vollständigkeit und jede einzelne SHA-256-Prüfsumme.

# Release Notes – v1.14

## Kompakte Ogg/Opus-Bibliothek

- 87.902 16-kHz-Mono-WAV-Sprachclips verlustbehaftet, aber sprachoptimiert nach **Ogg/Opus 32 kbit/s** konvertiert.
- Eingebettete Offline-Daten: **467.116.673 Bytes** statt 3.209.275.642 Bytes — rund **85,4 % weniger** Bibliotheksdaten im APK.
- Ein einzelnes `ZIP_STORED`-Asset bleibt direkt seekbar; es existiert keine vollständige entpackte Kopie im App-Speicher.
- Direkte Wiedergabe verwendet Androids Opus-Decoder; der WAV-Export wird nun streamingfähig über `MediaExtractor`/`MediaCodec` dekodiert und vermeidet große Heap-Puffer.
- Strikte Prüfung des neuen Archivs: 87.902 Opus-Einträge, 453.253.609 Audio-Bytes, feste Archiv-SHA-256 `80ada82a559fa5a40085cfd7c10aeae483991be68ec4ca0073150755489e4214`.
- Reproduzierbarer Konverter `scripts/build_opus_offline_library.py` und Vorbereitungs-Skript für die verifizierte Originalquelle ergänzt.

## v1.13 – Kompaktere Arbeitsansicht

- Primäre Wiedergabe ist als permanente untere Leiste verfügbar; sie bleibt beim Scrollen erreichbar und wechselt korrekt zwischen Abspielen, Pause, Weiter und Stop.
- Export und Speichern sind über **⋯** erreichbar; Datenprüfung und Verlauf löschen sind als seltene Verwaltungsaktionen unter **App & Daten → Details** zusammengefasst.
- Suchfeld und übernommenes Ziel doppeln sich nicht mehr. Vorschläge erscheinen erst beim Fokussieren/Tippen, die Auswahl bleibt als kompaktes Banner zurück.
- Kopfzeile, Modusbereich und Verlauf wurden deutlich komprimiert. Modus und Sprache liegen nebeneinander; die doppelte Schnellwahl wurde entfernt.
- Verlauf/Vorlagen zeigen zuerst drei kurze Zeilen, können bei Bedarf aufgeklappt werden und verschwinden bei Leerstand vollständig.
- Animationen konzentrieren sich auf echte Zustandswechsel statt auf dauerhafte Bewegung.

## v1.12 – Bedienung und Bewegung

- Kopfzeile mit kurzer Drei-Schritte-Führung und eindeutiger Bibliotheksanzeige.
- Suchfeld mit sichtbarer Löschen-Funktion, Hintergrund-Suchstatus und animierten Treffern.
- Ein Ziel muss bewusst übernommen werden; das Auswahlbanner zeigt IBNR und lässt sich direkt wieder entfernen.
- Schnelltasten für Einfahrt, Information und Im Zug ergänzen die vollständige Modusauswahl.
- Texteingaben und Listen haben klaren Fokusrahmen; Schaltflächen bieten Ripple- und Press-Feedback.
- Moduswechsel, Trefferlisten, Im-Zug-Reihenfolge und Vorlagen verwenden kurze, native, nicht blockierende Animationen.
- Auswahlkästchen sind großflächig und vertikal angeordnet statt in engen Zeilen.
- Gong-/Hinweisfolgen im Modus Im Zug lassen sich ohne Bahnhof speichern, sofern kein Stationsname enthalten ist.

## v1.11 – Legacy-Offlineseite entfernt

- Keine Offline-Webseite mehr in der App.
- Kein WebView, keine JavaScript-Bridge und kein lokaler Web-Origin mehr.
- Die App verwendet ausschließlich die native Benutzeroberfläche und den nativen Audio-Player.
- Die eingebettete ZIP64-Bibliothek bleibt als direkte, nicht entpackte Audioquelle erhalten.

## Neue RL100-/RIL-100-Liste

Quelle: bereitgestellte **Betriebsstellencodes-DB-Internetliste, Stand 31.05.2026**
`SHA-256: 541f99fee2ca3b65baf9074265f61f229fc34c976476422801fa406ce5a348a5`

- 71.901 Quellenzeilen
- 24.218 eindeutige RL100-Codes nach Gültigkeits-Auswahl für den **31.05.2026**
- 422 zeitlich ersetzte Dubletten verworfen
- 6.897 aktuelle Namenszuordnungen zu vorhandenen Audio-Clips
- 280 bisherige Code-Zuordnungen nur als Fallback erhalten

`KA` (Aachen Hbf), `KASZ` (Aachen Schanz), `MH` (München Hbf), `BL` (Berlin Hbf) und `ABCH` (Büchen) wurden gegen die generierte Liste geprüft.

## Robuste Suche

- Suche erst 180 ms nach der letzten Eingabe ausführen.
- RL100-/Stationsdaten vorindiziert und im einzelnen Hintergrund-Thread filtern.
- Suchgeneration verhindert, dass langsame alte Treffer den neueren Text überschreiben.
- Höchstens 18 Ergebniszeilen werden in die UI eingefügt.
- Großgeschriebene RL100-Codes werden priorisiert; gemischt geschriebene Namen bleiben Namenssuchen.

## UI-Struktur

- Abschnittstitel und Hilfetexte sind jetzt native, konsistente Abläufe statt historischer Website-Bezüge.
- Pro Modus werden nur die relevanten Eingabeblöcke gezeigt.
- Der Im-Zug-Editor bleibt frei sortierbar und unterstützt wiederholte Bausteine.
