//
//  QKAUAudioPlayer.h
//  QQKala
//
//  Created by frost on 12-7-6.
//  Copyright (c) 2012年 Tencent. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AudioToolbox/AudioToolbox.h>
#import "QKBaseAudioPlayer.h"
#import "TPCircularBuffer.h"

@interface QKAUAudioPlayer : QKBaseAudioPlayer
{
    AUGraph                         mProcessingGraph;
    AudioUnit                       mMixerUnit;
    AudioStreamBasicDescription     mStereoStreamFormat;
    AudioStreamBasicDescription     mMonoStreamFormat;
    AudioStreamBasicDescription     mSInt16CanonicalStereoFormat;
    AudioStreamBasicDescription     mSInt16CanonicalMonoFormat;
    
    /* for source audio file*/
    CFURLRef                        sourceURL;
    ExtAudioFileRef                 mSourceAudioFile;
    BOOL                            mCancelReadSource;
    BOOL                            mReading;
    NSTimeInterval                  mDuration;
    AudioBufferList                 *mBufferList;
    UInt8                           *mBuffer1;
    UInt8                           *mBuffer2;
    
    double                          mLastProgress;
    UInt64                          mFrameReadOffset;
    
@public
    NSThread                        *mInternalReadThread;
    AudioUnit                       mIOUnit;
    SoundChannel                    mAudioFileSoundChannel;
    SoundStruct                     soundStruct;
    AudioStreamBasicDescription     mClientStreamFormat;
    BOOL                            mReadComplete;

}

- (id)initWithAudioFile:(NSString*)filePath;
@end
