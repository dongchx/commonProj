//
//  QKBaseAudioPlayer.h
//  QQKala
//
//  Created by frost on 12-6-14.
//  Copyright (c) 2012年 Tencent. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "QKPlayerProtocol.h"
#import "AudioCommonDefine.h"


@interface QKBaseAudioPlayer : NSObject<QKPlayerProtocol>
{
    AudioStreamerState          mState;
    AudioStreamerStopReason     mStopReason;
    AudioStreamerErrorCode      mErrorCode;
    id<PlayerDelegate>          mDelegate;
}

@property (nonatomic, assign) AudioStreamerState			state;
@property (nonatomic, assign) AudioStreamerStopReason       stopReason;
@property (nonatomic, assign) AudioStreamerErrorCode        errorCode;
@property (nonatomic, assign) id<PlayerDelegate>            delegate;


- (void)playEventChanged:(PlayEventType)type description:(NSString*)desc;
- (void)failedWithError:(AudioStreamerErrorCode)error;
- (void)registerPlayStateChangeNotification;
- (void)unRegisterPlayStateChangeNotification;
@end
