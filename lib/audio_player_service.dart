import 'dart:async';

import 'package:flutter/services.dart';

class AudioPlayerService {
  static const MethodChannel _channel =
      const MethodChannel('audio_player_service');

  static Future<String> get platformVersion async {
    final String version = await _channel.invokeMethod('getPlatformVersion');
    return version;
  }
}
