//
//  CPAudioEngine.m
//  commonProj
//
//  Created by dongchx on 8/3/16.
//  Copyright © 2016 dongchx. All rights reserved.
//

#import "CPAudioEngine.h"
#import "QKAudioTrack.h"
#import "QKBaseAudioPlayer.h"
#import "QKNetAudioPlayer.h"
#import "QKFileAudioPlayer.h"
#import <MediaPlayer/MPNowPlayingInfoCenter.h>
#import <MediaPlayer/MPMediaItem.h>

@interface CPAudioEngine ()

@property (nonatomic, strong) QKAudioTrack          *currentAudioTrack;
@property (nonatomic, strong) QKBaseAudioPlayer     *mAudioPlayer;
@property (nonatomic, assign) NSUInteger            mBgTaskId;
@property (nonatomic, strong) NSTimer               *mTimer;
@property (nonatomic, strong) NSMutableDictionary   *nowPlayingInfo;

@property (nonatomic, assign) NSInteger             indexOfTrack;

@end

@implementation CPAudioEngine

#pragma mark - init

- (void)dealloc
{
    _delegate = nil;
    [self removeNotification];
}

+ (instancetype)sharedInstance
{
    static CPAudioEngine   *audioEngine;
    static dispatch_once_t onceToken;
    
    dispatch_once(&onceToken, ^{
        audioEngine = [[CPAudioEngine alloc] init];
    });
    
    return audioEngine;
}

- (instancetype)init
{
    if (self = [super init]) {
        _mTimer = [NSTimer scheduledTimerWithTimeInterval:1.0
                                                   target:self
                                                 selector:@selector(timerHandle)
                                                 userInfo:nil
                                                  repeats:YES];
        [self timerPause];
    }
    
    return self;
}

- (void)setTrackArray:(NSArray *)trackArray
{
    _trackArray = trackArray;
    _indexOfTrack = 0;
    [self makePlayAudioTrack:_indexOfTrack];
}

#pragma mark - Audio API

- (AudioStreamerErrorCode)currentError
{
    if (_mAudioPlayer != nil) {
        
        return _mAudioPlayer.errorCode;
    }
    
    return AS_NO_ERROR;
}

- (AudioStreamerState)currentState
{
    if (_mAudioPlayer != nil) {
        
        return _mAudioPlayer.state;
    }
    
    return AS_INITIALIZED;
}

- (void)playAudioTrack:(QKAudioTrack *)audioTrack
{
    if (audioTrack != nil) {
        
        if (_currentAudioTrack != nil) {
            if ([_currentAudioTrack.musicID isEqualToString:audioTrack.musicID]) {
                return;
            }
        }
        
        if (_mAudioPlayer != nil) {
            [_mAudioPlayer stop];
        }
        
        [[AudioEngineHelper sharedInstance] resetAudioCategoryForPlayOnly];
        _currentAudioTrack = audioTrack;
        
        // 获取正确的AudioPlayer
        if (audioTrack.type == AudioTrackTypeNetwork) {
            _mAudioPlayer = [[QKNetAudioPlayer alloc] initWithNetURL:_currentAudioTrack.url];
            _mAudioPlayer.delegate = self;
            
        } else if (audioTrack.type == AudioTrackTypeAccompanimentFile) {
            
            if (![self isFileExistAtPath:_currentAudioTrack.filePath]) {
                
                [self onPlayerEventChanged:PlayEventErrorOfNoFile description:nil];
                return;
            }
            _mAudioPlayer = [[QKFileAudioPlayer alloc] initWithFilePath:_currentAudioTrack.filePath];
        }
        
        if (_mAudioPlayer == nil) {
            
            [self onPlayerEventChanged:PlayEventError description:nil];
            return;
        }
        
        // play
        [_mAudioPlayer play];
        [self timerStart];
        [self configNowPlayingInfoCenter];
        [self startBackgroundTask];
        [self onPlayerEventChanged:PlayEventAudioTrackChanged description:nil];
        
        // add Notification
        [self addNotification];
    }
}

- (void)addNotification
{
    // remote config
    [[UIApplication sharedApplication] beginReceivingRemoteControlEvents];
    [[UIApplication sharedApplication] becomeFirstResponder];
}

