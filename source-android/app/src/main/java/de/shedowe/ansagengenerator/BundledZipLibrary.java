package de.shedowe.ansagengenerator;

import android.content.res.AssetFileDescriptor;
import android.content.res.AssetManager;
import android.os.ParcelFileDescriptor;

import java.io.Closeable;
import java.io.FileInputStream;
import java.io.IOException;
import java.io.InputStream;
import java.nio.ByteBuffer;
import java.nio.channels.FileChannel;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.util.ArrayList;
import java.util.Collections;
import java.util.HashMap;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.zip.Inflater;
import java.util.zip.InflaterInputStream;

/**
 * Reads the compact Ogg/Opus offline ZIP directly from an uncompressed APK asset.
 *
 * The asset stays uncompressed at the APK layer so Android exposes a seekable
 * descriptor. Individual Ogg files are stored inside the ZIP and copied only
 * when they are needed for playback or WAV export.
 */
final class BundledZipLibrary implements Closeable {
    private static final long MAX_EOCD_SCAN_BYTES = 65_557L;
    private static final long MAX_CENTRAL_DIRECTORY_BYTES = 64L * 1024L * 1024L;
    private static final int LOCAL_FILE_HEADER_BYTES = 30;
    private static final int CENTRAL_FILE_HEADER_BYTES = 46;
    private static final int BUFFER_BYTES = 128 * 1024;

    private final ArrayList<Part> parts = new ArrayList<>();
    private final HashMap<String, Entry> entries = new HashMap<>();
    private long totalBytes;
    private int libraryFileCount;
    private int libraryOpusCount;
    private long libraryUncompressedBytes;

    static BundledZipLibrary open(AssetManager assets, String[] assetNames) throws IOException {
        BundledZipLibrary library = new BundledZipLibrary();
        try {
            long offset = 0;
            for (String assetName : assetNames) {
                AssetFileDescriptor descriptor = assets.openFd(assetName);
                ParcelFileDescriptor duplicate = ParcelFileDescriptor.dup(descriptor.getFileDescriptor());
                FileInputStream stream = new FileInputStream(duplicate.getFileDescriptor());
                long length = descriptor.getLength();
                if (length <= 0) throw new IOException("Eingebetteter Offline-Teil ist leer: " + assetName);
                library.parts.add(new Part(offset, length, descriptor.getStartOffset(), duplicate, stream));
                offset = safeAdd(offset, length);
                descriptor.close();
            }
            library.totalBytes = offset;
            library.indexCentralDirectory();
            library.requireExpectedAudioLibrary();
            return library;
        } catch (Exception e) {
            library.close();
            if (e instanceof IOException) throw (IOException) e;
            throw new IOException("Eingebettete Offline-Bibliothek kann nicht geöffnet werden.", e);
        }
    }

    boolean hasLibraryFile(String relativePath) {
        return entries.containsKey(archiveEntryKey(relativePath));
    }

    InputStream openLibraryFile(String relativePath) throws IOException {
        Entry entry = entries.get(archiveEntryKey(relativePath));
        if (entry == null) throw new IOException("Eingebettete Datei fehlt: " + relativePath);
        return openEntry(entry);
    }

    int getLibraryFileCount() { return libraryFileCount; }
    int getLibraryOpusCount() { return libraryOpusCount; }
    long getLibraryUncompressedBytes() { return libraryUncompressedBytes; }

    String sha256OfArchive() throws IOException {
        try {
            MessageDigest digest = MessageDigest.getInstance("SHA-256");
            byte[] buffer = new byte[BUFFER_BYTES];
            try (InputStream archive = new RangeInputStream(this, 0, totalBytes)) {
                int read;
                while ((read = archive.read(buffer)) != -1) digest.update(buffer, 0, read);
            }
            return toHex(digest.digest());
        } catch (IOException e) {
            throw e;
        } catch (Exception e) {
            throw new IOException("Eingebettete Offline-Bibliothek kann nicht gehasht werden.", e);
        }
    }

    @Override public void close() {
        for (Part part : parts) part.close();
        parts.clear();
        entries.clear();
    }

