//
//  AudioPlayer.m
//  AudioTest
//
//  Created by Alex Paguis on 2019-03-20.
//  Copyright © 2019 Alex Paguis. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "AudioPlayer.h"
#import <AVFoundation/AVFoundation.h>
#import <MediaPlayer/MediaPlayer.h>

@interface AudioPlayer ()

@property (strong, nonatomic) AVQueuePlayer *player;
@property (strong, nonatomic) NSArray *items;
@property (strong, nonatomic) NSMutableArray<AVPlayerItem*> *playerItems;
@property (strong, nonatomic) NSNumber *playerPosition;
@property (readonly) bool isPlaying;
@property (readonly) bool isCompleted;

@property int itemIndex;
@property BOOL ready;

@end

@implementation AudioPlayer{
    id _periodicListener;
    NSMutableSet* _listeners;
}

+ (id)sharedManager {
    static AudioPlayer *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[self alloc] init];
    });
    return instance;
}

-  (instancetype)init {
    if (self = [super init]) {

        //setup audio session for background play
        NSError *AVSessionCategoryError;
        [[AVAudioSession sharedInstance] setCategory: AVAudioSessionCategoryPlayback error:&AVSessionCategoryError];

        //active the session
        NSError *AVSessionActiveError;
        [[AVAudioSession sharedInstance] setActive: YES error:&AVSessionActiveError];

        //setup control center and lock screen controls
        MPRemoteCommandCenter *commandCenter = [MPRemoteCommandCenter sharedCommandCenter];
        [commandCenter.togglePlayPauseCommand setEnabled:YES];
        [commandCenter.playCommand setEnabled:YES];
        [commandCenter.pauseCommand setEnabled:YES];
        [commandCenter.stopCommand setEnabled:YES];
        [commandCenter.nextTrackCommand setEnabled:YES];
        [commandCenter.previousTrackCommand setEnabled:YES];
        [commandCenter.changePlaybackRateCommand setEnabled:YES];

        [commandCenter.togglePlayPauseCommand addTarget:self action:@selector(playerPlayPause)];
        [commandCenter.playCommand addTarget:self action:@selector(playerPlayPause)];
        [commandCenter.pauseCommand addTarget:self action:@selector(playerPlayPause)];
        [commandCenter.stopCommand addTarget:self action:@selector(playerStop)];
        [commandCenter.nextTrackCommand addTarget:self action:@selector(playerNext)];
        [commandCenter.previousTrackCommand addTarget:self action:@selector(playerPrevious)];
        [commandCenter.changePlaybackPositionCommand addTarget:self action:@selector(playerPlaybackChanged:)];

        //Unused options
        [commandCenter.skipForwardCommand setEnabled:NO];
        [commandCenter.skipBackwardCommand setEnabled:NO];
        [commandCenter.enableLanguageOptionCommand setEnabled:NO];
        [commandCenter.disableLanguageOptionCommand setEnabled:NO];
        [commandCenter.changeRepeatModeCommand setEnabled:NO];
        [commandCenter.seekForwardCommand setEnabled:NO];
        [commandCenter.seekBackwardCommand setEnabled:NO];
        [commandCenter.changeShuffleModeCommand setEnabled:NO];

        // Rating Command
        [commandCenter.ratingCommand setEnabled:NO];

        // Feedback Commands
        // These are generalized to three distinct actions. Your application can provide
        // additional context about these actions with the localizedTitle property in
        // MPFeedbackCommand.
        [commandCenter.likeCommand setEnabled:NO];
        [commandCenter.dislikeCommand setEnabled:NO];
        [commandCenter.bookmarkCommand setEnabled:NO];

        //set the index to 0
        _itemIndex = 0;
        _ready = NO;
        _playerItems = [[NSMutableArray alloc] init];
        _listeners = [[NSMutableSet alloc] init];

    }
    return self;
}

