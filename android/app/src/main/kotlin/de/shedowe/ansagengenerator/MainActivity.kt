package de.shedowe.ansagengenerator

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val audioBridge by lazy { OfflineAudioBridge(applicationContext) }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "de.shedowe.ansagengenerator/audio")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "resolveAudioPaths", "exportWav" -> {
                        val paths = call.argument<List<String>>("paths") ?: emptyList()
                        Thread {
                            try {
                                val value: Any = if (call.method == "resolveAudioPaths") {
                                    audioBridge.resolveAudioPaths(paths)
                                } else {
                                    audioBridge.exportWav(paths)
                                }
                                runOnUiThread { result.success(value) }
                            } catch (error: Exception) {
                                runOnUiThread { result.error("AUDIO_ERROR", error.message, null) }
                            }
                        }.start()
                    }
                    else -> result.notImplemented()
                }
            }
    }
}
