package de.shedowe.ansagengenerator;

import android.media.AudioFormat;
import android.media.MediaCodec;
import android.media.MediaExtractor;
import android.media.MediaFormat;

import java.io.File;
import java.io.FileInputStream;
import java.io.FileOutputStream;
import java.io.IOException;
import java.io.OutputStream;
import java.io.RandomAccessFile;
import java.nio.ByteBuffer;
import java.nio.ByteOrder;
import java.util.List;

/**
 * Streams cached Ogg/Opus (and legacy WAV) fragments into one PCM WAV export.
 *
 * Nothing is accumulated in memory: the RIFF header is written only after all
 * fragments have been decoded, which keeps exports safe for long announcements.
 * Android's Opus decoder is available for the app's minimum SDK (23).
 */
final class AudioWavExporter {
    private static final long CODEC_TIMEOUT_US = 10_000L;
    private static final long MAX_RIFF_DATA_BYTES = 0xffff_ffffL - 36L;

    private AudioWavExporter() { }

    static void exportToWav(List<File> files, File destination) throws IOException {
        if (files == null || files.isEmpty()) throw new IOException("Keine Audios zum Exportieren.");
        File parent = destination.getParentFile();
        if (parent != null && !parent.exists() && !parent.mkdirs()) throw new IOException("Exportordner kann nicht erstellt werden.");
        File temporary = new File(parent == null ? destination.getAbsolutePath() + ".part" : new File(parent, destination.getName() + ".part").getAbsolutePath());
        if (temporary.exists() && !temporary.delete()) throw new IOException("Alter Exportrest kann nicht entfernt werden.");

        try (WavSink sink = new WavSink(temporary)) {
            for (File file : files) {
                if (file == null || !file.isFile()) throw new IOException("Audio-Datei fehlt für Export.");
                String name = file.getName().toLowerCase();
                if (name.endsWith(".opus") || name.endsWith(".ogg")) decodeOpusToSink(file, sink);
                else if (name.endsWith(".wav")) appendWavToSink(file, sink);
                else throw new IOException("Nicht unterstütztes Export-Audio: " + file.getName());
            }
            sink.finish();
        } catch (Exception e) {
            temporary.delete();
            if (e instanceof IOException) throw (IOException) e;
            throw new IOException("Audioexport konnte nicht dekodiert werden.", e);
        }
        if (destination.exists() && !destination.delete()) {
            temporary.delete();
            throw new IOException("Vorhandener Export kann nicht ersetzt werden.");
        }
        if (!temporary.renameTo(destination)) {
            temporary.delete();
            throw new IOException("Export kann nicht aktiviert werden.");
        }
    }

    private static void decodeOpusToSink(File file, WavSink sink) throws IOException {
        MediaExtractor extractor = new MediaExtractor();
        MediaCodec decoder = null;
        try {
            extractor.setDataSource(file.getAbsolutePath());
            int audioTrack = findAudioTrack(extractor);
            if (audioTrack < 0) throw new IOException("Keine Audiospur: " + file.getName());
            extractor.selectTrack(audioTrack);
            MediaFormat input = extractor.getTrackFormat(audioTrack);
            String mime = input.getString(MediaFormat.KEY_MIME);
            if (mime == null || !mime.startsWith("audio/")) throw new IOException("Ungültige Audiospur: " + file.getName());
            decoder = MediaCodec.createDecoderByType(mime);
            decoder.configure(input, null, null, 0);
            decoder.start();

            MediaCodec.BufferInfo info = new MediaCodec.BufferInfo();
            boolean inputDone = false;
            boolean outputDone = false;
            boolean outputConfigured = false;
            while (!outputDone) {
                if (!inputDone) {
                    int inputIndex = decoder.dequeueInputBuffer(CODEC_TIMEOUT_US);
                    if (inputIndex >= 0) {
                        ByteBuffer buffer = decoder.getInputBuffer(inputIndex);
                        if (buffer == null) throw new IOException("Decoder-Eingabepuffer fehlt.");
                        buffer.clear();
                        int size = extractor.readSampleData(buffer, 0);
                        if (size < 0) {
                            decoder.queueInputBuffer(inputIndex, 0, 0, 0, MediaCodec.BUFFER_FLAG_END_OF_STREAM);
                            inputDone = true;
                        } else {
                            decoder.queueInputBuffer(inputIndex, 0, size, extractor.getSampleTime(), 0);
                            extractor.advance();
                        }
                    }
                }

                int outputIndex = decoder.dequeueOutputBuffer(info, CODEC_TIMEOUT_US);
                if (outputIndex == MediaCodec.INFO_OUTPUT_FORMAT_CHANGED) {
                    configurePcmSink(sink, decoder.getOutputFormat(), file.getName());
                    outputConfigured = true;
                } else if (outputIndex >= 0) {
                    if (!outputConfigured) {
                        configurePcmSink(sink, decoder.getOutputFormat(), file.getName());
                        outputConfigured = true;
                    }
                    if (info.size > 0) {
                        ByteBuffer buffer = decoder.getOutputBuffer(outputIndex);
                        if (buffer == null) throw new IOException("Decoder-Ausgabepuffer fehlt.");
                        buffer.position(info.offset);
                        buffer.limit(info.offset + info.size);
                        sink.write(buffer);
                    }
                    boolean eos = (info.flags & MediaCodec.BUFFER_FLAG_END_OF_STREAM) != 0;
                    decoder.releaseOutputBuffer(outputIndex, false);
                    if (eos) outputDone = true;
                }
            }
        } finally {
            if (decoder != null) {
                try { decoder.stop(); } catch (Exception ignored) { }
                try { decoder.release(); } catch (Exception ignored) { }
            }
            extractor.release();
        }
    }

