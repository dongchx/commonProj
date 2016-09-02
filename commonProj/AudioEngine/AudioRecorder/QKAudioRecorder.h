//
//  QKAudioRecorder.h
//  QQKala
//
//  Created by frost on 12-6-6.
//  Copyright (c) 2012年 Tencent. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "QKRecorderProtocol.h"
#import "QKAudioRecorderDefine.h"

#define kNumberRecordBuffers	3

@interface QKAudioRecorder : NSObject<QKRecorderProtocol>
{
    UInt64                      mStartTime;
    CFStringRef					mFileName;
    AudioQueueRef				mQueue;
    AudioQueueBufferRef			mBuffers[kNumberRecordBuffers];
    AudioFileID					mRecordFile;
    SInt64						mRecordPacket; // current packet number in record file
    AudioStreamBasicDescription	mRecordFormat;
    AudioRecordState            mState;
}

@property (nonatomic, assign) AudioFileID   recordFile;
@property (nonatomic, assign) SInt64        recordPacket;
@property (nonatomic, assign) AudioQueueRef queue;

@end
