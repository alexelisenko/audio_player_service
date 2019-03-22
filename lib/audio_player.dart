import 'dart:ui' show VoidCallback;

import 'package:flutter/services.dart';
import 'package:logging/logging.dart';

final _log = new Logger('AudioPlayer');

class AudioPlayer {
  final MethodChannel channel;

  final Set<AudioPlayerListener> _listeners = Set();

  AudioPlayerState _state;
  Duration _audioLength;
  Duration _position;
  bool _isChangingItem;
  bool _queueInitialized = false;
  List<AudioPlayerItem> playerItems;
  int currentIndex = 0;
  bool invokeListeners = true;

  AudioPlayer({
    this.channel,
  }) {
    
    _log.fine('AudioPlayer init');

    _setState(AudioPlayerState.idle);

    channel.setMethodCallHandler((MethodCall call) {
      _log.fine('plugin: Received channel message: ${call.method}');
      switch (call.method) {
        case "onAudioLoading":
          _log.fine('plugin: onAudioLoading');

          // If new audio is loading then we have no playhead position and we
          // don't know the audio length.
          _setAudioLength(null);
          _setPosition(null);

          _setState(AudioPlayerState.loading);

          if(invokeListeners){
            for (AudioPlayerListener listener in _listeners) {
              listener.onAudioLoading();
            }
          }
          break;
        case "onBufferingUpdate":
          _log.fine('plugin: onBufferingUpdate');
          break;
        case "onAudioReady":
          _log.fine('plugin: onAudioReady, audioLength: ${call.arguments['audioLength']}');

          // When audio is ready then we get passed the length of the clip.
          final audioLengthInMillis = call.arguments['audioLength'];
          _setAudioLength(new Duration(milliseconds: audioLengthInMillis));

          // When audio is ready then the playhead is at zero.
          _setPosition(const Duration(milliseconds: 0));
          if(invokeListeners){
            for (AudioPlayerListener listener in _listeners) {
              listener.onAudioReady();
            }
          }
          break;
        case "onPlayerPlaying":
          _log.fine('plugin:onPlayerPlaying');

          _setState(AudioPlayerState.playing);

          if(invokeListeners) {
            for (AudioPlayerListener listener in _listeners) {
              listener.onPlayerPlaying();
            }
          }
          break;
        case "onPlayerPlaybackUpdate":
          _log.fine('plugin: onPlayerPlaybackUpdate, position: ${call.arguments['position']}');
          // The playhead has moved, update our playhead position reference.
          _setPosition(new Duration(seconds: call.arguments['position']));
          break;
        case "onPlayerPaused":
          _log.fine('plugin: onPlayerPaused');

          _setState(AudioPlayerState.paused);

          if(invokeListeners) {
            for (AudioPlayerListener listener in _listeners) {
              listener.onPlayerPaused();
            }
          }
          break;
        case "onPlayerStopped":
          _log.fine('plugin: onPlayerStopped');

          _setAudioLength(null);
          _setPosition(null);

          _setState(AudioPlayerState.stopped);

          if(invokeListeners) {
            for (AudioPlayerListener listener in _listeners) {
              listener.onPlayerStopped();
            }
          }
          break;
        case "onPlayerCompleted":
          _log.fine('plugin: onPlayerCompleted');

          _setState(AudioPlayerState.completed);

          if(invokeListeners) {
            for (AudioPlayerListener listener in _listeners) {
              listener.onPlayerCompleted();
            }
          }
          break;
        case "onSeekStarted":
          _log.fine('plugin: onSeekStarted, not implemented');
          break;
        case "onSeekCompleted":
          _log.fine('plugin: onSeekCompleted, position: ${call.arguments['position']}');
          _setPosition(new Duration(seconds: call.arguments['position']));
          if(invokeListeners) {
            for (AudioPlayerListener listener in _listeners) {
              listener.onSeekCompleted(call.arguments['position']);
            }
          }
          break;
        case "onNextStarted":
          _log.fine('plugin: onNextStarted, index: ${call.arguments['index']}');
          if(invokeListeners) {
            for (AudioPlayerListener listener in _listeners) {
              listener.onNextStarted(call.arguments['index']);
            }
          }
          break;
        case "onNextCompleted":
          _log.fine('plugin: onNextCompleted, index: ${call.arguments['index']}');
          if(invokeListeners) {
            for (AudioPlayerListener listener in _listeners) {
              listener.onNextCompleted(call.arguments['index']);
            }
          }
          break;
        case "onPreviousStarted":
          _log.fine('plugin: onPreviousStarted, index: ${call.arguments['index']}');
          if(invokeListeners) {
            for (AudioPlayerListener listener in _listeners) {
              listener.onPreviousStarted(call.arguments['index']);
            }
          }
          break;
        case "onPreviousCompleted":
          _log.fine('plugin: onPreviousCompleted, index: ${call.arguments['index']}');
          if(invokeListeners) {
            for (AudioPlayerListener listener in _listeners) {
              listener.onPreviousCompleted(call.arguments['index']);
            }
          }
          break;
        case "onIndexChangedExternally":
          _log.fine('plugin: onIndexChangedExternally, index: ${call.arguments['index']}');
          if(invokeListeners) {
            for (AudioPlayerListener listener in _listeners) {
              listener.onIndexChangedExternally(call.arguments['index']);
            }
          }
          break;
      }
    });

  }