- (void)deinit {
    [_player removeTimeObserver:_periodicListener];
    [_player removeObserver:self forKeyPath:@"status"];
    [_player removeObserver:self forKeyPath:@"rate"];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:AVPlayerItemDidPlayToEndTimeNotification object:_player.currentItem];
}

- (void) sendPlatformDebugMessage: (NSString*) message {

    @try{
        for (id<AudioPlayerListener> listener in [_listeners allObjects]) {
            [listener onDebugMessage: message];
        }
    }@catch(NSException * e){}

}

- (void) deinitPlayerQueue{

    @try {

        [[NSNotificationCenter defaultCenter] removeObserver:self name:AVPlayerItemDidPlayToEndTimeNotification object:_player.currentItem];
        [_player replaceCurrentItemWithPlayerItem:nil];
        [MPNowPlayingInfoCenter defaultCenter].nowPlayingInfo = nil;

        [_player removeTimeObserver:_periodicListener];

        [_player removeObserver:self forKeyPath:@"status"];
        [_player removeObserver:self forKeyPath:@"rate"];

        [_player removeAllItems];
        _player = nil;

    }
    @catch (NSException * e) {
        [self sendPlatformDebugMessage:[NSString stringWithFormat:@"deinitPlayerQueue Exception: %@", e]];
    }
    @finally {
    }

}

- (void) initPlayerQueue: (NSArray*)items{

    //[self deinitPlayerQueue];

    @try{

        [self sendPlatformDebugMessage:[NSString stringWithFormat:@"initPlayerQueue start: %@", items]];

        _items = items;
        _playerItems = [[NSMutableArray alloc] init];

        //set player items, we only need the URL
        for (NSDictionary* item in _items) {

            AVPlayerItem* playerItem;

            NSURL *url = [[NSURL alloc] initWithString: [item objectForKey:@"url"]];

            if([[item objectForKey:@"local"] intValue] == 1){

                NSLog(@"initPlayerqueue local asset");
                AVAsset *asset = [AVURLAsset URLAssetWithURL:url options:nil];
                playerItem = [AVPlayerItem playerItemWithAsset:asset];

            }else{

                NSLog(@"initPlayerqueue remote asset");
                playerItem = [[AVPlayerItem alloc] initWithURL:url];

            }

            [_playerItems addObject:playerItem];

            //edit thumbs right away
            NSString* itemThumb = [item objectForKey:@"thumb"];

            if(itemThumb != (id)[NSNull null]) {
                NSURL *thumbUrl = [[NSURL alloc] initWithString: itemThumb];
                NSData *data = [NSData dataWithContentsOfURL: thumbUrl];
                UIImage *artwork = [[UIImage alloc] initWithData:data];
                [item setValue:[self resizeImageWithImage:artwork scaledToSize:CGSizeMake(600, 600)] forKey:@"thumb_image"];
            }
        }
        if(_player == nil){

            _player = [[AVQueuePlayer alloc] initWithItems:_playerItems];

            //get audio state and call listeners
            [_player addObserver:self forKeyPath:@"status" options:0 context:nil];
            [_player addObserver:self forKeyPath:@"rate" options:0 context:nil];

            _playerPosition = [NSNumber numberWithInt:0];

            //use weak self to avoid retain cycle
            __unsafe_unretained typeof(self) weakSelf = self;

            //set listener to pull playback position
            _periodicListener = [_player addPeriodicTimeObserverForInterval:CMTimeMakeWithSeconds(1.0, NSEC_PER_SEC) queue:NULL usingBlock:^(CMTime time) {
                @try{
                    weakSelf->_playerPosition = [NSNumber numberWithInt:[weakSelf playbackPosition]/1000];
                    for (id<AudioPlayerListener> listener in [weakSelf->_listeners allObjects]) {
                        [listener onPlayerPlaybackUpdate:weakSelf->_playerPosition :[weakSelf audioLength]];
                    }
                    [weakSelf setPlaybackStatusInfo];
                }@catch(NSException * e){}
            }];

        }

    }@catch (NSException * e) {
        [self sendPlatformDebugMessage:[NSString stringWithFormat:@"initPlayerQueue Exception: %@", e]];
    }
    @finally {
    }

    NSLog(@"initPlayerQueue done");

}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSKeyValueChangeKey,id> *)change context:(void *)context {
    [self sendPlatformDebugMessage:[NSString stringWithFormat:@"observeValueForKeyPath keyPath: %@", keyPath]];
    [self sendPlatformDebugMessage:[NSString stringWithFormat:@"observeValueForKeyPath object: %@", object]];
    if ([keyPath isEqualToString:@"status"]) {
        if (_player.status == AVPlayerStatusReadyToPlay) {
            // Note: we look for the AVPlayerItem's status ready rather than the AVPlayer because this
            // way we know that the duration will be available.
            [self _onAudioReady];
        } else if (_player.status == AVPlayerStatusFailed) {
            [self _onFailedToPrepareAudio];
        }
    } else if ([keyPath isEqualToString:@"rate"]) {
        [self _onPlaybackRateChange];
    }
}

