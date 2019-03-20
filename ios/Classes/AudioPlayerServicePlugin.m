#import "AudioPlayerServicePlugin.h"

@implementation AudioPlayerServicePlugin{
  FlutterMethodChannel* _channel;
  AudioPlayer* _audioPlayer;
}

+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
  FlutterMethodChannel* channel = [FlutterMethodChannel
      methodChannelWithName:@"audio_player_service"
            binaryMessenger:[registrar messenger]];
  AudioPlayerServicePlugin* instance = [[AudioPlayerServicePlugin alloc] initWithChannel: channel];
  [registrar addMethodCallDelegate:instance channel:channel];
}

- (id)initWithChannel:(FlutterMethodChannel*)channel {
  if (self = [super init]) {
    _channel = channel;
    
    _audioPlayer = [[AudioPlayer alloc] init];
    [_audioPlayer addListener:self];
  }
  return self;
}

- (void)handleMethodCall:(FlutterMethodCall*)call result:(FlutterResult)result {
  
  if ([@"initPlayerQueue" isEqualToString:call.method]) {
    
    NSDictionary* args = call.arguments;

    NSLog(@"platform: initPlayerQueue items: %@", [args objectForKey:@"items"]);

    [_audioPlayer playerStop];
    [_audioPlayer initPlayerQueue: [args objectForKey:@"items"]];

    result(nil);
  
  } else if ([@"play" isEqualToString:call.method]) {
    
    NSLog(@"platform: play");

    [_audioPlayer playerPlayPause];

    result(nil);
  
  } else if ([@"pause" isEqualToString:call.method]) {
    
    NSLog(@"platform: pause");

    [_audioPlayer playerPlayPause];

    result(nil);
  
  } else if ([@"stop" isEqualToString:call.method]) {
    
    NSLog(@"platform: stop");

    [_audioPlayer playerStop];

    result(nil);
  
  } else if ([@"next" isEqualToString:call.method]) {
    
    NSLog(@"platform: next");

    [_audioPlayer playerNext];

    result(nil);
  
  } else if ([@"prev" isEqualToString:call.method]) {
    
    NSLog(@"platform: prev");

    [_audioPlayer playerPrevious];

    result(nil);
  
  } else if ([@"seek" isEqualToString:call.method]) {
    
    NSDictionary* args = call.arguments;

    NSLog(@"platform: seek args: %@", args);

    result(nil);
  
  } else if ([@"setIndex" isEqualToString:call.method]) {
    
    NSDictionary* args = call.arguments;

    NSLog(@"platform: setIndex args: %@", args);

    result(nil);
  
  } else {
  
    result(FlutterMethodNotImplemented);
  
  }

}

# pragma mark AudioPlayerListener
//----------- AudioPlayerListener -----------
- (void) onAudioLoading {
  NSLog(@"onAudioLoading");
  [_channel invokeMethod:@"onAudioLoading" arguments:nil];
}

- (void) onBufferingUpdate:(int) percent {
  NSLog(@"onBufferingUpdate: %i", percent);
  NSMutableDictionary* args = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                        [NSNumber numberWithInt:percent], @"percent",
                        nil];
  [_channel invokeMethod:@"onBufferingUpdate" arguments:args];
}

- (void) onAudioReady:(long) audioLengthInMillis {
  NSLog(@"onAudioReady");
  NSMutableDictionary* args = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                        [NSNumber numberWithLong:audioLengthInMillis], @"audioLength",
                        nil];
  [_channel invokeMethod:@"onAudioReady" arguments:args];
}

- (void) onPlayerPlaying {
  NSLog(@"onPlayerPlaying");
  [_channel invokeMethod:@"onPlayerPlaying" arguments:nil];
}

- (void) onFailedPrepare {
  NSLog(@"onFailedPrepare");
  [_channel invokeMethod:@"onFailedPrepare" arguments:nil];
}

- (void) onPlayerPlaybackUpdate:(NSNumber*)position :(long)audioLength {
  NSLog(@"onPlayerPlaybackUpdate - position: %@", position);
  NSMutableDictionary* args = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                        position, @"position",
                        [NSNumber numberWithLong:audioLength], @"audioLength",
                        nil];
  [_channel invokeMethod:@"onPlayerPlaybackUpdate" arguments:args];
}

- (void) onPlayerPaused {
  NSLog(@"onPlayerPaused");
  [_channel invokeMethod:@"onPlayerPaused" arguments:nil];
}

- (void) onPlayerStopped {
  NSLog(@"onPlayerStopped");
  [_channel invokeMethod:@"onPlayerStopped" arguments:nil];
}

- (void) onPlayerCompleted {
  NSLog(@"onPlayerCompleted");
  [_channel invokeMethod:@"onPlayerCompleted" arguments:nil];
}

- (void) onSeekStarted {
  NSLog(@"onSeekStarted");
  [_channel invokeMethod:@"onSeekStarted" arguments:nil];
}

- (void) onSeekCompleted:(long) position {
  NSLog(@"onSeekCompleted");
  NSMutableDictionary* args = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                        [NSNumber numberWithLong:position], @"position",
                        nil];
  [_channel invokeMethod:@"onSeekCompleted" arguments:args];
}

// play next track started
- (void) onNextStarted: (int) index{
  NSLog(@"onNextStarted: index %d", index);
  NSMutableDictionary* args = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                        [NSNumber numberWithInt:index], @"index",
                        nil];
  [_channel invokeMethod:@"onNextStarted" arguments:args];
}

// play next track completed
- (void) onNextCompleted: (int) index{
  NSLog(@"onNextCompleted: index %d", index);
  NSMutableDictionary* args = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                        [NSNumber numberWithInt:index], @"index",
                        nil];
  [_channel invokeMethod:@"onNextCompleted" arguments:args];
}

// play previous track started
- (void) onPreviousStarted: (int) index{
  NSLog(@"onPreviousStarted: index %d", index);
  NSMutableDictionary* args = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                        [NSNumber numberWithInt:index], @"index",
                        nil];
  [_channel invokeMethod:@"onPreviousStarted" arguments:args];
}

// play previous track completed
- (void) onPreviousCompleted: (int) index{
  NSLog(@"onPreviousCompleted: index %d", index);
  NSMutableDictionary* args = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                        [NSNumber numberWithInt:index], @"index",
                        nil];
  [_channel invokeMethod:@"onPreviousCompleted" arguments:args];
}

// play previous track completed
- (void) onIndexChangedExternally: (int) index{
  NSLog(@"onIndexChangedExternally: index %d", index);
  NSMutableDictionary* args = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                        [NSNumber numberWithInt:index], @"index",
                        nil];
  [_channel invokeMethod:@"onIndexChangedExternally" arguments:args];
}

//---------- End AudioPlayerListener ---------

@end
