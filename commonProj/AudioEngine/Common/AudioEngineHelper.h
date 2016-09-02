//
//  AudioEngineHelper.h
//  QQKala
//
//  Created by frost on 12-6-11.
//  Copyright (c) 2012年 Tencent. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>

@protocol AudioEngineHelperDelegate;

@interface AudioEngineHelper : NSObject <AVAudioSessionDelegate>
{
    BOOL                mIsConfiged;
    BOOL                mNeedRecording;
    BOOL                mIsRouteChangeEventRegistered;
    BOOL                mIsVolumeChangeEventRegistered;
    BOOL                mIsHideSystemVolumeOverLay;
    NSUInteger          mCurrentCategory;
    id<AudioEngineHelperDelegate> mDelegate;
}

@property (nonatomic, retain) id<AudioEngineHelperDelegate> delegate;

+ (AudioEngineHelper*)sharedInstance;

/*
 init audio session with default category, and make this session active
 */
- (void)initAudioSession;

/*
 check if current category is suitable for play and record, and set the right category if not.
 */
- (void)checkAudioCategoryForPlayAndRecord;

/**/
- (void)resetAudioCategoryForPlayOnly;

/*
 check if micphone exist
 */
- (BOOL)hasMicPhone;

/*
 get input channel number
 */
- (UInt32)inputChannelNumber;

/*
 check if headset plugined
 */
- (BOOL)hasHeadSet;

/*
 get current volume
 */
- (float)currentVolume;

- (OSStatus)setAudioSessionActive:(Boolean)active;

- (BOOL)shouldStopOnInterrupt;

- (void)hideSystemVolumeOverlay:(UIView*)superView;

- (void)resetOutputTarget;

- (void)resetAudioCategory;

- (void)reduceRecordingLatency;


- (void)registerRouteChangeEvent;
- (void)unregisterRouteChangeEvent;

- (void)registerVolumeChangeEvent;
- (void)unregisterVolumeChangeEvent;

- (void)applicationWillResignActive;
- (void)applicationDidBecomeActive;

@end

@protocol AudioEngineHelperDelegate <NSObject>

@optional

- (void)beginInterruption;
- (void)endInterruptionWithFlags:(NSUInteger)flags;

@end
