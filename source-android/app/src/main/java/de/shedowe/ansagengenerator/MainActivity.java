package de.shedowe.ansagengenerator;

import android.animation.LayoutTransition;
import android.app.Activity;
import android.content.res.ColorStateList;
import android.graphics.drawable.RippleDrawable;
import android.os.Bundle;
import android.os.Handler;
import android.os.Looper;
import android.content.SharedPreferences;
import android.content.res.AssetManager;
import android.graphics.Color;
import android.media.AudioAttributes;
import android.media.MediaPlayer;
import android.text.Editable;
import android.text.InputFilter;
import android.text.TextUtils;
import android.text.TextWatcher;
import android.view.Gravity;
import android.view.MotionEvent;
import android.view.View;
import android.view.ViewGroup;
import android.view.animation.DecelerateInterpolator;
import android.widget.*;
import android.graphics.Typeface;
import android.graphics.drawable.GradientDrawable;

import org.json.JSONArray;
import org.json.JSONObject;

import java.io.*;
import java.text.SimpleDateFormat;
import java.util.*;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;

public class MainActivity extends Activity {
    private static final String[] BUNDLED_OFFLINE_ARCHIVES = {
            "offline/ansagengenerator-offline-opus-data.zip"
    };
    private final ArrayList<Station> stations = new ArrayList<>();
    private final ArrayList<RilEntry> rilEntries = new ArrayList<>();
    private final ArrayList<String> trainTypes = new ArrayList<>();
    private final HashMap<String, InTrainStationClip> inTrainStationClips = new HashMap<>();
    private final HashMap<String, Station> stationsByFile = new HashMap<>();
    private final HashMap<String, Station> stationsByFoldedName = new HashMap<>();
    private final HashMap<String, Station> stationsByExpandedName = new HashMap<>();
    private final HashMap<String, RilEntry> rilByCode = new HashMap<>();
    private final Handler mainHandler = new Handler(Looper.getMainLooper());
    private final ExecutorService searchExecutor = Executors.newSingleThreadExecutor(runnable -> {
        Thread thread = new Thread(runnable, "station-search");
        thread.setDaemon(true);
        return thread;
    });

    private LinearLayout root;
    private ScrollView mainScroll;
    private LinearLayout stickyDock, stickyTools, historyCard, utilityContent;
    private TextView status, playerStatus, searchFeedback, selectedText, favoritesLabel, historyLabel;
    private Button clearSearchButton, stickyPrimaryButton, stickyPauseButton, stickyMoreButton, utilityToggle, addSelectedInTrainStationButton;
    private boolean stickyToolsExpanded = false;
    private boolean favoritesExpanded = false;
    private boolean historyExpanded = false;
    private EditText searchBox, gleisBox, hourBox, minuteBox, trainNumberBox;
    private EditText trainNumber2Box, trainNumber3Box, viaBox;
    private EditText mit1TrainNumberBox, mit1TrainNumber2Box, mit1TrainNumber3Box, mit1TargetBox, mit1ViaBox;
    private EditText mit2TrainNumberBox, mit2TrainNumber2Box, mit2TrainNumber3Box, mit2TargetBox, mit2ViaBox;
    private EditText split1TargetBox, split2TargetBox, continueTrainNumberBox, continueTrainNumber2Box, continueTrainNumber3Box, continueTargetBox, continueViaBox, continueHourBox, continueMinuteBox;
    private EditText infoNewPlatformBox, infoOnlyUntilBox, haltMinus1Box, haltMinus2Box, haltMinus3Box, haltPlus1Box, haltPlus2Box, haltPlus3Box;
    private EditText dispatchPlatformBox, throughPlatformBox, a2TargetBox, a2ViaBox, a2PlatformBox, a2HourBox, a2MinuteBox, a2TrainNumberBox, a2TrainNumber2Box, a2TrainNumber3Box, a3TargetBox, a3ViaBox, a3PlatformBox, a3HourBox, a3MinuteBox, a3TrainNumberBox, a3TrainNumber2Box, a3TrainNumber3Box;
    private Spinner trainSpinner, modeSpinner, languageSpinner, mit1TrainSpinner, mit2TrainSpinner, continueTrainSpinner, infoDelaySpinner, infoReasonSpinner, specialSpinner, a2TrainSpinner, a3TrainSpinner, inTrainBlockSpinner;
    private CheckBox ersatzBox, delayedBox, mit1Box, mit2Box, split1Box, split2Box, noBoardBox, continueBox, cancelTrainBox, sorryBox, connection2Box, connection3Box, inTrainPauseAfterStationBox;
    private LinearLayout resultList;
    private LinearLayout favoritesList, historyList;
    private LinearLayout coreSection, entrySection, mitSection, splitSection, arrivalSection, infoSection, connectionSection, dispatchSection, passingSection, specialSection, inTrainSection;
    private LinearLayout inTrainSequenceList;
    private Station selectedStation;
    private MediaPlayer currentPlayer;
    private final ArrayList<File> currentQueue = new ArrayList<>();
    private final ArrayList<String> currentRelQueue = new ArrayList<>();
    private int queueIndex = 0;
    private boolean paused = false;
    private boolean waitingForNextInTrainStop = false;
    private boolean pauseAfterInTrainStation = false;
    private String currentSource = "";
    private final ArrayList<String> inTrainSequence = new ArrayList<>();
    private volatile BundledZipLibrary bundledOfflineLibrary;
    private volatile boolean offlineLibraryLoading = false;
    private volatile String offlineLibraryNotice = "";
    private Runnable pendingSearch;
    private long searchGeneration = 0L;
    private boolean suppressMainSearch = false;
    private boolean activityDestroyed = false;

    private final int bg = Color.rgb(5, 6, 10);
    private final int panel = Color.rgb(16, 20, 31);
    private final int panel2 = Color.rgb(22, 27, 41);
    private final int text = Color.rgb(248, 250, 252);
    private final int soft = Color.rgb(219, 228, 240);
    private final int muted = Color.rgb(139, 152, 170);
    private final int accent = Color.rgb(124, 124, 255);
    private final int green = Color.rgb(16, 185, 129);

    private static final String[] MODES = {"Einfahrt", "Ankunft", "Steht bereit", "Information", "Anschluss", "Abfertigung", "Durchfahrt", "Sonderansage", "Im Zug"};
    private static final String[] LANGS = {"Deutsch", "Englisch", "Französisch (nur Sonderansage)"};
    private static final String[] IN_TRAIN_BLOCKS = InTrainSequenceSupport.LABELS;
    private static final long SEARCH_DEBOUNCE_MS = 180L;
    private static final String[] DELAYS = {"0 · keine", "005.wav · ca. 5 min", "010.wav · ca. 10 min", "015.wav · ca. 15 min", "020.wav · ca. 20 min", "025.wav · ca. 25 min", "030.wav · ca. 30 min", "035.wav · ca. 35 min", "040.wav · ca. 40 min", "045.wav · ca. 45 min", "050.wav · ca. 50 min", "055.wav · ca. 55 min", "060.wav · ca. 60 min", "070.wav · ca. 70 min", "080.wav · ca. 80 min", "090.wav · ca. 90 min", "100.wav · ca. 100 min", "110.wav · ca. 110 min", "120.wav · ca. 120 min", "130.wav · ca. 130 min", "140.wav · ca. 140 min", "150.wav · ca. 150 min", "160.wav · ca. 160 min", "170.wav · ca. 170 min", "180.wav · ca. 180 min", "190.wav · ca. 190 min", "200.wav · ca. 200 min", "210.wav · unbestimmt"};
    private static final String[] REASONS = {"0 · keiner", "001.wav · Verzögerung Betriebsablauf", "002.wav · Bauarbeiten", "003.wav · Personen im Gleis", "004.wav · technische Störung am Zug", "005.wav · Notarzteinsatz am Gleis", "006.wav · Oberleitungsstörung", "007.wav · Signalstörung", "008.wav · Stellwerksstörung/-ausfall", "009.wav · Gegenstände im Gleis", "010.wav · Warten auf Fahrgäste/anderer Zug", "011.wav · Polizeiliche Ermittlung", "012.wav · Feuerwehreinsatz an Strecke", "013.wav · ärztliche Versorgung Fahrgast", "014.wav · Betätigen der Notbremse", "015.wav · Streikauswirkungen", "016.wav · ausgebrochene Tiere im Gleis", "017.wav · Unwetter", "018.wav · Pass- und Zollkontrolle", "019.wav · Beeinträchtigung durch Vandalismus", "020.wav · Entschärfung einer Fliegerbombe", "021.wav · Beschädigung einer Brücke", "022.wav · umgestürzter Baum im Gleis", "023.wav · Unfall an Bahnübergang", "024.wav · Tiere im Gleis", "025.wav · Witterungsbedingte Störung", "026.wav · Feuerwehreinsatz auf Bahngelände", "027.wav · Verspätung im Ausland", "028.wav · Warten auf verspätete Zugteile", "029.wav · Verzögerung beim Ein-/Ausstieg", "030.wav · Streckensperrung", "031.wav · technische Störung an der Strecke", "032.wav · Anhängen zusätzlicher Wagen", "033.wav · Störung an Bahnübergang", "034.wav · apl. Geschwindigkeitsbeschränkung", "035.wav · Verspätung vorausfahrender Zug", "036.wav · Warten entgegenkommender Zug", "037.wav · Überholung", "038.wav · Warten auf freie Einfahrt", "039.wav · verspätete Bereitstellung", "040.wav · Verspätung aus vorheriger Fahrt", "041.wav · techn. Störung an anderem Zug", "042.wav · Umleitung"};
    private static final String[] SPECIALS = {"001.wav · Gepäck", "002.wav · Rauchverbot", "003.wav · Raucherbereich", "004.wav · Bettelgruppen", "005.wav · Trickdiebe", "006.wav · Hinweis Zugbetrieb", "007.wav · Feueralarm", "008.wav · Bombendrohung"};

    @Override public void onCreate(Bundle b) {
        super.onCreate(b);
        getWindow().setStatusBarColor(bg);
        getWindow().setNavigationBarColor(bg);
        loadData();
        buildMainUi();
        initializeBundledOfflineLibraryAsync();
    }

    private void loadData() {
        try {
            JSONArray s = new JSONArray(readAsset("stations.json"));
            for (int i = 0; i < s.length(); i++) {
                JSONObject o = s.getJSONObject(i);
                Station station = new Station(o.optString("station"), o.optString("filepath"), o.optString("ibnr"));
                stations.add(station);
                if (station.filepath.length() > 0 && !stationsByFile.containsKey(station.filepath)) stationsByFile.put(station.filepath, station);
                if (station.foldedName.length() > 0 && !stationsByFoldedName.containsKey(station.foldedName)) stationsByFoldedName.put(station.foldedName, station);
                if (station.expandedName.length() > 0 && !stationsByExpandedName.containsKey(station.expandedName)) stationsByExpandedName.put(station.expandedName, station);
            }
            JSONArray r = new JSONArray(readAsset("ril100.json"));
            for (int i = 0; i < r.length(); i++) {
                JSONObject o = r.getJSONObject(i);
                RilEntry entry = new RilEntry(o.optString("code"), o.optString("name"), o.optString("station"), o.optString("filepath"), o.optString("ibnr"));
                rilEntries.add(entry);
                if (entry.code.length() > 0 && !rilByCode.containsKey(entry.code)) rilByCode.put(entry.code, entry);
            }
            JSONArray t = new JSONArray(readAsset("train_types.json"));
            for (int i = 0; i < t.length(); i++) trainTypes.add(t.getString(i));
            JSONArray iz = new JSONArray(readAsset("inzug/inzug_station_mapping.json"));
            for (int i = 0; i < iz.length(); i++) {
                JSONObject o = iz.getJSONObject(i);
                InTrainStationClip clip = new InTrainStationClip(o.optString("station"), o.optString("raw"), o.optString("filepath"), o.optString("clip"));
                if (clip.filepath.length() > 0 && clip.clip.length() > 0) inTrainStationClips.put(clip.filepath, clip);
            }
        } catch (Exception e) {
            Toast.makeText(this, "Daten konnten nicht geladen werden: " + e.getMessage(), Toast.LENGTH_LONG).show();
        }
        // Ein Ziel wird bewusst nicht vorab gewählt: So kann keine Ansage versehentlich
        // mit dem historischen Standardbahnhof erzeugt werden.
        selectedStation = null;
    }

    private String readAsset(String name) throws IOException {
        AssetManager am = getAssets();
        ByteArrayOutputStream bos = new ByteArrayOutputStream();
        InputStream in = am.open(name);
        byte[] buf = new byte[16384];
        int n;
        while ((n = in.read(buf)) >= 0) bos.write(buf, 0, n);
        in.close();
        return bos.toString("UTF-8");
    }

