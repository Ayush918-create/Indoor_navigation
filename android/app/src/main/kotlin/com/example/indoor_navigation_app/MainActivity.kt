package com.example.indoor_navigation_app

import android.speech.tts.TextToSpeech
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.Locale

class MainActivity : FlutterActivity(), TextToSpeech.OnInitListener {
    private val channelName = "indoor_navigation/voice"
    private var textToSpeech: TextToSpeech? = null
    private var ttsReady = false

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        textToSpeech = TextToSpeech(this, this)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            channelName
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "speak" -> {
                    speak(call.arguments as? String ?: "")
                    result.success(null)
                }
                "stop" -> {
                    textToSpeech?.stop()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onInit(status: Int) {
        if (status == TextToSpeech.SUCCESS) {
            textToSpeech?.language = Locale.US
            ttsReady = true
        }
    }

    private fun speak(message: String) {
        if (!ttsReady || message.isBlank()) return

        textToSpeech?.speak(
            message,
            TextToSpeech.QUEUE_FLUSH,
            null,
            "indoor-navigation-instruction"
        )
    }

    override fun onDestroy() {
        textToSpeech?.stop()
        textToSpeech?.shutdown()
        super.onDestroy()
    }
}