    private static int findAudioTrack(MediaExtractor extractor) {
        for (int index = 0; index < extractor.getTrackCount(); index++) {
            String mime = extractor.getTrackFormat(index).getString(MediaFormat.KEY_MIME);
            if (mime != null && mime.startsWith("audio/")) return index;
        }
        return -1;
    }

    private static void configurePcmSink(WavSink sink, MediaFormat format, String name) throws IOException {
        int sampleRate = requiredInt(format, MediaFormat.KEY_SAMPLE_RATE, name);
        int channels = requiredInt(format, MediaFormat.KEY_CHANNEL_COUNT, name);
        int encoding = format.containsKey(MediaFormat.KEY_PCM_ENCODING)
                ? format.getInteger(MediaFormat.KEY_PCM_ENCODING) : AudioFormat.ENCODING_PCM_16BIT;
        if (encoding != AudioFormat.ENCODING_PCM_16BIT) {
            throw new IOException("Opus-Decoder liefert kein 16-Bit-PCM: " + name);
        }
        sink.configure(channels, sampleRate, 16);
    }

    private static int requiredInt(MediaFormat format, String key, String name) throws IOException {
        if (!format.containsKey(key)) throw new IOException("Audioformat ohne " + key + ": " + name);
        int value = format.getInteger(key);
        if (value <= 0) throw new IOException("Ungültiges Audioformat: " + name);
        return value;
    }

    private static void appendWavToSink(File file, WavSink sink) throws IOException {
        try (RandomAccessFile input = new RandomAccessFile(file, "r")) {
            if (input.length() < 12 || readLeInt(input) != fourCc("RIFF") || readLeInt(input) < 0 || readLeInt(input) != fourCc("WAVE")) {
                throw new IOException("Ungültige WAV-Datei: " + file.getName());
            }
            int channels = 0, sampleRate = 0, bits = 0;
            long dataOffset = -1, dataSize = -1;
            while (input.getFilePointer() + 8 <= input.length()) {
                int id = readLeInt(input);
                long size = readLeInt(input) & 0xffff_ffffL;
                long payload = input.getFilePointer();
                if (payload + size > input.length()) throw new IOException("Ungültiger WAV-Chunk: " + file.getName());
                if (id == fourCc("fmt ")) {
                    if (size < 16) throw new IOException("WAV ohne gültiges fmt: " + file.getName());
                    int codec = readLeShort(input);
                    channels = readLeShort(input);
                    sampleRate = readLeInt(input);
                    input.skipBytes(6);
                    bits = readLeShort(input);
                    if (codec != 1 || bits != 16) throw new IOException("Nur PCM-16-WAV exportierbar: " + file.getName());
                } else if (id == fourCc("data")) {
                    dataOffset = payload;
                    dataSize = size;
                }
                long next = payload + size + (size & 1);
                input.seek(next);
            }
            if (channels <= 0 || sampleRate <= 0 || dataOffset < 0) throw new IOException("WAV unvollständig: " + file.getName());
            sink.configure(channels, sampleRate, bits);
            input.seek(dataOffset);
            byte[] buffer = new byte[64 * 1024];
            long remaining = dataSize;
            while (remaining > 0) {
                int read = input.read(buffer, 0, (int) Math.min(buffer.length, remaining));
                if (read < 0) throw new IOException("WAV-Daten enden zu früh: " + file.getName());
                sink.write(buffer, 0, read);
                remaining -= read;
            }
        }
    }

