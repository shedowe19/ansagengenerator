package de.shedowe.ansagengenerator;

import java.util.ArrayList;
import java.util.List;

/** Pure mapping for freely ordered, bundled in-train announcement atoms. */
final class InTrainSequenceSupport {
    private static final String STATION_ITEM_PREFIX = "station:";
    private static final String STATION_ASSET_PREFIX = "asset:/inzug/station_name_only/";
    private static final String OPUS_SUFFIX = ".opus";
    private static final String WAV_SUFFIX = ".wav";
    private static final String COMBINED_END_ID = "train_ends_all_exit";
    private static final String COMBINED_END_LABEL = "Dieser Zug endet dort · Fahrgäste bitte aussteigen";

    static final String[] LABELS = {
            "Gong",
            "Nächste Station",
            COMBINED_END_LABEL,
            "Ausstieg in Fahrtrichtung links",
            "Ausstieg in Fahrtrichtung rechts",
            "Maskenhinweis FFP2",
            "Maskenhinweis FFP2 Englisch",
            "Hinweis · Persönliche Gegenstände",
            "Hinweis · Vielen Dank und auf Wiedersehen",
            "Hinweis · DB Regio Verabschiedung",
            "Hinweis · Bis zum nächsten Mal · S-Bahn Rhein-Ruhr",
            "Hinweis · Bauarbeiten und Fahrplanänderungen",
            "Hinweis · Trittstufen fahren nicht aus",
            "Hinweis · Verspätung wegen Signalreparatur",
            "Hinweis · Türbereich freihalten",
            "Hinweis · Außerplanmäßiger Halt",
            "Hinweis · Abstand zur Bahnsteigkante",
            "Hinweis · Weiterfahrt in die Abstellung",
            "Hinweis · Corona · Abstand und medizinische Maske"
    };

    private InTrainSequenceSupport() { }

    /**
     * A self-contained station row. The persisted token contains the approved bundled clip,
     * so later target selection cannot overwrite an already assembled route playlist.
     */
    static String stationItem(String stationClip) {
        String opusClip = toBundledStationClip(stationClip);
        if (opusClip.length() == 0) throw new IllegalArgumentException("Ungültiger Im-Zug-Stationsclip.");
        return STATION_ITEM_PREFIX + opusClip;
    }

    static boolean isStationItem(String id) {
        return id != null && id.startsWith(STATION_ITEM_PREFIX)
                && toBundledStationClip(id.substring(STATION_ITEM_PREFIX.length())).length() > 0;
    }

    static String stationClipForItem(String id) {
        return isStationItem(id) ? toBundledStationClip(id.substring(STATION_ITEM_PREFIX.length())) : "";
    }

    static boolean isStationAssetPath(String path) {
        return path != null && path.startsWith(STATION_ASSET_PREFIX)
                && toBundledStationClip(path.substring(STATION_ASSET_PREFIX.length())).length() > 0;
    }

    static boolean shouldPauseAfterQueueEntry(boolean pauseAfterStations, String assetPath) {
        return pauseAfterStations && isStationAssetPath(assetPath);
    }

    /** Accepts legacy WAV tokens but maps all runtime access to the bundled Opus asset. */
    private static String toBundledStationClip(String stationClip) {
        if (!isSafeStationClip(stationClip)) return "";
        return stationClip.endsWith(WAV_SUFFIX)
                ? stationClip.substring(0, stationClip.length() - WAV_SUFFIX.length()) + OPUS_SUFFIX
                : stationClip;
    }

    private static boolean isSafeStationClip(String stationClip) {
        return stationClip != null && stationClip.matches("[a-z0-9][a-z0-9_]*\\.(?:wav|opus)");
    }

