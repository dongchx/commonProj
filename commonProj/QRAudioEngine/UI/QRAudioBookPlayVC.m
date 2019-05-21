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
#import <WebKit/WebKit.h>
//===========================

@interface QRAudioBookPlayVC ()
<QRAudioEngineDelegate, UIWebViewDelegate, WKNavigationDelegate>

@property (nonatomic, weak) QRAudioBookEngine *audioEngine;

@property (nonatomic, strong) UILabel *durationLab;
@property (nonatomic, strong) UILabel *progressLab;
@property (nonatomic, strong) UILabel *downloadLab;

@property (nonatomic, strong) UIButton *playBtn;
@property (nonatomic, strong) UIButton *nextBtn;
@property (nonatomic, strong) UIButton *prevBtn;

@property (nonatomic, strong) AVPlayer *playerA;
@property (nonatomic, strong) AVPlayer *playerB;

@property (nonatomic, strong) UIWebView *webView;
@property (nonatomic, strong) WKWebView *wkWebView;

@end

@implementation QRAudioBookPlayVC

- (void)dealloc
{
    _audioEngine.delegate = nil;
    _audioEngine = nil;
}

- (instancetype)init
{
    if (self = [super init]) {
//        _audioEngine = [QRAudioBookEngine shareInstance];
//        [[AVAudioSession sharedInstance] setActive:YES error:nil];
//        [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategorySoloAmbient
//                                               error:nil];
//
//        [[NSNotificationCenter defaultCenter] addObserver:self
//                                                 selector:@selector(playerItemBecameCurrent:)
//                                                     name:AVPlayerItemNewAccessLogEntryNotification
//                                                   object:nil];
        [self registerNotifications];
    }
    
    return self;
}

- (void)registerNotifications
{
    NSNotificationCenter *defaultCenter = [NSNotificationCenter defaultCenter];
//    [defaultCenter addObserver:self
//                      selector:@selector(handleAVPlayerItemCurrentNotification:)
//                          name:@"AVPlayerItemBecameCurrentNotification"
//                        object:nil];
    [defaultCenter addObserver:self
                      selector:@selector(handleAVPlayerItemCurrentNotification:)
                          name:UIWindowDidBecomeHiddenNotification
                        object:nil];
}

- (void)handleAVPlayerItemCurrentNotification:(NSNotification *)noti
{
    NSLog(@"statrt");
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
//    [_audioEngine setTracks:[QRAudioTrack remoteTracks:@[]]];
    
//    [self _setupSubviews:self.view];
//    _audioEngine.delegate = self;
    
    [self _setupWebView:self.view];
//    [self _setupWkWebView:self.view];
    
//    [_webView stringByEvaluatingJavaScriptFromString:@""];
}

- (void)_setupWebView:(UIView *)parentView
{
    _webView = [[UIWebView alloc] init];
    [parentView addSubview:_webView];
    _webView.delegate =  self;
    
    _webView.allowsInlineMediaPlayback = YES;
    
    NSURLRequest *request = [NSURLRequest requestWithURL:[NSURL URLWithString:@"https://www.baidu.com"]];
    [_webView loadRequest:request];
    
    [_webView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.edges.equalTo(parentView);
    }];
}

- (void)_setupWkWebView:(UIView *)parentView
{
    WKWebViewConfiguration *config = [[WKWebViewConfiguration alloc] init];
    config.allowsInlineMediaPlayback = YES;
    _wkWebView = [[WKWebView alloc] initWithFrame:CGRectZero configuration:config];
    [parentView addSubview:_wkWebView];
    
    _wkWebView.navigationDelegate = self;
    
    NSURLRequest *request = [NSURLRequest requestWithURL:[NSURL URLWithString:@"https://www.baidu.com"]];
    [_wkWebView loadRequest:request];
    
    [_wkWebView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.edges.equalTo(parentView);
    }];
}