    private static int fourCc(String value) {
        byte[] bytes = value.getBytes(java.nio.charset.StandardCharsets.US_ASCII);
        return (bytes[0] & 255) | ((bytes[1] & 255) << 8) | ((bytes[2] & 255) << 16) | ((bytes[3] & 255) << 24);
    }

    private static int readLeShort(RandomAccessFile input) throws IOException {
        int lo = input.read(); int hi = input.read();
        if ((lo | hi) < 0) throw new IOException("Unerwartetes Dateiende.");
        return lo | (hi << 8);
    }

    private static int readLeInt(RandomAccessFile input) throws IOException {
        int a = input.read(), b = input.read(), c = input.read(), d = input.read();
        if ((a | b | c | d) < 0) throw new IOException("Unerwartetes Dateiende.");
        return a | (b << 8) | (c << 16) | (d << 24);
    }

    private static final class WavSink implements AutoCloseable {
        private final RandomAccessFile output;
        private int channels = -1, sampleRate = -1, bits = -1;
        private long bytes;
        private final byte[] transfer = new byte[64 * 1024];

        WavSink(File file) throws IOException {
            output = new RandomAccessFile(file, "rw");
            output.setLength(44);
            output.seek(44);
        }

        void configure(int channels, int sampleRate, int bits) throws IOException {
            if (channels <= 0 || sampleRate <= 0 || bits != 16) throw new IOException("Ungültiges PCM-Format für WAV-Export.");
            if (this.channels < 0) {
                this.channels = channels;
                this.sampleRate = sampleRate;
                this.bits = bits;
            } else if (this.channels != channels || this.sampleRate != sampleRate || this.bits != bits) {
                throw new IOException("Audiofragmente haben unterschiedliche PCM-Formate.");
            }
        }

        void write(ByteBuffer buffer) throws IOException {
            while (buffer.hasRemaining()) {
                int count = Math.min(buffer.remaining(), transfer.length);
                buffer.get(transfer, 0, count);
                write(transfer, 0, count);
            }
        }

        void write(byte[] data, int offset, int count) throws IOException {
            if (channels < 0) throw new IOException("PCM-Format vor Audiodaten fehlt.");
            if (count < 0 || bytes > MAX_RIFF_DATA_BYTES - count) throw new IOException("WAV-Export wäre größer als RIFF unterstützt.");
            output.write(data, offset, count);
            bytes += count;
        }

        void finish() throws IOException {
            if (channels < 0 || bytes == 0) throw new IOException("Keine PCM-Audiodaten für Export.");
            int blockAlign = channels * (bits / 8);
            int byteRate = sampleRate * blockAlign;
            output.seek(0);
            output.write("RIFF".getBytes(java.nio.charset.StandardCharsets.US_ASCII));
            writeLeInt(output, 36 + (int) bytes);
            output.write("WAVEfmt ".getBytes(java.nio.charset.StandardCharsets.US_ASCII));
            writeLeInt(output, 16);
            writeLeShort(output, 1);
            writeLeShort(output, channels);
            writeLeInt(output, sampleRate);
            writeLeInt(output, byteRate);
            writeLeShort(output, blockAlign);
            writeLeShort(output, bits);
            output.write("data".getBytes(java.nio.charset.StandardCharsets.US_ASCII));
            writeLeInt(output, (int) bytes);
        }

        @Override public void close() throws IOException { output.close(); }

        private static void writeLeShort(RandomAccessFile output, int value) throws IOException {
            output.write(value & 255); output.write((value >>> 8) & 255);
        }

        private static void writeLeInt(RandomAccessFile output, int value) throws IOException {
            output.write(value & 255); output.write((value >>> 8) & 255);
            output.write((value >>> 16) & 255); output.write((value >>> 24) & 255);
        }
    }
}
