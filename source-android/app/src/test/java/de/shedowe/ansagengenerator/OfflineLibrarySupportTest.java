package de.shedowe.ansagengenerator;

import org.junit.Test;

import java.io.File;
import java.nio.file.Files;

import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertFalse;
import static org.junit.Assert.assertTrue;

public class OfflineLibrarySupportTest {
    @Test public void acceptsOfficialDatasetStatistics() {
        OfflineLibrarySupport.requireExpectedDatasetStatistics(87902, 87902, 453253609L);
    }

    @Test(expected = IllegalArgumentException.class)
    public void rejectsIncompleteDatasetStatistics() {
        OfflineLibrarySupport.requireExpectedDatasetStatistics(87901, 87902, 453253609L);
    }

    @Test public void mapsLegacyPlaylistWavToBundledOpus() {
        assertEquals("dt/module/016.opus", OfflineLibrarySupport.toBundledOpusPath("dt/module/016.wav"));
        assertEquals("", OfflineLibrarySupport.toBundledOpusPath("dt/module/016.opus"));
        assertEquals("", OfflineLibrarySupport.toBundledOpusPath("../module/016.wav"));
    }

    @Test public void childPathCheckRejectsSibling() throws Exception {
        File root = Files.createTempDirectory("ansagen-root").toFile();
        File child = new File(root, "audio/test.wav");
        File sibling = new File(root.getParentFile(), root.getName() + "-sibling/test.wav");
        assertTrue(OfflineLibrarySupport.isChildOf(root, child));
        assertFalse(OfflineLibrarySupport.isChildOf(root, sibling));
        OfflineLibrarySupport.deleteRecursively(root);
    }
}
