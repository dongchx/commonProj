//
//  QRAudioBookEngine.m
//  commonProj
//
//  Created by dongchx on 12/21/16.
//  Copyright © 2016 dongchx. All rights reserved.
//

#if !__has_feature(objc_arc)
#error This file must be compiled with ARC. Use -fobjc-arc flag (or convert project to ARC).
#endif

#import "QRAudioBookEngine.h"
#import "QRAudioTrack.h"
#import "DOUAudioStreamer.h"
#import <MediaPlayer/MPNowPlayingInfoCenter.h>
#import <MediaPlayer/MPMediaItem.h>
#import "EXTKeyPathCoding.h"

static void *kStatusKVOKey = &kStatusKVOKey;
static void *kBufferingRatioKVOKey = &kBufferingRatioKVOKey;

@interface QRAudioBookEngine ()

@property (nonatomic, strong) NSArray<id<QRAudioFile>> *tracks;
@property (nonatomic, assign) NSUInteger               currentTrackIndex;
@property (nonatomic, strong) DOUAudioStreamer         *streamer;
@property (nonatomic, strong) NSTimer                  *timer;

@end

@implementation QRAudioBookEngine

#pragma maek -  init

- (void)dealloc
{
    [_timer invalidate];
    _timer = nil;
    [self removeNotification];
}

+ (instancetype)shareInstance
{
    static QRAudioBookEngine  *audioEngine;
    static dispatch_once_t    onceToken;

    dispatch_once(&onceToken, ^{
        audioEngine = [[QRAudioBookEngine alloc] init];
    });
    
    return audioEngine;
}

- (instancetype)init
{
    if (self = [super init]) {
        _currentTrackIndex = 0;
        _timer = [NSTimer scheduledTimerWithTimeInterval:1.
                                                  target:self
                                                selector:@selector(timerHandleAction)
                                                userInfo:nil
                                                 repeats:YES];
        [self timerPause];
        [self registerNotification];
    }
    
    return self;
}

- (void)registerNotification
{
    
}

- (void)removeNotification
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark - streamer

- (void)registerStreamerObserver
{
    [_streamer addObserver:self
                forKeyPath:@"status"
                   options:NSKeyValueObservingOptionNew
                   context:kStatusKVOKey];
    
    [_streamer addObserver:self
                forKeyPath:@"bufferingRatio"
                   options:NSKeyValueObservingOptionNew
                   context:kBufferingRatioKVOKey];
}

- (void)removeStreamerObserver
{
    [_streamer removeObserver:self forKeyPath:@"status"];
    [_streamer removeObserver:self forKeyPath:@"bufferingRatio"];
}

- (void)cancelStreamer
{
    if (_streamer != nil) {
        [_streamer pause];
        [self removeStreamerObserver];
        _streamer = nil;
    }
}

- (void)resetStreamer
{
    [self cancelStreamer];
    if (_tracks.count == 0 || _currentTrackIndex >= _tracks.count) {
        NSLog(@"(No tracks available)");
    }
    else {
        QRAudioTrack *track = [_tracks objectAtIndex:_currentTrackIndex];
        _streamer = [DOUAudioStreamer streamerWithAudioFile:track];
        
        [self registerStreamerObserver];
        [self playOrPause];
        [self configureNowPlayingInfoCenter];
    }
}

- (void)setTracks:(NSArray<id<QRAudioFile>> *)tracks
{
    _tracks = tracks;
    _currentTrackIndex = 0;
    [self resetStreamer];
}

#pragma mark - QRAudioBookProtocol

- (void)playOrPause
{
    if (_streamer.status == DOUAudioStreamerPaused ||
        _streamer.status == DOUAudioStreamerIdle) {
        [_streamer play];
        [self timerStart];
    }
    else {
        [_streamer pause];
        [self timerPause];
    }
}

- (void)stop
{
    [_streamer stop];
    [self timerPause];
}

- (void)setVolum:(float)volum
{
    [[_streamer class] setVolume:volum];
}

- (void)seekToTime:(double)newSeekTime
{
    _streamer.currentTime = newSeekTime;
}

- (double)duration
{
    return _streamer.duration;
}

- (float)playProgressValue
{
//    return _streamer.currentTime/_streamer.duration;
    return _streamer.currentTime;
}

- (float)downloadProgressValue
{
//    return _streamer.receivedLength/_streamer.expectedLength;
    return (float)_streamer.receivedLength;
}

- (float)expectedLengthValue
{
    return (float)_streamer.expectedLength;
}

- (BOOL)haveNextTrack
{
    return _currentTrackIndex < _tracks.count-1;
}