- (void) initPlayerItem{

    @try{

        _ready = NO;
        _isPlaying = NO;
        _isCompleted = NO;

        int itemIndex = (int) _itemIndex;

        NSLog(@"initPlayerItem with index: %d", itemIndex);

        //AVPlayerItem * item = [_playerItems objectAtIndex:itemIndex];

        //NSLog(@"initPlayerItem AVPlayerItem: %@", item);

        NSLog(@"initPlayerItem item: %@", [_items objectAtIndex:itemIndex]);

        [self sendPlatformDebugMessage:[NSString stringWithFormat:@"initPlayerItem  item: %@", [_items objectAtIndex:itemIndex]]];

        NSString* itemTitle = [[_items objectAtIndex:itemIndex] objectForKey:@"title"];
        NSString* itemAlbum = [[_items objectAtIndex:itemIndex] objectForKey:@"album"];
        NSString* itemThumb = [[_items objectAtIndex:itemIndex] objectForKey:@"thumb"];

        MPMediaItemArtwork* ControlArtwork;

        if(itemThumb != (id)[NSNull null]) {
            ControlArtwork = [[MPMediaItemArtwork alloc] initWithBoundsSize:CGSizeMake(600, 600) requestHandler:^UIImage * _Nonnull(CGSize size) {
                return [[_items objectAtIndex:itemIndex] objectForKey:@"thumb_image"];
            }];
        }

        NSLog(@"playing file: %@", [[_items objectAtIndex:itemIndex] objectForKey:@"url"]);

        // TODO: Fix this
        // This does not seem to work well for audio accessories/bluetooth devices.
        // Its not broken, but the current index/ total supplied to devices is incorrect
        BOOL itemInserted = NO;
        [_player removeAllItems];
        [self sendPlatformDebugMessage:[NSString stringWithFormat:@"initPlayerItem insert Items loop"]];
        for (int i = itemIndex; i <_items.count; i ++) {
            AVPlayerItem * new_item = [_playerItems objectAtIndex:i];
            if ([_player canInsertItem:new_item afterItem:nil]) {
                [new_item seekToTime:kCMTimeZero completionHandler:nil];
                [_player insertItem:new_item afterItem:nil];
                itemInserted = YES;
            }
        }

        if(itemInserted){

            NSNumber* itemDefinedDuration = [[_items objectAtIndex:itemIndex] objectForKey:@"duration"];
            NSNumber* duration = itemDefinedDuration != (id)[NSNull null] ? itemDefinedDuration : [self currentItemDuration];

            NSMutableDictionary *nowPlayingInfo = [NSMutableDictionary new];

            nowPlayingInfo[MPMediaItemPropertyTitle] = itemTitle;
            nowPlayingInfo[MPMediaItemPropertyAlbumTitle] = itemAlbum;
            nowPlayingInfo[MPMediaItemPropertyPlaybackDuration] = duration;
            nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = [NSNumber numberWithDouble:1.0];

            if(ControlArtwork != nil) {
                    nowPlayingInfo[MPMediaItemPropertyArtwork] = ControlArtwork;
                }

            [MPNowPlayingInfoCenter defaultCenter].nowPlayingInfo = nowPlayingInfo;

            [self sendPlatformDebugMessage:[NSString stringWithFormat:@"initPlayerItem itemInserted"]];

            [self _onAudioReady];

        }else{

            [self _onFailedToPrepareAudio];

        }
    }@catch (NSException * e) {
        [self sendPlatformDebugMessage:[NSString stringWithFormat:@"initPlayerItem Exception: %@", e]];
    }
    @finally {
    }

}