    private void buildMainUi() {
        FrameLayout appShell = new FrameLayout(this);
        mainScroll = new ScrollView(this);
        mainScroll.setFillViewport(true);
        mainScroll.setClipToPadding(false);
        root = new LinearLayout(this);
        root.setOrientation(LinearLayout.VERTICAL);
        // Freiraum für die dauerhaft erreichbare Wiedergabeleiste.
        root.setPadding(dp(16), dp(12), dp(16), dp(176));
        root.setBackgroundColor(bg);
        mainScroll.addView(root, new ScrollView.LayoutParams(-1, -2));
        appShell.addView(mainScroll, new FrameLayout.LayoutParams(-1, -1));
        buildStickyPlaybackDock(appShell);
        setContentView(appShell);

        LinearLayout hero = card();
        hero.setPadding(dp(14), dp(12), dp(14), dp(12));
        root.addView(hero, lp(-1, -2, 0, 0, 0, dp(10)));
        LinearLayout heroTop = buttonRow();
        hero.addView(heroTop);
        TextView mark = tv("▶", 16, Color.WHITE, true);
        mark.setGravity(Gravity.CENTER);
        mark.setContentDescription("Ansagengenerator");
        mark.setBackground(round(accent, dp(12), Color.argb(70, 255, 255, 255), 1));
        heroTop.addView(mark, new LinearLayout.LayoutParams(dp(40), dp(40)));
        LinearLayout heroCopy = new LinearLayout(this);
        heroCopy.setOrientation(LinearLayout.VERTICAL);
        LinearLayout.LayoutParams heroCopyLp = new LinearLayout.LayoutParams(0, -2, 1);
        heroCopyLp.leftMargin = dp(10);
        heroTop.addView(heroCopy, heroCopyLp);
        TextView title = tv("Ansagengenerator", 23, text, true);
        heroCopy.addView(title);
        TextView sub = tv("Ziel wählen · Ansage konfigurieren · abspielen", 12, muted, false);
        sub.setPadding(0, dp(1), 0, 0);
        heroCopy.addView(sub);
        status = tv(statusText(), 12, soft, false);
        status.setSingleLine(true);
        status.setEllipsize(TextUtils.TruncateAt.END);
        status.setPadding(dp(10), dp(7), dp(10), dp(7));
        status.setBackground(round(Color.rgb(20, 26, 39), dp(999), Color.argb(30,255,255,255), 1));
        status.setContentDescription("Status der Offline-Bibliothek");
        hero.addView(status, lp(-1, -2, 0, dp(9), 0, 0));

        LinearLayout searchCard = card();
        searchCard.setPadding(dp(14), dp(14), dp(14), dp(12));
        root.addView(searchCard, lp(-1, -2, 0, 0, 0, dp(10)));
        searchCard.addView(tv("1 · Zielbahnhof", 18, text, true));
        TextView hint = tv("Bahnhof oder RIL-100-Code eingeben", 12, muted, false);
        hint.setPadding(0, dp(3), 0, dp(8));
        searchCard.addView(hint);
        LinearLayout searchRow = buttonRow();
        searchCard.addView(searchRow, lp(-1, dp(50), 0, 0, 0, dp(6)));
        searchBox = edit("Suchen …", "");
        searchBox.setContentDescription("Zielbahnhof oder RIL-100-Code suchen");
        searchRow.addView(searchBox, new LinearLayout.LayoutParams(0, dp(50), 1));
        clearSearchButton = button("×", false);
        clearSearchButton.setContentDescription("Suche löschen");
        clearSearchButton.setVisibility(View.GONE);
        clearSearchButton.setOnClickListener(v -> clearSearch());
        LinearLayout.LayoutParams clearLp = new LinearLayout.LayoutParams(dp(50), dp(50));
        clearLp.leftMargin = dp(6);
        searchRow.addView(clearSearchButton, clearLp);
        searchFeedback = tv("", 12, muted, false);
        searchFeedback.setPadding(dp(4), dp(2), dp(4), dp(4));
        searchFeedback.setVisibility(View.GONE);
        searchCard.addView(searchFeedback);
        selectedText = tv("", 13, soft, true);
        selectedText.setPadding(dp(12), dp(9), dp(12), dp(9));
        selectedText.setBackground(round(Color.rgb(13, 30, 34), dp(14), Color.argb(70, 16, 185, 129), 1));
        selectedText.setContentDescription("Aktuell ausgewähltes Ziel, antippen zum Entfernen");
        selectedText.setOnClickListener(v -> clearSelectedStation());
        searchCard.addView(selectedText, lp(-1, -2, 0, 0, 0, dp(6)));
        resultList = new LinearLayout(this);
        resultList.setOrientation(LinearLayout.VERTICAL);
        resultList.setLayoutTransition(listTransition());
        searchCard.addView(resultList);
        updateSelected();
        searchBox.addTextChangedListener(new TextWatcher() {
            public void beforeTextChanged(CharSequence s, int st, int c, int a) {}
            public void onTextChanged(CharSequence s, int st, int before, int c) { }
            public void afterTextChanged(Editable e) {
                String query = e == null ? "" : e.toString();
                if (clearSearchButton != null) clearSearchButton.setVisibility(query.trim().isEmpty() ? View.GONE : View.VISIBLE);
                if (!suppressMainSearch) scheduleSearch(query);
            }
        });
        searchBox.setOnFocusChangeListener((view, focused) -> {
            view.setBackground(inputSurface(focused));
            if (focused) {
                animateEmphasis(view);
                if (searchBox.getText().toString().trim().isEmpty()) scheduleSearch("");
            }
        });
        resetSearchPresentation();

        LinearLayout genCard = card();
        genCard.setPadding(dp(14), dp(14), dp(14), dp(14));
        root.addView(genCard, lp(-1, -2, 0, 0, 0, dp(10)));
        genCard.addView(tv("2 · Ansage", 18, text, true));

        LinearLayout modeRow = buttonRow();
        genCard.addView(modeRow, lp(-1, -2, 0, dp(8), 0, dp(4)));
        modeSpinner = spinner(MODES);
        LinearLayout.LayoutParams modeLp = new LinearLayout.LayoutParams(0, -2, 2f);
        modeRow.addView(wrapSpinner("Modus", modeSpinner, 2), modeLp);
        languageSpinner = spinner(LANGS);
        LinearLayout.LayoutParams languageLp = new LinearLayout.LayoutParams(0, -2, 1f);
        languageLp.leftMargin = dp(8);
        modeRow.addView(wrapSpinner("Sprache", languageSpinner, 1), languageLp);
        // Die Moduswahl selbst ist die vollständige Navigation; keine zweite, konkurrierende Schnellwahl.

        coreSection = section(genCard, "Zug, Ziel und Zeit", "Gleis, Zuggattung, Zugnummer, Ziel, Via und Zeit für die gewählte Ansage.");
        LinearLayout row1 = row(); coreSection.addView(row1);
        gleisBox = numEdit("Gleis", "1", 3); row1.addView(wrapField("Gleis", gleisBox, 1));
        hourBox = numEdit("Std", "18", 2); row1.addView(wrapField("Stunde", hourBox, 1));
        minuteBox = numEdit("Min", "59", 2); row1.addView(wrapField("Minute", minuteBox, 1));
        trainSpinner = trainSpinnerControl(); coreSection.addView(fullWidth(wrapSpinner("Zuggattung", trainSpinner, 1)));
        trainNumberBox = numEdit("Zugnummer bis 5-stellig", "12345", 5); coreSection.addView(fullWidth(wrapField("Zugnummer", trainNumberBox, 1)));
        LinearLayout nrRow = row(); coreSection.addView(nrRow, lp(-1, -2, 0, 0, 0, dp(8)));
        trainNumber2Box = numEdit("weitere Nr.", "", 5); nrRow.addView(wrapField("Zugnummer 2", trainNumber2Box, 1));
        trainNumber3Box = numEdit("weitere Nr.", "", 5); nrRow.addView(wrapField("Zugnummer 3", trainNumber3Box, 1));
        viaBox = edit("Via Bahnhof/RIL/IBNR oder 0", "0"); coreSection.addView(fullWidth(wrapField("Via / über", viaBox, 1)));
        delayedBox = check("verspätet / ursprünglich"); addCheckRow(coreSection, delayedBox);

        entrySection = section(genCard, "Einfahrt / Zug steht bereit", "Ersatzzug, Mit-Züge und Zugteilung gezielt aktivieren.");
        ersatzBox = check("Ersatzzug"); mit1Box = check("mit Zug 1"); mit2Box = check("mit Zug 2"); split1Box = check("Zugteilung 1"); split2Box = check("Zugteilung 2");
        addCheckRow(entrySection, ersatzBox, mit1Box, mit2Box);
        addCheckRow(entrySection, split1Box, split2Box);

        mitSection = section(genCard, "Mit-Züge", "Optionale Zusatzzüge mit eigener Zuggattung, Nummer, Ziel und Via.");
        LinearLayout mitRow1 = row(); mitSection.addView(mitRow1);
        mit1TrainSpinner = trainSpinnerControl(); mitRow1.addView(wrapSpinner("Mit-Zug 1 Typ", mit1TrainSpinner, 1));
        mit1TrainNumberBox = numEdit("Nr.", "", 5); mitRow1.addView(wrapField("Mit-Zug 1 Nr.", mit1TrainNumberBox, 1));
        LinearLayout mitRow1n = row(); mitSection.addView(mitRow1n);
        mit1TrainNumber2Box = numEdit("weitere Nr.", "", 5); mitRow1n.addView(wrapField("Mit-Zug 1 Nr. 2", mit1TrainNumber2Box, 1));
        mit1TrainNumber3Box = numEdit("weitere Nr.", "", 5); mitRow1n.addView(wrapField("Mit-Zug 1 Nr. 3", mit1TrainNumber3Box, 1));
        LinearLayout mitRow1b = row(); mitSection.addView(mitRow1b);
        mit1TargetBox = edit("Ziel", ""); mitRow1b.addView(wrapField("Mit-Zug 1 Ziel", mit1TargetBox, 1));
        mit1ViaBox = edit("Via/0", "0"); mitRow1b.addView(wrapField("Mit-Zug 1 Via", mit1ViaBox, 1));
        LinearLayout mitRow2 = row(); mitSection.addView(mitRow2, lp(-1, -2, 0, dp(8), 0, 0));
        mit2TrainSpinner = trainSpinnerControl(); mitRow2.addView(wrapSpinner("Mit-Zug 2 Typ", mit2TrainSpinner, 1));
        mit2TrainNumberBox = numEdit("Nr.", "", 5); mitRow2.addView(wrapField("Mit-Zug 2 Nr.", mit2TrainNumberBox, 1));
        LinearLayout mitRow2n = row(); mitSection.addView(mitRow2n);
        mit2TrainNumber2Box = numEdit("weitere Nr.", "", 5); mitRow2n.addView(wrapField("Mit-Zug 2 Nr. 2", mit2TrainNumber2Box, 1));
        mit2TrainNumber3Box = numEdit("weitere Nr.", "", 5); mitRow2n.addView(wrapField("Mit-Zug 2 Nr. 3", mit2TrainNumber3Box, 1));
        LinearLayout mitRow2b = row(); mitSection.addView(mitRow2b);
        mit2TargetBox = edit("Ziel", ""); mitRow2b.addView(wrapField("Mit-Zug 2 Ziel", mit2TargetBox, 1));
        mit2ViaBox = edit("Via/0", "0"); mitRow2b.addView(wrapField("Mit-Zug 2 Via", mit2ViaBox, 1));

        splitSection = section(genCard, "Zugteilung", "Teilungsziele für die aktivierte Zugteilung.");
        LinearLayout splitRow = row(); splitSection.addView(splitRow);
        split1TargetBox = edit("Teil 1 Ziel", ""); splitRow.addView(wrapField("Teilung 1", split1TargetBox, 1));
        split2TargetBox = edit("Teil 2 Ziel", ""); splitRow.addView(wrapField("Teilung 2", split2TargetBox, 1));

        arrivalSection = section(genCard, "Ankunft", "Nicht einsteigen und Weiterfahrt als weitere Ansageelemente.");
        noBoardBox = check("bitte nicht einsteigen"); continueBox = check("weiter als"); addCheckRow(arrivalSection, noBoardBox, continueBox);
        LinearLayout contRow = row(); arrivalSection.addView(contRow);
        continueTrainSpinner = trainSpinnerControl(); contRow.addView(wrapSpinner("Weiter als Typ", continueTrainSpinner, 1));
        continueTrainNumberBox = numEdit("Nr.", "", 5); contRow.addView(wrapField("Weiter als Nr.", continueTrainNumberBox, 1));
        LinearLayout contNrRow = row(); arrivalSection.addView(contNrRow);
        continueTrainNumber2Box = numEdit("weitere Nr.", "", 5); contNrRow.addView(wrapField("Weiter als Nr. 2", continueTrainNumber2Box, 1));
        continueTrainNumber3Box = numEdit("weitere Nr.", "", 5); contNrRow.addView(wrapField("Weiter als Nr. 3", continueTrainNumber3Box, 1));
        LinearLayout contRow2 = row(); arrivalSection.addView(contRow2);
        continueTargetBox = edit("Ziel", ""); contRow2.addView(wrapField("Weiter Ziel", continueTargetBox, 1));
        continueViaBox = edit("Via/0", "0"); contRow2.addView(wrapField("Weiter Via", continueViaBox, 1));
        LinearLayout contRow3 = row(); arrivalSection.addView(contRow3);
        continueHourBox = numEdit("Std", "18", 2); contRow3.addView(wrapField("Weiter Stunde", continueHourBox, 1));
        continueMinuteBox = numEdit("Min", "59", 2); contRow3.addView(wrapField("Weiter Minute", continueMinuteBox, 1));

        infoSection = section(genCard, "Information", "Verspätung, Grund, Gleiswechsel, Halte und Ausfall.");
        LinearLayout infoRow = row(); infoSection.addView(infoRow);
        infoDelaySpinner = spinner(DELAYS); infoRow.addView(wrapSpinner("Verspätung", infoDelaySpinner, 1));
        infoReasonSpinner = spinner(REASONS); infoRow.addView(wrapSpinner("Grund", infoReasonSpinner, 1));
        LinearLayout infoRow2 = row(); infoSection.addView(infoRow2);
        infoNewPlatformBox = numEdit("0", "0", 3); infoRow2.addView(wrapField("Gleiswechsel", infoNewPlatformBox, 1));
        infoOnlyUntilBox = edit("Bahnhof/RIL/0", "0"); infoRow2.addView(wrapField("Heute nur bis", infoOnlyUntilBox, 1));
        LinearLayout haltMinusRow = row(); infoSection.addView(haltMinusRow);
        haltMinus1Box = edit("0", "0"); haltMinusRow.addView(wrapField("Halt entfällt 1", haltMinus1Box, 1));
        haltMinus2Box = edit("0", "0"); haltMinusRow.addView(wrapField("Halt entfällt 2", haltMinus2Box, 1));
        haltMinus3Box = edit("0", "0"); haltMinusRow.addView(wrapField("Halt entfällt 3", haltMinus3Box, 1));
        LinearLayout haltPlusRow = row(); infoSection.addView(haltPlusRow);
        haltPlus1Box = edit("0", "0"); haltPlusRow.addView(wrapField("Zusatzhalt 1", haltPlus1Box, 1));
        haltPlus2Box = edit("0", "0"); haltPlusRow.addView(wrapField("Zusatzhalt 2", haltPlus2Box, 1));
        haltPlus3Box = edit("0", "0"); haltPlusRow.addView(wrapField("Zusatzhalt 3", haltPlus3Box, 1));
        cancelTrainBox = check("Zugausfall"); sorryBox = check("Entschuldigung"); addCheckRow(infoSection, cancelTrainBox, sorryBox);

        connectionSection = section(genCard, "Anschluss", "Anschluss 1 nutzt die Hauptfelder; Anschluss 2 und 3 können zusätzlich aktiviert werden.");
        connection2Box = check("Anschluss 2"); connection3Box = check("Anschluss 3"); addCheckRow(connectionSection, connection2Box, connection3Box);
        LinearLayout a2row = row(); connectionSection.addView(a2row);
        a2TrainSpinner = trainSpinnerControl(); a2row.addView(wrapSpinner("Anschluss 2 Typ", a2TrainSpinner, 1));
        a2TrainNumberBox = numEdit("Nr.", "", 5); a2row.addView(wrapField("Anschluss 2 Nr.", a2TrainNumberBox, 1));
        LinearLayout a2nrRow = row(); connectionSection.addView(a2nrRow);
        a2TrainNumber2Box = numEdit("weitere Nr.", "", 5); a2nrRow.addView(wrapField("Anschluss 2 Nr. 2", a2TrainNumber2Box, 1));
        a2TrainNumber3Box = numEdit("weitere Nr.", "", 5); a2nrRow.addView(wrapField("Anschluss 2 Nr. 3", a2TrainNumber3Box, 1));
        LinearLayout a2row2 = row(); connectionSection.addView(a2row2);
        a2TargetBox = edit("Ziel", ""); a2row2.addView(wrapField("Anschluss 2 Ziel", a2TargetBox, 1));
        a2ViaBox = edit("Via/0", "0"); a2row2.addView(wrapField("Anschluss 2 Via", a2ViaBox, 1));
        a2PlatformBox = numEdit("Gleis", "1", 3); a2row2.addView(wrapField("Anschluss 2 Gleis", a2PlatformBox, 1));
        LinearLayout a2row3 = row(); connectionSection.addView(a2row3);
        a2HourBox = numEdit("Std", "18", 2); a2row3.addView(wrapField("Anschluss 2 Stunde", a2HourBox, 1));
        a2MinuteBox = numEdit("Min", "59", 2); a2row3.addView(wrapField("Anschluss 2 Minute", a2MinuteBox, 1));
        LinearLayout a3row = row(); connectionSection.addView(a3row, lp(-1, -2, 0, dp(8), 0, 0));
        a3TrainSpinner = trainSpinnerControl(); a3row.addView(wrapSpinner("Anschluss 3 Typ", a3TrainSpinner, 1));
        a3TrainNumberBox = numEdit("Nr.", "", 5); a3row.addView(wrapField("Anschluss 3 Nr.", a3TrainNumberBox, 1));
        LinearLayout a3nrRow = row(); connectionSection.addView(a3nrRow);
        a3TrainNumber2Box = numEdit("weitere Nr.", "", 5); a3nrRow.addView(wrapField("Anschluss 3 Nr. 2", a3TrainNumber2Box, 1));
        a3TrainNumber3Box = numEdit("weitere Nr.", "", 5); a3nrRow.addView(wrapField("Anschluss 3 Nr. 3", a3TrainNumber3Box, 1));
        LinearLayout a3row2 = row(); connectionSection.addView(a3row2);
        a3TargetBox = edit("Ziel", ""); a3row2.addView(wrapField("Anschluss 3 Ziel", a3TargetBox, 1));
        a3ViaBox = edit("Via/0", "0"); a3row2.addView(wrapField("Anschluss 3 Via", a3ViaBox, 1));
        a3PlatformBox = numEdit("Gleis", "1", 3); a3row2.addView(wrapField("Anschluss 3 Gleis", a3PlatformBox, 1));
        LinearLayout a3row3 = row(); connectionSection.addView(a3row3);
        a3HourBox = numEdit("Std", "18", 2); a3row3.addView(wrapField("Anschluss 3 Stunde", a3HourBox, 1));
        a3MinuteBox = numEdit("Min", "59", 2); a3row3.addView(wrapField("Anschluss 3 Minute", a3MinuteBox, 1));

        dispatchSection = section(genCard, "Abfertigung", "Gleis für die Abfertigungsansage.");
        dispatchPlatformBox = numEdit("Gleis", "1", 3); dispatchSection.addView(fullWidth(wrapField("Abfertigung Gleis", dispatchPlatformBox, 1)));

        passingSection = section(genCard, "Durchfahrt", "Gleis für die Durchfahrtsansage.");
        throughPlatformBox = numEdit("Gleis", "1", 3); passingSection.addView(fullWidth(wrapField("Durchfahrt Gleis", throughPlatformBox, 1)));

        specialSection = section(genCard, "Sonderansagen", "Sprache und gewünschte Sonderansage wählen.");
        specialSpinner = spinner(SPECIALS); specialSection.addView(fullWidth(wrapSpinner("Sonderansage", specialSpinner, 1)));

        inTrainSection = section(genCard, "Im Zug · Wiedergabeliste", "Bausteine und einzelne Stationen manuell hinzufügen, frei sortieren und als zusammenhängende Strecke abspielen.");
        inTrainBlockSpinner = spinner(IN_TRAIN_BLOCKS);
        inTrainSection.addView(fullWidth(wrapSpinner("Baustein", inTrainBlockSpinner, 1)));
        LinearLayout inTrainActions = buttonRow();
        inTrainSection.addView(inTrainActions);
        Button addInTrainBlock = button("＋ Baustein", true);
        addInTrainBlock.setOnClickListener(v -> addSelectedInTrainBlock());
        inTrainActions.addView(addInTrainBlock, new LinearLayout.LayoutParams(0, dp(48), 1));
        Button clearInTrainBlocks = button("Leeren", false);
        clearInTrainBlocks.setContentDescription("Im-Zug-Wiedergabeliste leeren");
        clearInTrainBlocks.setOnClickListener(v -> { inTrainSequence.clear(); renderInTrainSequence(); });
        LinearLayout.LayoutParams clearInTrainLp = new LinearLayout.LayoutParams(0, dp(48), 1);
        clearInTrainLp.leftMargin = dp(8);
        inTrainActions.addView(clearInTrainBlocks, clearInTrainLp);
        addSelectedInTrainStationButton = button("＋ Ausgewählte Station", true);
        addSelectedInTrainStationButton.setContentDescription("Aktuell ausgewählte Station in die Im-Zug-Wiedergabeliste einfügen");
        addSelectedInTrainStationButton.setOnClickListener(v -> addSelectedInTrainStation());
        inTrainSection.addView(addSelectedInTrainStationButton, lp(-1, dp(48), 0, dp(8), 0, 0));
        inTrainPauseAfterStationBox = check("Nach jedem Stationsnamen auf „Nächster Halt“ warten");
        inTrainPauseAfterStationBox.setChecked(true);
        inTrainPauseAfterStationBox.setContentDescription("Nach jedem Stationsnamen die Wiedergabe anhalten, bis Nächster Halt gewählt wird");
        addCheckRow(inTrainSection, inTrainPauseAfterStationBox);
        TextView inTrainOrder = tv("Reihenfolge", 13, soft, true);
        inTrainOrder.setPadding(0, dp(12), 0, dp(4));
        inTrainSection.addView(inTrainOrder);
        inTrainSequenceList = new LinearLayout(this);
        inTrainSequenceList.setOrientation(LinearLayout.VERTICAL);
        inTrainSequenceList.setLayoutTransition(listTransition());
        inTrainSection.addView(inTrainSequenceList);
        renderInTrainSequence();
        refreshInTrainStationAddAction();
        TextView inTrainHint = tv("Wähle oben einen Bahnhof und füge ihn als festen Listenpunkt ein. Danach bleibt die Station auch bei einer neuen Bahnhofsauswahl, in Vorlagen und beim WAV-Export unverändert. Nur die verfügbaren kuratierten Im-Zug-Stationsclips lassen sich einfügen.", 12, muted, false);
        inTrainHint.setPadding(0, dp(4), 0, 0);
        inTrainSection.addView(inTrainHint);

        modeSpinner.setOnItemSelectedListener(new AdapterView.OnItemSelectedListener() {
            public void onItemSelected(AdapterView<?> parent, View view, int position, long id) { applyModeStructure(); }
            public void onNothingSelected(AdapterView<?> parent) { applyModeStructure(); }
        });
        applyModeStructure();

        // Wiedergabe, Export und Speichern liegen dauerhaft in der unteren Leiste.
        // Der Formularbereich bleibt dadurch auf die eigentliche Ansage konzentriert.

        historyCard = card();
        historyCard.setPadding(dp(14), dp(14), dp(14), dp(12));
        root.addView(historyCard, lp(-1, -2, 0, 0, 0, dp(10)));
        historyCard.addView(tv("Vorlagen & Verlauf", 18, text, true));
        favoritesLabel = tv("Favoriten", 12, soft, true);
        favoritesLabel.setPadding(0, dp(10), 0, dp(4));
        historyCard.addView(favoritesLabel);
        favoritesList = new LinearLayout(this);
        favoritesList.setOrientation(LinearLayout.VERTICAL);
        favoritesList.setLayoutTransition(listTransition());
        historyCard.addView(favoritesList);
        historyLabel = tv("Zuletzt verwendet", 12, soft, true);
        historyLabel.setPadding(0, dp(10), 0, dp(4));
        historyCard.addView(historyLabel);
        historyList = new LinearLayout(this);
        historyList.setOrientation(LinearLayout.VERTICAL);
        historyList.setLayoutTransition(listTransition());
        historyCard.addView(historyList);
        renderStoredLists();

        LinearLayout utilityCard = card();
        utilityCard.setPadding(dp(14), dp(12), dp(14), dp(12));
        root.addView(utilityCard, lp(-1, -2, 0, 0, 0, dp(0)));
        LinearLayout utilityHeader = buttonRow();
        utilityCard.addView(utilityHeader);
        LinearLayout utilityCopy = new LinearLayout(this);
        utilityCopy.setOrientation(LinearLayout.VERTICAL);
        utilityHeader.addView(utilityCopy, new LinearLayout.LayoutParams(0, -2, 1));
        utilityCopy.addView(tv("App & Daten", 16, text, true));
        utilityCopy.addView(tv("Offline-Bibliothek und Verlauf verwalten", 12, muted, false));
        utilityToggle = compactButton("Details");
        utilityToggle.setContentDescription("App- und Datenoptionen ein- oder ausblenden");
        utilityToggle.setOnClickListener(v -> toggleUtility());
        LinearLayout.LayoutParams utilityToggleLp = new LinearLayout.LayoutParams(dp(86), dp(42));
        utilityToggleLp.leftMargin = dp(8);
        utilityHeader.addView(utilityToggle, utilityToggleLp);
        utilityContent = new LinearLayout(this);
        utilityContent.setOrientation(LinearLayout.VERTICAL);
        utilityContent.setVisibility(View.GONE);
        TextView detail = tv("Die vollständige Bibliothek bleibt in der APK. Nur gerade benötigte WAV-Dateien landen kurz im Cache.", 12, muted, false);
        detail.setPadding(0, dp(12), 0, dp(8));
        utilityContent.addView(detail);
        LinearLayout utilityActions = buttonRow();
        Button verify = compactButton("Daten prüfen");
        verify.setOnClickListener(v -> verifyOfflineData());
        utilityActions.addView(verify, new LinearLayout.LayoutParams(0, dp(44), 1));
        Button clearLists = compactButton("Verlauf löschen");
        clearLists.setOnClickListener(v -> clearHistory());
        LinearLayout.LayoutParams clearHistoryLp = new LinearLayout.LayoutParams(0, dp(44), 1);
        clearHistoryLp.leftMargin = dp(8);
        utilityActions.addView(clearLists, clearHistoryLp);
        utilityContent.addView(utilityActions);
        utilityCard.addView(utilityContent);

        animateEntrance(hero, 0L);
        animateEntrance(searchCard, 45L);
        animateEntrance(genCard, 90L);
        if (historyCard.getVisibility() == View.VISIBLE) animateEntrance(historyCard, 135L);
        animateEntrance(utilityCard, 165L);
    }