    private void indexCentralDirectory() throws IOException {
        if (totalBytes < 22) throw new IOException("Eingebettetes Offline-Archiv ist zu klein.");
        int scanSize = (int) Math.min(totalBytes, MAX_EOCD_SCAN_BYTES);
        byte[] tail = readBytes(totalBytes - scanSize, scanSize);
        int eocd = -1;
        for (int i = tail.length - 22; i >= 0; i--) {
            if (u32(tail, i) == 0x06054b50L) { eocd = i; break; }
        }
        if (eocd < 0) throw new IOException("Eingebettetes Offline-Archiv hat kein ZIP-Ende.");

        long declaredEntries = u16(tail, eocd + 10);
        long centralSize = u32(tail, eocd + 12);
        long centralOffset = u32(tail, eocd + 16);
        if (declaredEntries == 0xffffL || centralSize == 0xffffffffL || centralOffset == 0xffffffffL) {
            if (eocd < 20 || u32(tail, eocd - 20) != 0x07064b50L) throw new IOException("ZIP64-Verweis fehlt im eingebetteten Offline-Archiv.");
            long zip64EndOffset = u64(tail, eocd - 12);
            byte[] zip64End = readBytes(zip64EndOffset, 56);
            if (u32(zip64End, 0) != 0x06064b50L) throw new IOException("ZIP64-Ende im eingebetteten Offline-Archiv ist ungültig.");
            declaredEntries = u64(zip64End, 32);
            centralSize = u64(zip64End, 40);
            centralOffset = u64(zip64End, 48);
        }
        if (declaredEntries <= 0 || declaredEntries > Integer.MAX_VALUE || centralSize <= 0 || centralSize > MAX_CENTRAL_DIRECTORY_BYTES || safeAdd(centralOffset, centralSize) > totalBytes) {
            throw new IOException("Ungültiges zentrales ZIP-Verzeichnis.");
        }

        byte[] directory = readBytes(centralOffset, (int) centralSize);
        int cursor = 0;
        int parsedEntries = 0;
        while (cursor < directory.length && parsedEntries < declaredEntries) {
            if (cursor + CENTRAL_FILE_HEADER_BYTES > directory.length || u32(directory, cursor) != 0x02014b50L) {
                throw new IOException("Ungültiger ZIP-Verzeichniseintrag.");
            }
            int method = u16(directory, cursor + 10);
            long compressedSize = u32(directory, cursor + 20);
            long uncompressedSize = u32(directory, cursor + 24);
            int nameLength = u16(directory, cursor + 28);
            int extraLength = u16(directory, cursor + 30);
            int commentLength = u16(directory, cursor + 32);
            long localOffset = u32(directory, cursor + 42);
            int recordLength = CENTRAL_FILE_HEADER_BYTES + nameLength + extraLength + commentLength;
            if (recordLength < CENTRAL_FILE_HEADER_BYTES || cursor + recordLength > directory.length) {
                throw new IOException("Ungültige ZIP-Dateinamenlänge.");
            }
            String name = new String(directory, cursor + CENTRAL_FILE_HEADER_BYTES, nameLength, StandardCharsets.UTF_8);
            if (!name.endsWith("/")) {
                if (entries.put(name, new Entry(name, method, compressedSize, uncompressedSize, localOffset)) != null) {
                    throw new IOException("Doppelte eingebettete ZIP-Datei: " + name);
                }
                if (name.startsWith("site/")) {
                    libraryFileCount++;
                    libraryUncompressedBytes = safeAdd(libraryUncompressedBytes, uncompressedSize);
                    if (name.toLowerCase(Locale.ROOT).endsWith(".opus")) libraryOpusCount++;
                }
            }
            cursor += recordLength;
            parsedEntries++;
        }
        if (parsedEntries != declaredEntries) throw new IOException("ZIP-Verzeichnis ist unvollständig.");
    }

    private void requireExpectedAudioLibrary() throws IOException {
        try {
            OfflineLibrarySupport.requireExpectedDatasetStatistics(libraryFileCount, libraryOpusCount, libraryUncompressedBytes);
        } catch (IllegalArgumentException e) {
            throw new IOException("Eingebettete Offline-Bibliothek stimmt nicht mit dem erwarteten Release überein.", e);
        }
        String[] required = {"dt/module_3_1/016.opus", "gong/513/513_2.opus", "dt/ziele/variante2/tief/8000261.opus"};
        for (String file : required) if (!hasLibraryFile(file)) throw new IOException("Eingebettete Offline-Bibliothek enthält nicht: " + file);
    }

    private InputStream openEntry(Entry entry) throws IOException {
        byte[] header = readBytes(entry.localOffset, LOCAL_FILE_HEADER_BYTES);
        if (u32(header, 0) != 0x04034b50L) throw new IOException("Ungültiger lokaler ZIP-Header: " + entry.name);
        int nameLength = u16(header, 26);
        int extraLength = u16(header, 28);
        long dataOffset = safeAdd(entry.localOffset, LOCAL_FILE_HEADER_BYTES + nameLength + extraLength);
        if (safeAdd(dataOffset, entry.compressedSize) > totalBytes) throw new IOException("ZIP-Datei liegt außerhalb des eingebetteten Archivs.");
        InputStream raw = new RangeInputStream(this, dataOffset, entry.compressedSize);
        if (entry.method == 0) return raw;
        if (entry.method == 8) return new InflaterInputStream(raw, new Inflater(true), BUFFER_BYTES);
        raw.close();
        throw new IOException("Nicht unterstützte ZIP-Kompression für " + entry.name);
    }

    private byte[] readBytes(long offset, int length) throws IOException {
        byte[] data = new byte[length];
        readFully(offset, data, 0, length);
        return data;
    }