- (void)removeNotification
{
    // remote config
    [[UIApplication sharedApplication] endReceivingRemoteControlEvents];
    [[UIApplication sharedApplication] resignFirstResponder];
}

- (void)pause
{
    if (_mAudioPlayer != nil) {
        
        [_mAudioPlayer pause];
        [self timerPause];
    }
}

- (void)resume
{
    if (_mAudioPlayer != nil) {
        
        [_mAudioPlayer resume];
        [self timerStart];
    }
}

- (void)stop
{
    if (_mAudioPlayer != nil) {
        
        [_mAudioPlayer stop];
        [self timerPause];
        //        [self removeNotification];
    }
}

- (BOOL)isPlaying
{
    if (_mAudioPlayer != nil) {
        
        return [_mAudioPlayer isPlaying];
    }
    return NO;
}

- (float)volume
{
    return [[AudioEngineHelper sharedInstance] currentVolume];
}

- (BOOL)seekToTime:(double)second
{
    if (_mAudioPlayer != nil) {
        
        if ([_mAudioPlayer isSeekable]) {
            [_mAudioPlayer seekToTime:second];
            return YES;
        }
    }
    return NO;
}

- (double)progressTime
{
    if (_mAudioPlayer != nil) {
        
        return [_mAudioPlayer progress];
    }
    return 0.0;
}

- (double)durationTime
{
    if (_mAudioPlayer != nil) {
        
        return [_mAudioPlayer duration];
    }
    return 0.0;
}

- (double)durationTimeCanPlay
{
    if (_mAudioPlayer != nil) {
        
        return [_mAudioPlayer durationCanPlay];
    }
    return 0.0;
}

- (void)nextTrack:(id)sender
{
    if (_indexOfTrack >= _trackArray.count-1) {
        return;
    }
    _indexOfTrack += 1;
    [self makePlayAudioTrack:_indexOfTrack];
}

- (void)previousTrack:(id)sender
{
    if (_indexOfTrack <= 0) {
        return;
    }
    _indexOfTrack -= 1;
    [self makePlayAudioTrack:_indexOfTrack];
}

- (void)makePlayAudioTrack:(NSUInteger)index
{
    if (index > _trackArray.count-1) {
        return;
    }
    
    QKAudioTrack *audioTrack = [self audioTrack];
    audioTrack.url = (NSString *)_trackArray[index];
    [self playAudioTrack:audioTrack];
    
    //    [self refreshButtonState];
    if (_delegate && [_delegate respondsToSelector:@selector(refreshButtonState:)]) {
        [_delegate refreshButtonState:index];
    }
}

//=================test==========================
- (QKAudioTrack *)audioTrack
{
    QKAudioTrack *audioTrack = [[QKAudioTrack alloc] init];
    audioTrack.type = AudioTrackTypeNetwork;
    audioTrack.songName = @"第一章";
    audioTrack.albumName = @"未知";
    audioTrack.artistName = @"未知";
    audioTrack.cover = [UIImage imageNamed:@"playDefault"];
    
    return audioTrack;
    
    //    [_audioEngine playAudioTrack:audioTrack];
}

#pragma mark - funcion

- (BOOL)isFileExistAtPath:(NSString*)filePath
{
    NSFileManager* fileManger = [[NSFileManager alloc] init];
    
    BOOL fileExist = NO;
    @try
    {
        fileExist = [fileManger fileExistsAtPath:filePath];
    }
    @catch (NSException * e)
    {
    }
    @finally
    {
        
    }
    return fileExist;
}

