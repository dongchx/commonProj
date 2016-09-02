//
//  QKReverbEffect.m
//  QQKala
//
//  Created by frost on 12-7-23.
//  Copyright (c) 2012年 Tecnent. All rights reserved.
//

#import "QKReverbEffect.h"

// ---------------------------------------------
// QKReverbEffect private category
// ---------------------------------------------
@interface QKReverbEffect()
@end

// ---------------------------------------------
// QKReverbEffect implementation
// ---------------------------------------------
@implementation QKReverbEffect
#pragma mark life cycle
- (void)dealloc
{
    [self stop];
    [super dealloc];
}

- (id)initWithReverbTime:(float) reverbTime numDelays:(unsigned short) numDelays delayTimes:(float*)delays inSignalSampleRate:(unsigned int)rate
{
    if(!(self = [super init])) return nil;
    
    super.name = @"reverb";
    initResult = reverb_init(&reverb, rate, numDelays, reverbTime, delays);
    
    return self;
}
#pragma mark QKAudioEffectProtocol
- (int)start
{
    return reverb_start(&reverb);
}

- (int)flow:(char*)iBuf outBuffer:(char*)obuf bufferLen:(int)len
{
    return reverb_flow(&reverb, (short*)iBuf, (short*)obuf, len / 2);
}

- (int)stop
{
    return reverb_stop(&reverb);
}
@end