- (BOOL)havePrevTrack
{
    return (_currentTrackIndex > 0 && _tracks.count > 1);
}

- (void)nextTrack
{
    if (self.haveNextTrack) {
        _currentTrackIndex += 1;
        [self resetStreamer];
    }
}

- (void)prevTrack
{
    if (self.havePrevTrack) {
        _currentTrackIndex -= 1;
        [self resetStreamer];
    }
}

- (NSInteger)status
{
    return _streamer.status;
}

#pragma mark - Timer

- (void)timerHandleAction
{
    if (_delegate &&
        [_delegate respondsToSelector:@selector(onAudioEngineChangedDuratin:currentTime:)]) {
        
        [_delegate onAudioEngineChangedDuratin:_streamer.duration
                                   currentTime:_streamer.currentTime];
    }
    
    [self refreshNowPlayingInfoCenter];
}

- (void)timerStart
{
    _timer.fireDate = [NSDate date];
}

- (void)timerPause
{
    _timer.fireDate = [NSDate distantFuture];
}

#pragma mark - remote event

- (void)remoteremoteControlReceivedWithEvent:(UIEvent *)receivedEvent
{
    if (receivedEvent.type == UIEventTypeRemoteControl) {
        
        switch (receivedEvent.subtype) {
            case UIEventSubtypeRemoteControlPause:
            case UIEventSubtypeRemoteControlPlay:
                [self playOrPause];
                break;
                
            case UIEventSubtypeRemoteControlNextTrack:
                // next
                [self nextTrack];
                break;
                
            case UIEventSubtypeRemoteControlPreviousTrack:
                // previous
                [self prevTrack];
                break;
                
            case UIEventSubtypeRemoteControlTogglePlayPause:
                // 耳机线控事件，播放和暂停
                [self playOrPause];
                break;
            default:
                break;
        }
    }
}

#pragma mark - NowPlayingInfoCenter

- (void)configureNowPlayingInfoCenter
{
    NSMutableDictionary *dict = [[NSMutableDictionary alloc] init];
    
    //书名
    [dict setObject:@"腾讯传" forKey:MPMediaItemPropertyAlbumTitle];
    //章节
    [dict setObject:@"第一章" forKey:MPMediaItemPropertyTitle];
    //作者
    [dict setObject:@"小马哥" forKey:MPMediaItemPropertyArtist];
    
    [[MPNowPlayingInfoCenter defaultCenter] setNowPlayingInfo:dict];
}

- (void)refreshNowPlayingInfoCenter
{
    NSMutableDictionary *info =
    [NSMutableDictionary dictionaryWithDictionary:[[MPNowPlayingInfoCenter defaultCenter] nowPlayingInfo]];
    
    // duration
    [info setObject:[NSNumber numberWithDouble:_streamer.duration]
             forKey:MPMediaItemPropertyPlaybackDuration];
    // 播放时间
    [info setObject:[NSNumber numberWithDouble:_streamer.currentTime]
             forKey:MPNowPlayingInfoPropertyElapsedPlaybackTime];
    
    [[MPNowPlayingInfoCenter defaultCenter] setNowPlayingInfo:info];
}

#pragma mark - KVO

- (void)updateStreamerStatus
{
//    NSLog(@"status");
    if (_streamer.status == DOUAudioStreamerFinished) {
//        NSLog(@"status Finish");
        [self nextTrack];
    }
}

- (void)updateStreamerBufferingStatus
{
//    NSLog(@"%f", _streamer.bufferingRatio);
    
    if (_delegate &&
        [_delegate respondsToSelector:@selector(onAudioEngineChangedReceivedLength:expectedLength:bufferingRatio:)]) {
        [_delegate onAudioEngineChangedReceivedLength:_streamer.receivedLength
                                       expectedLength:_streamer.expectedLength
                                       bufferingRatio:_streamer.bufferingRatio];
    }
}

#pragma mark - KVO

- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary<NSKeyValueChangeKey,id> *)change
                       context:(void *)context
{
    if (context == kStatusKVOKey) {
//        [self updateStreamerStatus];
        [self performSelector:@selector(updateStreamerStatus)
                     onThread:[NSThread mainThread]
                   withObject:nil
                waitUntilDone:NO];
    }
    else if (context == kBufferingRatioKVOKey) {
//        [self updateStreamerBufferingStatus];
        [self performSelector:@selector(updateStreamerBufferingStatus)
                     onThread:[NSThread mainThread]
                   withObject:nil
                waitUntilDone:NO];
    }
}

@end

























