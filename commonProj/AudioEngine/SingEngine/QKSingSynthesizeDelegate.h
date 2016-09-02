//
//  QKSingSynthesizeDelegate.h
//  QQKala
//
//  Created by frost on 12-7-2.
//  Copyright (c) 2012年 Tencent. All rights reserved.
//

#import <Foundation/Foundation.h>

@class QKAudioTrack;
@protocol QKSingSynthesizeDelegate <NSObject>

- (void)synthesizeAudioTrack:(QKAudioTrack*)audioTrack didFinishWithOutput:(QKAudioTrack*)outPutAudioTrack;
- (void)synthesizeAudioTrack:(QKAudioTrack*)audioTrack didFailWithError:(NSError*)error;

@optional
- (void)synthesizeAudioTrack:(QKAudioTrack*)audioTrack didMakeProgress:(CGFloat)progress;

@end
