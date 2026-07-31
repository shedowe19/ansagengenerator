import 'package:ansagengenerator/core/announcement_builder.dart';
import 'package:ansagengenerator/core/information_options.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('exposes the complete Android-reference delay catalog', () {
    expect(InformationOptions.delays, const <String>[
      '0 · keine',
      '005.wav · ca. 5 min',
      '010.wav · ca. 10 min',
      '015.wav · ca. 15 min',
      '020.wav · ca. 20 min',
      '025.wav · ca. 25 min',
      '030.wav · ca. 30 min',
      '035.wav · ca. 35 min',
      '040.wav · ca. 40 min',
      '045.wav · ca. 45 min',
      '050.wav · ca. 50 min',
      '055.wav · ca. 55 min',
      '060.wav · ca. 60 min',
      '070.wav · ca. 70 min',
      '080.wav · ca. 80 min',
      '090.wav · ca. 90 min',
      '100.wav · ca. 100 min',
      '110.wav · ca. 110 min',
      '120.wav · ca. 120 min',
      '130.wav · ca. 130 min',
      '140.wav · ca. 140 min',
      '150.wav · ca. 150 min',
      '160.wav · ca. 160 min',
      '170.wav · ca. 170 min',
      '180.wav · ca. 180 min',
      '190.wav · ca. 190 min',
      '200.wav · ca. 200 min',
      '210.wav · unbestimmt',
    ]);
  });

  test('exposes the complete Android-reference delay-reason catalog', () {
    expect(InformationOptions.reasons, const <String>[
      '0 · keiner',
      '001.wav · Verzögerung Betriebsablauf',
      '002.wav · Bauarbeiten',
      '003.wav · Personen im Gleis',
      '004.wav · technische Störung am Zug',
      '005.wav · Notarzteinsatz am Gleis',
      '006.wav · Oberleitungsstörung',
      '007.wav · Signalstörung',
      '008.wav · Stellwerksstörung/-ausfall',
      '009.wav · Gegenstände im Gleis',
      '010.wav · Warten auf Fahrgäste/anderer Zug',
      '011.wav · Polizeiliche Ermittlung',
      '012.wav · Feuerwehreinsatz an Strecke',
      '013.wav · ärztliche Versorgung Fahrgast',
      '014.wav · Betätigen der Notbremse',
      '015.wav · Streikauswirkungen',
      '016.wav · ausgebrochene Tiere im Gleis',
      '017.wav · Unwetter',
      '018.wav · Pass- und Zollkontrolle',
      '019.wav · Beeinträchtigung durch Vandalismus',
      '020.wav · Entschärfung einer Fliegerbombe',
      '021.wav · Beschädigung einer Brücke',
      '022.wav · umgestürzter Baum im Gleis',
      '023.wav · Unfall an Bahnübergang',
      '024.wav · Tiere im Gleis',
      '025.wav · Witterungsbedingte Störung',
      '026.wav · Feuerwehreinsatz auf Bahngelände',
      '027.wav · Verspätung im Ausland',
      '028.wav · Warten auf verspätete Zugteile',
      '029.wav · Verzögerung beim Ein-/Ausstieg',
      '030.wav · Streckensperrung',
      '031.wav · technische Störung an der Strecke',
      '032.wav · Anhängen zusätzlicher Wagen',
      '033.wav · Störung an Bahnübergang',
      '034.wav · apl. Geschwindigkeitsbeschränkung',
      '035.wav · Verspätung vorausfahrender Zug',
      '036.wav · Warten entgegenkommender Zug',
      '037.wav · Überholung',
      '038.wav · Warten auf freie Einfahrt',
      '039.wav · verspätete Bereitstellung',
      '040.wav · Verspätung aus vorheriger Fahrt',
      '041.wav · techn. Störung an anderem Zug',
      '042.wav · Umleitung',
    ]);
  });

  test('builds the selected delay time and reason into an information playlist', () {
    final playlist = AnnouncementBuilder(
      draft: const AnnouncementDraft(
        mode: AnnouncementMode.information,
        targetFile: '8010324.wav',
        trainNumbers: <String>['1035'],
        infoDelay: '055.wav · ca. 55 min',
        infoReason: '041.wav · techn. Störung an anderem Zug',
      ),
    ).build();

    expect(playlist, contains('dt/zeiten/verspaetung_heute/055.wav'));
    expect(playlist, contains('dt/gruende/grund_dafuer/041.wav'));
  });
}
