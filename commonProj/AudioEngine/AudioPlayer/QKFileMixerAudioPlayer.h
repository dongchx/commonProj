//
//  QKFileMixerAudioPlayer.h
//  QQKala
//
//  Created by frost on 12-6-26.
//  Copyright (c) 2012年 Tencent. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AudioToolbox/AudioToolbox.h>
#import "QKBaseAudioPlayer.h"
#import "TPCircularBuffer.h"

#define NUM_FILES 2

@interface QKFileMixerAudioPlayer : QKBaseAudioPlayer
{
    AUGraph                         mProcessingGraph;
    AudioUnit                       mMixerUnit;
    AudioStreamBasicDescription     mStereoStreamFormat;
    AudioStreamBasicDescription     mMonoStreamFormat;
    AudioStreamBasicDescription     mSInt16CanonicalStereoFormat;
    AudioStreamBasicDescription     mSInt16CanonicalMonoFormat;
    
    /* for source audio file*/
    CFURLRef                        sourceURL[NUM_FILES];
    ExtAudioFileRef                 mSourceAudioFile[NUM_FILES];
    BOOL                            mCancelReadSource[NUM_FILES];
    BOOL                            mReading[NUM_FILES];
    NSTimeInterval                  mDuration[NUM_FILES];
    NSThread                        *mInternalReadThread[NUM_FILES];
    
    
    double                          mLastProgress;
    NSUInteger                      mMeasureIndex;  // must < NUM_FILES
    UInt64                          mFrameReadOffset;
    
@public
    AudioUnit                       mIOUnit;
    SoundChannel                    mAudioFileSoundChannel;
    SoundStruct                     soundStruct[NUM_FILES];
    AudioStreamBasicDescription     mClientStreamFormat[NUM_FILES];
    BOOL                            mSourceFileReadComplete[NUM_FILES];
    UInt64                          mFrameCount;    // the frame count to be played
}
- (void)setAudioFileChannel:(SoundChannel)channel;
- (id)initWithAudioFile:(NSString*)filePath audioFile2:(NSString*)recordFilePath;

@end
