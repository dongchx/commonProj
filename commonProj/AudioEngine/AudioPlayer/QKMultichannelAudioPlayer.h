//
//  QKMultichannelAudioPlayer.h
//  QQKala
//
//  Created by frost on 12-6-13.
//  Copyright (c) 2012年 Tencent. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AudioToolbox/AudioToolbox.h>
#import "QKBaseAudioPlayer.h"
#import "TPCircularBuffer.h"


@class QKAudioSynthesizeProcessor;
@class QKEvaluator;

@interface QKMultichannelAudioPlayer : QKBaseAudioPlayer<QKMultiChannelProtocol>
{
    /* audio graph*/
    AUGraph                         mProcessingGraph;
    AudioUnit                       mMixerUnit;
    AudioStreamBasicDescription     mStereoStreamFormat;
    AudioStreamBasicDescription     mMonoStreamFormat;
    AudioStreamBasicDescription     mSInt16CanonicalStereoFormat;
    AudioStreamBasicDescription     mSInt16CanonicalMonoFormat;
    AudioStreamBasicDescription     mSInt16StereoFormat;
    AudioStreamBasicDescription     mSInt16MonoFormat;
    
    AudioStreamBasicDescription     mRecordFormat;
    AudioStreamBasicDescription     mOutputFormat;
    NSString                        *mRecordFileName;
    Float32                         mRecordGain;
    AudioStreamBasicDescription     mMixerOutputScopeFormat;
    
    
    /* for source audio file*/
    CFURLRef                        sourceURL;
    ExtAudioFileRef                 mSourceAudioFile;
    BOOL                            mCancelReadSource;
    BOOL                            mReading;
    NSTimeInterval                  mDuration;
    double                          mLastProgress;
    AudioBufferList                 *mBufferList;
    UInt8                           *mBuffer1;
    UInt8                           *mBuffer2;
    
    /* for record*/
    void                            *mRecordBuffer;
    
    /* used for synthesize audio buffer*/
    QKAudioSynthesizeProcessor      *mSynthesizeProcessor;
    
    /* used for evaluate*/
    QKEvaluator                     *mEvaluator;
    

    @public
    NSThread                        *mInternalReadThread;
    AudioUnit                       mIOUnit;
    ExtAudioFileRef                 mRecordFileRef;
    SoundChannel                    mCurrentChannel;
    SoundChannel                    mAccompanimentChannel;
    SoundStruct                     soundStruct;
    AudioStreamBasicDescription     mClientStreamFormat;
    BOOL                            mReadComplete;
}

@property (nonatomic, readonly, retain)NSString                     *recordFilePath;
@property (nonatomic, readwrite, retain)QKAudioSynthesizeProcessor  *audioProcessor;
@property (nonatomic, readwrite, retain)QKEvaluator                 *evaluator;

- (id)initWithAudioFile:(NSString*)filePath recordFilePath:(NSString*)recordFilePath;

- (void)setDefaultChannel:(SoundChannel)channel;
- (void)setAccompanimentChannel:(SoundChannel)channel;
- (AudioStreamBasicDescription)getRecordFormat;
- (AudioStreamBasicDescription)getOutputFormat;
- (float)getcurrentVolume;
@end