    private synchronized void readFully(long offset, byte[] data, int dataOffset, int length) throws IOException {
        if (offset < 0 || length < 0 || safeAdd(offset, length) > totalBytes) throw new IOException("Ungültiger Lesezugriff auf eingebettete Offline-Daten.");
        long position = offset;
        int targetOffset = dataOffset;
        int remaining = length;
        while (remaining > 0) {
            Part part = partAt(position);
            long inPart = position - part.virtualOffset;
            int chunk = (int) Math.min((long) remaining, part.length - inPart);
            ByteBuffer target = ByteBuffer.wrap(data, targetOffset, chunk);
            long apkPosition = safeAdd(part.apkOffset, inPart);
            while (target.hasRemaining()) {
                int read = part.channel.read(target, apkPosition);
                if (read <= 0) throw new IOException("Eingebettete Offline-Daten konnten nicht vollständig gelesen werden.");
                apkPosition += read;
            }
            position += chunk;
            targetOffset += chunk;
            remaining -= chunk;
        }
    }

    private Part partAt(long position) throws IOException {
        for (Part part : parts) if (position >= part.virtualOffset && position < safeAdd(part.virtualOffset, part.length)) return part;
        throw new IOException("Eingebetteter Offline-Teil fehlt an Position " + position);
    }

    private static String archiveEntryKey(String rawPath) {
        if (rawPath == null) return "";
        String path = rawPath.replace('\\', '/').trim();
        while (path.startsWith("/")) path = path.substring(1);
        if (path.startsWith("site/")) path = path.substring(5);
        if (path.length() == 0 || path.contains("..") || path.contains("//")) return "";
        return "site/" + path;
    }

    private static long u64(byte[] data, int offset) throws IOException {
        long low = u32(data, offset);
        long high = u32(data, offset + 4);
        if (high > 0x7fffffffL) throw new IOException("ZIP64-Wert ist zu groß für diese Offline-Bibliothek.");
        return low | (high << 32);
    }

    private static long safeAdd(long first, long second) throws IOException {
        if (first < 0 || second < 0 || first > Long.MAX_VALUE - second) throw new IOException("Größenüberlauf in eingebetteter Offline-Bibliothek.");
        return first + second;
    }

    private static int u16(byte[] data, int offset) {
        return (data[offset] & 0xff) | ((data[offset + 1] & 0xff) << 8);
    }

    private static long u32(byte[] data, int offset) {
        return ((long) data[offset] & 0xff)
                | (((long) data[offset + 1] & 0xff) << 8)
                | (((long) data[offset + 2] & 0xff) << 16)
                | (((long) data[offset + 3] & 0xff) << 24);
    }

    private static String toHex(byte[] bytes) {
        StringBuilder out = new StringBuilder(bytes.length * 2);
        for (byte value : bytes) out.append(String.format(Locale.ROOT, "%02x", value & 255));
        return out.toString();
    }

    private static final class Entry {
        final String name;
        final int method;
        final long compressedSize;
        final long uncompressedSize;
        final long localOffset;

        Entry(String name, int method, long compressedSize, long uncompressedSize, long localOffset) {
            this.name = name;
            this.method = method;
            this.compressedSize = compressedSize;
            this.uncompressedSize = uncompressedSize;
            this.localOffset = localOffset;
        }
    }

    private static final class Part {
        final long virtualOffset;
        final long length;
        final long apkOffset;
        final ParcelFileDescriptor descriptor;
        final FileInputStream stream;
        final FileChannel channel;

        Part(long virtualOffset, long length, long apkOffset, ParcelFileDescriptor descriptor, FileInputStream stream) {
            this.virtualOffset = virtualOffset;
            this.length = length;
            this.apkOffset = apkOffset;
            this.descriptor = descriptor;
            this.stream = stream;
            this.channel = stream.getChannel();
        }

        void close() {
            try { stream.close(); } catch (IOException ignored) { }
            try { descriptor.close(); } catch (IOException ignored) { }
        }
    }

    private static final class RangeInputStream extends InputStream {
        private final BundledZipLibrary library;
        private long position;
        private long remaining;

        RangeInputStream(BundledZipLibrary library, long position, long remaining) {
            this.library = library;
            this.position = position;
            this.remaining = remaining;
        }

        @Override public int read() throws IOException {
            byte[] one = new byte[1];
            return read(one, 0, 1) == -1 ? -1 : one[0] & 0xff;
        }

        @Override public int read(byte[] buffer, int offset, int length) throws IOException {
            if (length == 0) return 0;
            if (remaining == 0) return -1;
            int count = (int) Math.min((long) length, remaining);
            library.readFully(position, buffer, offset, count);
            position += count;
            remaining -= count;
            return count;
        }

        @Override public long skip(long count) {
            long skipped = Math.min(Math.max(0, count), remaining);
            position += skipped;
            remaining -= skipped;
            return skipped;
        }

        @Override public int available() { return (int) Math.min(Integer.MAX_VALUE, remaining); }
    }
}
