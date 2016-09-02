//
//  QKReverbEffect.h
//  QQKala
//
//  Created by frost on 12-7-23.
//  Copyright (c) 2012年 Tencent. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "QKAudioEffect.h"
#import "reverb.h"

@interface QKReverbEffect : QKAudioEffect
{
    reverbstuff         reverb;
    int                 initResult;
}

- (id)initWithReverbTime:(float) reverbTime numDelays:(unsigned short) numDelays delayTimes:(float*)delays inSignalSampleRate:(unsigned int)rate;
@end
