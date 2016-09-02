//
//  QKAudioMixer.h
//  QQKala
//
//  Created by frost on 12-6-6.
//  Copyright (c) 2012年 Tencent. All rights reserved.
//

#import <Foundation/Foundation.h>
#include <AudioToolbox/AudioToolbox.h>
#import "AudioCommonDefine.h"

enum  {
    QKAudioMixerSourceFileNotExistError,
    QKAudioMixerSourceFileError,
    QKAudioMixerSourceFileReadError,
    QKAudioMixerUnsupportedFileTypeError,
    QKAudioMixerDestinationFileCreateError,
    QKAudioMixerDestinationFileWriteError,
    QKAudioMixerFormatError,
    QKAudioMixerInvalidDestinationFormat,
    QKAudioMixerUnrecoverableInterruptionError,
    QKAudioMixerOutofMemoryError,
    QKAudioMixerGetPropertyFailedError,
    QKAudioMixerInitializationError
};

@protocol QKAudioMixerDelegate;

@interface QKAudioMixer : NSObject
{
@private
    id<QKAudioMixerDelegate>        mDelegate;
    SoundChannel                    mChannel1;              // sound channel of audio file 1
    NSString                        *mSourceAudioFilePath1;
    NSString                        *mSourceAudioFilePath2;
    NSString                        *mMixAudioFilePath;

    // mix audio file property
    UInt32                          mFormatID;
    AudioFileTypeID                 mFileTypeID;
    NSInteger                       mChannels;
    
    // internal use
    BOOL                            mProcessing;
    BOOL                            mCancelled;
//    BOOL                            mInterrupted;
    NSCondition                     *mCondition;
    NSThread                        *mInternalProcessingThread;
}

@property (nonatomic, assign) id<QKAudioMixerDelegate>              delegate;
@property (nonatomic, readonly, assign) SoundChannel                channel1;
@property (nonatomic, readonly, retain) NSString                    *sourceAudioFilePath1;
@property (nonatomic, readonly, retain) NSString                    *sourceAudioFilePath2;
@property (nonatomic, readonly, retain) NSString                    *mixAudioFilePath;


+ (void)mixBuffers:(const int16_t*)buffer1 buffer2:(const int16_t*)buffer2 mixbuffer:(int16_t *)mixbuffer mixbufferNumSamples:(int)mixbufferNumSamples;

// deprecated
- (NSInteger)mix:(NSString*)file1 file2:(NSString*)file2 mixfile:(NSString*)mixfile mixAudioSampleRate:(UInt32)sampleRate;

/*
 @discussion                run a thread to mix two input audio files to mix file
 @param file1               the path of the first audio file which is used to mix
 @param channel             the sound channel of the first audio file
 @param file2               the path of the second audio file which is used to mix
 @param mixfile             the output mixed audio file path
 @param audioFileTypeID     the output mixed audio file type
 @param formatID            the output mixed audio file data format id
 @param numChannels         the output mixed audio file channels
 @return                    if thread start successfully, YES will returned, vice versa.
 */
- (BOOL)startThreadToMix:(NSString*)file1 soundChannel:(SoundChannel)channel file2:(NSString*)file2 mixfile:(NSString*)mixfile mixAudioFileType:(AudioFileTypeID)audioFileTypeID
  mixAudioFormat:(UInt32)formatID numChannels:(NSInteger)numChannels;

- (BOOL)isWorking;

- (void)cancel;

/*
 @discussion                mix two input files to mix file
 @param file1               the path of the first audio file which is used to mix
 @param channel             the sound channel of the first audio file
 @param file2               the path of the second audio file which is used to mix
 @param mixfile             the output mixed audio file path
 @param audioFileTypeID     the output mixed audio file type
 @param asbd                the output mixed audio file data format
 @return                    error code
 */
- (NSInteger)mix:(NSString*)file1 soundChannel:(SoundChannel)channel file2:(NSString*)file2 mixfile:(NSString*)mixfile mixAudioFileType:(AudioFileTypeID)audioFileTypeID
  mixAudioFormat:(AudioStreamBasicDescription)asbd;



@end

// QKAudioConverterDelegate Protocol
@protocol QKAudioMixerDelegate <NSObject>

- (void)audioMixerdidFinishMix:(QKAudioMixer*)audioMixer;
- (void)audioMixer:(QKAudioMixer*)audioMixer didFailWithError:(NSError*)error;

@optional
- (void)audioMixer:(QKAudioMixer *)audioMixer didMakeProgress:(CGFloat)progress;
@end
