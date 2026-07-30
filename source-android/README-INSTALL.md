# Ansagengenerator Android v1.19 – Installation

## Eine native Offline-App

Die APK enthält die Android-App sowie Ogg/Opus-Audio: die vollständige Offline-Bibliothek **und** alle kuratierten Im-Zug-Stations-/Textbausteine mit 32 kbit/s. Es gibt keinen ZIP-Import, keine Dateiauswahl und keine Legacy-Offline-Webseite.

- Die Audiodaten werden direkt aus der APK verwendet.
- Beim Abspielen entsteht nur ein temporärer Opus-Audio-Cache.
- Für **WAV exportieren** werden nur die aktuell gewählten Clips lokal nach PCM dekodiert und als WAV geschrieben.
- Es wird keine zweite, dauerhaft entpackte Datenbibliothek angelegt.

## Installation

1. APK auf das Android-Gerät kopieren und installieren.
2. App starten.
3. Warten, bis oben der Status **„● Daten bereit“** zeigt.
4. Oben einen Zielbahnhof bzw. RL100-Code eingeben und einen Treffer übernehmen. Das Suchfeld wird danach wieder frei; das grüne Ziel-Banner zeigt die aktive Auswahl.
5. Modus und Sprache wählen, die sichtbaren Felder ausfüllen.
6. Unten auf **Abspielen** drücken – die Wiedergabeleiste bleibt beim Scrollen sichtbar.
7. Über **⋯** erreichst du WAV-Export und Vorlage speichern. Datenprüfung und Verlauf löschen liegen unter **App & Daten → Details**.

Es wird kein Bahnhof unbemerkt vorausgewählt. Das Ziel-Banner lässt sich durch Antippen wieder entfernen.

Die Bibliothek wird beim Start im Hintergrund geöffnet. Währenddessen bleiben die übrigen App-Bereiche bedienbar.

## Suche

- RL100-Code in Großbuchstaben eingeben, z. B. `KA`, `KASZ`, `MH` oder `BL`.
- Bahnhofsnamen funktionieren normal sowie mit Umlaut-/ASCII-Variante, z. B. `Köln`/`Koln` und `München`/`Muenchen`.
- Die Suche wartet kurz nach der letzten Eingabe und läuft im Hintergrund. Dadurch bleibt die Tastatur bei schnellen Eingaben flüssig.
- Ein ausgegrauter RIL-Treffer ist in der neuen Liste vorhanden, hat aber keinen passenden Audio-Clip in der eingebetteten Bibliothek.

## Im Zug

1. Modus **Im Zug** wählen.
2. Oben einen Bahnhof suchen und übernehmen. Ist dafür ein kuratierter Im-Zug-Clip vorhanden, wird **„＋ Station einfügen · …“** aktiv. Damit wird genau dieser Stationsclip dauerhaft an die Liste angehängt.
3. Einen weiteren Baustein auswählen und **＋ Baustein** drücken; etwa Gong, „Nächste Station“ oder einen Hinweis. Stationen und Bausteine können beliebig wiederholt werden.
4. Alle Zeilen mit **↑** und **↓** in die Fahrtreihenfolge bringen oder mit **×** löschen.
5. Standardmäßig hält der Player nach jedem Stationsnamen und zeigt **▶ Nächster Halt**. Für eine lückenlose Gesamtwiedergabe das Kästchen **„Nach jedem Stationsnamen auf ‚Nächster Halt‘ warten“** deaktivieren. Die normale Pause bleibt jederzeit verfügbar.
6. **Vorlage speichern** und **WAV exportieren** verwenden dieselbe feste Reihenfolge. Bereits gespeicherte Stationen ändern sich nicht, wenn danach oben ein anderer Bahnhof gewählt wird.

Die fünf separaten **Hinweise** für persönliche Gegenstände, Dank/Verabschiedung, **DB Regio Verabschiedung**, S-Bahn Rhein-Ruhr und Bahnsteigkante stehen als freie Bausteine bereit.

## Datenprüfung

Über **„Offline-Daten prüfen“** wird die SHA-256-Prüfsumme des eingebetteten Opus-Archivs erneut validiert.

Alte, von Vorgängerversionen importierte `offline/`-Daten im App-Speicher werden nach dem erfolgreichen Öffnen der eingebetteten Bibliothek automatisch entfernt.
