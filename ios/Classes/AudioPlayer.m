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
        NSLog(@"\ndeinitPlayerQueue Exception: %@", e);
    }
    @finally {
    }

}

- (void) initPlayerQueue: (NSArray*)items{
    
    [self deinitPlayerQueue];

    _items = items;
    
    //set player items, we only need the URL
    for (NSDictionary* item in _items) {
        
        AVPlayerItem* playerItem;

        NSURL *url = [[NSURL alloc] initWithString: [item objectForKey:@"url"]];
        
        if([[item objectForKey:@"local"] intValue] == 1){

            NSLog(@"\ninitPlayerqueue local asset");    
            AVAsset *asset = [AVURLAsset URLAssetWithURL:url options:nil];
            playerItem = [AVPlayerItem playerItemWithAsset:asset];

        }else{
            
            NSLog(@"\ninitPlayerqueue remote asset");   
            playerItem = [[AVPlayerItem alloc] initWithURL:url];

        }

        [_playerItems addObject:playerItem];

        //edit thumbs right away
        NSString* itemThumb = [item objectForKey:@"thumb"];
        NSURL *thumbUrl = [[NSURL alloc] initWithString: itemThumb];
        NSData *data = [NSData dataWithContentsOfURL: thumbUrl];
        UIImage *artwork = [[UIImage alloc] initWithData:data];
        [item setValue:[self resizeImageWithImage:artwork scaledToSize:CGSizeMake(600, 600)] forKey:@"thumb_image"];
        
    }
    
    _player = [[AVQueuePlayer alloc] initWithItems:_playerItems];
    
    //get audio state and call listeners
    [_player addObserver:self forKeyPath:@"status" options:0 context:nil];
    [_player addObserver:self forKeyPath:@"rate" options:0 context:nil];
    
    _playerPosition = [NSNumber numberWithInt:0];
    
    //use weak self to avoid retain cycle
    __unsafe_unretained typeof(self) weakSelf = self;
    
    //set listener to pull playback position
    _periodicListener = [_player addPeriodicTimeObserverForInterval:CMTimeMakeWithSeconds(1.0, NSEC_PER_SEC) queue:NULL usingBlock:^(CMTime time) {
        weakSelf->_playerPosition = [NSNumber numberWithInt:[weakSelf playbackPosition]/1000];
        for (id<AudioPlayerListener> listener in [weakSelf->_listeners allObjects]) {
            [listener onPlayerPlaybackUpdate:weakSelf->_playerPosition :[weakSelf audioLength]];
        }
        [weakSelf setPlaybackStatusInfo];
    }];
    
    NSLog(@"\ninitPlayerQueue done");
    
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSKeyValueChangeKey,id> *)change context:(void *)context {
    NSLog(@"\nobserveValueForKeyPath: %@", keyPath);
    if ([keyPath isEqualToString:@"status"]) {
        if (_player.status == AVPlayerStatusReadyToPlay && object == _player.currentItem) {
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
    
    _ready = NO;
    _isPlaying = NO;
    _isCompleted = NO;
    
    int itemIndex = (int) _itemIndex;
    
    NSLog(@"\ninitPlayerItem with index: %d", itemIndex);
    
    //AVPlayerItem * item = [_playerItems objectAtIndex:itemIndex];
    
    //NSLog(@"\ninitPlayerItem AVPlayerItem: %@", item);
    
    NSLog(@"\ninitPlayerItem item: %@", [_items objectAtIndex:itemIndex]);
    
    NSString* itemTitle = [[_items objectAtIndex:itemIndex] objectForKey:@"title"];
    NSString* itemAlbum = [[_items objectAtIndex:itemIndex] objectForKey:@"album"];
    
    MPMediaItemArtwork* ControlArtwork = [[MPMediaItemArtwork alloc] initWithBoundsSize:CGSizeMake(600, 600) requestHandler:^UIImage * _Nonnull(CGSize size) {
        return [[_items objectAtIndex:itemIndex] objectForKey:@"thumb_image"];
    }];
    
    NSLog(@"\nplaying file: %@", [[_items objectAtIndex:itemIndex] objectForKey:@"url"]);
    
    // TODO: Fix this
    // This does not seem to work well for audio accessories/bluetooth devices.
    // Its not broken, but the current index/ total supplied to devices is incorrect
    BOOL itemInserted = NO;
    [_player removeAllItems];
    for (int i = itemIndex; i <_items.count; i ++) {
        AVPlayerItem * new_item = [_playerItems objectAtIndex:i];
        if ([_player canInsertItem:new_item afterItem:nil]) {
            [new_item seekToTime:kCMTimeZero completionHandler:nil];
            [_player insertItem:new_item afterItem:nil];
            itemInserted = YES;
        }
    }
    
    if(itemInserted){
    
        NSNumber* duration = [[_items objectAtIndex:itemIndex] objectForKey:@"duration"];
    
        [MPNowPlayingInfoCenter defaultCenter].nowPlayingInfo = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                                                                itemTitle, MPMediaItemPropertyTitle,
                                                                ControlArtwork, MPMediaItemPropertyArtwork,
                                                                itemAlbum, MPMediaItemPropertyAlbumTitle,
                                                                duration, MPMediaItemPropertyPlaybackDuration,
                                                                [NSNumber numberWithDouble:1.0], MPNowPlayingInfoPropertyPlaybackRate, nil];
        
        [self _onAudioReady];
    
    }else{

        [self _onFailedToPrepareAudio];

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
        NSNumber* duration = [[_items objectAtIndex:_itemIndex] objectForKey:@"duration"];
        long millis = [duration intValue] * 1000;
        return millis;
    } else {
        return 0;
    }
}

- (int) playbackPosition {
    if (_player.currentItem != nil) {
        return CMTimeGetSeconds([_player.currentItem currentTime]) * 1000;
    } else {
        return 0;
    }
}

- (void) addListener:(id <AudioPlayerListener>) listener {
    NSLog(@"\nAdding listener: %@", listener);
    [_listeners addObject:listener];
    NSLog(@"\nadded listeners: %@", _listeners);
}

# pragma mark player commands

- (void) setPlaybackStatusInfo{
    
    // This was added to handle metadata being passed to external devices (bluetooth in car),
    // but it causes a crash in latest tests, leaving here until further testing

    // int itemIndex = (int) _itemIndex;
    
    // NSLog(@"\nsetPlaybackStatusInfo item: %@", [_items objectAtIndex:itemIndex]);

    // @try{

    //       NSString* itemTitle = [[_items objectAtIndex:itemIndex] objectForKey:@"title"];
    //       NSString* itemAlbum = [[_items objectAtIndex:itemIndex] objectForKey:@"album"];

    //       MPMediaItemArtwork* ControlArtwork = [[MPMediaItemArtwork alloc] initWithBoundsSize:CGSizeMake(600, 600) requestHandler:^UIImage * _Nonnull(CGSize size) {
    //           return [[_items objectAtIndex:itemIndex] objectForKey:@"thumb_image"];
    //       }];

    //       NSNumber* duration = [[_items objectAtIndex:itemIndex] objectForKey:@"duration"];

    //       [MPNowPlayingInfoCenter defaultCenter].nowPlayingInfo = [NSMutableDictionary dictionaryWithObjectsAndKeys:
    //                                                                itemTitle, MPMediaItemPropertyTitle,
    //                                                                ControlArtwork, MPMediaItemPropertyArtwork,
    //                                                                itemAlbum, MPMediaItemPropertyAlbumTitle,
    //                                                                duration, MPMediaItemPropertyPlaybackDuration,
    //                                                                _playerPosition, MPNowPlayingInfoPropertyElapsedPlaybackTime,
    //                                                                _player.rate, MPNowPlayingInfoPropertyPlaybackRate, nil];
          
    // }
    // @catch (NSException * e) {
    //     NSLog(@"\nsetPlaybackStatusInfo Exception: %@", e);
    // }
    // @finally {
    // }

}

- (void) playerPlaybackChanged: (MPChangePlaybackPositionCommandEvent *)event{
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
}

- (void) playerSeek: (NSNumber*) seconds{
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
}

- (void) playerPlayPause{
    if (_player.currentItem != nil && _ready == YES) {
        if ([_player rate] > 0.0) {
            NSLog(@"\nplayerPlayPause pause");
            [_player pause];
        }else{
            NSLog(@"\nplayerPlayPause play");
            [_player play];
        }
    }else{
        NSLog(@"\nplayerPlayPause initPlayerItem");
        [self initPlayerItem];
    }
    
}

- (void) playerStop{
    
    NSLog(@"\nplayerStop");
    if (_player.currentItem != nil){
        [_player pause];
        [[NSNotificationCenter defaultCenter] removeObserver:self name:AVPlayerItemDidPlayToEndTimeNotification object:_player.currentItem];
    }
    
    for (id<AudioPlayerListener> listener in [_listeners allObjects]) {
        [listener onPlayerStopped];
    }
    
    [_player replaceCurrentItemWithPlayerItem:nil];
    [MPNowPlayingInfoCenter defaultCenter].nowPlayingInfo = nil;
    
}

- (void) playerNext{
    NSLog(@"\nplayerNext");
    if (_items.count > (int) _itemIndex+1) {
        [self playerStop];
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
}

- (void) playerPrevious{
    if ((int) _itemIndex > 0) {
        [self playerStop];
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
}

- (void) setPlayerIndex: (int) itemIndex{
    if(itemIndex >= 0 && _items.count > itemIndex){
        _itemIndex = itemIndex;
        [self initPlayerItem];
    }
}

# pragma mark player events


- (void) _onAudioReady {
    
    NSLog(@"\n_onAudioReady ready: %d", _ready);
    NSLog(@"\n_onAudioReady listeners: %@", _listeners);
    if (!_ready) {
        _ready = YES;
        _isPlaying = FALSE;
        
        for (id<AudioPlayerListener> listener in [_listeners allObjects]) {
            [listener onAudioReady:[self audioLength]];
        }
        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(playerDidFinish) name:AVPlayerItemDidPlayToEndTimeNotification object:_player.currentItem];
        
        _playerPosition = [NSNumber numberWithInt:0];
        [_player play];
        [self setPlaybackStatusInfo];
        
    }
}

- (void) _onFailedToPrepareAudio {
    NSLog(@"\nAVPlayer failed to load audio");
    
    for (id<AudioPlayerListener> listener in [_listeners allObjects]) {
        [listener onFailedPrepare];
    }
    
}

- (void) _onPlaybackRateChange {
    NSLog(@"\nRate just changed to %f", _player.rate);
    if (_player.rate > 0 && !_isPlaying) {
        // Just started playing.
        NSLog(@"\nAVPlayer started playing.");
        for (id<AudioPlayerListener> listener in [_listeners allObjects]) {
            [listener onPlayerPlaying];
        }
        _isPlaying = YES;
        _isCompleted = NO;
    } else if (_player.rate == 0 && _isPlaying) {
        // Just paused playing.
        NSLog(@"\nAVPlayer paused playback.");
        for (id<AudioPlayerListener> listener in [_listeners allObjects]) {
            [listener onPlayerPaused];
        }
        _isPlaying = NO;
    }
}

- (void) playerDidFinish {
    NSLog(@"\nplayerDidFinish");
    _isPlaying = NO;
    _isCompleted = YES;
    
    [[NSNotificationCenter defaultCenter] removeObserver:self name:AVPlayerItemDidPlayToEndTimeNotification object:_player.currentItem];
    
    for (id<AudioPlayerListener> listener in [_listeners allObjects]) {
        [listener onPlayerCompleted];
    }
}

@end