    private void buildStickyPlaybackDock(FrameLayout shell) {
        stickyDock = new LinearLayout(this);
        stickyDock.setOrientation(LinearLayout.VERTICAL);
        stickyDock.setPadding(dp(12), dp(8), dp(12), dp(10));
        stickyDock.setElevation(dp(14));
        stickyDock.setBackground(round(Color.rgb(16, 20, 31), dp(22), Color.argb(74, 255, 255, 255), 1));

        playerStatus = tv("Bereit zum Abspielen", 12, soft, false);
        playerStatus.setSingleLine(true);
        playerStatus.setEllipsize(TextUtils.TruncateAt.END);
        playerStatus.setContentDescription("Wiedergabestatus");
        playerStatus.setPadding(dp(8), 0, dp(8), dp(6));
        stickyDock.addView(playerStatus, new LinearLayout.LayoutParams(-1, -2));

        stickyTools = new LinearLayout(this);
        stickyTools.setOrientation(LinearLayout.VERTICAL);
        stickyTools.setVisibility(View.GONE);
        LinearLayout firstToolsRow = buttonRow();
        Button export = compactButton("WAV exportieren");
        export.setOnClickListener(v -> exportCurrentAnnouncement());
        firstToolsRow.addView(export, new LinearLayout.LayoutParams(0, dp(42), 1));
        Button favorite = compactButton("Vorlage speichern");
        favorite.setOnClickListener(v -> saveCurrentFavorite());
        LinearLayout.LayoutParams favoriteLp = new LinearLayout.LayoutParams(0, dp(42), 1);
        favoriteLp.leftMargin = dp(8);
        firstToolsRow.addView(favorite, favoriteLp);
        stickyTools.addView(firstToolsRow, lp(-1, -2, 0, 0, 0, dp(8)));
        stickyDock.addView(stickyTools, new LinearLayout.LayoutParams(-1, -2));

        LinearLayout dockActions = buttonRow();
        stickyDock.addView(dockActions);
        stickyPrimaryButton = button("▶ Abspielen", true);
        stickyPrimaryButton.setTextSize(15);
        dockActions.addView(stickyPrimaryButton, new LinearLayout.LayoutParams(0, dp(52), 1));
        stickyPauseButton = compactButton("⏸");
        stickyPauseButton.setContentDescription("Wiedergabe pausieren");
        stickyPauseButton.setVisibility(View.GONE);
        LinearLayout.LayoutParams pauseLp = new LinearLayout.LayoutParams(dp(52), dp(52));
        pauseLp.leftMargin = dp(8);
        dockActions.addView(stickyPauseButton, pauseLp);
        stickyMoreButton = compactButton("⋯");
        stickyMoreButton.setContentDescription("Weitere Aktionen anzeigen");
        stickyMoreButton.setOnClickListener(v -> toggleStickyTools());
        LinearLayout.LayoutParams moreLp = new LinearLayout.LayoutParams(dp(52), dp(52));
        moreLp.leftMargin = dp(8);
        dockActions.addView(stickyMoreButton, moreLp);

        FrameLayout.LayoutParams dockLp = new FrameLayout.LayoutParams(-1, -2, Gravity.BOTTOM);
        dockLp.setMargins(dp(10), 0, dp(10), dp(10));
        shell.addView(stickyDock, dockLp);
        updatePlaybackControls();
    }

    private void toggleStickyTools() {
        stickyToolsExpanded = !stickyToolsExpanded;
        setVisible(stickyTools, stickyToolsExpanded);
        if (stickyMoreButton != null) {
            stickyMoreButton.setText(stickyToolsExpanded ? "⌃" : "⋯");
            stickyMoreButton.setContentDescription(stickyToolsExpanded ? "Weitere Aktionen ausblenden" : "Weitere Aktionen anzeigen");
        }
    }

    private void toggleUtility() {
        boolean visible = utilityContent != null && utilityContent.getVisibility() != View.VISIBLE;
        setVisible(utilityContent, visible);
        if (utilityToggle != null) utilityToggle.setText(visible ? "Weniger" : "Details");
    }

    private void updatePlaybackControls() {
        if (stickyPrimaryButton == null || stickyPauseButton == null) return;
        if (currentPlayer == null) {
            if (waitingForNextInTrainStop && queueIndex < currentQueue.size()) {
                stickyPrimaryButton.setText("▶ Nächster Halt");
                stickyPrimaryButton.setContentDescription("Nächsten Halt der Im-Zug-Wiedergabeliste abspielen");
                stickyPrimaryButton.setOnClickListener(v -> resumePlayback());
                stickyPauseButton.setVisibility(View.VISIBLE);
                stickyPauseButton.setText("■");
                stickyPauseButton.setContentDescription("Wiedergabeliste stoppen");
                stickyPauseButton.setOnClickListener(v -> stopPlayback());
                return;
            }
            stickyPrimaryButton.setText("▶ Abspielen");
            stickyPrimaryButton.setContentDescription("Ansage abspielen");
            stickyPrimaryButton.setOnClickListener(v -> playAnnouncement());
            stickyPauseButton.setVisibility(View.GONE);
            return;
        }
        stickyPauseButton.setVisibility(View.VISIBLE);
        if (paused) {
            stickyPrimaryButton.setText("▶ Weiter");
            stickyPrimaryButton.setContentDescription("Pausierte Wiedergabe fortsetzen");
            stickyPrimaryButton.setOnClickListener(v -> resumePlayback());
            stickyPauseButton.setText("■");
            stickyPauseButton.setContentDescription("Wiedergabe stoppen");
            stickyPauseButton.setOnClickListener(v -> stopPlayback());
        } else {
            stickyPrimaryButton.setText("■ Stop");
            stickyPrimaryButton.setContentDescription("Wiedergabe stoppen");
            stickyPrimaryButton.setOnClickListener(v -> stopPlayback());
            stickyPauseButton.setText("⏸");
            stickyPauseButton.setContentDescription("Wiedergabe pausieren");
            stickyPauseButton.setOnClickListener(v -> pausePlayback());
        }
    }

    private LinearLayout card() {
        LinearLayout l = new LinearLayout(this);
        l.setOrientation(LinearLayout.VERTICAL);
        l.setPadding(dp(16), dp(16), dp(16), dp(16));
        l.setBackground(round(panel, dp(24), Color.argb(28,255,255,255), 1));
        l.setElevation(dp(3));
        return l;
    }

    private LinearLayout section(LinearLayout parent, String title, String hint) {
        LinearLayout l = new LinearLayout(this);
        l.setOrientation(LinearLayout.VERTICAL);
        l.setPadding(dp(14), dp(14), dp(14), dp(14));
        l.setBackground(round(Color.rgb(12, 16, 26), dp(18), Color.argb(35,255,255,255), 1));
        TextView h = tv(title, 16, text, true);
        l.addView(h);
        if (hint != null && hint.length() > 0) {
            TextView sub = tv(hint, 12, muted, false);
            sub.setPadding(0, dp(4), 0, dp(10));
            l.addView(sub);
        }
        parent.addView(l, lp(-1, -2, 0, dp(10), 0, 0));
        return l;
    }

    private void setVisible(View v, boolean visible) {
        if (v == null) return;
        if (!visible) {
            v.animate().cancel();
            v.setAlpha(1f);
            v.setTranslationY(0f);
            v.setVisibility(View.GONE);
            return;
        }
        if (v.getVisibility() == View.VISIBLE) return;
        v.setVisibility(View.VISIBLE);
        v.setAlpha(0f);
        v.setTranslationY(dp(14));
        v.animate().alpha(1f).translationY(0f).setDuration(190L).setInterpolator(new DecelerateInterpolator()).start();
    }

    private void applyModeStructure() {
        String m = selectedMode();
        boolean trainLike = "Einfahrt".equals(m) || "Ankunft".equals(m) || "Steht bereit".equals(m) || "Information".equals(m) || "Anschluss".equals(m);
        setVisible(coreSection, trainLike);
        setVisible(entrySection, "Einfahrt".equals(m) || "Steht bereit".equals(m));
        setVisible(mitSection, "Einfahrt".equals(m) || "Steht bereit".equals(m) || "Information".equals(m));
        setVisible(splitSection, "Einfahrt".equals(m) || "Steht bereit".equals(m));
        setVisible(arrivalSection, "Ankunft".equals(m));
        setVisible(infoSection, "Information".equals(m));
        setVisible(connectionSection, "Anschluss".equals(m));
        setVisible(dispatchSection, "Abfertigung".equals(m));
        setVisible(passingSection, "Durchfahrt".equals(m));
        setVisible(specialSection, "Sonderansage".equals(m));
        setVisible(inTrainSection, "Im Zug".equals(m));
    }

