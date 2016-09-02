//
//  QKAudioEffect.m
//  QQKala
//
//  Created by frost on 12-7-23.
//  Copyright (c) 2012年 Tencent. All rights reserved.
//

#import "QKAudioEffect.h"

// ---------------------------------------------
// QKAudioEffect private category
// ---------------------------------------------
@interface QKAudioEffect()
@end

// ---------------------------------------------
// QKAudioEffect implementation
// ---------------------------------------------
@implementation QKAudioEffect
@synthesize name = mName;

#pragma mark life cycle
- (void)dealloc
{
    self.name = nil;
    [super dealloc];
}

- (id)init
{
    if(!(self = [super init])) return nil;
    return self;
}

#pragma mark QKAudioEffectProtocol
- (int)start
{
    // need be override by subclass
    return QK_AUDIO_EFFECT_OK;
}

- (int)flow:(char*)iBuf outBuffer:(char*)obuf bufferLen:(int)len
{
    // need be override by subclass
    return QK_AUDIO_EFFECT_OK;
}

- (int)stop
{
    // need be override by subclass
    return QK_AUDIO_EFFECT_OK;
}
@end
