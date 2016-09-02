//
//  QKBaseAudioPlayer.m
//  QQKala
//
//  Created by frost on 12-6-14.
//  Copyright (c) 2012年 Tencent. All rights reserved.
//

#import "QKBaseAudioPlayer.h"
#import <MediaPlayer/MediaPlayer.h>

NSString * const ASStatusChangedNotification = @"ASStatusChangedNotification";

// ---------------------------------------------
// QKBaseAudioPlayer private category
// ---------------------------------------------
@interface QKBaseAudioPlayer(Private)

- (void)setState:(AudioStreamerState)state;
- (void)postNotificationOnMainThread;
- (void)onPlaybackStateChanged:(id)notification;

@end

// ---------------------------------------------
// QKBaseAudioPlayer implementation
// ---------------------------------------------
@implementation QKBaseAudioPlayer

@synthesize state = mState;
@synthesize stopReason = mStopReason;
@synthesize errorCode = mErrorCode;
@synthesize delegate = mDelegate;

#pragma mark life cycle

- (void)dealloc
{
    [super dealloc];
}

#pragma mark Private Category
- (void)setState:(AudioStreamerState)state
{
	@synchronized(self)
	{
		if (mState != state)
		{
			mState = state;
			if ([[NSThread currentThread] isEqual:[NSThread mainThread]])
			{
				[self postNotificationOnMainThread];
			}
			else
			{
				[self
				 performSelectorOnMainThread:@selector(postNotificationOnMainThread)
				 withObject:nil
				 waitUntilDone:NO];
			}
		}
	}
}

- (void)postNotificationOnMainThread
{
	NSNotification *notification =[NSNotification notificationWithName:ASStatusChangedNotification
	 object:self];
    
	[[NSNotificationCenter defaultCenter] postNotification:notification];
}

- (void)onPlaybackStateChanged:(id)notification
{
	NSNotification* note = (NSNotification*)notification;
	QKBaseAudioPlayer *player = (QKBaseAudioPlayer *)[note object];
	
	switch (self.state) 
	{
		case AS_PLAYING:

			break;
		case AS_INITIALIZED:
			//[[AppData getInstance] stopHeartBeat];
			if (( player.stopReason != AS_STOPPING_ERROR )
				&&( player.stopReason != AS_STOPPING_NO_DATA )
				&&( player.stopReason != AS_STOPPING_USER_ACTION ))
			{
				[self unRegisterPlayStateChangeNotification];
				[self playEventChanged:PlayEventEnd description:nil];
			}
			break;
		case AS_PAUSED:
		case AS_STOPPED:

			break;
		default:
			break;
	}
}

#pragma mark public function
- (void)playEventChanged:(PlayEventType)type description:(NSString*)desc
{
    if (self.delegate)
    {
        [self.delegate player:self playerEventChanged:type description:desc];
    }
}

- (void)failedWithError:(AudioStreamerErrorCode)error
{
    [self playEventChanged:PlayEventError description:nil];
}

- (void)registerPlayStateChangeNotification
{
    [[NSNotificationCenter defaultCenter] addObserver:self	selector:@selector(onPlaybackStateChanged:)	 name:ASStatusChangedNotification object:self];	
}

- (void)unRegisterPlayStateChangeNotification
{
    [[NSNotificationCenter defaultCenter] removeObserver: self name: ASStatusChangedNotification	object: self];
}

#pragma mark QKPlayerProtocol
- (id)initWithAudioTrack:(QKAudioTrack *)audioTrack
{
    // must be override in subclass
    return nil;
}

- (void)play
{
    // need be override in subclass
}

- (void)pause
{
    // need be override in subclass
}

- (void)resume
{
    // need be override in subclass
}

- (void)stop
{
    // need be override in subclass
}

- (void)setVolume:(float)volume
{
    [[MPMusicPlayerController applicationMusicPlayer] setVolume:volume];
}

- (BOOL)isPlaying
{
    return (self.state == AS_PLAYING || self.state == AS_PLAYING_AND_RECORDING|| self.state == AS_WAITING_FOR_QUEUE_TO_START|| self.state==AS_BUFFERING ||self.state == AS_WAITING_FOR_DATA);
}
- (BOOL)isPaused
{
    return self.state == AS_PAUSED;
}
- (BOOL)isWaiting
{
    return NO;
}
- (double)duration
{
    return 0.0;
}
- (double)durationCanPlay
{
    return 0.0;
}
- (double)progress
{
    return 0.0;
}
- (BOOL)isSeekable
{
    return NO;
}
- (BOOL)seekToTime:(double)newSeekTime
{
    return NO;
}

@end