    private void addSelectedInTrainBlock() {
        String block = inTrainBlockId(spin(inTrainBlockSpinner));
        if (block == null) return;
        inTrainSequence.add(block);
        renderInTrainSequence();
        if (playerStatus != null) playerStatus.setText("Baustein hinzugefügt: " + inTrainBlockLabel(block));
        if (inTrainSequenceList != null) animateEmphasis(inTrainSequenceList);
    }

    private void addSelectedInTrainStation() {
        InTrainStationClip stationClip = selectedInTrainStationClip();
        if (stationClip == null) {
            String name = selectedStation == null ? "Bitte zuerst einen Bahnhof wählen." : "Für „" + selectedStation.station + "“ gibt es noch keinen kuratierten Im-Zug-Stationsclip.";
            Toast.makeText(this, name, Toast.LENGTH_LONG).show();
            if (playerStatus != null) playerStatus.setText(name);
            return;
        }
        inTrainSequence.add(InTrainSequenceSupport.stationItem(stationClip.clip));
        renderInTrainSequence();
        if (playerStatus != null) playerStatus.setText("Station eingefügt: " + stationClip.station);
        if (inTrainSequenceList != null) animateEmphasis(inTrainSequenceList);
    }

    private void refreshInTrainStationAddAction() {
        if (addSelectedInTrainStationButton == null) return;
        InTrainStationClip clip = selectedInTrainStationClip();
        boolean available = clip != null;
        addSelectedInTrainStationButton.setEnabled(available);
        addSelectedInTrainStationButton.setText(available ? "＋ Station einfügen · " + clip.station : "＋ Ausgewählte Station");
        addSelectedInTrainStationButton.setContentDescription(available
                ? "Station " + clip.station + " in die Im-Zug-Wiedergabeliste einfügen"
                : "Zuerst eine Station mit kuratiertem Im-Zug-Audio auswählen");
    }

    private InTrainStationClip inTrainStationClipForPlaylistItem(String item) {
        String clipFile = InTrainSequenceSupport.stationClipForItem(item);
        if (clipFile.isEmpty()) return null;
        for (InTrainStationClip clip : inTrainStationClips.values()) if (clipFile.equals(clip.clip)) return clip;
        return null;
    }

    private String inTrainSequenceItemLabel(String item) {
        InTrainStationClip stationClip = inTrainStationClipForPlaylistItem(item);
        return stationClip == null ? inTrainBlockLabel(item) : "Station · " + stationClip.station;
    }

    private void renderInTrainSequence() {
        if (inTrainSequenceList == null) return;
        inTrainSequenceList.removeAllViews();
        if (inTrainSequence.isEmpty()) {
            TextView empty = tv("Noch keine Bausteine. Wähle oben z. B. Gong und danach Stationsname.", 13, muted, false);
            empty.setPadding(0, dp(6), 0, dp(6));
            inTrainSequenceList.addView(empty);
            return;
        }
        for (int index = 0; index < inTrainSequence.size(); index++) {
            final int position = index;
            LinearLayout line = buttonRow();
            line.setPadding(dp(10), dp(5), dp(8), dp(5));
            line.setBackground(round(panel2, dp(12), Color.argb(32, 255, 255, 255), 1));
            TextView label = tv((position + 1) + ". " + inTrainSequenceItemLabel(inTrainSequence.get(position)), 13, soft, false);
            label.setGravity(Gravity.CENTER_VERTICAL);
            line.addView(label, new LinearLayout.LayoutParams(0, dp(42), 1));
            Button up = button("↑", false);
            up.setContentDescription("Baustein nach oben");
            up.setEnabled(position > 0);
            up.setOnClickListener(v -> moveInTrainBlock(position, position - 1));
            line.addView(up, new LinearLayout.LayoutParams(dp(42), dp(42)));
            Button down = button("↓", false);
            down.setContentDescription("Baustein nach unten");
            down.setEnabled(position < inTrainSequence.size() - 1);
            down.setOnClickListener(v -> moveInTrainBlock(position, position + 1));
            LinearLayout.LayoutParams downLp = new LinearLayout.LayoutParams(dp(42), dp(42));
            downLp.leftMargin = dp(4);
            line.addView(down, downLp);
            Button remove = button("×", false);
            remove.setContentDescription("Baustein entfernen");
            remove.setOnClickListener(v -> { inTrainSequence.remove(position); renderInTrainSequence(); });
            LinearLayout.LayoutParams removeLp = new LinearLayout.LayoutParams(dp(42), dp(42));
            removeLp.leftMargin = dp(4);
            line.addView(remove, removeLp);
            inTrainSequenceList.addView(line, lp(-1, -2, 0, dp(3), 0, dp(3)));
            animateListItem(line, index);
        }
    }

    private void moveInTrainBlock(int from, int to) {
        if (from < 0 || to < 0 || from >= inTrainSequence.size() || to >= inTrainSequence.size()) return;
        Collections.swap(inTrainSequence, from, to);
        renderInTrainSequence();
    }

    private String inTrainBlockId(String label) { return InTrainSequenceSupport.idForLabel(label); }
    private String inTrainBlockLabel(String id) { return InTrainSequenceSupport.labelForId(id); }
    private boolean isInTrainBlock(String id) { return InTrainSequenceSupport.isKnown(id); }
    private boolean hasInTrainBlock(String id) { return inTrainSequence.contains(id); }

    private JSONArray inTrainSequenceJson() {
        JSONArray sequence = new JSONArray();
        for (String block : inTrainSequence) sequence.put(block);
        return sequence;
    }

    private void restoreInTrainSequence(JSONObject preset) {
        inTrainSequence.clear();
        JSONArray sequence = preset.optJSONArray("inTrainSequence");
        if (sequence != null) {
            for (int i = 0; i < sequence.length(); i++) {
                String block = sequence.optString(i, "");
                if (isInTrainBlock(block)) inTrainSequence.add(block);
            }
        } else {
            boolean gong = !preset.has("inTrainGong") || preset.optBoolean("inTrainGong", true);
            String type = preset.optString("inTrainType", "Nächste Station");
            if (gong) inTrainSequence.add("gong");
            if ("Maskenhinweis FFP2".equals(type)) inTrainSequence.add("mask_ffp2");
            else if ("Maskenhinweis FFP2 Englisch".equals(type)) inTrainSequence.add("mask_ffp2_en");
            else {
                inTrainSequence.add("next_station");
                inTrainSequence.add("station_name");
                if ("Dieser Zug endet dort · Fahrgäste bitte aussteigen".equals(type)
                        || "Dieser Zug endet dort".equals(type)
                        || "Alle aussteigen".equals(type)) inTrainSequence.add("train_ends_all_exit");
                if (preset.optBoolean("inTrainExitLeft", false)) inTrainSequence.add("exit_left");
                if (preset.optBoolean("inTrainExitRight", false)) inTrainSequence.add("exit_right");
            }
        }
        if (inTrainPauseAfterStationBox != null) inTrainPauseAfterStationBox.setChecked(preset.optBoolean("inTrainPauseAfterStation", true));
        renderInTrainSequence();
    }

    private LinearLayout row() {
        LinearLayout l = new LinearLayout(this);
        l.setOrientation(LinearLayout.VERTICAL);
        l.setGravity(Gravity.CENTER_VERTICAL);
        l.setPadding(0, dp(2), 0, dp(4));
        return l;
    }

    private LinearLayout buttonRow() {
        LinearLayout l = new LinearLayout(this);
        l.setOrientation(LinearLayout.HORIZONTAL);
        l.setGravity(Gravity.CENTER_VERTICAL);
        return l;
    }


    private LinearLayout wrapField(String label, EditText input, float weight) {
        LinearLayout w = new LinearLayout(this);
        w.setOrientation(LinearLayout.VERTICAL);
        TextView t = tv(label, 12, soft, true);
        t.setPadding(0, 0, 0, dp(6));
        w.addView(t);
        w.addView(input, new LinearLayout.LayoutParams(-1, dp(58)));
        LinearLayout.LayoutParams lp = new LinearLayout.LayoutParams(-1, -2);
        lp.setMargins(0, 0, 0, dp(10));
        w.setLayoutParams(lp);
        return w;
    }

    private TextView tv(String s, int sp, int color, boolean bold) {
        TextView t = new TextView(this);
        t.setText(s);
        t.setTextColor(color);
        t.setTextSize(sp);
        t.setLineSpacing(0, 1.08f);
        if (bold) t.setTypeface(Typeface.DEFAULT, Typeface.BOLD);
        return t;
    }

    private EditText edit(String hint, String val) {
        EditText e = new EditText(this);
        e.setSingleLine(true);
        e.setHint(hint);
        e.setText(val);
        e.setTextColor(text);
        e.setHintTextColor(muted);
        e.setTextSize(16);
        e.setPadding(dp(16), 0, dp(16), 0);
        e.setBackground(inputSurface(false));
        e.setOnFocusChangeListener((view, focused) -> {
            view.setBackground(inputSurface(focused));
            if (focused) animateEmphasis(view);
        });
        return e;
    }

    private EditText numEdit(String hint, String val, int maxLen) {
        EditText e = edit(hint, val);
        e.setInputType(android.text.InputType.TYPE_CLASS_NUMBER);
        if (maxLen > 0) e.setFilters(new InputFilter[]{new InputFilter.LengthFilter(maxLen)});
        return e;
    }

    private Spinner spinner(String[] values) {
        Spinner s = new Spinner(this);
        s.setBackground(inputSurface(false));
        s.setContentDescription("Auswahlliste");
        s.setOnFocusChangeListener((view, focused) -> {
            view.setBackground(inputSurface(focused));
            if (focused) animateEmphasis(view);
        });
        ArrayAdapter<String> a = new ArrayAdapter<String>(this, android.R.layout.simple_spinner_item, values) {
            @Override public View getView(int position, View convertView, ViewGroup parent) {
                TextView v = (TextView) super.getView(position, convertView, parent);
                v.setTextColor(text);
                v.setTextSize(16);
                v.setSingleLine(false);
                v.setPadding(dp(16), 0, dp(16), 0);
                return v;
            }
            @Override public View getDropDownView(int position, View convertView, ViewGroup parent) {
                TextView v = (TextView) super.getDropDownView(position, convertView, parent);
                v.setTextColor(text);
                v.setTextSize(16);
                v.setBackgroundColor(Color.rgb(16, 20, 31));
                v.setPadding(dp(16), dp(16), dp(16), dp(16));
                return v;
            }
        };
        a.setDropDownViewResource(android.R.layout.simple_spinner_dropdown_item);
        s.setAdapter(a);
        return s;
    }

    private Spinner trainSpinnerControl() {
        return spinner((trainTypes == null || trainTypes.isEmpty()) ? new String[]{"ICE"} : trainTypes.toArray(new String[0]));
    }

    private LinearLayout wrapSpinner(String label, Spinner input, float weight) {
        LinearLayout w = new LinearLayout(this);
        w.setOrientation(LinearLayout.VERTICAL);
        TextView t = tv(label, 12, soft, true);
        t.setPadding(0, 0, 0, dp(6));
        w.addView(t);
        w.addView(input, new LinearLayout.LayoutParams(-1, dp(58)));
        LinearLayout.LayoutParams lp = new LinearLayout.LayoutParams(-1, -2);
        lp.setMargins(0, 0, 0, dp(10));
        w.setLayoutParams(lp);
        return w;
    }

    private LinearLayout fullWidth(LinearLayout w) {
        LinearLayout.LayoutParams lp = new LinearLayout.LayoutParams(-1, -2);
        lp.setMargins(0, 0, 0, dp(8));
        w.setLayoutParams(lp);
        return w;
    }

    private CheckBox check(String label) {
        CheckBox c = new CheckBox(this);
        c.setText(label);
        c.setTextColor(soft);
        c.setTextSize(14);
        c.setGravity(Gravity.CENTER_VERTICAL);
        c.setMinHeight(dp(52));
        c.setPadding(dp(8), 0, dp(10), 0);
        c.setBackground(rippleSurface(round(Color.rgb(10, 13, 20), dp(13), Color.argb(42,255,255,255), 1)));
        c.setButtonTintList(android.content.res.ColorStateList.valueOf(accent));
        c.setOnCheckedChangeListener((buttonView, isChecked) -> {
            buttonView.setTextColor(isChecked ? Color.WHITE : soft);
            animateEmphasis(buttonView);
        });
        return c;
    }

    private void addCheckRow(LinearLayout parent, CheckBox... checks) {
        LinearLayout r = row();
        for (CheckBox c : checks) {
            LinearLayout.LayoutParams cp = new LinearLayout.LayoutParams(-1, dp(52));
            cp.setMargins(0, 0, 0, dp(4));
            r.addView(c, cp);
        }
        parent.addView(r, lp(-1, -2, 0, dp(6), 0, 0));
    }

    private Button button(String s, boolean primary) {
        Button b = new Button(this);
        b.setAllCaps(false);
        b.setText(s);
        b.setTextSize(13);
        b.setTextColor(Color.WHITE);
        b.setTypeface(Typeface.DEFAULT, Typeface.BOLD);
        b.setMinHeight(dp(48));
        b.setPadding(dp(12), 0, dp(12), 0);
        b.setGravity(Gravity.CENTER);
        b.setElevation(dp(primary ? 4 : 2));
        b.setBackground(rippleSurface(round(primary ? accent : panel2, dp(14), Color.argb(primary ? 76 : 45,255,255,255), 1)));
        b.setOnTouchListener((view, event) -> {
            if (event.getAction() == MotionEvent.ACTION_DOWN) {
                view.animate().scaleX(0.97f).scaleY(0.97f).setDuration(70L).start();
            } else if (event.getAction() == MotionEvent.ACTION_UP || event.getAction() == MotionEvent.ACTION_CANCEL) {
                view.animate().scaleX(1f).scaleY(1f).setDuration(130L).setInterpolator(new DecelerateInterpolator()).start();
            }
            return false;
        });
        return b;
    }

    private Button compactButton(String label) {
        Button compact = button(label, false);
        compact.setTextSize(12);
        compact.setMinHeight(0);
        compact.setMinimumHeight(0);
        compact.setPadding(dp(8), 0, dp(8), 0);
        compact.setElevation(dp(1));
        return compact;
    }

    private GradientDrawable inputSurface(boolean focused) {
        return round(Color.rgb(10, 13, 20), dp(14), focused ? Color.argb(230, 124, 124, 255) : Color.argb(45,255,255,255), focused ? dp(2) : 1);
    }

    private RippleDrawable rippleSurface(GradientDrawable content) {
        GradientDrawable mask = round(Color.WHITE, dp(14), Color.TRANSPARENT, 0);
        return new RippleDrawable(ColorStateList.valueOf(Color.argb(48, 255, 255, 255)), content, mask);
    }

    private LayoutTransition listTransition() {
        LayoutTransition transition = new LayoutTransition();
        transition.setDuration(160L);
        transition.setStartDelay(LayoutTransition.APPEARING, 0L);
        transition.setStartDelay(LayoutTransition.DISAPPEARING, 0L);
        transition.setAnimateParentHierarchy(false);
        return transition;
    }

    private void animateEntrance(View view, long delayMillis) {
        view.setAlpha(0f);
        view.setTranslationY(dp(18));
        view.post(() -> view.animate().alpha(1f).translationY(0f).setStartDelay(delayMillis).setDuration(260L).setInterpolator(new DecelerateInterpolator()).start());
    }

    private void animateEmphasis(View view) {
        view.animate().cancel();
        view.animate().scaleX(1.018f).scaleY(1.018f).setDuration(105L).setInterpolator(new DecelerateInterpolator()).withEndAction(() ->
                view.animate().scaleX(1f).scaleY(1f).setDuration(145L).setInterpolator(new DecelerateInterpolator()).start()).start();
    }

    private GradientDrawable round(int color, int radius, int stroke, int strokeWidth) {
        GradientDrawable g = new GradientDrawable();
        g.setColor(color); g.setCornerRadius(radius); g.setStroke(strokeWidth, stroke);
        return g;
    }

