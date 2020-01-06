//
//  AudioPlayer.h
//  AudioTest
//
//  Created by Alex Paguis on 2019-03-20.
//  Copyright © 2019 Alex Paguis. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import <MediaPlayer/MediaPlayer.h>

NS_ASSUME_NONNULL_BEGIN

@protocol AudioPlayerListener;

@interface AudioPlayer : NSObject
+ (id)sharedManager;

- (void) initPlayerQueue: (NSArray*)items;
- (MPRemoteCommandHandlerStatus) playerPlayPause;
- (MPRemoteCommandHandlerStatus) playerStop;
- (MPRemoteCommandHandlerStatus) playerSeek: (NSNumber*) seconds;

- (MPRemoteCommandHandlerStatus) playerNext;
- (MPRemoteCommandHandlerStatus) playerPrevious;
- (void) setPlayerIndex: (int) itemIndex;

- (void) addListener:(id <AudioPlayerListener>) listener;
- (void) removeListener:(id <AudioPlayerListener>) listener;

@end

@protocol AudioPlayerListener

// An audio stream/clip just started being loaded.
- (void) onAudioLoading;

// An audio stream/clip has buffered to the given percent.
- (void) onBufferingUpdate:(int) percent;

// An audio stream/clip has been loaded to the point that it can be played.
// Immediately after this call listeners will be notified of either
// onPlayerPlaying or onPlayerPaused depending on what the state was prior
// to loading the audio.
- (void) onAudioReady:(long) audioLength;

// failed to load audio item
- (void) onFailedPrepare;

// An audio stream/clip has started to play (this could be from the paused
// state or immediately after onAudioReady).
- (void) onPlayerPlaying;

// An audio stream/clip has progressed forward to the given playhead position.
- (void) onPlayerPlaybackUpdate:(NSNumber*)position :(long)audioLength;

// An audio stream/clip has paused (this could be from the playing state or
// immediately after onAudioReady).
- (void) onPlayerPaused;

// An audio stream/clip has stopped which means playback has ceased AND the
// audio has been released. To start playing again, the caller must load a
// new audio stream/clip.
- (void) onPlayerStopped;

// An audio stream/clip has reached its end.  Playback has ceased.
- (void) onPlayerCompleted;

// A seek operation has begun.
- (void) onSeekStarted;

// play next track started
- (void) onNextStarted: (int) index;

// play next track completed
- (void) onNextCompleted: (int) index;

// play previous track started
- (void) onPreviousStarted: (int) index;

// play previous track completed
- (void) onPreviousCompleted: (int) index;

// index changed outside the app
- (void) onIndexChangedExternally: (int) index;

// A seek operation has completed.
- (void) onSeekCompleted:(long)position;

// Send messages for debugging
- (void) onDebugMessage:(NSString*)message;

@end

NS_ASSUME_NONNULL_END
