//
//  CPAudioEngine.h
//  commonProj
//
//  Created by dongchx on 8/3/16.
//  Copyright © 2016 dongchx. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "AudioCommonDefine.h"
#import "AudioEngineHelper.h"
#import "QKPlayerProtocol.h"

@class QKAudioTrack;
@class QKBaseAudioPlayer;

@protocol QRAudioEngineDelegate <NSObject>

- (void)playEventChanged:(PlayEventType)type description:(NSString *)desc;

@optional
- (void)player:(QKBaseAudioPlayer *)player
  durationTime:(double)duration
     validTime:(double)validTime
  progressTime:(double)progress;

- (void)refreshButtonState:(NSInteger)index;

@end

@interface CPAudioEngine : NSObject<PlayerDelegate>

@property (nonatomic, weak) id<QRAudioEngineDelegate> delegate;
@property (nonatomic, readonly) QKBaseAudioPlayer     *mAudioPlayer;
@property (nonatomic, strong)   NSArray               *trackArray;
@property (nonatomic, strong)   NSString              *bookId;

@property (nonatomic, assign) BOOL isBackground;

+ (instancetype)sharedInstance;

#pragma mark - Audio API

/* get current error of Engine*/
- (AudioStreamerErrorCode)currentError;

/* get current state of Engine*/
- (AudioStreamerState)currentState;

/* play an audio track*/
- (void)playAudioTrack:(QKAudioTrack*)audioTrack;

/* pause current played(or signed) audio*/
- (void)pause;

/* resume paused audio*/
- (void)resume;

/* stop playing(or singing)*/
- (void)stop;

/* get the current volume*/
- (float)volume;

/* set the current volume of the playing music*/
/* whether is playing or not*/
- (BOOL)isPlaying;

/* seek to specified position, will be failed while the player underlying do not support seeking*/
- (BOOL)seekToTime:(double)second;

/* get progree time of current played audio*/
- (double)progressTime;

/* get duration time of current played audio*/
- (double)durationTime;

/* get duration time of current played audio that can played */
- (double)durationTimeCanPlay;

/* remoteControl */
- (void)remoteremoteControlReceivedWithEvent:(UIEvent *)receivedEvent;

/* timer */
- (void)timerStart;
- (void)timerPause;

- (void)nextTrack:(id)sender;
- (void)previousTrack:(id)sender;

@end











