    private LinearLayout.LayoutParams lp(int w, int h, int l, int t, int r, int b) {
        LinearLayout.LayoutParams p = new LinearLayout.LayoutParams(w, h);
        p.setMargins(l, t, r, b);
        return p;
    }

    private void scheduleSearch(String rawQuery) {
        if (activityDestroyed || resultList == null) return;
        final String query = rawQuery == null ? "" : rawQuery.trim();
        final long generation = ++searchGeneration;
        if (pendingSearch != null) mainHandler.removeCallbacks(pendingSearch);
        renderSearchPending(query);
        pendingSearch = () -> searchExecutor.execute(() -> {
            final ArrayList<Result> results = search(query);
            mainHandler.post(() -> {
                if (activityDestroyed || generation != searchGeneration || searchBox == null || !query.equals(searchBox.getText().toString().trim())) return;
                renderSearchResults(results, query.isEmpty() ? 6 : 18);
            });
        });
        mainHandler.postDelayed(pendingSearch, query.isEmpty() ? 0L : SEARCH_DEBOUNCE_MS);
    }

    private void cancelPendingSearch() {
        searchGeneration++;
        if (pendingSearch != null) mainHandler.removeCallbacks(pendingSearch);
        pendingSearch = null;
    }

    private void renderSearchPending(String query) {
        resultList.removeAllViews();
        TextView pending = tv(query.isEmpty() ? "Ziele werden geladen …" : "Suche läuft …", 13, muted, false);
        pending.setPadding(0, dp(6), 0, dp(6));
        resultList.addView(pending, lp(-1, -2, 0, 0, 0, 0));
        if (searchFeedback != null) {
            searchFeedback.setVisibility(View.VISIBLE);
            searchFeedback.setText(query.isEmpty() ? "Beliebte Hauptbahnhöfe werden angezeigt." : "Suche im Hintergrund – die Eingabe bleibt flüssig.");
            animateEmphasis(searchFeedback);
        }
    }

    private void renderSearchResults(ArrayList<Result> results, int max) {
        resultList.removeAllViews();
        int count = Math.min(max, results.size());
        if (searchFeedback != null) {
            searchFeedback.setVisibility(View.VISIBLE);
            searchFeedback.setText(count == 0 ? "Kein Treffer – prüfe Schreibweise oder RIL-Code." : count + (count == 1 ? " passender Treffer" : " passende Treffer") + " – antippen zum Übernehmen.");
            animateEmphasis(searchFeedback);
        }
        for (int i = 0; i < count; i++) addResult(results.get(i), i);
        if (count == 0) {
            TextView none = tv("Keine Treffer", 13, muted, false);
            none.setPadding(0, dp(6), 0, dp(6));
            resultList.addView(none, lp(-1, -2, 0, 0, 0, 0));
            animateListItem(none, 0);
        }
    }

    private ArrayList<Result> search(String query) {
        ArrayList<Result> out = new ArrayList<>();
        String qFold = SearchQuerySupport.fold(query);
        String qExpanded = SearchQuerySupport.expand(query);
        String qCode = SearchQuerySupport.code(query);
        boolean codeQuery = SearchQuerySupport.isCodeQuery(query);
        boolean containsQuery = qFold.length() >= 3;
        ArrayList<Result> ril = new ArrayList<>();
        ArrayList<Result> stationResults = new ArrayList<>();
        if (query.isEmpty()) {
            for (Station station : stations) {
                if (station.foldedName.contains("hbf")) stationResults.add(new Result(station.station, "IBNR " + station.ibnr, station.filepath, false, 1));
            }
        } else {
            for (RilEntry entry : rilEntries) {
                int score = 0;
                if (codeQuery && entry.code.equals(qCode)) score = 120;
                else if (codeQuery && entry.code.startsWith(qCode)) score = 105;
                else if (containsQuery && (entry.foldedName.contains(qFold) || entry.expandedName.contains(qExpanded) || entry.foldedStation.contains(qFold) || entry.expandedStation.contains(qExpanded))) score = 65;
                if (score > 0) {
                    String title = entry.name + (entry.station.length() > 0 ? " → " + entry.station : "");
                    String subtitle = entry.filepath.length() > 0 ? "RIL 100 " + entry.code + " · " + entry.filepath : "RIL 100 " + entry.code + " · keine Audiodatei";
                    ril.add(new Result(title, subtitle, entry.filepath, entry.filepath.length() == 0, score));
                }
            }
            for (Station station : stations) {
                int score = 0;
                if (station.foldedName.equals(qFold) || station.expandedName.equals(qExpanded)) score = 95;
                else if (station.foldedName.startsWith(qFold) || station.expandedName.startsWith(qExpanded)) score = station.foldedName.contains("hbf") ? 88 : 75;
                else if (containsQuery && (station.foldedName.contains(qFold) || station.expandedName.contains(qExpanded))) score = 45;
                if (score > 0) stationResults.add(new Result(station.station, "IBNR " + station.ibnr, station.filepath, false, score));
            }
        }
        Collections.sort(ril);
        Collections.sort(stationResults);
        HashSet<String> seen = new HashSet<>();
        if (codeQuery) { append(out, ril, seen); append(out, stationResults, seen); }
        else { append(out, stationResults, seen); append(out, ril, seen); }
        return out;
    }

    private void append(ArrayList<Result> out, ArrayList<Result> source, HashSet<String> seen) {
        for (Result result : source) {
            String key = result.filepath.length() > 0 ? result.filepath : result.title + result.subtitle;
            if (seen.add(key)) out.add(result);
            if (out.size() >= 30) break;
        }
    }

    private void addResult(Result result, int position) {
        Button button = button(result.title + "\n" + result.subtitle, false);
        button.setGravity(Gravity.LEFT | Gravity.CENTER_VERTICAL);
        button.setEnabled(!result.disabled);
        button.setTextColor(result.disabled ? muted : text);
        resultList.addView(button, lp(-1, -2, 0, dp(5), 0, dp(5)));
        animateListItem(button, position);
        button.setOnClickListener(v -> {
            Station station = findStationByFile(result.filepath);
            if (station == null) station = new Station(result.title, result.filepath, "");
            selectedStation = station;
            updateSelected();
            cancelPendingSearch();
            suppressMainSearch = true;
            searchBox.setText("");
            suppressMainSearch = false;
            resultList.removeAllViews();
            if (searchFeedback != null) searchFeedback.setVisibility(View.GONE);
            updateSelected();
            animateEmphasis(selectedText);
        });
    }

    private void updateSelected() {
        if (selectedText == null) {
            refreshInTrainStationAddAction();
            return;
        }
        if (selectedStation == null) {
            selectedText.setVisibility(View.GONE);
            refreshInTrainStationAddAction();
            return;
        }
        selectedText.setVisibility(View.VISIBLE);
        selectedText.setText("✓ " + selectedStation.station + " · IBNR " + selectedStation.ibnr + "   ×");
        selectedText.setTextColor(soft);
        selectedText.setBackground(round(Color.rgb(13, 30, 34), dp(14), Color.argb(70, 16, 185, 129), 1));
        refreshInTrainStationAddAction();
    }

    private void resetSearchPresentation() {
        if (resultList != null) resultList.removeAllViews();
        if (searchFeedback != null) searchFeedback.setVisibility(View.GONE);
    }

    private void clearSearch() {
        if (searchBox == null) return;
        suppressMainSearch = true;
        searchBox.setText("");
        suppressMainSearch = false;
        cancelPendingSearch();
        scheduleSearch("");
        searchBox.requestFocus();
    }

    private void clearSelectedStation() {
        if (selectedStation == null) return;
        selectedStation = null;
        updateSelected();
        if (searchBox != null) searchBox.requestFocus();
    }

    private void animateListItem(View item, int position) {
        item.setAlpha(0f);
        item.setTranslationY(dp(8));
        item.animate().alpha(1f).translationY(0f).setStartDelay(Math.min(position, 5) * 24L).setDuration(170L).setInterpolator(new DecelerateInterpolator()).start();
    }

    private String statusText() {
        if (offlineLibraryReady()) return "● Daten bereit · " + stations.size() + " Ziele · " + rilEntries.size() + " Codes";
        if (offlineLibraryLoading) return "◌ Offline-Bibliothek wird vorbereitet …";
        return "⚠ Daten nicht verfügbar" + offlineLibraryNotice;
    }

    private boolean offlineLibraryReady() { return bundledOfflineLibrary != null; }

    private void updateStatusText(String value) {
        if (status == null) return;
        String next = value == null ? "" : value;
        if (!next.contentEquals(status.getText())) {
            status.setText(next);
            animateEmphasis(status);
        }
    }


    private SharedPreferences prefs() { return getSharedPreferences("ansagen-store", MODE_PRIVATE); }

    private JSONArray storedArray(String key) {
        try { return new JSONArray(prefs().getString(key, "[]")); }
        catch (Exception e) { return new JSONArray(); }
    }

    private void saveArray(String key, JSONArray arr) {
        prefs().edit().putString(key, arr.toString()).apply();
    }

    private void putText(JSONObject o, String k, EditText e) throws Exception { o.put(k, txt(e)); }
    private void putSpin(JSONObject o, String k, Spinner s) throws Exception { o.put(k, spin(s)); }
    private void putCheck(JSONObject o, String k, CheckBox c) throws Exception { o.put(k, checked(c)); }
    private void setText(JSONObject o, String k, EditText e, String d) { if (e != null) e.setText(o.optString(k, d)); }
    private void setCheck(JSONObject o, String k, CheckBox c) { if (c != null) c.setChecked(o.optBoolean(k, false)); }
    private void setSpin(JSONObject o, String k, Spinner s, String d) {
        if (s == null) return;
        String val = o.optString(k, d);
        for (int i = 0; i < s.getCount(); i++) if (val.equals(String.valueOf(s.getItemAtPosition(i)))) { s.setSelection(i); return; }
    }

    private JSONObject currentPreset() throws Exception {
        JSONObject o = new JSONObject();
        o.put("title", currentTitle());
        o.put("station", selectedStation == null ? "" : selectedStation.station);
        o.put("filepath", selectedStation == null ? "" : selectedStation.filepath);
        o.put("ibnr", selectedStation == null ? "" : selectedStation.ibnr);
        putSpin(o, "mode", modeSpinner); putSpin(o, "lang", languageSpinner); putSpin(o, "train", trainSpinner);
        putText(o, "trainNumber", trainNumberBox); putText(o, "trainNumber2", trainNumber2Box); putText(o, "trainNumber3", trainNumber3Box);
        putText(o, "gleis", gleisBox); putText(o, "hour", hourBox); putText(o, "minute", minuteBox); putText(o, "via", viaBox);
        putCheck(o, "ersatz", ersatzBox); putCheck(o, "delayed", delayedBox); putCheck(o, "mit1", mit1Box); putCheck(o, "mit2", mit2Box);
        putCheck(o, "split1", split1Box); putCheck(o, "split2", split2Box); putCheck(o, "noBoard", noBoardBox); putCheck(o, "continue", continueBox);
        putCheck(o, "cancel", cancelTrainBox); putCheck(o, "sorry", sorryBox); putCheck(o, "connection2", connection2Box); putCheck(o, "connection3", connection3Box);
        putSpin(o, "mit1Train", mit1TrainSpinner); putText(o, "mit1Nr", mit1TrainNumberBox); putText(o, "mit1Nr2", mit1TrainNumber2Box); putText(o, "mit1Nr3", mit1TrainNumber3Box); putText(o, "mit1Target", mit1TargetBox); putText(o, "mit1Via", mit1ViaBox);
        putSpin(o, "mit2Train", mit2TrainSpinner); putText(o, "mit2Nr", mit2TrainNumberBox); putText(o, "mit2Nr2", mit2TrainNumber2Box); putText(o, "mit2Nr3", mit2TrainNumber3Box); putText(o, "mit2Target", mit2TargetBox); putText(o, "mit2Via", mit2ViaBox);
        putText(o, "split1Target", split1TargetBox); putText(o, "split2Target", split2TargetBox);
        putSpin(o, "continueTrain", continueTrainSpinner); putText(o, "continueNr", continueTrainNumberBox); putText(o, "continueNr2", continueTrainNumber2Box); putText(o, "continueNr3", continueTrainNumber3Box); putText(o, "continueTarget", continueTargetBox); putText(o, "continueVia", continueViaBox); putText(o, "continueHour", continueHourBox); putText(o, "continueMinute", continueMinuteBox);
        putSpin(o, "delay", infoDelaySpinner); putSpin(o, "reason", infoReasonSpinner); putText(o, "newPlatform", infoNewPlatformBox); putText(o, "onlyUntil", infoOnlyUntilBox);
        putText(o, "haltMinus1", haltMinus1Box); putText(o, "haltMinus2", haltMinus2Box); putText(o, "haltMinus3", haltMinus3Box); putText(o, "haltPlus1", haltPlus1Box); putText(o, "haltPlus2", haltPlus2Box); putText(o, "haltPlus3", haltPlus3Box);
        putText(o, "dispatchPlatform", dispatchPlatformBox); putText(o, "throughPlatform", throughPlatformBox); putSpin(o, "special", specialSpinner);
        putSpin(o, "a2Train", a2TrainSpinner); putText(o, "a2Nr", a2TrainNumberBox); putText(o, "a2Nr2", a2TrainNumber2Box); putText(o, "a2Nr3", a2TrainNumber3Box); putText(o, "a2Target", a2TargetBox); putText(o, "a2Via", a2ViaBox); putText(o, "a2Platform", a2PlatformBox); putText(o, "a2Hour", a2HourBox); putText(o, "a2Minute", a2MinuteBox);
        putSpin(o, "a3Train", a3TrainSpinner); putText(o, "a3Nr", a3TrainNumberBox); putText(o, "a3Nr2", a3TrainNumber2Box); putText(o, "a3Nr3", a3TrainNumber3Box); putText(o, "a3Target", a3TargetBox); putText(o, "a3Via", a3ViaBox); putText(o, "a3Platform", a3PlatformBox); putText(o, "a3Hour", a3HourBox); putText(o, "a3Minute", a3MinuteBox);
        o.put("inTrainSequence", inTrainSequenceJson());
        o.put("inTrainPauseAfterStation", checked(inTrainPauseAfterStationBox));
        o.put("ts", System.currentTimeMillis());
        return o;
    }

    private String currentTitle() {
        String mode = selectedMode();
        String station = selectedStation == null ? "ohne Ziel" : selectedStation.station;
        if ("Im Zug".equals(mode)) return "Im Zug · " + inTrainSequenceTitle();
        String train = trainSpinner == null ? "ICE" : String.valueOf(trainSpinner.getSelectedItem());
        String nr = trainNumberBox == null ? "" : trainNumberBox.getText().toString().trim();
        String gleis = gleisBox == null ? "?" : gleisBox.getText().toString();
        String h = hourBox == null ? "--" : hourBox.getText().toString();
        String m = minuteBox == null ? "--" : minuteBox.getText().toString();
        return mode + " · " + train + (nr.length() > 0 ? " " + nr : "") + " nach " + station + " · Gl. " + gleis + " · " + h + ":" + two(safeInt(m, 0));
    }

    private String inTrainSequenceTitle() {
        if (inTrainSequence.isEmpty()) return "keine Bausteine";
        StringBuilder title = new StringBuilder();
        int shown = Math.min(3, inTrainSequence.size());
        for (int i = 0; i < shown; i++) {
            if (i > 0) title.append(" → ");
            title.append(inTrainSequenceItemLabel(inTrainSequence.get(i)));
        }
        if (inTrainSequence.size() > shown) title.append(" …");
        return title.toString();
    }

    private String presetSignature(JSONObject preset) {
        String base = preset.optString("mode") + "|" + preset.optString("filepath") + "|" + preset.optString("train") + "|"
                + preset.optString("trainNumber") + "|" + preset.optString("gleis") + "|" + preset.optString("hour") + "|" + preset.optString("minute");
        JSONArray sequence = preset.optJSONArray("inTrainSequence");
        return base + "|" + (sequence == null ? "" : sequence.toString()) + "|" + preset.optBoolean("inTrainPauseAfterStation", true);
    }

