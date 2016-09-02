//
//  CPAudioMainVC.m
//  commonProj
//
//  Created by dongchx on 8/3/16.
//  Copyright © 2016 dongchx. All rights reserved.
//

#import "CPAudioMainVC.h"
#import "CPAudioEngine.h"
#import "QKAudioTrack.h"
#import <MediaPlayer/MPNowPlayingInfoCenter.h>
#import <MediaPlayer/MPMediaItem.h>

#define kAudioEngine [CPAudioEngine sharedInstance]

@interface CPAudioMainVC () <QRAudioEngineDelegate>

@property (nonatomic, strong) UIButton      *playButton;
@property (nonatomic, strong) UIButton      *nextButton;
@property (nonatomic, strong) UIButton      *previousButton;
@property (nonatomic, strong) UISlider      *slider;
@property (nonatomic, strong) UILabel       *leftLabel;
@property (nonatomic, strong) UILabel       *rightLabel;

@property (nonatomic, strong) NSArray       *urlArray;
@property (nonatomic, assign) float         sliderValue;

@end

@implementation CPAudioMainVC

#pragma mark - init

//=========================test===========================
- (NSArray *)urlList
{
    return @[
             @"http://so1.111ttt.com:8282/2016/5/02m/25/195251254501.m4a?tflag=1460092748&pin=3dbb05a5b04feabee40fda7afd41146c&ip=14.17.22.35#.mp3",
             @"http://so1.111ttt.com:8282/2016/5/02m/25/195251254501.m4a?tflag=1460092748&pin=3dbb05a5b04feabee40fda7afd41146c&ip=14.17.22.35#.mp3",
             @"http://so1.111ttt.com:8282/2016/5/02m/25/195251254501.m4a?tflag=1460092748&pin=3dbb05a5b04feabee40fda7afd41146c&ip=14.17.22.35#.mp3",
             ];
}
//========================================================

- (instancetype)init
{
    if (self = [super init]) {
        self.view.backgroundColor = [UIColor colorWithHex:0xffffff];
    }
    
    return self;
}

- (void)setupSubviews:(__weak UIView *)parentView
{
    UIButton *playButton = [UIButton buttonWithType:UIButtonTypeCustom];
    playButton.backgroundColor = [UIColor greenColor];
    [playButton addTarget:self
                   action:@selector(playButtonAction:)
         forControlEvents:UIControlEventTouchUpInside];
    [parentView addSubview:playButton];
    
    [playButton mas_makeConstraints:^(MASConstraintMaker *make) {
        make.width.mas_equalTo(65.);
        make.height.mas_equalTo(65.);
        make.center.equalTo(parentView);
    }];
    
    UIButton *nextButton = [UIButton buttonWithType:UIButtonTypeCustom];
    nextButton.backgroundColor = [UIColor greenColor];
    [nextButton addTarget:self
                   action:@selector(nextTrack:)
         forControlEvents:UIControlEventTouchUpInside];
    [parentView addSubview:nextButton];
    
    [nextButton mas_makeConstraints:^(MASConstraintMaker *make) {
        make.width.mas_equalTo(50.);
        make.height.mas_equalTo(50.);
        make.centerY.equalTo(playButton);
        make.left.equalTo(playButton.mas_right).offset(16.);
    }];
    
    UIButton *previousButton = [UIButton buttonWithType:UIButtonTypeCustom];
    previousButton.backgroundColor = [UIColor greenColor];
    [previousButton addTarget:self
                       action:@selector(previousTrack:)
             forControlEvents:UIControlEventTouchUpInside];
    [parentView addSubview:previousButton];
    
    [previousButton mas_makeConstraints:^(MASConstraintMaker *make) {
        make.width.mas_equalTo(50.);
        make.height.mas_equalTo(50.);
        make.centerY.equalTo(playButton);
        make.right.equalTo(playButton.mas_left).offset(-16.0);
    }];
    
    UISlider *slider = [[UISlider alloc] init];
//    slider.backgroundColor = [UIColor colorWithHex:0x000000 alpha:0.8];
    slider.minimumTrackTintColor = [UIColor colorWithHex:0xe65051 alpha:1.];
    slider.maximumTrackTintColor = [UIColor colorWithHex:0x000000 alpha:0.8];
    slider.minimumValue = 0.;
    slider.maximumValue = 1.;
    [slider addTarget:self
               action:@selector(sliderValueChange:)
     forControlEvents:UIControlEventValueChanged];
    [parentView addSubview:slider];
    
    [slider mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(playButton.mas_bottom).offset(10.);
        make.left.equalTo(parentView);
        make.width.equalTo(parentView);
        make.height.mas_equalTo(5);
    }];
    
    UILabel *leftLabel = [[UILabel alloc] init];
    leftLabel.font = [UIFont systemFontOfSize:10.];
    leftLabel.textColor = [UIColor colorWithHex:0x000000 alpha:0.6];
    leftLabel.textAlignment = NSTextAlignmentLeft;
    leftLabel.text = @"00:00";
    [parentView addSubview:leftLabel];
    
    [leftLabel mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(slider.mas_bottom).offset(10.);
        make.left.equalTo(parentView).offset(6.);
    }];
    
    UILabel *rightLabel = [[UILabel alloc] init];
    rightLabel.font = [UIFont systemFontOfSize:10.];
    rightLabel.textColor = [UIColor colorWithHex:0x000000 alpha:0.6];
    rightLabel.textAlignment = NSTextAlignmentRight;
    rightLabel.text = @"01:00";
    [parentView addSubview:rightLabel];
    
    [rightLabel mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(leftLabel);
        make.right.equalTo(parentView).offset(-6.);
    }];
    
    _playButton  = playButton;
    _nextButton  = nextButton;
    _previousButton = previousButton;
    _slider = slider;
    _leftLabel = leftLabel;
    _rightLabel = rightLabel;
}

