import 'dart:async';

import 'package:audio_player_service/audio_player.dart';
import 'package:flutter/services.dart';

class AudioPlayerService {
  static const MethodChannel _channel =
      const MethodChannel('audio_player_service');

  static AudioPlayer audioPlayer() {
    return new AudioPlayer(
      channel: _channel,
    );
  }
}
