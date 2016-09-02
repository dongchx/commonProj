//
//  QKSingEngine.h
//  QQKala
//
//  Created by frost on 12-6-20.
//  Copyright (c) 2012年 Tencent. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AudioToolbox/AudioToolbox.h>
#import "QKSingEngineDelegate.h"
#import "QKSingEvaluateDelegate.h"
#import "QKSingSynthesizeDelegate.h"
#import "QKBaseAudioPlayer.h"
#import "QKAudioConverter.h"
#import "QKAudioSynthesizeProcessor.h"
#import "QKEvaluator.h"
#import "AudioEngineHelper.h"


enum  
{
    FailedToStartEvaluator
};
typedef NSInteger SingEngineError;

@class QKAudioTrack;
@class QKAiSingWrapper;
@class QKAudioUnitOutputRecorder;

@interface QKSingEngine : NSObject<PlayerDelegate,QKAudioConverterDelegate,QKAudioEvaluatorDelegate,QKAudioProcessorDelegate,AudioEngineHelperDelegate>
{
    QKAudioTrack                    *mCurrentAudioTrack;
    QKBaseAudioPlayer               *mAudioPlayer;
    QKEvaluator                     *mEvaluator;
    QKAudioSynthesizeProcessor      *mSynthesizeProcessor;
    QKAudioConverter                *mOutputConverter;
    QKAudioTrack                    *mSynthesizeSourceAudioTrack;
    QKAudioTrack                    *mSynthesizeDestinationAudioTrack;
    NSString                        *mCurrentRecordFilePath;
    NSString                        *mCurrentOutputFilePath;
    
    NSUInteger                      mBgTaskId;
    AudioSampleRate                 mCurrentSampleRate;
    NSUInteger                      mReverbEffectIndex;
    
    UInt64                          mCriticalSpace;
    AudioStreamBasicDescription     mOutputFormat;
    
    BOOL                            mNeedResume;
    BOOL                            mShouldStopOnInterrupt;
    BOOL                            mIsSinging;
    
    // delegates
    NSMutableArray                  *mDelegates;                
    id<QKSingEvaluateDelegate>      mEvaluateDelagate;
    id<QKSingSynthesizeDelegate>    mSynthesizeDelegate;
}

@property (nonatomic, readonly, retain)QKAudioTrack         *currentAudioTrack;
@property (nonatomic, assign)id<QKSingEvaluateDelegate>     evaluateDelegate;
@property (nonatomic, assign)id<QKSingSynthesizeDelegate>   synthesizeDelegate;
@property (nonatomic, readonly, retain)NSString             *currentRecordFilePath;
@property (nonatomic, readonly, retain)NSString             *currentOutputFilePath;
@property (nonatomic, assign)UInt64                         criticalSpace;

/* get singleton instance of QKSingEngine*/
+ (QKSingEngine*)sharedInstance;

#pragma mark delegate API
- (void)addSingEngineDelegate:(id<QKSingEngineDelegate>)delegate;
- (void)removeSingEngineDelegate:(id<QKSingEngineDelegate>)delegate;
- (void)removeAllSingEngineDelegates;

#pragma mark core API
/* sing an audio track*/
- (void)singAudioTrack:(QKAudioTrack*)audioTrack;
/* resing*/
- (void)reSing;
/* playback singed audio track*/
- (void)playback;
/* play an audio track*/
- (void)playAudioTrack:(QKAudioTrack*)audioTrack;
/* determine if sing or not*/
- (BOOL)isSinging;


#pragma mark processing API
/* synthesize the specified audio track, get an output file*/
- (void)synthesizeAudioTrack:(QKAudioTrack*)audioTrack outPutFilePath:(NSString*)filePath;
/* */
- (void)cancelSynthesize;


#pragma mark universal API
/* get current error of QKSingEngine*/
- (AudioStreamerErrorCode)currentError;
/* get current state of QKSingEngine*/
- (AudioStreamerState)currentState;
/* pause current played(or signed) audio*/
- (void)pause;
/* resume paused audio*/
- (void)resume;
/* stop playing(or singing)*/
- (void)stop;
/* get the current volume*/
- (float)volume;
/* set the current volume of the playing music*/
- (void)setVolume:(float)volume;
/* whether is playing or not*/
- (BOOL)isPlaying;
/* whether is recording or not*/
- (BOOL)isRecording;
/* seek to specified position, will be failed while the player underlying do not support seeking*/
- (void)seekToTime:(double)second;
/* get progree time of current played(or singed) audio*/
- (double)progressTime;
/* get duration time of current played(or singed) audio*/
- (double)durationTime;

#pragma mark Audio Effect API
/* get avaliabled reverb effect count */
- (NSUInteger)getReverbEffectCount;
/* set active reverb effect index */
- (void)setReverbEffectIndex:(NSUInteger)index;

#pragma mark multi channel control API

- (void)switchToOriginal:(BOOL)isOriginal;

/* check the audio playing is original or accompaniment, YES if played original audio.
   If there is no audio played, NO will returned.*/
- (BOOL)isOriginal;

/*
 @discussion        切换音频输入通道(audio line)的声道
 @param channel     left or right sound channel
 */
- (void)switchAudioChannel:(SoundChannel)channel;

/*
 @discussion        获取当前音频输入通道(audio line)的声道
 @result            left or right sound channel
 */
- (SoundChannel)getCurrentAudioChannel;

/*
 @discussion        开关音频输入通道(audio line),如果打开，则通过mic输入的语音直接通过扬声器播出，vice versa
 @param enable      on or off
 */
- (void)enableVoiceInputBus:(BOOL)enable;

/* 
 @discussion        改变语音输入通道(mic line)音量增益 
 @param gain        Linear Gain, 0.01->1
 */
- (void)changeVoiceInputBusGain:(Float32)gain;

/* 
 @discussion        获取语音输入通道(mic line)音量增益 
 @return            Linear Gain, 0～1
 */
- (Float32)getVoiceInputBusGain;

/* 
 @discussion        改变音频输入通道(audio line)音量增益
 @param gain        Linear Gain, 0.01->1
 */
- (void)changeAudioBusGain:(Float32)gain;

/* 
 @discussion        获取音频输入通道(audio line)音量增益 
 @return            Linear Gain, 0～1
 */
- (Float32)getAudioBusGain;

/* 
 @discussion        改变输出音量(out put)增益
 @param gain        Linear Gain, 0.01->1
 */
- (void)changeOputGain:(Float32)gain;

#pragma mark evaluate API

/*
 @discussion            获取当前的音高值
 @param outPitch        current pitch
 @return                YES for get successfully, NO for failed
 */
- (BOOL)getCurrentPitch:(short*)outPitch;

/*
 @discussion        获取最终得分，即歌曲唱完之后整首歌的得分
 @param outScore    歌曲得分
 @return            如果有整首歌得分，返回YES,否则返回NO
 */
- (BOOL)getResultingScore:(NSInteger*)outScore;

/*
 @discussion        获取每句得分数组
 @return            句得分数组, may be nil if none sentence scores
 
 @notice            建议在唱完后获取
                    在唱的过程中，最好不要获取句得分数组，因为这个数组会不断增加
 */
- (NSArray*)getSentenceScores;

/*
 @discussion        获取每字得分数组
 @return            字得分数组, may be nil if none tone scores
 
 @notice            建议在唱完后获取
                    在唱的过程中，最好不要获取字得分数组，因为这个数组会不断增加
 */
- (NSArray*)getToneScores;

- (BOOL)isAllEvaluated;

@end
