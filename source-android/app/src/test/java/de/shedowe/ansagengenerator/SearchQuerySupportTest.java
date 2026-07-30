package de.shedowe.ansagengenerator;

import org.junit.Test;

import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertFalse;
import static org.junit.Assert.assertTrue;

public class SearchQuerySupportTest {
    @Test public void normalizesUmlautsAndWhitespace() {
        assertEquals("munchen hbf", SearchQuerySupport.fold("  München   Hbf "));
        assertEquals("muenchen hbf", SearchQuerySupport.expand("München Hbf"));
        assertEquals("AA G", SearchQuerySupport.code(" AA   G "));
    }

    @Test public void recognizesRealCodeShapes() {
        assertTrue(SearchQuerySupport.isCodeQuery("KA"));
        assertTrue(SearchQuerySupport.isCodeQuery("KASZ"));
        assertTrue(SearchQuerySupport.isCodeQuery("AA G"));
    }

    @Test public void keepsMixedCaseStationNamesAsNames() {
        assertFalse(SearchQuerySupport.isCodeQuery("Cottbus"));
        assertFalse(SearchQuerySupport.isCodeQuery("München"));
        assertFalse(SearchQuerySupport.isCodeQuery("Ka"));
    }
}