- (UIImage *)resizeImageWithImage:(UIImage *)image scaledToSize:(CGSize)newSize {
    // UIGraphicsBeginImageContext(newSize);
    // In next line, pass 0.0 to use the current device's pixel scaling factor (and thus account for Retina resolution).
    // Pass 1.0 to force exact pixel size.
    UIGraphicsBeginImageContextWithOptions(newSize, NO, 0.0);
    [image drawInRect:CGRectMake(0, 0, newSize.width, newSize.height)];
    UIImage *newImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return newImage;
}

- (long) audioLength {
    if (_player.currentItem != nil) {
        NSNumber* itemDefinedDuration = [[_items objectAtIndex:_itemIndex] objectForKey:@"duration"];
        NSNumber* duration = itemDefinedDuration != (id)[NSNull null] ? itemDefinedDuration : [self currentItemDuration];

        long millis = [duration intValue] * 1000;
        return millis;
    } else {
        return 0;
    }
}

- (NSNumber*) currentItemDuration {
    CMTime duration = _player.currentItem.asset.duration;
    float seconds = CMTimeGetSeconds(duration);
    return @(seconds);
}

- (int) playbackPosition {
    if (_player.currentItem != nil) {
        return CMTimeGetSeconds([_player.currentItem currentTime]) * 1000;
    } else {
        return 0;
    }
}

- (void) addListener:(id <AudioPlayerListener>) listener {
    NSLog(@"Adding listener: %@", listener);
    [_listeners addObject:listener];
    NSLog(@"added listeners: %@", _listeners);
}

# pragma mark player commands

- (void) setPlaybackStatusInfo{

     int itemIndex = (int) _itemIndex;

     NSLog(@"setPlaybackStatusInfo item: %@", [_items objectAtIndex:itemIndex]);

     @try{


           NSString* itemTitle = [[_items objectAtIndex:itemIndex] objectForKey:@"title"];
           NSString* itemAlbum = [[_items objectAtIndex:itemIndex] objectForKey:@"album"];
           NSString* itemThumb = [[_items objectAtIndex:itemIndex] objectForKey:@"thumb"];

           MPMediaItemArtwork* ControlArtwork;

           if(itemThumb != (id)[NSNull null]) {
               ControlArtwork = [[MPMediaItemArtwork alloc] initWithBoundsSize:CGSizeMake(600, 600) requestHandler:^UIImage * _Nonnull(CGSize size) {
                 return [[_items objectAtIndex:itemIndex] objectForKey:@"thumb_image"];
             }];
           }

           NSNumber* itemDefinedDuration = [[_items objectAtIndex:itemIndex] objectForKey:@"duration"];
           NSNumber* duration = itemDefinedDuration != (id)[NSNull null] ? itemDefinedDuration : [self currentItemDuration];

           NSMutableDictionary *nowPlayingInfo = [NSMutableDictionary new];

           nowPlayingInfo[MPMediaItemPropertyTitle] = itemTitle;
           nowPlayingInfo[MPMediaItemPropertyAlbumTitle] = itemAlbum;
           nowPlayingInfo[MPMediaItemPropertyPlaybackDuration] = duration;
           nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = [NSNumber numberWithFloat:_player.rate];
           nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = _playerPosition;

           if(ControlArtwork != nil) {
               nowPlayingInfo[MPMediaItemPropertyArtwork] = ControlArtwork;
           }

           [MPNowPlayingInfoCenter defaultCenter].nowPlayingInfo = nowPlayingInfo;

     }
     @catch (NSException * e) {
         NSLog(@"setPlaybackStatusInfo Exception: %@", e);
     }
     @finally {
     }

}

