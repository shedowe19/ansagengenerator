package de.shedowe.ansagengenerator;

import org.junit.Test;

import static org.junit.Assert.assertTrue;

public class SearchResultOrderingTest {
    @Test public void ranksHigherScoresBeforeAlphabeticalTitles() {
        MainActivity.Result low = new MainActivity.Result("Aachen Hbf", "", "", false, 65);
        MainActivity.Result high = new MainActivity.Result("Zürich HB", "", "", false, 120);
        assertTrue(high.compareTo(low) < 0);
    }

    @Test public void sortsSameScoreWithNormalizedGermanNames() {
        MainActivity.Result umlaut = new MainActivity.Result("Äpfel", "", "", false, 65);
        MainActivity.Result berlin = new MainActivity.Result("Berlin Hbf", "", "", false, 65);
        assertTrue(umlaut.compareTo(berlin) < 0);
    }
}