- (void)startBackgroundTask
{
    if (![UIDevice currentDevice].multitaskingSupported) {
        return;
    }
    
    NSUInteger newTaskId = UIBackgroundTaskInvalid;
    newTaskId = [[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler:^
                 {
                     if (_mBgTaskId != UIBackgroundTaskInvalid)
                     {
                         [[UIApplication sharedApplication] endBackgroundTask:_mBgTaskId];
                     }
                     _mBgTaskId = UIBackgroundTaskInvalid;
                 } ];
    
    if (newTaskId != UIBackgroundTaskInvalid && _mBgTaskId != UIBackgroundTaskInvalid)
    {
        [[UIApplication sharedApplication] endBackgroundTask: _mBgTaskId];
    }
    _mBgTaskId = newTaskId;
}

- (void)onPlayerEventChanged:(PlayEventType)type description:(NSString *)desc
{
    if (_delegate != nil
        && [_delegate respondsToSelector:@selector(playEventChanged:description:)]) {
        [_delegate playEventChanged:type description:desc];
    }
}

#pragma mark - playerDelegate

- (void)player:(id<QKPlayerProtocol>)player playerEventChanged:(PlayEventType)type description:(NSString *)desc
{
    if (player == _mAudioPlayer) {
        
        [self onPlayerEventChanged:type description:desc];
    }
}

#pragma mark - remote event

/**
 *响应远程播放控制消息
 */

- (void)remoteremoteControlReceivedWithEvent:(UIEvent *)receivedEvent
{
    if (receivedEvent.type == UIEventTypeRemoteControl) {
        
        switch (receivedEvent.subtype) {
            case UIEventSubtypeRemoteControlPause:
                
                // pause
                [self pause];
                break;
                
            case UIEventSubtypeRemoteControlPlay:
                // resume
                [self resume];
                break;
                
            case UIEventSubtypeRemoteControlNextTrack:
                // next
                [self nextTrack:nil];
                break;
                
            case UIEventSubtypeRemoteControlPreviousTrack:
                // previous
                [self previousTrack:nil];
                break;
                
            case UIEventSubtypeRemoteControlTogglePlayPause:
                // 耳机线控事件，播放和暂停
                if ([self isPlaying]) {
                    [self pause];
                    
                } else {
                    [self resume];
                }
                
                break;
            default:
                break;
        }
    }
}

#pragma mark - NowPlayingInfoCenter

/**
 *设置锁屏信息
 *
 */

-(void)configNowPlayingInfoCenter
{
    NSMutableDictionary *dict = [[NSMutableDictionary alloc] init];
    
    // 书名
    [dict setObject:_currentAudioTrack.albumName forKey:MPMediaItemPropertyAlbumTitle];
    // 章节
    [dict setObject:_currentAudioTrack.songName forKey:MPMediaItemPropertyTitle];
    // 作者
    [dict setObject:_currentAudioTrack.artistName forKey:MPMediaItemPropertyArtist];
    // 书封
    [dict setObject:[[MPMediaItemArtwork alloc] initWithImage:_currentAudioTrack.cover]
             forKey:MPMediaItemPropertyArtwork];
    // 剩余时长
    [dict setObject:[NSNumber numberWithDouble:[self durationTime]]
             forKey:MPMediaItemPropertyPlaybackDuration];
    // 播放时间
    [dict setObject:[NSNumber numberWithDouble:[self progressTime]]
             forKey:MPNowPlayingInfoPropertyElapsedPlaybackTime];
    
    _nowPlayingInfo = dict;
    
    [[MPNowPlayingInfoCenter defaultCenter] setNowPlayingInfo:_nowPlayingInfo];
}

#pragma mark - Timer

/**
 *定时器
 */

- (void)timerHandle
{
    if (_isBackground) {
        if (_nowPlayingInfo) {
            // 剩余时长
            [_nowPlayingInfo setObject:[NSNumber numberWithDouble:[self durationTime]]
                                forKey:MPMediaItemPropertyPlaybackDuration];
            // 播放时间
            [_nowPlayingInfo setObject:[NSNumber numberWithDouble:[self progressTime]]
                                forKey:MPNowPlayingInfoPropertyElapsedPlaybackTime];
            
            [[MPNowPlayingInfoCenter defaultCenter] setNowPlayingInfo:_nowPlayingInfo];
        }
        return;
    }
    
    if (_delegate &&
        [_delegate respondsToSelector:@selector(player:durationTime:validTime:progressTime:)]) {
        
        [_delegate player:_mAudioPlayer
             durationTime:[self durationTime]
                validTime:[self durationTimeCanPlay]
             progressTime:[self progressTime]];
    }
}

- (void)timerStart
{
    _mTimer.fireDate = [NSDate date];
}

- (void)timerPause
{
    _mTimer.fireDate = [NSDate distantFuture];
}

@end






