    static String idForLabel(String label) {
        if ("Gong".equals(label)) return "gong";
        if ("Nächste Station".equals(label)) return "next_station";
        // Compatiblity for saved templates from v1.14/v1.15. New station rows use station:<clip>.
        if ("Stationsname (Auswahl oben)".equals(label) || "Stationsname (alte Vorlage / Auswahl oben)".equals(label)) return "station_name";
        if (COMBINED_END_LABEL.equals(label) || "Dieser Zug endet dort".equals(label) || "Fahrgäste bitte alle aussteigen".equals(label)) return COMBINED_END_ID;
        if ("Ausstieg in Fahrtrichtung links".equals(label)) return "exit_left";
        if ("Ausstieg in Fahrtrichtung rechts".equals(label)) return "exit_right";
        if ("Maskenhinweis FFP2".equals(label)) return "mask_ffp2";
        if ("Maskenhinweis FFP2 Englisch".equals(label)) return "mask_ffp2_en";
        if ("Hinweis · Persönliche Gegenstände".equals(label)) return "personal_belongings";
        if ("Hinweis · Vielen Dank und auf Wiedersehen".equals(label)) return "thank_you";
        if ("Hinweis · DB Regio Verabschiedung".equals(label)) return "db_regio_farewell";
        if ("Hinweis · Bis zum nächsten Mal · S-Bahn Rhein-Ruhr".equals(label)) return "next_time_sbahn_rheinruhr";
        if ("Hinweis · Bauarbeiten und Fahrplanänderungen".equals(label)) return "construction_work_notice";
        if ("Hinweis · Trittstufen fahren nicht aus".equals(label)) return "step_extension_unavailable";
        if ("Hinweis · Verspätung wegen Signalreparatur".equals(label)) return "signal_repair_delay_notice";
        if ("Hinweis · Türbereich freihalten".equals(label)) return "door_area_clear_notice";
        if ("Hinweis · Außerplanmäßiger Halt".equals(label)) return "unscheduled_stop_notice";
        if ("Hinweis · Abstand zur Bahnsteigkante".equals(label) || "Hinweis · Höhenunterschied zur Bahnsteigkante".equals(label)) return "platform_edge_gap_notice";
        if ("Hinweis · Weiterfahrt in die Abstellung".equals(label)) return "stabling_exit_notice";
        if ("Hinweis · Corona · Abstand und medizinische Maske".equals(label)) return "corona_mask_notice";
        return null;
    }

    static String labelForId(String id) {
        if (isStationItem(id)) return "Station in Wiedergabeliste";
        id = canonicalBlockId(id);
        if ("gong".equals(id)) return "Gong";
        if ("next_station".equals(id)) return "Nächste Station";
        if ("station_name".equals(id)) return "Stationsname (alte Vorlage / Auswahl oben)";
        if (COMBINED_END_ID.equals(id)) return COMBINED_END_LABEL;
        if ("exit_left".equals(id)) return "Ausstieg in Fahrtrichtung links";
        if ("exit_right".equals(id)) return "Ausstieg in Fahrtrichtung rechts";
        if ("mask_ffp2".equals(id)) return "Maskenhinweis FFP2";
        if ("mask_ffp2_en".equals(id)) return "Maskenhinweis FFP2 Englisch";
        if ("personal_belongings".equals(id)) return "Hinweis · Persönliche Gegenstände";
        if ("thank_you".equals(id)) return "Hinweis · Vielen Dank und auf Wiedersehen";
        if ("db_regio_farewell".equals(id)) return "Hinweis · DB Regio Verabschiedung";
        if ("next_time_sbahn_rheinruhr".equals(id)) return "Hinweis · Bis zum nächsten Mal · S-Bahn Rhein-Ruhr";
        if ("construction_work_notice".equals(id)) return "Hinweis · Bauarbeiten und Fahrplanänderungen";
        if ("step_extension_unavailable".equals(id)) return "Hinweis · Trittstufen fahren nicht aus";
        if ("signal_repair_delay_notice".equals(id)) return "Hinweis · Verspätung wegen Signalreparatur";
        if ("door_area_clear_notice".equals(id)) return "Hinweis · Türbereich freihalten";
        if ("unscheduled_stop_notice".equals(id)) return "Hinweis · Außerplanmäßiger Halt";
        if ("platform_edge_gap_notice".equals(id)) return "Hinweis · Abstand zur Bahnsteigkante";
        if ("stabling_exit_notice".equals(id)) return "Hinweis · Weiterfahrt in die Abstellung";
        if ("corona_mask_notice".equals(id)) return "Hinweis · Corona · Abstand und medizinische Maske";
        return "Unbekannter Baustein";
    }