    private void addStored(String key, JSONObject obj, int max) {
        JSONArray old = storedArray(key);
        JSONArray out = new JSONArray();
        String newSig = presetSignature(obj);
        out.put(obj);
        for (int i = 0; i < old.length() && out.length() < max; i++) {
            JSONObject item = old.optJSONObject(i);
            if (item == null) continue;
            String sig = presetSignature(item);
            if (!newSig.equals(sig)) out.put(item);
        }
        saveArray(key, out);
        renderStoredLists();
    }

    private void saveCurrentFavorite() {
        try {
            if (!ensureInTrainReady()) return;
            if (selectedStation == null && !"Im Zug".equals(selectedMode())) { Toast.makeText(this, "Bitte zuerst Ziel wählen.", Toast.LENGTH_SHORT).show(); return; }
            addStored("favorites", currentPreset(), 12);
            Toast.makeText(this, "Vorlage gespeichert", Toast.LENGTH_SHORT).show();
        } catch (Exception e) { Toast.makeText(this, "Speichern fehlgeschlagen: " + e.getMessage(), Toast.LENGTH_LONG).show(); }
    }

    private void addHistory() {
        try { addStored("history", currentPreset(), 20); }
        catch (Exception ignored) {}
    }

    private void clearHistory() {
        prefs().edit().remove("history").apply();
        renderStoredLists();
        Toast.makeText(this, "Verlauf gelöscht", Toast.LENGTH_SHORT).show();
    }

    private void renderStoredLists() {
        if (favoritesList == null || historyList == null || historyCard == null) return;
        JSONArray favorites = storedArray("favorites");
        JSONArray history = storedArray("history");
        boolean hasFavorites = favorites.length() > 0;
        boolean hasHistory = history.length() > 0;
        favoritesLabel.setVisibility(hasFavorites ? View.VISIBLE : View.GONE);
        favoritesList.setVisibility(hasFavorites ? View.VISIBLE : View.GONE);
        historyLabel.setVisibility(hasHistory ? View.VISIBLE : View.GONE);
        historyList.setVisibility(hasHistory ? View.VISIBLE : View.GONE);
        historyCard.setVisibility((hasFavorites || hasHistory) ? View.VISIBLE : View.GONE);
        if (hasFavorites) renderPresetList(favoritesList, favorites, true, favoritesExpanded);
        else favoritesList.removeAllViews();
        if (hasHistory) renderPresetList(historyList, history, false, historyExpanded);
        else historyList.removeAllViews();
    }

    private void renderPresetList(LinearLayout target, JSONArray arr, boolean favorite, boolean expanded) {
        target.removeAllViews();
        int visibleCount = expanded ? arr.length() : Math.min(3, arr.length());
        for (int index = 0; index < visibleCount; index++) {
            JSONObject item = arr.optJSONObject(index);
            if (item == null) continue;
            target.addView(presetRow(item, favorite), lp(-1, dp(58), 0, dp(2), 0, dp(2)));
        }
        if (arr.length() > 3) {
            Button toggle = compactButton(expanded ? "Weniger anzeigen" : "Alle " + arr.length() + " anzeigen");
            toggle.setOnClickListener(v -> {
                if (favorite) favoritesExpanded = !favoritesExpanded;
                else historyExpanded = !historyExpanded;
                renderStoredLists();
            });
            target.addView(toggle, lp(-1, dp(42), 0, dp(5), 0, 0));
        }
    }

    private View presetRow(JSONObject item, boolean favorite) {
        LinearLayout row = buttonRow();
        row.setGravity(Gravity.CENTER_VERTICAL);
        row.setPadding(dp(12), dp(6), dp(10), dp(6));
        row.setBackground(rippleSurface(round(panel2, dp(14), Color.argb(42, 255, 255, 255), 1)));
        row.setContentDescription((favorite ? "Vorlage: " : "Verlauf: ") + item.optString("title", "Ansage"));
        TextView icon = tv(favorite ? "★" : "↺", 17, favorite ? Color.rgb(250, 204, 21) : soft, true);
        icon.setGravity(Gravity.CENTER);
        row.addView(icon, new LinearLayout.LayoutParams(dp(30), -1));
        LinearLayout copy = new LinearLayout(this);
        copy.setOrientation(LinearLayout.VERTICAL);
        LinearLayout.LayoutParams copyLp = new LinearLayout.LayoutParams(0, -2, 1);
        copyLp.leftMargin = dp(6);
        row.addView(copy, copyLp);
        TextView title = tv(item.optString("title", "Ansage"), 14, text, true);
        title.setSingleLine(true);
        title.setEllipsize(TextUtils.TruncateAt.END);
        copy.addView(title);
        TextView subtitle = tv(favorite ? "Gespeicherte Vorlage" : "Letzte Wiedergabe", 11, muted, false);
        subtitle.setPadding(0, dp(2), 0, 0);
        copy.addView(subtitle);
        TextView arrow = tv("›", 24, muted, false);
        arrow.setGravity(Gravity.CENTER);
        row.addView(arrow, new LinearLayout.LayoutParams(dp(22), -1));
        row.setOnClickListener(v -> applyPreset(item));
        return row;
    }

    private void applyPreset(JSONObject o) {
        try {
            String fp = o.optString("filepath");
            Station s = fp.length() == 0 ? null : findStationByFile(fp);
            if (s == null && fp.length() > 0) s = new Station(o.optString("station", "Ziel"), fp, o.optString("ibnr", ""));
            selectedStation = s;
            setSpin(o, "mode", modeSpinner, "Einfahrt"); setSpin(o, "lang", languageSpinner, "Deutsch"); setSpin(o, "train", trainSpinner, "ICE");
            setText(o, "trainNumber", trainNumberBox, ""); setText(o, "trainNumber2", trainNumber2Box, ""); setText(o, "trainNumber3", trainNumber3Box, "");
            setText(o, "gleis", gleisBox, "1"); setText(o, "hour", hourBox, "18"); setText(o, "minute", minuteBox, "59"); setText(o, "via", viaBox, "0");
            setCheck(o, "ersatz", ersatzBox); setCheck(o, "delayed", delayedBox); setCheck(o, "mit1", mit1Box); setCheck(o, "mit2", mit2Box);
            setCheck(o, "split1", split1Box); setCheck(o, "split2", split2Box); setCheck(o, "noBoard", noBoardBox); setCheck(o, "continue", continueBox);
            setCheck(o, "cancel", cancelTrainBox); setCheck(o, "sorry", sorryBox); setCheck(o, "connection2", connection2Box); setCheck(o, "connection3", connection3Box);
            setSpin(o, "mit1Train", mit1TrainSpinner, "ICE"); setText(o, "mit1Nr", mit1TrainNumberBox, ""); setText(o, "mit1Nr2", mit1TrainNumber2Box, ""); setText(o, "mit1Nr3", mit1TrainNumber3Box, ""); setText(o, "mit1Target", mit1TargetBox, ""); setText(o, "mit1Via", mit1ViaBox, "0");
            setSpin(o, "mit2Train", mit2TrainSpinner, "ICE"); setText(o, "mit2Nr", mit2TrainNumberBox, ""); setText(o, "mit2Nr2", mit2TrainNumber2Box, ""); setText(o, "mit2Nr3", mit2TrainNumber3Box, ""); setText(o, "mit2Target", mit2TargetBox, ""); setText(o, "mit2Via", mit2ViaBox, "0");
            setText(o, "split1Target", split1TargetBox, ""); setText(o, "split2Target", split2TargetBox, "");
            setSpin(o, "continueTrain", continueTrainSpinner, "ICE"); setText(o, "continueNr", continueTrainNumberBox, ""); setText(o, "continueNr2", continueTrainNumber2Box, ""); setText(o, "continueNr3", continueTrainNumber3Box, ""); setText(o, "continueTarget", continueTargetBox, ""); setText(o, "continueVia", continueViaBox, "0"); setText(o, "continueHour", continueHourBox, "18"); setText(o, "continueMinute", continueMinuteBox, "59");
            setSpin(o, "delay", infoDelaySpinner, "0 · keine"); setSpin(o, "reason", infoReasonSpinner, "0 · keiner"); setText(o, "newPlatform", infoNewPlatformBox, "0"); setText(o, "onlyUntil", infoOnlyUntilBox, "0");
            setText(o, "haltMinus1", haltMinus1Box, "0"); setText(o, "haltMinus2", haltMinus2Box, "0"); setText(o, "haltMinus3", haltMinus3Box, "0"); setText(o, "haltPlus1", haltPlus1Box, "0"); setText(o, "haltPlus2", haltPlus2Box, "0"); setText(o, "haltPlus3", haltPlus3Box, "0");
            setText(o, "dispatchPlatform", dispatchPlatformBox, "1"); setText(o, "throughPlatform", throughPlatformBox, "1"); setSpin(o, "special", specialSpinner, SPECIALS[0]);
            setSpin(o, "a2Train", a2TrainSpinner, "ICE"); setText(o, "a2Nr", a2TrainNumberBox, ""); setText(o, "a2Nr2", a2TrainNumber2Box, ""); setText(o, "a2Nr3", a2TrainNumber3Box, ""); setText(o, "a2Target", a2TargetBox, ""); setText(o, "a2Via", a2ViaBox, "0"); setText(o, "a2Platform", a2PlatformBox, "1"); setText(o, "a2Hour", a2HourBox, "18"); setText(o, "a2Minute", a2MinuteBox, "59");
            setSpin(o, "a3Train", a3TrainSpinner, "ICE"); setText(o, "a3Nr", a3TrainNumberBox, ""); setText(o, "a3Nr2", a3TrainNumber2Box, ""); setText(o, "a3Nr3", a3TrainNumber3Box, ""); setText(o, "a3Target", a3TargetBox, ""); setText(o, "a3Via", a3ViaBox, "0"); setText(o, "a3Platform", a3PlatformBox, "1"); setText(o, "a3Hour", a3HourBox, "18"); setText(o, "a3Minute", a3MinuteBox, "59");
            restoreInTrainSequence(o);
            cancelPendingSearch();
            suppressMainSearch = true;
            searchBox.setText("");
            suppressMainSearch = false;
            resultList.removeAllViews();
            if (searchFeedback != null) searchFeedback.setVisibility(View.GONE);
            updateSelected();
            Toast.makeText(this, "Vorlage geladen", Toast.LENGTH_SHORT).show();
        } catch (Exception e) { Toast.makeText(this, "Laden fehlgeschlagen: " + e.getMessage(), Toast.LENGTH_LONG).show(); }
    }

    private void verifyOfflineData() {
        BundledZipLibrary library = bundledOfflineLibrary;
        if (library == null) {
            Toast.makeText(this, "Die eingebettete Bibliothek wird noch geöffnet.", Toast.LENGTH_SHORT).show();
            return;
        }
        updateStatusText("Prüfe eingebettete Offline-Bibliothek …");
        if (playerStatus != null) playerStatus.setText("Prüfsumme der APK-Bibliothek wird berechnet …");
        new Thread(() -> {
            String msg;
            try {
                OfflineLibrarySupport.requireExpectedArchiveSha256(library.sha256OfArchive());
                msg = "Daten OK · Opus direkt in der App · Dateien: " + library.getLibraryFileCount()
                        + " · Opus: " + library.getLibraryOpusCount()
                        + " · Größe: " + humanSize(library.getLibraryUncompressedBytes());
            } catch (Exception e) {
                msg = "Eingebettete Daten fehlerhaft: " + e.getMessage();
            }
            final String result = msg;
            runOnUiThread(() -> {
                updateStatusText(statusText());
                if (playerStatus != null) playerStatus.setText(result);
                Toast.makeText(this, result, Toast.LENGTH_LONG).show();
            });
        }, "verify-bundled-offline-data").start();
    }

    private String humanSize(long b) {
        double v = b; String[] u = {"B", "KB", "MB", "GB"}; int i = 0;
        while (v >= 1024 && i < u.length - 1) { v /= 1024; i++; }
        return String.format(Locale.GERMANY, "%.1f %s", v, u[i]);
    }

    private void initializeBundledOfflineLibraryAsync() {
        if (bundledOfflineLibrary != null || offlineLibraryLoading) return;
        offlineLibraryLoading = true;
        offlineLibraryNotice = "";
        updateStatusText(statusText());
        new Thread(() -> {
            try {
                BundledZipLibrary library = BundledZipLibrary.open(getAssets(), BUNDLED_OFFLINE_ARCHIVES);
                bundledOfflineLibrary = library;
                File previousExternalRoot = getExternalFilesDir(null);
                if (previousExternalRoot != null) OfflineLibrarySupport.deleteRecursively(new File(previousExternalRoot, "offline"));
                OfflineLibrarySupport.deleteRecursively(new File(getFilesDir(), "offline"));
                clearBundledAudioCache();
                offlineLibraryNotice = "";
            } catch (Exception e) {
                offlineLibraryNotice = " · Fehler: " + e.getMessage();
            } finally {
                offlineLibraryLoading = false;
                runOnUiThread(() -> {
                    updateStatusText(statusText());
                    if (playerStatus != null && !offlineLibraryReady()) playerStatus.setText("Eingebettete Offline-Bibliothek konnte nicht geöffnet werden." + offlineLibraryNotice);
                });
            }
        }, "open-bundled-offline-library").start();
    }

    private String selectedMode() {
        return modeSpinner == null ? "Einfahrt" : String.valueOf(modeSpinner.getSelectedItem());
    }

    private String langCode() {
        String s = languageSpinner == null ? "Deutsch" : String.valueOf(languageSpinner.getSelectedItem());
        if (s.startsWith("Eng")) return "en";
        if (s.startsWith("Fran")) return "Sonderansage".equals(selectedMode()) ? "fr" : "dt";
        return "dt";
    }

    private String txt(EditText e) { return e == null ? "" : e.getText().toString().trim(); }
    private String spin(Spinner s) { return s == null ? "" : String.valueOf(s.getSelectedItem()); }
    private boolean checked(CheckBox c) { return c != null && c.isChecked(); }
    private boolean hasFile(String f) { return f != null && f.trim().length() > 0 && !"0".equals(f.trim()) && !"-".equals(f.trim()); }

    private String selectedTargetFile() {
        return selectedStation == null || selectedStation.filepath.length() == 0 ? "8010324.wav" : selectedStation.filepath;
    }

    private String optionFile(Spinner s) {
        String v = spin(s);
        int idx = v.indexOf(".wav");
        if (idx < 0) return "";
        return v.substring(0, idx + 4);
    }

    private String stationFileFromText(String raw, String fallback) {
        String q = raw == null ? "" : raw.trim();
        if (q.length() == 0) return fallback == null ? "" : fallback;
        if ("0".equals(q) || "-".equals(q)) return "";
        String clean = cleanAudioPath(q);
        int slash = clean.lastIndexOf('/');
        if (slash >= 0) clean = clean.substring(slash + 1);
        if (clean.toLowerCase(Locale.ROOT).endsWith(".wav")) return clean;
        if (clean.matches("\\d{4,8}")) return clean + ".wav";
        RilEntry entry = rilByCode.get(SearchQuerySupport.code(q));
        if (entry != null && entry.filepath.length() > 0) return entry.filepath;
        String folded = SearchQuerySupport.fold(q);
        String expanded = SearchQuerySupport.expand(q);
        if (folded.isEmpty() || expanded.isEmpty()) return fallback == null ? "" : fallback;
        Station exact = stationsByFoldedName.get(folded);
        if (exact == null) exact = stationsByExpandedName.get(expanded);
        if (exact != null) return exact.filepath;
        for (Station station : stations) if (station.foldedName.contains(folded) || station.expandedName.contains(expanded)) return station.filepath;
        return fallback == null ? "" : fallback;
    }

    private void addM31(ArrayList<String> rel, String lang, String dt, String en, String fr) {
        rel.add(lang + "/module_3_1/" + ("dt".equals(lang) ? dt : ("en".equals(lang) ? en : fr)) + ".wav");
    }

    private void addMod(ArrayList<String> rel, String lang, String dt, String en, String fr) {
        rel.add(lang + "/module/" + ("dt".equals(lang) ? dt : ("en".equals(lang) ? en : fr)) + ".wav");
    }

