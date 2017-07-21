//
//  QRAudioTrack+Provider.m
//  commonProj
//
//  Created by dongchx on 12/23/16.
//  Copyright © 2016 dongchx. All rights reserved.
//

#import "QRAudioTrack+Provider.h"

@implementation QRAudioTrack (Provider)

+ (NSArray *)remoteTracks:(NSArray *)list
{
    NSArray *tracks = nil;
    
    NSArray *URLs =
    @[
      @"http://mr3.doubanio.com/7ec4e00b52593f5a7d242c03e78e1235/1/fm/song/p34466_128k.mp4",
      @"http://mr3.doubanio.com/e8d23b0955709007a96098c0370d0a64/0/fm/song/p191676_128k.mp4",
      @"http://mr3.doubanio.com/62f4333f528620649b83028fe165664f/0/fm/song/p2254565_128k.mp4",
      @"http://mr3.doubanio.com/e7bdbd6e06e084027c98f90aaababe96/0/fm/song/p1022867_128k.mp4",
      @"http://mr1.doubanio.com/2aa24e8237777d4933965ddcbdc1f060/0/fm/song/p762243_128k.mp4",
      
      ];
    
    NSMutableArray *allTracks = [NSMutableArray array];
    QRAudioTrack *track = [[QRAudioTrack alloc] init];
    track.artist = @"樱木花道";
    track.title = @"灌篮高手";
//    track.audioFileURL = [NSURL URLWithString:@"https://mr3.doubanio.com/506bc020f69206d1adf943fbab92ae10/0/fm/song/p606357_128k.mp4"];
//    track.audioFileURL = [NSURL URLWithString:@"http://mr3.doubanio.com/7ec4e00b52593f5a7d242c03e78e1235/1/fm/song/p34466_128k.mp4"];
//    track.audioFileURL = [NSURL URLWithString:@"http://mr3.doubanio.com/e8d23b0955709007a96098c0370d0a64/0/fm/song/p191676_128k.mp4"];
//    track.audioFileURL = [NSURL URLWithString:@"http://mr3.doubanio.com/62f4333f528620649b83028fe165664f/0/fm/song/p2254565_128k.mp4"];
//    track.audioFileURL = [NSURL URLWithString:@"http://mr3.doubanio.com/e7bdbd6e06e084027c98f90aaababe96/0/fm/song/p1022867_128k.mp4"];
//    track.audioFileURL = [NSURL URLWithString:@"http://mr1.doubanio.com/2aa24e8237777d4933965ddcbdc1f060/0/fm/song/p762243_128k.mp4"];
    
    for (NSString *url in URLs) {
        QRAudioTrack *track = [[QRAudioTrack alloc] init];
        track.artist = @"樱木花道";
        track.title = @"灌篮高手";
        track.audioFileURL = [NSURL URLWithString:url];
        [allTracks addObject:track];
    }
    
    tracks = [allTracks copy];
    
    return tracks;
}

+ (NSArray *)localTracks:(NSArray *)list
{
    static NSArray *tracks = nil;
    
    
    return tracks;
}


@end