- (void)webView:(WKWebView *)webView didFinishNavigation:(WKNavigation *)navigation
{
//    NSString *videoStr = @"$('video').attr('playsinline', 'true');";
//    [webView evaluateJavaScript:videoStr completionHandler:nil];
    
    NSString *videoStr = @"var observer1 = new PerformanceObserver((list) => {\
    for (var entry of list.getEntries()) {\
    var metricName = entry.name;\
    alert(metricName);\
    }\
    });\
    observer1.observe({entryTypes: ['paint']});";
    
    [webView evaluateJavaScript:videoStr completionHandler:nil];
}

- (void)webView:(WKWebView *)webView didStartProvisionalNavigation:(WKNavigation *)navigation
{
    NSString *videoStr = @"var observer1 = new PerformanceObserver((list) => {\
    for (var entry of list.getEntries()) {\
    var metricName = entry.name;\
    alert(metricName);\
    }\
    });\
    observer1.observe({entryTypes: ['paint']});";
    
    [webView evaluateJavaScript:videoStr completionHandler:nil];
}

- (void)webViewDidFinishLoad:(UIWebView *)webView
{
    NSString *videoStr = @"alert('h')";
    
    [webView stringByEvaluatingJavaScriptFromString:videoStr];
}

- (void)webViewDidStartLoad:(UIWebView *)webView
{
    NSString *videoStr = @"var observer1 = new PerformanceObserver((list) => {\
    for (var entry of list.getEntries()) {\
    var metricName = entry.name;\
    alert(metricName);\
    }\
    });\
    observer1.observe({entryTypes: ['paint']});";
    
    [webView stringByEvaluatingJavaScriptFromString:videoStr];
}

- (void)_setupSubviews:(UIView *)parentView
{
    parentView.backgroundColor = UIColor.whiteColor;
    UIButton *btnA = [UIButton buttonWithType:UIButtonTypeCustom];
    [parentView addSubview:btnA];
    btnA.frame = CGRectMake(100, 100, 100, 60);
    [btnA setTitle:@"btnA" forState:UIControlStateNormal];
    [btnA addTarget:self action:@selector(btnAAction:) forControlEvents:UIControlEventTouchUpInside];
    btnA.backgroundColor = UIColor.yellowColor;
    
    UIButton *btnB = [UIButton buttonWithType:UIButtonTypeCustom];
    [parentView addSubview:btnB];
    btnB.frame = CGRectMake(100, 220, 100, 60);
    [btnB setTitle:@"btnB" forState:UIControlStateNormal];
    [btnB addTarget:self action:@selector(btnBAction:) forControlEvents:UIControlEventTouchUpInside];
    btnB.backgroundColor = UIColor.yellowColor;
    
    _webView = [[UIWebView alloc] initWithFrame:CGRectMake(100, 320, 100, 60)];
    [parentView addSubview:_webView];
    _webView.backgroundColor = UIColor.greenColor;
    NSURL *url = [NSURL URLWithString:@"http://mr3.doubanio.com/e7bdbd6e06e084027c98f90aaababe96/0/fm/song/p1022867_128k.mp4"];
    NSURLRequest *request = [NSURLRequest requestWithURL:url];
    [_webView loadRequest:request];
}

- (void)btnAAction:(id)sender
{
    NSURL *url = [[NSURL alloc] initWithString:@"http://mr3.doubanio.com/7ec4e00b52593f5a7d242c03e78e1235/1/fm/song/p34466_128k.mp4"];
    AVPlayer *player = [AVPlayer playerWithURL:url];
    [player play];
    
    _playerA = player;
}

- (void)btnBAction:(id)sender
{
//    NSURL *url = [[NSURL alloc] initWithString:@"http://mr3.doubanio.com/e7bdbd6e06e084027c98f90aaababe96/0/fm/song/p1022867_128k.mp4"];
//    AVPlayer *player = [AVPlayer playerWithURL:url];
//    [player play];
//
//    _playerB = player;
    
    NSString *pauseScriptString = @"function pauseAllAudio() {\
    var audios = document.getElementsByTagName(\"audio\");\
    if(audios.length > 0){\
    for(var i = 0; i< audios.length; i++){\
    audios[i].pause();\
    }\
    }\
    }";
    [_webView stringByEvaluatingJavaScriptFromString:pauseScriptString];
    [_webView stringByEvaluatingJavaScriptFromString:[NSString stringWithFormat:@"pauseAllAudio()"]];
}