    private void addNumberAudio(ArrayList<String> rel, String lang, int n, boolean high) {
        if (n < 0) return;
        String tone = high ? "hoch" : "tief";
        if (n < 100 || (n >= 100 && n % 100 == 0)) {
            rel.add(lang + "/gleise_zahlen/" + tone + "/" + n + ".wav");
        } else if (n < 1000) {
            int rest = n % 100;
            int hundred = n - rest;
            rel.add(lang + "/gleise_zahlen/" + tone + "/" + hundred + "_.wav");
            if (rest > 0) rel.add(lang + "/gleise_zahlen/" + tone + "/" + rest + ".wav");
        } else {
            String digits = String.valueOf(n);
            for (int i = 0; i < digits.length() && i < 5; i++) rel.add(lang + "/gleise_zahlen/" + tone + "/" + digits.charAt(i) + ".wav");
        }
    }

    private void addNumberChunkAudio(ArrayList<String> rel, int n) { addNumberAudio(rel, "dt", n, true); }
    private void addTrainNumberAudio(ArrayList<String> rel, String raw) { addTrainNumberAudio(rel, raw, "dt"); }

    private void addTrainNumberAudio(ArrayList<String> rel, String raw, String lang) {
        if (raw == null) return;
        String digits = raw.replaceAll("\\D+", "");
        if (digits.length() == 0) return;
        if (digits.length() <= 3 && !digits.startsWith("0")) { addNumberAudio(rel, lang, safeInt(digits, 0), true); return; }
        for (int i = 0; i < digits.length() && i < 5; i++) rel.add(lang + "/gleise_zahlen/hoch/" + digits.charAt(i) + ".wav");
    }

    private void addTrainNumbers(ArrayList<String> rel, String lang, EditText... boxes) {
        for (EditText b : boxes) addTrainNumberAudio(rel, txt(b), lang);
    }

    private void addTrain(ArrayList<String> rel, String lang, Spinner train, EditText... nums) {
        String t = spin(train);
        if (t.length() == 0) t = "ICE";
        rel.add(lang + "/zuggattungen/hoch/" + t.toLowerCase(Locale.ROOT) + ".wav");
        addTrainNumbers(rel, lang, nums);
    }

    private void addNach(ArrayList<String> rel, String lang) { addMod(rel, lang, "0054", "0049", "0049"); }
    private void addVon(ArrayList<String> rel, String lang) { addMod(rel, lang, "0065", "0012", "0012"); }
    private void addDeparture(ArrayList<String> rel, String lang, EditText h, EditText m) { addM31(rel, lang, "001", "008", "042"); addTime(rel, lang, safeInt(txt(h), 18), safeInt(txt(m), 59)); }
    private void addTime(ArrayList<String> rel, String lang, int hour, int min) { rel.add(lang + "/zeiten/stunden/hoch/" + two(hour) + ".wav"); rel.add(lang + "/zeiten/minuten/tief/" + two(min) + ".wav"); }
    private void addCaution(ArrayList<String> rel, String lang) { addM31(rel, lang, "046", "005", "042"); }

    private void addTargetWithVia(ArrayList<String> rel, String lang, String targetFile, String viaRaw, boolean viaVariant1) {
        String via = stationFileFromText(viaRaw, "");
        if (hasFile(via)) {
            rel.add(lang + "/ziele/variante2/hoch/" + targetFile);
            addM31(rel, lang, "035", "035", "042");
            rel.add(lang + "/ziele/" + (viaVariant1 ? "variante1" : "variante2") + "/tief/" + via);
        } else rel.add(lang + "/ziele/variante2/tief/" + targetFile);
    }

    private void addWithTrain(ArrayList<String> rel, String lang, Spinner train, EditText target, EditText via, EditText... nums) {
        addM31(rel, lang, "031", "039", "042"); addTrain(rel, lang, train, nums); addNach(rel, lang);
        addTargetWithVia(rel, lang, stationFileFromText(txt(target), selectedTargetFile()), txt(via), true);
    }

    private void addSplit(ArrayList<String> rel, String lang) {
        if (!checked(split1Box)) return;
        String t1 = stationFileFromText(txt(split1TargetBox), selectedTargetFile());
        String t2 = stationFileFromText(txt(split2TargetBox), "");
        addM31(rel, lang, "045", "030", "042");
        if (checked(split2Box) && hasFile(t2)) { rel.add(lang + "/ziele/variante2/hoch/" + t1); addM31(rel, lang, "036", "002", "042"); rel.add(lang + "/ziele/variante2/tief/" + t2); }
        else rel.add(lang + "/ziele/variante2/tief/" + t1);
        addM31(rel, lang, "015", "000", "042");
    }

    private ArrayList<String> buildNativePlaylist() {
        String lang = langCode(); String mode = selectedMode();
        if ("Ankunft".equals(mode)) return buildArrival(lang);
        if ("Steht bereit".equals(mode)) return buildStanding(lang);
        if ("Information".equals(mode)) return buildInfo(lang);
        if ("Anschluss".equals(mode)) return buildConnections(lang);
        if ("Abfertigung".equals(mode)) return buildDispatch(lang);
        if ("Durchfahrt".equals(mode)) return buildPassing(lang);
        if ("Sonderansage".equals(mode)) return buildSpecial(lang);
        if ("Im Zug".equals(mode)) return buildInTrain();
        return buildEntry(lang);
    }

    private ArrayList<String> buildEntry(String lang) {
        ArrayList<String> rel = new ArrayList<>(); int gleis = safeInt(txt(gleisBox), 1);
        rel.add("gong/513/513_2.wav"); addM31(rel, lang, "016", "023", "042"); addNumberAudio(rel, lang, gleis, true); addM31(rel, lang, "012", "022", "042");
        if (checked(ersatzBox)) addM31(rel, lang, "008", "025", "042");
        addTrain(rel, lang, trainSpinner, trainNumberBox, trainNumber2Box, trainNumber3Box); addNach(rel, lang); addTargetWithVia(rel, lang, selectedTargetFile(), txt(viaBox), true);
        if (checked(mit1Box)) addWithTrain(rel, lang, mit1TrainSpinner, mit1TargetBox, mit1ViaBox, mit1TrainNumberBox, mit1TrainNumber2Box, mit1TrainNumber3Box);
        if (checked(mit2Box)) addWithTrain(rel, lang, mit2TrainSpinner, mit2TargetBox, mit2ViaBox, mit2TrainNumberBox, mit2TrainNumber2Box, mit2TrainNumber3Box);
        if (checked(delayedBox)) addM31(rel, lang, "002", "027", "042"); else addM31(rel, lang, "001", "008", "042");
        addTime(rel, lang, safeInt(txt(hourBox), 18), safeInt(txt(minuteBox), 59)); addSplit(rel, lang); addCaution(rel, lang); return rel;
    }

    private ArrayList<String> buildArrival(String lang) {
        ArrayList<String> rel = new ArrayList<>(); int gleis = safeInt(txt(gleisBox), 1);
        rel.add("gong/513/513_2.wav"); addM31(rel, lang, "016", "023", "042"); addNumberAudio(rel, lang, gleis, true); addM31(rel, lang, "012", "022", "042");
        addTrain(rel, lang, trainSpinner, trainNumberBox, trainNumber2Box, trainNumber3Box); addVon(rel, lang); rel.add(lang + "/ziele/variante2/tief/" + selectedTargetFile());
        if (checked(continueBox)) { addM31(rel, lang, "040", "006", "042"); addTrain(rel, lang, continueTrainSpinner, continueTrainNumberBox, continueTrainNumber2Box, continueTrainNumber3Box); addNach(rel, lang); addTargetWithVia(rel, lang, stationFileFromText(txt(continueTargetBox), selectedTargetFile()), txt(continueViaBox), false); addDeparture(rel, lang, continueHourBox, continueMinuteBox); addCaution(rel, lang); }
        else { if (checked(delayedBox)) addM31(rel, lang, "005", "026", "042"); else addMod(rel, lang, "0004", "0001", "0004"); addTime(rel, lang, safeInt(txt(hourBox), 18), safeInt(txt(minuteBox), 59)); if (checked(noBoardBox)) addM31(rel, lang, "007", "024", "042"); addCaution(rel, lang); }
        return rel;
    }

    private ArrayList<String> buildStanding(String lang) {
        ArrayList<String> rel = new ArrayList<>(); int gleis = safeInt(txt(gleisBox), 1);
        rel.add("gong/513/513_2.wav"); addM31(rel, lang, "016", "023", "042"); addNumberAudio(rel, lang, gleis, true); addM31(rel, lang, "034", "000", "042");
        addTrain(rel, lang, trainSpinner, trainNumberBox, trainNumber2Box, trainNumber3Box); addNach(rel, lang); addTargetWithVia(rel, lang, selectedTargetFile(), txt(viaBox), true);
        if (checked(mit1Box)) addWithTrain(rel, lang, mit1TrainSpinner, mit1TargetBox, mit1ViaBox, mit1TrainNumberBox, mit1TrainNumber2Box, mit1TrainNumber3Box); if (checked(mit2Box)) addWithTrain(rel, lang, mit2TrainSpinner, mit2TargetBox, mit2ViaBox, mit2TrainNumberBox, mit2TrainNumber2Box, mit2TrainNumber3Box);
        addDeparture(rel, lang, hourBox, minuteBox); addSplit(rel, lang); return rel;
    }

    private ArrayList<String> buildInfo(String lang) {
        ArrayList<String> rel = new ArrayList<>(); rel.add("gong/513/513_2.wav"); addM31(rel, lang, "030", "020", "042");
        addTrain(rel, lang, trainSpinner, trainNumberBox, trainNumber2Box, trainNumber3Box); addNach(rel, lang); addTargetWithVia(rel, lang, selectedTargetFile(), txt(viaBox), true);
        if (checked(mit1Box)) addWithTrain(rel, lang, mit1TrainSpinner, mit1TargetBox, mit1ViaBox, mit1TrainNumberBox, mit1TrainNumber2Box, mit1TrainNumber3Box); if (checked(mit2Box)) addWithTrain(rel, lang, mit2TrainSpinner, mit2TargetBox, mit2ViaBox, mit2TrainNumberBox, mit2TrainNumber2Box, mit2TrainNumber3Box);
        addDeparture(rel, lang, hourBox, minuteBox); String delay = optionFile(infoDelaySpinner); if (hasFile(delay)) rel.add(lang + "/zeiten/verspaetung_heute/" + delay);
        int newPlatform = safeInt(txt(infoNewPlatformBox), 0); if (newPlatform > 0) { addMod(rel, lang, "0323", "0073", "042"); addNumberAudio(rel, lang, newPlatform, true); }
        String onlyUntil = stationFileFromText(txt(infoOnlyUntilBox), ""); if (hasFile(onlyUntil)) { addM31(rel, lang, "021", "011", "042"); rel.add(lang + "/ziele/variante2/tief/" + onlyUntil); addM31(rel, lang, "044", "021", "042"); }
        addHaltPlus(rel, lang); addHaltMinus(rel, lang); if (checked(cancelTrainBox)) addM31(rel, lang, "014", "015", "042");
        String reason = optionFile(infoReasonSpinner); if (hasFile(reason)) rel.add(lang + "/gruende/grund_dafuer/" + reason); if (checked(sorryBox)) addM31(rel, lang, "042", "036", "042"); return rel;
    }

    private void addHaltPlus(ArrayList<String> rel, String lang) {
        String h1 = stationFileFromText(txt(haltPlus1Box), ""), h2 = stationFileFromText(txt(haltPlus2Box), ""), h3 = stationFileFromText(txt(haltPlus3Box), ""); if (!hasFile(h1)) return;
        addM31(rel, lang, "020", "037", "042"); if (!hasFile(h2)) rel.add(lang + "/ziele/variante2/tief/" + h1); else if (!hasFile(h3)) { rel.add(lang + "/ziele/variante2/hoch/" + h1); addM31(rel, lang, "036", "002", "042"); rel.add(lang + "/ziele/variante2/tief/" + h2); } else { rel.add(lang + "/ziele/variante2/hoch/" + h1); rel.add(lang + "/ziele/variante2/hoch/" + h2); addM31(rel, lang, "036", "002", "042"); rel.add(lang + "/ziele/variante2/tief/" + h3); }
    }

    private void addHaltMinus(ArrayList<String> rel, String lang) {
        String h1 = stationFileFromText(txt(haltMinus1Box), ""), h2 = stationFileFromText(txt(haltMinus2Box), ""), h3 = stationFileFromText(txt(haltMinus3Box), ""); if (!hasFile(h1)) return;
        addM31(rel, lang, "022", "038", "042"); if (!hasFile(h2)) rel.add(lang + "/ziele/variante2/tief/" + h1); else if (!hasFile(h3)) { rel.add(lang + "/ziele/variante2/hoch/" + h1); addM31(rel, lang, "036", "002", "042"); rel.add(lang + "/ziele/variante2/hoch/" + h2); } else { rel.add(lang + "/ziele/variante2/hoch/" + h1); rel.add(lang + "/ziele/variante2/hoch/" + h2); addM31(rel, lang, "036", "002", "042"); rel.add(lang + "/ziele/variante2/hoch/" + h3); }
    }

    private ArrayList<String> buildSpecial(String lang) { ArrayList<String> rel = new ArrayList<>(); rel.add("gong/513/513_2.wav"); rel.add(lang + "/nza/" + optionFile(specialSpinner)); return rel; }

    private ArrayList<String> buildDispatch(String lang) { ArrayList<String> rel = new ArrayList<>(); rel.add("gong/klangtyp_konvent/ceg-gongs2.wav"); addMod(rel, lang, "0048", "0021", "0048"); addNumberAudio(rel, lang, safeInt(txt(dispatchPlatformBox), 1), true); addMod(rel, lang, "0011", "0029", "0029"); return rel; }

    private ArrayList<String> buildPassing(String lang) { ArrayList<String> rel = new ArrayList<>(); int gleis = safeInt(txt(throughPlatformBox), 1); rel.add("gong/513/513_2.wav"); addMod(rel, lang, "0153", "040", "0153"); addNumberAudio(rel, lang, gleis, true); addMod(rel, lang, "0155", "040", "0155"); addNumberAudio(rel, lang, gleis, true); addMod(rel, lang, "0159", "040", "0159"); return rel; }

    private ArrayList<String> buildConnections(String lang) {
        ArrayList<String> rel = new ArrayList<>(); rel.add("gong/513/513_2.wav"); addConnection(rel, lang, trainSpinner, selectedTargetFile(), txt(viaBox), hourBox, minuteBox, gleisBox, false, trainNumberBox, trainNumber2Box, trainNumber3Box);
        if (checked(connection2Box)) addConnection(rel, lang, a2TrainSpinner, stationFileFromText(txt(a2TargetBox), selectedTargetFile()), txt(a2ViaBox), a2HourBox, a2MinuteBox, a2PlatformBox, !checked(connection3Box), a2TrainNumberBox, a2TrainNumber2Box, a2TrainNumber3Box);
        if (checked(connection3Box)) addConnection(rel, lang, a3TrainSpinner, stationFileFromText(txt(a3TargetBox), selectedTargetFile()), txt(a3ViaBox), a3HourBox, a3MinuteBox, a3PlatformBox, true, a3TrainNumberBox, a3TrainNumber2Box, a3TrainNumber3Box);
        return rel;
    }

    private void addConnection(ArrayList<String> rel, String lang, Spinner train, String targetFile, String viaRaw, EditText h, EditText m, EditText platform, boolean withUnd, EditText... nums) {
        if (withUnd) addM31(rel, lang, "036", "002", "042"); else if (rel.size() == 1) addM31(rel, lang, "026", "040", "042");
        addTrain(rel, lang, train, nums); addNach(rel, lang); addTargetWithVia(rel, lang, targetFile, viaRaw, true); addDeparture(rel, lang, h, m); addM31(rel, lang, "039", "014", "042"); addNumberAudio(rel, lang, safeInt(txt(platform), 1), false);
    }

    private ArrayList<String> buildInTrain() {
        InTrainStationClip stationClip = selectedInTrainStationClip();
        return InTrainSequenceSupport.toAssetPlaylist(inTrainSequence, stationClip == null ? "" : stationClip.clip);
    }

