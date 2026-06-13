import 'package:flutter/services.dart';

class VoiceNavigationService {
  static const MethodChannel _channel =
      MethodChannel('indoor_navigation/voice');

  Future<void> speak(String message) async {
    if (message.trim().isEmpty) return;

    try {
      await _channel.invokeMethod<void>('speak', message);
    } on PlatformException {
      // Voice guidance is optional on platforms without the native bridge.
    } on MissingPluginException {
      // Keeps desktop/web development builds usable.
    }
  }

  Future<void> stop() async {
    try {
      await _channel.invokeMethod<void>('stop');
    } on PlatformException {
      // Voice guidance is optional on platforms without the native bridge.
    } on MissingPluginException {
      // Keeps desktop/web development builds usable.
    }
  }
}