  void dispose() {
    _listeners.clear();
  }

  AudioPlayerState get state => _state;

  _setState(AudioPlayerState state) {
    _state = state;
    if(invokeListeners) {
      for (AudioPlayerListener listener in _listeners) {
        listener.onAudioStateChanged(state);
      }
    }
  }

  //This is set when moving from one item to another via next or prev methods
  bool get isChangingItem => _isChangingItem;

  //This is set to true once a queue of player items have been supplied
  bool get queueInitialized => _queueInitialized;

  /// Length of the loaded audio clip.
  ///
  /// Accessing [audioLength] is only valid after the [AudioPlayer] has loaded
  /// an audio clip and before the [AudioPlayer] is stopped.
  Duration get audioLength => _audioLength;

  _setAudioLength(Duration audioLength) {
    _audioLength = audioLength;

    if(invokeListeners) {
      for (AudioPlayerListener listener in _listeners) {
        listener.onAudioLengthChanged(_audioLength);
      }
    }
  }

  /// Current playhead position of the [AudioPlayer].
  ///
  /// Accessing [position] is only valid after the [AudioPlayer] has loaded
  /// an audio clip and before the [AudioPlayer] is stopped.
  Duration get position => _position;

  _setPosition(Duration position) {
    _position = position;

    if(invokeListeners) {
      for (AudioPlayerListener listener in _listeners) {
        listener.onPlayerPositionChanged(position);
      }
    }
  }

  void addListener(AudioPlayerListener listener) {
    _listeners.add(listener);
  }

  void removeListener(AudioPlayerListener listener) {
    _listeners.remove(listener);
  }

  Future<void> removeAllListeners() async {
    invokeListeners = false;
    _log.fine("removing all listeners");
    _listeners.clear();
    _log.fine("_listeners ${_listeners}");
    invokeListeners = true;
  }

  Future<void> initPlayerQueue(List<AudioPlayerItem> newItems) async {
    _log.fine('initPlayerQueue()');
    this.playerItems = newItems;
    List<Map<String, dynamic>> items = playerItems.map((item) => item.toMap()).toList();

    await channel.invokeMethod(
      'initPlayerQueue',
      {'items': items},
    );

    _queueInitialized = true;
  }

  Future<void> setIndex(int index) async {
    _log.fine('setIndex() $index');
    await channel.invokeMethod(
      'setIndex',
      {'index': index},
    );
    currentIndex = index;
  }

  void play() {
    _log.fine('play()');
    channel.invokeMethod('play');

  }

  void next() {
    _log.fine('next()');
    channel.invokeMethod('next');
  }

  void prev() {
    _log.fine('prev()');
    channel.invokeMethod('prev');
  }

  void pause() {
    _log.fine('pause()');
    channel.invokeMethod('pause');
  }

  void seek(Duration duration) {
    _log.fine('seek(): $duration');
    channel.invokeMethod(
      'seek',
      {
        'seekPosition': duration.inSeconds,
      },
    );
  }

  void stop() {
    _log.fine('stop()');
    channel.invokeMethod('stop');
  }
}