    private static String canonicalBlockId(String id) {
        if ("train_ends".equals(id) || "all_exit".equals(id)) return COMBINED_END_ID;
        return "platform_gap".equals(id) ? "platform_edge_gap_notice" : id;
    }

    static boolean isKnown(String id) {
        return isStationItem(id) || !"Unbekannter Baustein".equals(labelForId(id));
    }

    /** Only legacy global station rows require a currently selected station. */
    static boolean requiresStation(List<String> sequence) {
        return sequence != null && sequence.contains("station_name");
    }

    static ArrayList<String> toAssetPlaylist(List<String> sequence, String stationClip) {
        ArrayList<String> output = new ArrayList<>();
        if (sequence == null) return output;
        String previousBlock = "";
        for (String rawBlock : sequence) {
            String block = canonicalBlockId(rawBlock);
            if (COMBINED_END_ID.equals(block) && COMBINED_END_ID.equals(previousBlock)) continue;
            if (isStationItem(block)) output.add(STATION_ASSET_PREFIX + stationClipForItem(block));
            else if ("gong".equals(block)) output.add("asset:/inzug/text/gong_start.opus");
            else if ("next_station".equals(block)) output.add("asset:/inzug/text/naechste_station.opus");
            else if ("station_name".equals(block)) {
                String opusClip = toBundledStationClip(stationClip);
                if (opusClip.length() == 0) throw new IllegalArgumentException("Für den Baustein Stationsname fehlt ein In-Zug-Stationsclip.");
                output.add(STATION_ASSET_PREFIX + opusClip);
            } else if (COMBINED_END_ID.equals(block)) output.add("asset:/inzug/text/zug_endet_fahrgaeste_aussteigen.opus");
            else if ("exit_left".equals(block)) output.add("asset:/inzug/text/ausstieg_fahrtrichtung_links.opus");
            else if ("exit_right".equals(block)) output.add("asset:/inzug/text/ausstieg_fahrtrichtung_rechts.opus");
            else if ("mask_ffp2".equals(block)) output.add("asset:/inzug/text/hinweis_maskenpflicht_ffp2_komplett.opus");
            else if ("mask_ffp2_en".equals(block)) output.add("asset:/inzug/text/hinweis_ffp2_mask_english.opus");
            else if ("personal_belongings".equals(block)) output.add("asset:/inzug/text/hinweis_persoenliche_gegenstaende.opus");
            else if ("thank_you".equals(block)) output.add("asset:/inzug/text/hinweis_vielen_dank_und_auf_wiedersehen.opus");
            else if ("db_regio_farewell".equals(block)) output.add("asset:/inzug/text/hinweis_db_regio_verabschiedung.opus");
            else if ("next_time_sbahn_rheinruhr".equals(block)) output.add("asset:/inzug/text/hinweis_bis_zum_naechsten_mal_s_bahn_rhein_ruhr.opus");
            else if ("construction_work_notice".equals(block)) output.add("asset:/inzug/text/hinweis_bauarbeiten_fahrplanaenderungen.opus");
            else if ("step_extension_unavailable".equals(block)) output.add("asset:/inzug/text/hinweis_trittstufen_fahren_nicht_aus.opus");
            else if ("signal_repair_delay_notice".equals(block)) output.add("asset:/inzug/text/hinweis_signalreparatur_verzoegerung.opus");
            else if ("door_area_clear_notice".equals(block)) output.add("asset:/inzug/text/hinweis_tuerbereich_freihalten.opus");
            else if ("unscheduled_stop_notice".equals(block)) output.add("asset:/inzug/text/hinweis_ausserplanmaessiger_halt.opus");
            else if ("platform_edge_gap_notice".equals(block)) output.add("asset:/inzug/text/hinweis_abstand_zur_bahnsteigkante.opus");
            else if ("stabling_exit_notice".equals(block)) output.add("asset:/inzug/text/hinweis_weiterfahrt_in_die_abstellung.opus");
            else if ("corona_mask_notice".equals(block)) output.add("asset:/inzug/text/hinweis_corona_abstand_medizinische_maske.opus");
            else throw new IllegalArgumentException("Unbekannter Im-Zug-Baustein: " + block);
            previousBlock = block;
        }
        return output;
    }
}
