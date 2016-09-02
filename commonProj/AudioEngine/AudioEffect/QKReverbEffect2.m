//
//  QKReverbEffect2.m
//  QQKala
//
//  Created by frost on 12-8-22.
//  Copyright (c) 2012年 Tencent. All rights reserved.
//

#import "QKReverbEffect2.h"

int k16BitDeapth = 16;
int k8BitDeapth = 8;

char* argv[10] = {"","","","reverb","90","90","100","100","50","10"};

@implementation QKReverbEffect2

#pragma mark life cycle
- (void)dealloc
{
    [super dealloc];
}

- (id)initWithChannels:(int)channels inSignalSampleRate:(unsigned int)rate
{
    if(!(self = [super init])) return nil;
    
    super.name = @"reverb2";
    initResult = init(rate, channels, 16);
    
    return self;
}

#pragma mark QKAudioEffectProtocol
- (int)start
{
    return 0;
}

- (int)flow:(char*)iBuf outBuffer:(char*)obuf bufferLen:(int)len
{
    int outbufSize = len;
    return doReverb(iBuf, len, &obuf, &outbufSize, argv);
}

- (int)stop
{
    return uninit();;
}

@end