class AudioPlayerListener {
  AudioPlayerListener({
    Function(AudioPlayerState) onAudioStateChanged,
    VoidCallback onAudioLoading,
    VoidCallback onAudioReady,
    Function(Duration) onAudioLengthChanged,
    Function(Duration) onPlayerPositionChanged,
    VoidCallback onPlayerPlaying,
    VoidCallback onPlayerPaused,
    VoidCallback onPlayerStopped,
    VoidCallback onPlayerCompleted,
    VoidCallback onSeekStarted,
    Function(int) onSeekCompleted,
    Function(int) onNextStarted,
    Function(int) onNextCompleted,
    Function(int) onPreviousStarted,
    Function(int) onPreviousCompleted,
    Function(int) onIndexChangedExternally,
  })  : _onAudioStateChanged = onAudioStateChanged,
        _onAudioLoading = onAudioLoading,
        _onAudioReady = onAudioReady,
        _onAudioLengthChanged = onAudioLengthChanged,
        _onPlayerPositionChanged = onPlayerPositionChanged,
        _onPlayerPlaying = onPlayerPlaying,
        _onPlayerPaused = onPlayerPaused,
        _onPlayerStopped = onPlayerStopped,
        _onPlayerCompleted = onPlayerCompleted,
        _onSeekStarted = onSeekStarted,
        _onSeekCompleted = onSeekCompleted,
        _onNextStarted = onNextStarted,
        _onNextCompleted = onNextCompleted,
        _onPreviousStarted = onPreviousStarted,
        _onPreviousCompleted = onPreviousCompleted,
        _onIndexChangedExternally = onIndexChangedExternally;

  final Function(AudioPlayerState) _onAudioStateChanged;
  final VoidCallback _onAudioLoading;
  final VoidCallback _onAudioReady;
  final Function(Duration) _onAudioLengthChanged;
  final Function(Duration) _onPlayerPositionChanged;
  final VoidCallback _onPlayerPlaying;
  final VoidCallback _onPlayerPaused;
  final VoidCallback _onPlayerStopped;
  final VoidCallback _onPlayerCompleted;
  final VoidCallback _onSeekStarted;
  final Function(int) _onSeekCompleted;
  final Function(int) _onNextStarted;
  final Function(int) _onNextCompleted;
  final Function(int) _onPreviousStarted;
  final Function(int) _onPreviousCompleted;
  final Function(int) _onIndexChangedExternally;

  onAudioStateChanged(AudioPlayerState audioState) {
    if (_onAudioStateChanged != null) {
      _onAudioStateChanged(audioState);
    }
  }

  onAudioLoading() {
    if (_onAudioLoading != null) {
      _onAudioLoading();
    }
  }

  onAudioReady() {
    if (_onAudioReady != null) {
      _onAudioReady();
    }
  }

  onAudioLengthChanged(Duration length) {
    if (_onAudioLengthChanged != null) {
      _onAudioLengthChanged(length);
    }
  }

  onPlayerPositionChanged(Duration position) {
    if (_onPlayerPositionChanged != null) {
      _onPlayerPositionChanged(position);
    }
  }

  onPlayerPlaying() {
    if (_onPlayerPlaying != null) {
      _onPlayerPlaying();
    }
  }

  onPlayerPaused() {
    if (_onPlayerPaused != null) {
      _onPlayerPaused();
    }
  }

  onPlayerStopped() {
    if (_onPlayerStopped != null) {
      _onPlayerStopped();
    }
  }

  onPlayerCompleted() {
    if (_onPlayerCompleted != null) {
      _onPlayerCompleted();
    }
  }

  onSeekStarted() {
    if (_onSeekStarted != null) {
      _onSeekStarted();
    }
  }

  onSeekCompleted(int position) {
    if (_onSeekCompleted != null) {
      _onSeekCompleted(position);
    }
  }

  onNextStarted(int index) {
    if (_onNextStarted != null) {
      _onNextStarted(index);
    }
  }

  onNextCompleted(int index) {
    if (_onNextCompleted != null) {
      _onNextCompleted(index);
    }
  }
  
  onPreviousStarted (int index) {
    if (_onPreviousStarted != null) {
      _onPreviousStarted(index);
    }
  }

  onPreviousCompleted(int index) {
    if (_onPreviousCompleted != null) {
      _onPreviousCompleted(index);
    }
  }

  onIndexChangedExternally(int index) {
    if (_onIndexChangedExternally != null) {
      _onIndexChangedExternally(index);
    }
  }

}

enum AudioPlayerState {
  idle,
  loading,
  playing,
  paused,
  stopped,
  completed,
}

class AudioPlayerItem{
  String id;
  String url;
  String thumbUrl;
  String title;
  Duration duration;
  String album;
  bool local;

  AudioPlayerItem({
    this.id,
    this.url,
    this.thumbUrl,
    this.title,
    this.duration,
    this.album,
    this.local
  });

  Map<String, dynamic> toMap(){
    return {
      'id': this.id,
      'url': this.url,
      'thumb': this.thumbUrl,
      'title': this.title,
      'duration': this.duration.inSeconds,
      'album': this.album,
      'local': this.local
    };
  }

}
