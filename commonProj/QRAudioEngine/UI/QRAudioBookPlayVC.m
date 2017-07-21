//
//  QRAudioBookPlayVC.m
//  commonProj
//
//  Created by dongchx on 12/23/16.
//  Copyright © 2016 dongchx. All rights reserved.
//

#import "QRAudioBookPlayVC.h"
#import "QRAudioTrack+Provider.h"
#import "QRAudioBookEngine.h"
#import "QRAudioBookEngine.h"
#import "Masonry.h"
#import "EXTKeyPathCoding.h"

//===========================
#import <AudioToolbox/AudioToolbox.h>
#import <AVFoundation/AVFoundation.h>
//===========================

@interface QRAudioBookPlayVC ()
<QRAudioEngineDelegate>

@property (nonatomic, weak) QRAudioBookEngine *audioEngine;

@property (nonatomic, strong) UILabel *durationLab;
@property (nonatomic, strong) UILabel *progressLab;
@property (nonatomic, strong) UILabel *downloadLab;

@property (nonatomic, strong) UIButton *playBtn;
@property (nonatomic, strong) UIButton *nextBtn;
@property (nonatomic, strong) UIButton *prevBtn;

@end

@implementation QRAudioBookPlayVC

- (void)dealloc
{
    _audioEngine.delegate = nil;
    _audioEngine = nil;
    
    // 初始化方法
    extern OSStatus AudioSessionInitialize(CFRunLoopRef inRunLoop,
                                           CFStringRef inRunLoopMode,
                                           AudioSessionInterruptionListener inInterruptionListener,
                                           void *inClientData);
    
    typedef void (*AudioSessionInterruptionListener)(void *inClientData, UInt32 inInterruptionState);
    
    // 设置类别
    extern OSStatus
    AudioSessionSetProperty(AudioSessionPropertyID inID,
                            UInt32 inDataSize,
                            const void *inData);
    
    extern OSStatus
    AudioSessionAddPropertyListener(AudioSessionPropertyID inID,
                                    AudioSessionPropertyListener inProc,
                                    void *inClientData);
    
    typedef void (*AudioSessionPropertyListener)(void *                 inClientData,
                                                 AudioSessionPropertyID	inID,
                                                 UInt32                 inDataSize,
                                                 const void *           inData);
    
    
    extern OSStatus
    AudioFileStreamOpen (void * __nullable						    inClientData,
                         AudioFileStream_PropertyListenerProc       inPropertyListenerProc,
                         AudioFileStream_PacketsProc				inPacketsProc,
                         AudioFileTypeID							inFileTypeHint,
                         AudioFileStreamID __nullable * __nonnull   outAudioFileStream);
    
    //
    
    extern OSStatus
    AudioFileStreamParseBytes(AudioFileStreamID				inAudioFileStream,
                              UInt32						inDataByteSize,
                              const void *					inData,
                              AudioFileStreamParseFlags		inFlags);
    
    
    extern OSStatus
    AudioFileStreamGetProperty(
                               AudioFileStreamID            inAudioFileStream,
                               AudioFileStreamPropertyID	inPropertyID,
                               UInt32 *						ioPropertyDataSize,
                               void *						outPropertyData);
    
    double audioDataByteCount, bitRate;
    
    
    double duration = (audioDataByteCount * 8) / bitRate;
    
    
}

- (instancetype)init
{
    if (self = [super init]) {
        _audioEngine = [QRAudioBookEngine shareInstance];
        
    }
    
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    [_audioEngine setTracks:[QRAudioTrack remoteTracks:@[]]];
    
    [self setupSubviews:self.view];
    _audioEngine.delegate = self;
}

- (void)setupSubviews:(UIView *)parentView
{
    parentView.backgroundColor = [UIColor whiteColor];
    
    UILabel *progressLab = [[UILabel alloc] init];
    [parentView addSubview:progressLab];
    [progressLab mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(parentView).offset(20.);
        make.right.equalTo(parentView).offset(-20);
        make.top.equalTo(parentView).offset(70.);
    }];
    
    UILabel *durationLab = [[UILabel alloc] init];
    [parentView addSubview:durationLab];
    [durationLab mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(progressLab);
        make.right.equalTo(progressLab);
        make.top.equalTo(progressLab.mas_bottom).offset(10.);
    }];
    
    UILabel *downloadLab = [[UILabel alloc] init];
    [parentView addSubview:downloadLab];
    [downloadLab mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(durationLab);
        make.right.equalTo(durationLab);
        make.top.equalTo(durationLab.mas_bottom).offset(10.);
    }];
    
    NSArray<UILabel *> *labels = @[progressLab, durationLab, downloadLab,];
    
    for (UILabel *label in labels) {
        label.font = [UIFont systemFontOfSize:12];
        label.textColor = [UIColor blackColor];
        label.backgroundColor = [UIColor yellowColor];
    }
    
    _durationLab = durationLab;
    _progressLab = progressLab;
    _downloadLab = downloadLab;
    
    //==============================================================================//
    
    //控制按钮
    //
    _playBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    [parentView addSubview:_playBtn];
    [_playBtn mas_makeConstraints:^(MASConstraintMaker *make) {
        make.centerX.equalTo(parentView);
        make.centerY.equalTo(parentView);
        make.width.height.equalTo(@50);
    }];
    [_playBtn setTitle:@"暂停" forState:UIControlStateNormal];
    [_playBtn setTitle:@"开始" forState:UIControlStateHighlighted];
    
    _nextBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    [parentView addSubview:_nextBtn];
    [_nextBtn mas_makeConstraints:^(MASConstraintMaker *make) {
        make.centerY.equalTo(_playBtn);
        make.left.equalTo(_playBtn.mas_right).offset(16.);
        make.width.height.equalTo(@40);
    }];
    [_nextBtn setTitle:@"下一首" forState:UIControlStateNormal];
    [_nextBtn setTitle:@"点不了" forState:UIControlStateDisabled];
    
    _prevBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    [parentView addSubview:_prevBtn];
    [_prevBtn mas_makeConstraints:^(MASConstraintMaker *make) {
        make.centerY.equalTo(_playBtn);
        make.right.equalTo(_playBtn.mas_left).offset(16.);
        make.width.height.equalTo(@40);
    }];
    [_prevBtn setTitle:@"上一首" forState:UIControlStateNormal];
    [_prevBtn setTitle:@"点不了" forState:UIControlStateDisabled];
}

#pragma mark - Event

- (void)playButtonAction:(UIButton *)sender
{
    
}

- (void)nextButtonAction:(UIButton *)sender
{
    
}

- (void)prevButtonAction:(UIButton *)sender
{
    
}

#pragma mark - AudioEngineDelegate

- (void)onAudioEngineChangedStatus:(QRAudioStreamerStatus)status
{
    
}

- (void)onAudioEngineChangedDuratin:(double)duration
                        currentTime:(double)currentTime
{
    _durationLab.text = [NSString stringWithFormat:@"duration:%.2f", duration];
    _progressLab.text = [NSString stringWithFormat:@"progress:%.2f", currentTime];
}

- (void)onAudioEngineChangedReceivedLength:(NSUInteger)receivedLength
                            expectedLength:(NSUInteger)expectedLength
                            bufferingRatio:(double)bufferingRatio
{
    _downloadLab.text = [NSString stringWithFormat:@"%f (receiced %td expected %td)",
                         bufferingRatio,receivedLength, expectedLength];
}


@end

























