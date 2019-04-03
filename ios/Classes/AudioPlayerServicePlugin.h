#import <Flutter/Flutter.h>
#import "AudioPlayer.h"

@interface AudioPlayerServicePlugin : NSObject<FlutterPlugin, AudioPlayerListener>

+ (id)sharedManager;

@end