- (MPRemoteCommandHandlerStatus) playerPlaybackChanged: (MPChangePlaybackPositionCommandEvent *)event{

    @try{

        if (_player.currentItem != nil) {

            //use weak self to avoid retain cycle
            __unsafe_unretained typeof(self) weakSelf = self;

            [_player seekToTime:CMTimeMake([event positionTime], 1) completionHandler:^ void (BOOL finished){
                if(finished){
                    for (id<AudioPlayerListener> listener in [weakSelf->_listeners allObjects]) {
                        [listener onSeekCompleted:[event positionTime]];
                    }
                }
            }];
        }

    }@catch (NSException * e) {
        [self sendPlatformDebugMessage:[NSString stringWithFormat:@"playerPlaybackChanged Exception: %@", e]];
    }
    @finally {
    }

    return MPRemoteCommandHandlerStatusSuccess;
}

- (void) playerSeek: (NSNumber*) seconds{

    @try{

        if (_player.currentItem != nil) {

            //use weak self to avoid retain cycle
            __unsafe_unretained typeof(self) weakSelf = self;

            [_player seekToTime:CMTimeMake([seconds intValue], 1) completionHandler:^ void (BOOL finished){
                if(finished){
                    for (id<AudioPlayerListener> listener in [weakSelf->_listeners allObjects]) {
                        [listener onSeekCompleted:[seconds longValue]];
                    }
                }
            }];
        }

    }@catch (NSException * e) {
        [self sendPlatformDebugMessage:[NSString stringWithFormat:@"playerSeek Exception: %@", e]];
    }
    @finally {
    }

}

- (MPRemoteCommandHandlerStatus) playerPlayPause{

    @try{

        [self sendPlatformDebugMessage:[NSString stringWithFormat:@"playerPlayPause _player.currentItem: %@", _player.currentItem]];

        if (_player.currentItem != nil && _ready == YES) {
            if ([_player rate] > 0.0) {
                [self sendPlatformDebugMessage:[NSString stringWithFormat:@"playerPlayPause pause"]];
                [_player pause];
            }else{
                [self sendPlatformDebugMessage:[NSString stringWithFormat:@"playerPlayPause play"]];
                [_player play];
            }
        }else{
            [self sendPlatformDebugMessage:[NSString stringWithFormat:@"playerPlayPause initPlayerItem"]];
            [self initPlayerItem];
        }

    }@catch (NSException * e) {
        [self sendPlatformDebugMessage:[NSString stringWithFormat:@"playerPlayPause Exception: %@", e]];
    }
    @finally {
    }

    return MPRemoteCommandHandlerStatusSuccess;
}

- (MPRemoteCommandHandlerStatus) playerStop{

    NSLog(@"playerStop");

    @try{

        if (_player.currentItem != nil){
            [_player pause];
            [[NSNotificationCenter defaultCenter] removeObserver:self name:AVPlayerItemDidPlayToEndTimeNotification object:_player.currentItem];
        }

        for (id<AudioPlayerListener> listener in [_listeners allObjects]) {
            [listener onPlayerStopped];
        }

        [_player replaceCurrentItemWithPlayerItem:nil];
        [MPNowPlayingInfoCenter defaultCenter].nowPlayingInfo = nil;

    }@catch (NSException * e) {
        [self sendPlatformDebugMessage:[NSString stringWithFormat:@"playerStop Exception: %@", e]];
    }
    @finally {
    }

    return MPRemoteCommandHandlerStatusSuccess;
}

