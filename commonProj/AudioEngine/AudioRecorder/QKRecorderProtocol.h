//
//  QKRecorderProtocol.h
//  QQKala
//
//  Created by frost on 12-6-6.
//  Copyright (c) 2012年 Tencent. All rights reserved.
//


#import <Foundation/Foundation.h>
#include <AudioToolbox/AudioToolbox.h>

// ----------------------------------------------
// Recorder interface definition
// ----------------------------------------------
@protocol QKRecorderProtocol <NSObject>

/*
 * @abstract start recording, and save recorded packet to specified file.
 * @param   inRecordFile
    where to save recorded packet
 *
 */
- (void)startRecord:(CFStringRef)inRecordFile format:(UInt32)formatID sampleRate:(UInt32)sampleRate;
/*
 * @abstract pause recording
 *
 */
- (void)pauseRecord;
/*
 * @abstract resume recording paused before
 *
 */
- (void)resumeRecord;
/*
 * @abstract stop recording
 *
 */
- (void)stopRecord;
/*
 * @abstract 

 * @result  An Bool value
 *
 */
- (BOOL)isRecording;
/*
 * @abstract 
 * @result  An Bool value
 *
 */
- (BOOL)isPaused;
/*
 *
 *
 */
- (AudioStreamBasicDescription)audioDataFormat;


@end


