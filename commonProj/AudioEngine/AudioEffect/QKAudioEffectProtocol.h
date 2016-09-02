//
//  QKAudioEffectProtocol.h
//  QQKala
//
//  Created by frost on 12-7-23.
//  Copyright (c) 2012年 Tencent. All rights reserved.
//

#import <Foundation/Foundation.h>

@protocol QKAudioEffectProtocol <NSObject>

- (int)start;   // Called to initialize effect
- (int)flow:(char*)iBuf outBuffer:(char*)obuf bufferLen:(int)len;    // Called to process samples
- (int)stop;    // Called to shut down effect

@end
