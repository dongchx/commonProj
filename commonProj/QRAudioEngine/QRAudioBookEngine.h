//
//  QRAudioBookEngine.h
//  commonProj
//
//  Created by dongchx on 12/21/16.
//  Copyright © 2016 dongchx. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "QRAudioBookProtocol.h"

typedef NS_ENUM(NSUInteger, QRAudioStreamerStatus) {
    QRAudioStreamerPlaying = 0,
    QRAudioStreamerPaused,
    QRAudioStreamerIdle,
    QRAudioStreamerFinished,
    QRAudioStreamerBuffering,
    QRAudioStreamerError
};

@protocol QRAudioFile;

@protocol QRAudioEngineDelegate <NSObject>

- (void)onAudioEngineChangedDuratin:(double)duration
                        currentTime:(double)currentTime;

- (void)onAudioEngineChangedStatus:(QRAudioStreamerStatus)status;

- (void)onAudioEngineChangedReceivedLength:(NSUInteger)receivedLength
                            expectedLength:(NSUInteger)expectedLength
                            bufferingRatio:(double)bufferingRatio;


@end

@interface QRAudioBookEngine : NSObject<QRAudioBookProtocol>

@property (nonatomic, weak) id<QRAudioEngineDelegate> delegate;

+ (instancetype)shareInstance;

- (void)setTracks:(NSArray<id<QRAudioFile>> *)tracks;

@end