    private InTrainStationClip selectedInTrainStationClip() {
        if (selectedStation == null) return null;
        InTrainStationClip byFile = inTrainStationClips.get(selectedStation.filepath);
        if (byFile != null) return byFile;
        String selected = norm(selectedStation.station);
        for (InTrainStationClip clip : inTrainStationClips.values()) {
            if (norm(clip.station).equals(selected) || norm(clip.raw).equals(selected)) return clip;
        }
        return null;
    }

    private boolean ensureInTrainReady() {
        if (!"Im Zug".equals(selectedMode())) return true;
        if (inTrainSequence.isEmpty()) {
            Toast.makeText(this, "Bitte mindestens einen Im-Zug-Baustein hinzufügen.", Toast.LENGTH_LONG).show();
            if (playerStatus != null) playerStatus.setText("Im Zug: Bausteinliste ist leer");
            return false;
        }
        if (!InTrainSequenceSupport.requiresStation(inTrainSequence)) return true;
        if (selectedInTrainStationClip() != null) return true;
        String name = selectedStation == null ? "keine Station" : selectedStation.station;
        Toast.makeText(this, "Für „" + name + "“ gibt es noch keinen sauberen In-Zug-Stationsclip.", Toast.LENGTH_LONG).show();
        if (playerStatus != null) playerStatus.setText("Im Zug: kein v9-Stationsclip für " + name);
        return false;
    }

    private void playAnnouncement() {
        if (selectedStation == null && !"Im Zug".equals(selectedMode())) { Toast.makeText(this, "Bitte Ziel auswählen.", Toast.LENGTH_SHORT).show(); return; }
        if (!ensureInTrainReady()) return;
        if (!"Im Zug".equals(selectedMode()) && !offlineLibraryReady()) { Toast.makeText(this, "Die eingebettete Offline-Bibliothek wird noch geöffnet.", Toast.LENGTH_LONG).show(); return; }
        startRelativeQueue(buildNativePlaylist(), "Im Zug".equals(selectedMode()) ? "Im Zug" : "Native App");
    }

    private void startRelativeQueue(ArrayList<String> rel, String source) {
        currentQueue.clear();
        currentRelQueue.clear();
        currentSource = source;
        ArrayList<String> missing = new ArrayList<>();
        ArrayList<File> files = resolveAudioFiles(rel, missing);
        if (!missing.isEmpty()) {
            Toast.makeText(this, "Fehlende Audios (" + source + "): " + missing.get(0), Toast.LENGTH_LONG).show();
            if (playerStatus != null) playerStatus.setText("Fehlt: " + missing.get(0));
            return;
        }
        if (files.isEmpty()) {
            Toast.makeText(this, "Keine Audios in der Ansage gefunden.", Toast.LENGTH_SHORT).show();
            return;
        }
        currentQueue.addAll(files);
        currentRelQueue.addAll(rel);
        queueIndex = 0;
        paused = false;
        waitingForNextInTrainStop = false;
        pauseAfterInTrainStation = "Im Zug".equals(source) && checked(inTrainPauseAfterStationBox);
        stickyToolsExpanded = false;
        setVisible(stickyTools, false);
        if (stickyMoreButton != null) stickyMoreButton.setText("⋯");
        addHistory();
        Toast.makeText(this, source + ": " + currentQueue.size() + " Audio-Bausteine", Toast.LENGTH_SHORT).show();
        if (playerStatus != null) playerStatus.setText(source + ": bereit · " + currentQueue.size() + " Bausteine");
        updatePlaybackControls();
        playNext();
    }

    private ArrayList<File> resolveAudioFiles(ArrayList<String> rel, ArrayList<String> missing) {
        ArrayList<File> files = new ArrayList<>();
        try {
            BundledZipLibrary library = bundledOfflineLibrary;
            if (library == null) throw new IOException("Eingebettete Offline-Bibliothek wird noch geöffnet.");
            for (String p : rel) {
                String clean = cleanAudioPath(p);
                if (clean.length() == 0) continue;
                if (clean.startsWith("asset:/")) {
                    files.add(copyAssetAudioToCache(clean.substring("asset:/".length())));
                    continue;
                }
                String bundledPath = OfflineLibrarySupport.toBundledOpusPath(clean);
                if (bundledPath.length() == 0 || !library.hasLibraryFile(bundledPath)) { missing.add(clean); continue; }
                files.add(copyBundledAudioToCache(clean));
            }
        } catch (Exception e) {
            missing.add("Audiofehler: " + e.getMessage());
        }
        return files;
    }

    private File copyBundledAudioToCache(String relativePath) throws IOException {
        BundledZipLibrary library = bundledOfflineLibrary;
        String clean = cleanAudioPath(relativePath);
        String bundledPath = OfflineLibrarySupport.toBundledOpusPath(clean);
        if (library == null || bundledPath.length() == 0) throw new IOException("Ungültiger eingebetteter Audio-Pfad: " + relativePath);
        File dir = new File(getCacheDir(), "bundled-offline-audio");
        File out = new File(dir, bundledPath);
        if (!OfflineLibrarySupport.isChildOf(dir, out)) throw new IOException("Audio außerhalb Cache: " + relativePath);
        if (out.isFile()) return out;
        File parent = out.getParentFile();
        if (parent == null || (!parent.exists() && !parent.mkdirs())) throw new IOException("Audio-Cache kann nicht erstellt werden.");
        File temporary = new File(parent, out.getName() + ".part");
        try (InputStream input = library.openLibraryFile(bundledPath); FileOutputStream output = new FileOutputStream(temporary)) {
            byte[] buffer = new byte[1024 * 64];
            int read;
            while ((read = input.read(buffer)) != -1) output.write(buffer, 0, read);
        }
        if (!temporary.renameTo(out)) {
            OfflineLibrarySupport.deleteRecursively(temporary);
            throw new IOException("Audio-Cache kann nicht aktiviert werden.");
        }
        return out;
    }

    private void clearBundledAudioCache() {
        OfflineLibrarySupport.deleteRecursively(new File(getCacheDir(), "bundled-offline-audio"));
    }

    private File copyAssetAudioToCache(String assetPath) throws IOException {
        String clean = cleanAudioPath(assetPath);
        if (clean.length() == 0 || clean.contains("..") || clean.startsWith("/")) throw new IOException("Ungültiger Asset-Pfad: " + assetPath);
        File dir = new File(getCacheDir(), "audio-assets");
        File out = new File(dir, clean);
        if (!OfflineLibrarySupport.isChildOf(dir, out)) throw new IOException("Asset außerhalb Cache: " + assetPath);
        if (out.isFile()) return out;
        File parent = out.getParentFile();
        if (parent != null) parent.mkdirs();
        InputStream in = getAssets().open(clean);
        FileOutputStream fos = new FileOutputStream(out);
        byte[] buf = new byte[1024 * 64];
        int n;
        while ((n = in.read(buf)) > 0) fos.write(buf, 0, n);
        in.close();
        fos.close();
        return out;
    }

    private String cleanAudioPath(String p) {
        if (p == null) return "";
        String clean = p.replace('\\', '/').trim();
        int siteIdx = clean.indexOf("/site/");
        if (siteIdx >= 0) clean = clean.substring(siteIdx + 6);
        while (clean.startsWith("file://")) clean = clean.substring(7);
        while (clean.startsWith("/")) clean = clean.substring(1);
        if (clean.contains("..")) return "";
        return clean;
    }

    private void exportCurrentAnnouncement() {
        if (selectedStation == null && !"Im Zug".equals(selectedMode())) { Toast.makeText(this, "Bitte Ziel auswählen.", Toast.LENGTH_SHORT).show(); return; }
        if (!ensureInTrainReady()) return;
        if (!"Im Zug".equals(selectedMode()) && !offlineLibraryReady()) { Toast.makeText(this, "Die eingebettete Offline-Bibliothek wird noch geöffnet.", Toast.LENGTH_LONG).show(); return; }
        ArrayList<String> rel = buildNativePlaylist();
        ArrayList<String> missing = new ArrayList<>();
        ArrayList<File> files = resolveAudioFiles(rel, missing);
        if (!missing.isEmpty()) { Toast.makeText(this, "Export nicht möglich, fehlt: " + missing.get(0), Toast.LENGTH_LONG).show(); return; }
        if (files.isEmpty()) { Toast.makeText(this, "Keine Audios zum Exportieren.", Toast.LENGTH_SHORT).show(); return; }
        if (playerStatus != null) playerStatus.setText("Export läuft …");
        new Thread(() -> {
            try {
                File dir = new File(getExternalFilesDir(null), "exports");
                dir.mkdirs();
                String stamp = new SimpleDateFormat("yyyyMMdd-HHmmss", Locale.ROOT).format(new Date());
                File out = new File(dir, "ansage-" + stamp + ".wav");
                AudioWavExporter.exportToWav(files, out);
                runOnUiThread(() -> {
                    addHistory();
                    String msg = "Export fertig: " + out.getAbsolutePath();
                    if (playerStatus != null) playerStatus.setText(msg);
                    Toast.makeText(this, msg, Toast.LENGTH_LONG).show();
                });
            } catch (Exception e) {
                runOnUiThread(() -> {
                    String msg = "Export fehlgeschlagen: " + e.getMessage();
                    if (playerStatus != null) playerStatus.setText(msg);
                    Toast.makeText(this, msg, Toast.LENGTH_LONG).show();
                });
            }
        }).start();
    }

    private void playNext() {
        stopPlayerOnly();
        waitingForNextInTrainStop = false;
        if (queueIndex >= currentQueue.size()) {
            if (playerStatus != null) playerStatus.setText(currentSource + ": Ansage fertig");
            updatePlaybackControls();
            Toast.makeText(this, "Ansage fertig", Toast.LENGTH_SHORT).show();
            return;
        }
        final int queueItemIndex = queueIndex;
        final int displayIndex = queueItemIndex + 1;
        final String currentRelativePath = queueItemIndex < currentRelQueue.size() ? currentRelQueue.get(queueItemIndex) : "";
        final boolean pauseAfterThisItem = InTrainSequenceSupport.shouldPauseAfterQueueEntry(pauseAfterInTrainStation, currentRelativePath);
        File f = currentQueue.get(queueIndex++);
        try {
            currentPlayer = new MediaPlayer();
            currentPlayer.setAudioAttributes(new AudioAttributes.Builder().setUsage(AudioAttributes.USAGE_MEDIA).setContentType(AudioAttributes.CONTENT_TYPE_MUSIC).build());
            currentPlayer.setDataSource(f.getAbsolutePath());
            currentPlayer.setOnCompletionListener(mp -> {
                if (pauseAfterThisItem && queueIndex < currentQueue.size()) {
                    if (currentPlayer == mp) currentPlayer = null;
                    try { mp.release(); } catch (Exception ignored) { }
                    paused = false;
                    waitingForNextInTrainStop = true;
                    if (playerStatus != null) playerStatus.setText("Haltestelle " + displayIndex + " fertig · Nächster Halt bereit");
                    updatePlaybackControls();
                    Toast.makeText(this, "Haltestelle fertig", Toast.LENGTH_SHORT).show();
                } else {
                    playNext();
                }
            });
            currentPlayer.setOnErrorListener((mp, what, extra) -> { playNext(); return true; });
            currentPlayer.prepare();
            currentPlayer.start();
            paused = false;
            if (playerStatus != null) playerStatus.setText(currentSource + ": " + displayIndex + "/" + currentQueue.size() + " · " + f.getName());
            updatePlaybackControls();
        } catch (Exception e) {
            Toast.makeText(this, "Audiofehler: " + e.getMessage(), Toast.LENGTH_SHORT).show();
            playNext();
        }
    }

    private void pausePlayback() {
        if (currentPlayer != null && currentPlayer.isPlaying()) {
            currentPlayer.pause();
            paused = true;
            if (playerStatus != null) playerStatus.setText("Pausiert · " + queueIndex + "/" + currentQueue.size());
            updatePlaybackControls();
            Toast.makeText(this, "Pausiert", Toast.LENGTH_SHORT).show();
        }
    }

    private void resumePlayback() {
        if (waitingForNextInTrainStop && currentPlayer == null && queueIndex < currentQueue.size()) {
            waitingForNextInTrainStop = false;
            paused = false;
            playNext();
            Toast.makeText(this, "Nächster Halt", Toast.LENGTH_SHORT).show();
        } else if (currentPlayer != null && paused) {
            currentPlayer.start();
            paused = false;
            if (playerStatus != null) playerStatus.setText("Weiter · " + queueIndex + "/" + currentQueue.size());
            updatePlaybackControls();
            Toast.makeText(this, "Weiter", Toast.LENGTH_SHORT).show();
        } else if (!currentQueue.isEmpty() && currentPlayer == null && queueIndex < currentQueue.size()) {
            playNext();
        }
    }

    private void stopPlayback() {
        currentQueue.clear();
        currentRelQueue.clear();
        queueIndex = 0;
        paused = false;
        waitingForNextInTrainStop = false;
        pauseAfterInTrainStation = false;
        stopPlayerOnly();
        if (playerStatus != null) playerStatus.setText("Gestoppt");
        updatePlaybackControls();
        Toast.makeText(this, "Gestoppt", Toast.LENGTH_SHORT).show();
    }
    private void stopPlayerOnly() { if (currentPlayer != null) { try { currentPlayer.stop(); } catch(Exception ignored) {} currentPlayer.release(); currentPlayer = null; } }
    @Override protected void onDestroy() {
        activityDestroyed = true;
        cancelPendingSearch();
        mainHandler.removeCallbacksAndMessages(null);
        searchExecutor.shutdownNow();
        stopPlayerOnly();
        BundledZipLibrary library = bundledOfflineLibrary;
        bundledOfflineLibrary = null;
        if (library != null) library.close();
        super.onDestroy();
    }

    private int safeInt(String s, int d) { try { return Integer.parseInt(s.trim()); } catch(Exception e) { return d; } }
    private String two(int n) { return n < 10 ? "0" + n : String.valueOf(n); }

    private Station findStationByFile(String file) {
        return file == null ? null : stationsByFile.get(file);
    }

    private String norm(String value) { return SearchQuerySupport.fold(value); }

    private int dp(int v) { return (int)(v * getResources().getDisplayMetrics().density + 0.5f); }

    static class Station {
        final String station, filepath, ibnr, foldedName, expandedName;
        Station(String station, String filepath, String ibnr) {
            this.station = station == null ? "" : station;
            this.filepath = filepath == null ? "" : filepath;
            this.ibnr = ibnr == null ? "" : ibnr;
            this.foldedName = SearchQuerySupport.fold(this.station);
            this.expandedName = SearchQuerySupport.expand(this.station);
        }
    }
    static class RilEntry {
        final String code, name, station, filepath, ibnr, foldedName, expandedName, foldedStation, expandedStation;
        RilEntry(String code, String name, String station, String filepath, String ibnr) {
            this.code = SearchQuerySupport.code(code);
            this.name = name == null ? "" : name;
            this.station = station == null ? "" : station;
            this.filepath = filepath == null ? "" : filepath;
            this.ibnr = ibnr == null ? "" : ibnr;
            this.foldedName = SearchQuerySupport.fold(this.name);
            this.expandedName = SearchQuerySupport.expand(this.name);
            this.foldedStation = SearchQuerySupport.fold(this.station);
            this.expandedStation = SearchQuerySupport.expand(this.station);
        }
    }
    static class InTrainStationClip { String station,raw,filepath,clip; InTrainStationClip(String s,String r,String f,String c){station=s == null ? "" : s;raw=r == null ? "" : r;filepath=f == null ? "" : f;clip=c == null ? "" : c;} }
    static class Result implements Comparable<Result> {
        String title, subtitle, filepath, sortKey; boolean disabled; int score;
        Result(String t, String st, String f, boolean d) { this(t,st,f,d,0); }
        Result(String t, String st, String f, boolean d, int sc) {
            title=t;
            subtitle=st;
            filepath=f == null ? "" : f;
            sortKey=SearchQuerySupport.fold(t);
            disabled=d;
            score=sc;
        }
        public int compareTo(Result other) {
            int byScore = Integer.compare(other.score, score);
            if (byScore != 0) return byScore;
            int byNormalizedTitle = sortKey.compareTo(other.sortKey);
            return byNormalizedTitle != 0 ? byNormalizedTitle : title.compareToIgnoreCase(other.title);
        }
    }
}