- (MPRemoteCommandHandlerStatus) playerNext{
    NSLog(@"playerNext");
    if (_items.count > (int) _itemIndex+1) {
        //[self playerStop];
        _itemIndex = _itemIndex+1;
        for (id<AudioPlayerListener> listener in [_listeners allObjects]) {
            [listener onNextStarted: (int) _itemIndex];
        }
        [self initPlayerItem];
        for (id<AudioPlayerListener> listener in [_listeners allObjects]) {
            [listener onNextCompleted: (int) _itemIndex];
        }
        for (id<AudioPlayerListener> listener in [_listeners allObjects]) {
            [listener onIndexChangedExternally: (int) _itemIndex];
        }
    }

    return MPRemoteCommandHandlerStatusSuccess;
}

- (MPRemoteCommandHandlerStatus) playerPrevious{
    if ((int) _itemIndex > 0) {
        //[self playerStop];
        _itemIndex = _itemIndex-1;
        for (id<AudioPlayerListener> listener in [_listeners allObjects]) {
            [listener onPreviousStarted: (int) _itemIndex];
        }
        [self initPlayerItem];
        for (id<AudioPlayerListener> listener in [_listeners allObjects]) {
            [listener onPreviousCompleted: (int) _itemIndex];
        }
        for (id<AudioPlayerListener> listener in [_listeners allObjects]) {
            [listener onIndexChangedExternally: (int) _itemIndex];
        }
    }

    return MPRemoteCommandHandlerStatusSuccess;
}

- (void) setPlayerIndex: (int) itemIndex{
    if(itemIndex >= 0 && _items.count > itemIndex){
        _itemIndex = itemIndex;
        [self initPlayerItem];
    }
}

# pragma mark player events


- (void) _onAudioReady {

    [self sendPlatformDebugMessage:[NSString stringWithFormat:@"_onAudioReady ready: %d", _ready]];

    if (!_ready) {

        @try{

            _ready = YES;

            for (id<AudioPlayerListener> listener in [_listeners allObjects]) {
                [listener onAudioReady:[self audioLength]];
            }

            [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(playerDidFinish) name:AVPlayerItemDidPlayToEndTimeNotification object:_player.currentItem];

            _playerPosition = [NSNumber numberWithInt:0];
            [_player play];
            [self setPlaybackStatusInfo];
            [self _onPlaybackRateChange];

        }@catch (NSException * e) {
            [self sendPlatformDebugMessage:[NSString stringWithFormat:@"_onAudioReady Exception: %@", e]];
        }
        @finally {
        }

    }
}

- (void) _onFailedToPrepareAudio {
    NSLog(@"AVPlayer failed to load audio");

    for (id<AudioPlayerListener> listener in [_listeners allObjects]) {
        [listener onFailedPrepare];
    }

}

- (void) _onPlaybackRateChange {
    @try{

        [self sendPlatformDebugMessage:[NSString stringWithFormat:@"_onPlaybackRateChange _player.rate: %f", _player.rate]];
        if (_player.rate > 0 && !_isPlaying) {
            // Just started playing.
            NSLog(@"AVPlayer started playing.");
            for (id<AudioPlayerListener> listener in [_listeners allObjects]) {
                [listener onPlayerPlaying];
            }
            _isPlaying = YES;
            _isCompleted = NO;
        } else if (_player.rate == 0 && _isPlaying) {
            // Just paused playing.
            NSLog(@"AVPlayer paused playback.");
            for (id<AudioPlayerListener> listener in [_listeners allObjects]) {
                [listener onPlayerPaused];
            }
            _isPlaying = NO;
        }

    }@catch (NSException * e) {
        [self sendPlatformDebugMessage:[NSString stringWithFormat:@"_onPlaybackRateChange Exception: %@", e]];
    }
    @finally {
    }

}

- (void) playerDidFinish {
    NSLog(@"playerDidFinish");
    _isPlaying = NO;
    _isCompleted = YES;

    [[NSNotificationCenter defaultCenter] removeObserver:self name:AVPlayerItemDidPlayToEndTimeNotification object:_player.currentItem];

    for (id<AudioPlayerListener> listener in [_listeners allObjects]) {
        [listener onPlayerCompleted];
    }
}

@end