- (void)playerItemBecameCurrent:(NSNotification*)notification {
    AVPlayerItem *playerItem = [notification object];
    if(playerItem == nil) return;
    // Break down the AVPlayerItem to get to the path
    AVURLAsset *asset = (AVURLAsset*)[playerItem asset];
    NSURL *url = [asset URL];
    NSString *path = [url absoluteString];
}

//- (void)setupSubviews:(UIView *)parentView
//{
//    parentView.backgroundColor = [UIColor whiteColor];
//
//    UILabel *progressLab = [[UILabel alloc] init];
//    [parentView addSubview:progressLab];
//    [progressLab mas_makeConstraints:^(MASConstraintMaker *make) {
//        make.left.equalTo(parentView).offset(20.);
//        make.right.equalTo(parentView).offset(-20);
//        make.top.equalTo(parentView).offset(70.);
//    }];
//
//    UILabel *durationLab = [[UILabel alloc] init];
//    [parentView addSubview:durationLab];
//    [durationLab mas_makeConstraints:^(MASConstraintMaker *make) {
//        make.left.equalTo(progressLab);
//        make.right.equalTo(progressLab);
//        make.top.equalTo(progressLab.mas_bottom).offset(10.);
//    }];
//
//    UILabel *downloadLab = [[UILabel alloc] init];
//    [parentView addSubview:downloadLab];
//    [downloadLab mas_makeConstraints:^(MASConstraintMaker *make) {
//        make.left.equalTo(durationLab);
//        make.right.equalTo(durationLab);
//        make.top.equalTo(durationLab.mas_bottom).offset(10.);
//    }];
//
//    NSArray<UILabel *> *labels = @[progressLab, durationLab, downloadLab,];
//
//    for (UILabel *label in labels) {
//        label.font = [UIFont systemFontOfSize:12];
//        label.textColor = [UIColor blackColor];
//        label.backgroundColor = [UIColor yellowColor];
//    }
//
//    _durationLab = durationLab;
//    _progressLab = progressLab;
//    _downloadLab = downloadLab;
//
//    //==============================================================================//
//
//    //控制按钮
//    //
//    _playBtn = [UIButton buttonWithType:UIButtonTypeCustom];
//    [parentView addSubview:_playBtn];
//    [_playBtn mas_makeConstraints:^(MASConstraintMaker *make) {
//        make.centerX.equalTo(parentView);
//        make.centerY.equalTo(parentView);
//        make.width.height.equalTo(@50);
//    }];
//    [_playBtn setTitle:@"暂停" forState:UIControlStateNormal];
//    [_playBtn setTitle:@"开始" forState:UIControlStateHighlighted];
//
//    _nextBtn = [UIButton buttonWithType:UIButtonTypeCustom];
//    [parentView addSubview:_nextBtn];
//    [_nextBtn mas_makeConstraints:^(MASConstraintMaker *make) {
//        make.centerY.equalTo(_playBtn);
//        make.left.equalTo(_playBtn.mas_right).offset(16.);
//        make.width.height.equalTo(@40);
//    }];
//    [_nextBtn setTitle:@"下一首" forState:UIControlStateNormal];
//    [_nextBtn setTitle:@"点不了" forState:UIControlStateDisabled];
//
//    _prevBtn = [UIButton buttonWithType:UIButtonTypeCustom];
//    [parentView addSubview:_prevBtn];
//    [_prevBtn mas_makeConstraints:^(MASConstraintMaker *make) {
//        make.centerY.equalTo(_playBtn);
//        make.right.equalTo(_playBtn.mas_left).offset(16.);
//        make.width.height.equalTo(@40);
//    }];
//    [_prevBtn setTitle:@"上一首" forState:UIControlStateNormal];
//    [_prevBtn setTitle:@"点不了" forState:UIControlStateDisabled];
//}

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

























