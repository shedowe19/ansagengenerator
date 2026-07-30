package de.shedowe.ansagengenerator;

import java.io.File;
import java.io.IOException;

/** Constants and filesystem guards for the fixed embedded offline release. */
final class OfflineLibrarySupport {
    static final String EXPECTED_ARCHIVE_SHA256 = "80ada82a559fa5a40085cfd7c10aeae483991be68ec4ca0073150755489e4214";
    static final int EXPECTED_FILE_COUNT = 87902;
    static final int EXPECTED_OPUS_COUNT = 87902;
    static final long EXPECTED_UNCOMPRESSED_BYTES = 453253609L;

    private OfflineLibrarySupport() { }

    static void requireExpectedArchiveSha256(String actualSha256) {
        String actual = actualSha256 == null ? "" : actualSha256.trim();
        if (!EXPECTED_ARCHIVE_SHA256.equalsIgnoreCase(actual)) {
            throw new IllegalArgumentException("Eingebettetes Datenarchiv stimmt nicht mit der erwarteten Release-Prüfsumme überein.");
        }
    }

    static void requireExpectedDatasetStatistics(int fileCount, int opusCount, long uncompressedBytes) {
        if (fileCount != EXPECTED_FILE_COUNT || opusCount != EXPECTED_OPUS_COUNT || uncompressedBytes != EXPECTED_UNCOMPRESSED_BYTES) {
            throw new IllegalArgumentException("Eingebettete Bibliothek enthält nicht den erwarteten vollständigen Offline-Bestand.");
        }
    }

    static String toBundledOpusPath(String relativeWavPath) {
        String path = relativeWavPath == null ? "" : relativeWavPath.replace('\\', '/').trim();
        if (path.length() == 0 || path.contains("..") || !path.toLowerCase(java.util.Locale.ROOT).endsWith(".wav")) return "";
        return path.substring(0, path.length() - 4) + ".opus";
    }

    static boolean isChildOf(File root, File candidate) throws IOException {
        String canonicalRoot = root.getCanonicalPath();
        String canonicalCandidate = candidate.getCanonicalPath();
        return canonicalCandidate.startsWith(canonicalRoot + File.separator);
    }

    static boolean deleteRecursively(File file) {
        if (file == null || !file.exists()) return true;
        boolean deleted = true;
        if (file.isDirectory()) {
            File[] children = file.listFiles();
            if (children != null) for (File child : children) deleted &= deleteRecursively(child);
        }
        return (file.delete() || !file.exists()) && deleted;
    }
}
