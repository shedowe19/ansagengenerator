package de.shedowe.ansagengenerator;

import android.content.Context;
import android.content.res.AssetManager;

import java.io.File;
import java.io.FileOutputStream;
import java.io.IOException;
import java.io.InputStream;
import java.text.SimpleDateFormat;
import java.util.ArrayList;
import java.util.Date;
import java.util.List;
import java.util.Locale;

/** Flutter platform bridge for the immutable ZIP64 library from the Android source snapshot. */
final class OfflineAudioBridge {
    private static final String FLUTTER_ASSET_ROOT = "flutter_assets/source-android/app/src/main/assets/";
    private static final String[] BUNDLED_OFFLINE_ARCHIVES = {
            FLUTTER_ASSET_ROOT + "offline/ansagengenerator-offline-opus-data.zip"
    };

    private final Context context;
    private BundledZipLibrary library;

    OfflineAudioBridge(Context context) { this.context = context.getApplicationContext(); }

    synchronized List<String> resolveAudioPaths(List<String> relativePaths) throws IOException {
        ArrayList<String> result = new ArrayList<>();
        if (relativePaths == null) return result;
        for (String path : relativePaths) {
            String clean = clean(path);
            if (clean.length() == 0) throw new IOException("Ungültiger Audio-Pfad.");
            File file = path != null && path.startsWith("asset:/")
                    ? copyFlutterAsset(clean.substring("asset:/".length()))
                    : copyBundledAudio(clean);
            result.add(file.getAbsolutePath());
        }
        return result;
    }

    synchronized String exportWav(List<String> relativePaths) throws IOException {
        List<String> resolved = resolveAudioPaths(relativePaths);
        ArrayList<File> files = new ArrayList<>();
        for (String value : resolved) files.add(new File(value));
        File exports = new File(context.getExternalFilesDir(null), "exports");
        String stamp = new SimpleDateFormat("yyyyMMdd-HHmmss", Locale.ROOT).format(new Date());
        File destination = new File(exports, "ansage-" + stamp + ".wav");
        AudioWavExporter.exportToWav(files, destination);
        return destination.getAbsolutePath();
    }

    private File copyBundledAudio(String relativeWavPath) throws IOException {
        String opus = OfflineLibrarySupport.toBundledOpusPath(relativeWavPath);
        if (opus.length() == 0) throw new IOException("Ungültiger Archiv-Audio-Pfad: " + relativeWavPath);
        File root = new File(context.getCacheDir(), "bundled-offline-audio");
        File target = new File(root, opus);
        if (!OfflineLibrarySupport.isChildOf(root, target)) throw new IOException("Audio außerhalb Cache.");
        if (target.isFile()) return target;
        File parent = target.getParentFile();
        if (parent == null || (!parent.exists() && !parent.mkdirs())) throw new IOException("Audio-Cache kann nicht erstellt werden.");
        File temporary = new File(parent, target.getName() + ".part");
        try (InputStream input = library().openLibraryFile(opus); FileOutputStream output = new FileOutputStream(temporary)) {
            byte[] buffer = new byte[64 * 1024];
            int read;
            while ((read = input.read(buffer)) != -1) output.write(buffer, 0, read);
        }
        if (!temporary.renameTo(target)) {
            OfflineLibrarySupport.deleteRecursively(temporary);
            throw new IOException("Audio-Cache kann nicht aktiviert werden.");
        }
        return target;
    }

    private File copyFlutterAsset(String relativeAsset) throws IOException {
        String clean = clean(relativeAsset);
        if (clean.length() == 0) throw new IOException("Ungültiger Flutter-Asset-Pfad.");
        File root = new File(context.getCacheDir(), "flutter-audio-assets");
        File target = new File(root, clean);
        if (!OfflineLibrarySupport.isChildOf(root, target)) throw new IOException("Asset außerhalb Cache.");
        if (target.isFile()) return target;
        File parent = target.getParentFile();
        if (parent != null && !parent.exists() && !parent.mkdirs()) throw new IOException("Asset-Cache kann nicht erstellt werden.");
        try (InputStream input = context.getAssets().open(FLUTTER_ASSET_ROOT + clean); FileOutputStream output = new FileOutputStream(target)) {
            byte[] buffer = new byte[64 * 1024];
            int read;
            while ((read = input.read(buffer)) != -1) output.write(buffer, 0, read);
        }
        return target;
    }

    private BundledZipLibrary library() throws IOException {
        if (library == null) library = BundledZipLibrary.open(context.getAssets(), BUNDLED_OFFLINE_ARCHIVES);
        return library;
    }

    private static String clean(String raw) {
        if (raw == null) return "";
        String value = raw.replace('\\', '/').trim();
        while (value.startsWith("file://")) value = value.substring(7);
        while (value.startsWith("/")) value = value.substring(1);
        if (value.contains("..")) return "";
        return value;
    }
}
