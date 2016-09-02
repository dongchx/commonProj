//
//  QKAudioEffect.h
//  QQKala
//
//  Created by frost on 12-7-23.
//  Copyright (c) 2012年 Tencent. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "QKAudioEffectProtocol.h"
#import "AudioEffectCommonDefine.h"


@interface QKAudioEffect : NSObject<QKAudioEffectProtocol>
{
    NSString                *mName; // Effect name
}

@property   (nonatomic, readwrite, retain) NSString      *name;
@end
