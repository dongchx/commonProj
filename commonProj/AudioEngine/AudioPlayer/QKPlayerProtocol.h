//
//  QKPlayerProtocol.h
//  QQKala
//
//  Created by frost on 12-6-11.
//  Copyright (c) 2012年 Tencent. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "AudioCommonDefine.h"
#import "QKAudioTrack.h"

/* Player Protocol*/
@protocol QKPlayerProtocol <NSObject>
- (void)play;
- (void)pause;
- (void)resume;
- (void)stop;
- (void)setVolume:(float)volume;
- (BOOL)isPlaying;
- (BOOL)isPaused;
- (BOOL)isWaiting;
- (double)duration;
- (double)durationCanPlay;
- (double)progress;
- (BOOL)isSeekable;
- (BOOL)seekToTime:(double)newSeekTime;

@end

/* Player Delegate*/
@protocol PlayerDelegate <NSObject>

- (void)player:(id<QKPlayerProtocol>)player playerEventChanged:(PlayEventType)type description:(NSString*)desc;

@end

/* Channel protocol for player
 *
 * implement this protocol, to supply channel switch support
 */
@protocol QKMultiChannelProtocol <NSObject>

/*
 @discussion        切换音频输入通道(audio line)的声道
 @param channel     left or right sound channel
 */
- (void)switchAudioChannel:(SoundChannel)channel;

/*
 @discussion        获取当前音频输入通道(audio line)的声道
 @result            left or right sound channel
 */
- (SoundChannel)getCurrentAudioChannel;

/*
 @discussion        开关音频输入通道(audio line),如果打开，则通过mic输入的语音直接通过扬声器播出，vice versa
 @param enable      on or off
 */
- (void)enableVoiceInputBus:(BOOL)enable;

/* 
 @discussion        改变语音输入通道(mic line)音量增益 
 @param gain        Linear Gain, 0.01->1
 */
- (void)changeVoiceInputBusGain:(Float32)gain;

/* 
 @discussion        获取语音输入通道(mic line)音量增益 
 @return            Linear Gain, 0～1
 */
- (Float32)getVoiceInputBusGain;

/* 
 @discussion        改变音频输入通道(audio line)音量增益
 @param gain        Linear Gain, 0.01->1
 */
- (void)changeAudioBusGain:(Float32)gain;

/* 
 @discussion        获取音频输入通道(audio line)音量增益 
 @return            Linear Gain, 0～1
 */
- (Float32)getAudioBusGain;

/* 
 @discussion        改变输出音量(out put)增益
 @param gain        Linear Gain, 0.01->1
 */
- (void)changeOputGain:(Float32)gain;

@end
