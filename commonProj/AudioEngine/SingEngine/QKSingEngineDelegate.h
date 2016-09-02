//
//  QKSingEngineDelegate.h
//  QQKala
//
//  Created by frost on 12-6-25.
//  Copyright (c) 2012年 Tencent. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "AudioCommonDefine.h"

@class QKAudioTrack;
@class QKSingEngine;

@protocol QKSingEngineDelegate <NSObject>

@required
- (void)playEventChanged:(PlayEventType)type description:(NSString*)desc;

@optional
- (void)failedToSingAudioTrack:(QKAudioTrack*)audioTrack error:(NSInteger)error;
- (void)onVolumeChanged:(float)newVolume;
- (void)diskSpaceLessThan:(UInt64)spaceInBytes toSingAudioTrack:(QKAudioTrack*)audioTrack;
- (void)processAudioTrackComplete:(QKAudioTrack*)audioTrack;
@end
