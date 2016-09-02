//
//  QKReverbEffect2.h
//  QQKala
//
//  Created by frost on 12-8-22.
//  Copyright (c) 2012年 Tencent. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "QKAudioEffect.h"
#import "reverb_i.h"

extern int k16BitDeapth;
extern int k8BitDeapth;

@interface QKReverbEffect2 : QKAudioEffect
{
    int                 initResult;
}

- (id)initWithChannels:(int)channels inSignalSampleRate:(unsigned int)rate;

@end