#pragma mark - lifecycle

- (void)dealloc
{
//    [kAudioEngine removeObserver:self forKeyPath:@"mAudioPlayer.state"];
    NSLog(@"AudioVC dealloc");
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    _urlArray = [self urlList];
    
    [self setupSubviews:self.view];
    
    if (kAudioEngine.trackArray == nil) {
        kAudioEngine.trackArray = _urlArray;
    }
    
//    [self startPlay];
}

- (void)viewWillAppear:(BOOL)animated
{
    kAudioEngine.delegate = self;
    
//    [kAudioEngine addObserver:self
//                   forKeyPath:@"mAudioPlayer.state"
//                      options:NSKeyValueObservingOptionNew
//                      context:nil];

}

- (void)viewDidDisappear:(BOOL)animated
{
    kAudioEngine.delegate =  nil;
}

#pragma mark - event

- (void)playButtonAction:(id)sender
{
    if ([kAudioEngine isPlaying]) {
        [kAudioEngine pause];
        _playButton.backgroundColor = [UIColor redColor];
    }
    else {
        [kAudioEngine resume];
        _playButton.backgroundColor = [UIColor greenColor];
    }
}

- (void)nextTrack:(id)sender
{
    [kAudioEngine nextTrack:sender];
}

- (void)previousTrack:(id)sender
{
    [kAudioEngine previousTrack:sender];
}

- (void)sliderValueChange:(UISlider *)sender
{
    [kAudioEngine timerPause];
    BOOL suc =  [kAudioEngine seekToTime:(kAudioEngine.durationTime * sender.value)];
    
    if (suc) {
        _sliderValue = sender.value;
    } else {
        sender.value = _sliderValue;
    }
    
    [kAudioEngine timerStart];
}

- (NSString *)stringFromDate:(NSDate *)date;
{
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    [dateFormatter setDateFormat:@"mm:ss"];
    
    return [dateFormatter stringFromDate:date];
}

#pragma mark - QRAudioEngineDelegate

- (void)playEventChanged:(PlayEventType)type description:(NSString *)desc
{
    
}

- (void)player:(QKBaseAudioPlayer *)player
  durationTime:(double)duration
     validTime:(double)validTime
  progressTime:(double)progress
{
    if (duration > 0) {
        _slider.value = progress/duration;
        _sliderValue = _slider.value;
        
        _leftLabel.text = [self stringFromDate:[NSDate dateWithTimeIntervalSince1970:progress]];
        _rightLabel.text = [self stringFromDate:[NSDate dateWithTimeIntervalSince1970:duration-progress]];
                        
    }
}

- (void)refreshButtonState:(NSInteger)index
{
    if (index >= _urlArray.count-1) {
        _nextButton.backgroundColor = [UIColor colorWithHex:0xaaaaaa];
        _nextButton.userInteractionEnabled = NO;
    }
    else {
        _nextButton.backgroundColor = [UIColor greenColor];
        _nextButton.userInteractionEnabled = YES;
    }
    
    if (index == 0) {
        _previousButton.backgroundColor = [UIColor colorWithHex:0xaaaaaa];
        _previousButton.userInteractionEnabled = NO;
    }
    else {
        _previousButton.backgroundColor = [UIColor greenColor];
        _previousButton.userInteractionEnabled  = YES;
    }
}

#pragma mark - KVO

- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary<NSString *,id> *)change
                       context:(void *)context
{
    
}

- (void)handleStatusChanged
{
    
}

@end
















































