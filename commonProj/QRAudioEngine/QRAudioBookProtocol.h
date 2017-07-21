//
//  QRAudioBookProtocol.h
//  commonProj
//
//  Created by dongchx on 12/21/16.
//  Copyright © 2016 dongchx. All rights reserved.
//

#import <Foundation/Foundation.h>

/* AudioBook Protocol
 */
@protocol QRAudioBookProtocol <NSObject>

- (void)playOrPause;
- (void)stop;
- (void)setVolum:(float)volum;
- (void)seekToTime:(double)newSeekTime;

//- (BOOL)isPlaying;
//- (BOOL)isPaused;
//- (BOOL)isWaiting;
- (double)duration;
- (float)playProgressValue;
- (float)downloadProgressValue;
- (float)expectedLengthValue;

- (void)nextTrack;
- (void)prevTrack;
- (BOOL)haveNextTrack;
- (BOOL)havePrevTrack;

- (NSInteger)status;

@end
