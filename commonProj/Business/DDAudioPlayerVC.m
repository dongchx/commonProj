//
//  DDAudioPlayerVC.m
//  commonProj
//
//  Created by dongchx on 10/20/16.
//  Copyright © 2016 dongchx. All rights reserved.
//

#import "DDAudioPlayerVC.h"
#import "DDNetAudioPlayer.h"

@interface DDAudioPlayerVC ()

@property (nonatomic, strong) DDNetAudioPlayer *netAudioPlayer;

@end

@implementation DDAudioPlayerVC

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.view.backgroundColor = [UIColor blueColor];
    
    _netAudioPlayer = [DDNetAudioPlayer player];
    
    [_netAudioPlayer startWithUrl:@"http://datashat.net/music_for_programming_18-konx_om_pax.mp3"];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}

@end // DDAudioPlayerVC
