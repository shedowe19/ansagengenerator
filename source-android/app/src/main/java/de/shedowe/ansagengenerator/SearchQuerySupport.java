package de.shedowe.ansagengenerator;

import java.text.Normalizer;
import java.util.Locale;

/** Pure normalizers and classification rules shared by the native station search. */
final class SearchQuerySupport {
    private SearchQuerySupport() { }

    static String fold(String value) {
        if (value == null) return "";
        String folded = Normalizer.normalize(value.toLowerCase(Locale.ROOT), Normalizer.Form.NFD).replaceAll("\\p{Mn}+", "");
        folded = folded.replace("ß", "ss").replaceAll("[^a-z0-9]+", " ").trim();
        return folded.replaceAll("\\s+", " ");
    }

    static String expand(String value) {
        if (value == null) return "";
        String expanded = value.toLowerCase(Locale.ROOT).replace("ä", "ae").replace("ö", "oe").replace("ü", "ue").replace("ß", "ss");
        expanded = Normalizer.normalize(expanded, Normalizer.Form.NFD).replaceAll("\\p{Mn}+", "");
        expanded = expanded.replaceAll("[^a-z0-9]+", " ").trim();
        return expanded.replaceAll("\\s+", " ");
    }

    static String code(String value) {
        return value == null ? "" : value.trim().toUpperCase(Locale.ROOT).replaceAll("\\s+", " ");
    }

    /**
     * Short/uppercase RL100-shaped input is treated as a code. Mixed-case names
     * such as "Cottbus" deliberately stay name searches.
     */
    static boolean isCodeQuery(String rawQuery) {
        if (rawQuery == null) return false;
        String trimmed = rawQuery.trim();
        if (trimmed.isEmpty() || !trimmed.equals(trimmed.toUpperCase(Locale.ROOT))) return false;
        return trimmed.matches("[A-Z0-9 ]{1,7}");
    }
}
