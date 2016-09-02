//
//  QKAudioSynthesizeProcessor.h
//  QQKala
//
//  Created by frost on 12-8-17.
//  Copyright (c) 2012年 Tencent. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AudioToolbox/AudioToolbox.h>
#import "TPCircularBuffer.h"

@class QKAudioEffect;
@protocol QKAudioProcessorDelegate;

@interface QKAudioSynthesizeProcessor : NSObject
{
    @public
    char*                           mReverbBuffer;
    char*                           mMixBuffer;
    BOOL                            mCancelSynthesize;
    BOOL                            mSynthesizeComplete;
    
    @private
    id<QKAudioProcessorDelegate>    mDelegate;
    
    /* source buffer used for synthesizing*/
    TPCircularBuffer                mSourceBuffer1;
    TPCircularBuffer                mSourceBuffer2;
    
    /* audio effect*/
    BOOL                            mUseEffectForSource1;
    BOOL                            mUseEffectForSource2;
    QKAudioEffect                   *mAudioEffectForSource1;
    QKAudioEffect                   *mAudioEffectForSource2;
    
    /* synthesize thread*/
    NSThread                        *mInternalSynthesizeThread;
    BOOL                            mSynthesizing;
    AudioBufferList                 mBufferList;
    BOOL                            mSourceBufferDrain;
    
    /* file path*/
    NSString                        *mOutputFilePath;
    AudioFileTypeID                 mOutputFileTypeID;
    ExtAudioFileRef                 mOutputFileRef;
    AudioStreamBasicDescription     mOutputFormat;
    AudioStreamBasicDescription     mSourceFormat;
}

@property (nonatomic, assign) id<QKAudioProcessorDelegate>          delegate;
@property (nonatomic, readonly) TPCircularBuffer        *ptrSourceBuffer1;
@property (nonatomic, readonly) TPCircularBuffer        *ptrSourceBuffer2;
@property (nonatomic, readwrite)BOOL                    useEffectForSource1;
@property (nonatomic, readwrite)BOOL                    useEffectForSource2;
@property (nonatomic, readonly, retain)QKAudioEffect    *audioEffectForSource1;
@property (nonatomic, readonly, retain)QKAudioEffect    *audioEffectForSource2;
@property (nonatomic, readonly, retain)NSString         *outputFilePath;

- (void)configOutputFile:(NSString*)fileName fileType:(AudioFileTypeID)type destinationASBD:(AudioStreamBasicDescription)destinationASBD clientASBD:(AudioStreamBasicDescription)clientASBD;

- (void)startThreadToProcess;
- (void)cancelProcess;
- (void)produceBytesForSourceBuffer1:(const void*)src bufferLength:(NSInteger)len;
- (void)produceBytesForSourceBuffer2:(const void*)src bufferLength:(NSInteger)len;
- (void)setAudioEffectForSource1:(QKAudioEffect *)audioEffectForSource1;
- (void)setAudioEffectForSource2:(QKAudioEffect *)audioEffectForSource2;
- (void)setSourceBufferDrain;

@end

enum 
{
    AudioProcessorFinishTypeCancel,
    AudioProcessorFinishTypeComplete,
    AudioProcessorFinishTypeFailed,
};
typedef NSInteger AudioProcessorFinishType;

// QKAudioProcessorDelegate Protocol
@protocol QKAudioProcessorDelegate <NSObject>

- (void)audioProcessor:(QKAudioSynthesizeProcessor*)audioProcessor didFinishWithFinishType:(AudioProcessorFinishType)type;
@optional
- (void)audioProcessor:(QKAudioSynthesizeProcessor*)audioProcessor didFailWithError:(NSError*)error;
@end
