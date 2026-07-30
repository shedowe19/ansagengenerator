package de.shedowe.ansagengenerator;

import org.junit.Test;

import java.util.Arrays;

import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertFalse;
import static org.junit.Assert.assertTrue;

public class InTrainSequenceSupportTest {
    @Test public void preservesManualOrderAndRepeatedBlocksWithOpusAssets() {
        assertEquals(Arrays.asList(
                        "asset:/inzug/text/gong_start.opus",
                        "asset:/inzug/station_name_only/station_name_berlin_hbf.opus",
                        "asset:/inzug/text/ausstieg_fahrtrichtung_links.opus",
                        "asset:/inzug/text/gong_start.opus"),
                InTrainSequenceSupport.toAssetPlaylist(Arrays.asList("gong", "station_name", "exit_left", "gong"), "station_name_berlin_hbf.opus"));
    }

    @Test public void allowsAnnouncementWithoutStationName() {
        assertFalse(InTrainSequenceSupport.requiresStation(Arrays.asList("gong", "mask_ffp2")));
        assertEquals(Arrays.asList("asset:/inzug/text/gong_start.opus", "asset:/inzug/text/hinweis_maskenpflicht_ffp2_komplett.opus"),
                InTrainSequenceSupport.toAssetPlaylist(Arrays.asList("gong", "mask_ffp2"), ""));
    }

    @Test public void requiresStationOnlyWhenStationBlockWasChosen() {
        assertTrue(InTrainSequenceSupport.requiresStation(Arrays.asList("next_station", "station_name", "train_ends")));
    }

    @Test public void keepsNewHintAtomsStationIndependentAndInOrder() {
        assertFalse(InTrainSequenceSupport.requiresStation(Arrays.asList("personal_belongings", "thank_you", "next_time_sbahn_rheinruhr", "platform_gap")));
        assertEquals(Arrays.asList(
                        "asset:/inzug/text/hinweis_persoenliche_gegenstaende.opus",
                        "asset:/inzug/text/hinweis_vielen_dank_und_auf_wiedersehen.opus",
                        "asset:/inzug/text/hinweis_bis_zum_naechsten_mal_s_bahn_rhein_ruhr.opus",
                        "asset:/inzug/text/hinweis_bahnsteigkante.opus"),
                InTrainSequenceSupport.toAssetPlaylist(Arrays.asList("personal_belongings", "thank_you", "next_time_sbahn_rheinruhr", "platform_gap"), ""));
    }

    @Test public void keepsStationPlaylistItemsSelfContainedAndInOrder() {
        String moenchengladbach = InTrainSequenceSupport.stationItem("station_name_moenchengladbach_hbf.opus");
        String luerrip = InTrainSequenceSupport.stationItem("station_name_moenchengladbach_luerrip.opus");
        assertTrue(InTrainSequenceSupport.isStationItem(moenchengladbach));
        assertTrue(InTrainSequenceSupport.isKnown(moenchengladbach));
        assertFalse(InTrainSequenceSupport.requiresStation(Arrays.asList("gong", moenchengladbach, "next_station", luerrip, moenchengladbach)));
        assertEquals(Arrays.asList(
                        "asset:/inzug/text/gong_start.opus",
                        "asset:/inzug/station_name_only/station_name_moenchengladbach_hbf.opus",
                        "asset:/inzug/text/naechste_station.opus",
                        "asset:/inzug/station_name_only/station_name_moenchengladbach_luerrip.opus",
                        "asset:/inzug/station_name_only/station_name_moenchengladbach_hbf.opus"),
                InTrainSequenceSupport.toAssetPlaylist(Arrays.asList("gong", moenchengladbach, "next_station", luerrip, moenchengladbach), ""));
        assertTrue(InTrainSequenceSupport.isStationAssetPath("asset:/inzug/station_name_only/station_name_moenchengladbach_hbf.opus"));
        assertTrue(InTrainSequenceSupport.shouldPauseAfterQueueEntry(true, "asset:/inzug/station_name_only/station_name_moenchengladbach_hbf.opus"));
        assertFalse(InTrainSequenceSupport.shouldPauseAfterQueueEntry(false, "asset:/inzug/station_name_only/station_name_moenchengladbach_hbf.opus"));
        assertFalse(InTrainSequenceSupport.shouldPauseAfterQueueEntry(true, "asset:/inzug/text/hinweis_persoenliche_gegenstaende.opus"));
    }

    @Test public void migratesLegacyWavStationTokensToBundledOpus() {
        String legacy = "station:station_name_hagen_hbf.wav";
        assertTrue(InTrainSequenceSupport.isStationItem(legacy));
        assertEquals("station_name_hagen_hbf.opus", InTrainSequenceSupport.stationClipForItem(legacy));
        assertEquals(Arrays.asList("asset:/inzug/station_name_only/station_name_hagen_hbf.opus"),
                InTrainSequenceSupport.toAssetPlaylist(Arrays.asList(legacy), ""));
    }

    @Test(expected = IllegalArgumentException.class)
    public void rejectsUnsafeStationPlaylistItem() {
        InTrainSequenceSupport.stationItem("../outside.wav");
    }

    @Test public void mapsNewHintLabelsBothWays() {
        assertEquals("personal_belongings", InTrainSequenceSupport.idForLabel("Hinweis · Persönliche Gegenstände"));
        assertEquals("Hinweis · Bis zum nächsten Mal · S-Bahn Rhein-Ruhr", InTrainSequenceSupport.labelForId("next_time_sbahn_rheinruhr"));
        assertTrue(InTrainSequenceSupport.isKnown("platform_gap"));
    }

    @Test public void keepsDbRegioFarewellHintStationIndependentAndInOrder() {
        assertEquals("db_regio_farewell", InTrainSequenceSupport.idForLabel("Hinweis · DB Regio Verabschiedung"));
        assertEquals("Hinweis · DB Regio Verabschiedung", InTrainSequenceSupport.labelForId("db_regio_farewell"));
        assertFalse(InTrainSequenceSupport.requiresStation(Arrays.asList("db_regio_farewell")));
        assertEquals(Arrays.asList("asset:/inzug/text/hinweis_db_regio_verabschiedung.opus"),
                InTrainSequenceSupport.toAssetPlaylist(Arrays.asList("db_regio_farewell"), ""));
    }

    @Test(expected = IllegalArgumentException.class)
    public void rejectsStationBlockWithoutMappedClip() {
        InTrainSequenceSupport.toAssetPlaylist(Arrays.asList("station_name"), "");
    }

    @Test(expected = IllegalArgumentException.class)
    public void rejectsUnknownManualBlock() {
        InTrainSequenceSupport.toAssetPlaylist(Arrays.asList("not_a_block"), "");
    }
}
