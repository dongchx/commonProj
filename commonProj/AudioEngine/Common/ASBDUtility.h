//
//  ASBDUtility.h
//  QQKala
//
//  Created by frost on 12-6-6.
//  Copyright (c) 2012年 Tencent. All rights reserved.
//

#import <Foundation/Foundation.h>
#include <AudioToolbox/AudioToolbox.h>
#import "AudioCommonDefine.h"

@interface ASBDUtility : NSObject

+ (void)setASBD:(AudioStreamBasicDescription*)audioFormatPtr formatID:(UInt32) formatID numChannels:(NSUInteger)numChannels sampleRate:(UInt32)sampleRate;

+ (void)setCanonical:(AudioStreamBasicDescription*)audioFormatPtr numChannels:(NSUInteger)numChannels sampleRate:(UInt32)sampleRate isInterleaved:(BOOL)isInterleaved;

+ (void)setAudioUnitASBD:(AudioStreamBasicDescription *)audioFormatPtr numChannels:(NSUInteger)numChannels sampleRate:(UInt32)sampleRate;

+ (void)printASBD:(AudioStreamBasicDescription) asbd;

@end
