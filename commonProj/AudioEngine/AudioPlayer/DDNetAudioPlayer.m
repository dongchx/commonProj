//
//  DDNetAudioPlayer.m
//  commonProj
//
//  Created by dongchx on 10/20/16.
//  Copyright © 2016 dongchx. All rights reserved.
//

#import "DDNetAudioPlayer.h"
#import "AFHTTPSessionManager.h"
#import "AFDownloadRequestOperation.h"
#import "QKFileAudioPlayer.h"

#define kDDAudioCacheFolderName @"/com.dongchx.DDNetAudioPlayer/"
#define kDDAudioSizeBuffer 100000.0f

@interface DDNetAudioPlayer ()

@property (nonatomic, strong) AFDownloadRequestOperation *operation;
@property (nonatomic, strong) NSString *cacheFilePath;
@property (nonatomic, strong) QKFileAudioPlayer *player;

@end

@implementation DDNetAudioPlayer

#pragma mark - init

+ (instancetype)player
{
    return [[[self class] alloc] init];
}

- (instancetype)init
{
    if (self = [super init]) {
        ;
    }
    
    return self;
}

#pragma mark - public

- (void)startWithUrl:(NSString *)urlString
{
    NSLog(@"start string : %@", urlString);
    
    NSURL *url = [NSURL URLWithString:urlString];
    NSString *cacheKey = [self cacheKeyFromUrl:url];
    [self startWithUrl:url withCacheKey:cacheKey];
}

- (void)startWithUrl:(NSURL *)url withCacheKey:(NSString *)cacheKey
{
    // 文件缓存路径
    NSString *localFileName = [NSString stringWithFormat:@"%@.%@",cacheKey,url.pathExtension];
    NSString *localFilePath = [[[self class] cacheFolder] stringByAppendingString:localFileName];
    
    _cacheFilePath = localFilePath;
    
    // player state
    if (_player) {
        [_player stop];
        _player = nil;
    }
    
    // request
    if (_operation) {
        if (!_operation.isCancelled) { [_operation cancel]; }
        _operation = nil;
    }
    
    NSURLRequest *request = [NSURLRequest requestWithURL:url];
    
    _operation = [[AFDownloadRequestOperation alloc] initWithRequest:request
                                                          targetPath:_cacheFilePath
                                                        shouldResume:YES];
    
    __typeof(self) __weak weakSelf = self;
    
    NSLog(@"operation Progress");
    [self.operation setProgressiveDownloadProgressBlock:
     ^(AFDownloadRequestOperation *operation,
       NSInteger bytesRead,
       long long totalBytesRead,
       long long totalBytesExpected,
       long long totalBytesReadForFile,
       long long totalBytesExpectedToReadForFile) {
         NSLog(@"[DDAudioEngine] Download Progress: %ld, %lld, %lld, %lld, %lld",
               (long)bytesRead, totalBytesRead, totalBytesExpected, totalBytesReadForFile, totalBytesExpectedToReadForFile);
         
         if (totalBytesReadForFile > kDDAudioSizeBuffer) {
             NSLog(@"totalBytesReadForFile > kDDAudioSizeBuffer");
             [weakSelf playLocalAudioFile:weakSelf.operation.tempPath];
         }
     }];
    
    [_operation start];
}

#pragma mark - play AudioFile

- (void)playLocalAudioFile:(NSString *)filePath
{
    NSLog(@"playLocalAudioFile");
    if (!_player) {
//        NSURL *musicURL = [[NSURL alloc] initFileURLWithPath:filePath isDirectory:NO];
        _player = [[QKFileAudioPlayer alloc] initWithFilePath:filePath];
    }
    
    if (_player) {
        if (!_player.isPlaying) { [_player play]; }
    }
}

#pragma mark - private

- (NSString *)cacheKeyFromUrl:(NSURL *)url
{
    NSString *key = [NSString stringWithFormat:@"%lx",url.absoluteString.hash];
    return key;
}

+ (NSString *)cacheFolder
{
    static NSString *cacheFolder;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSString *cacheDir = [[[[NSFileManager defaultManager]
                               URLsForDirectory:NSCachesDirectory
                               inDomains:NSUserDomainMask] lastObject] path];
//        NSString *cacheDir = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0];
        cacheFolder = [cacheDir stringByAppendingString:kDDAudioCacheFolderName];
        
        NSError *error = nil;
        if(![[NSFileManager new] createDirectoryAtPath:cacheFolder
                           withIntermediateDirectories:YES
                                            attributes:nil
                                                 error:&error]) {
            NSLog(@"[DDAudioEngine] Failed to create cache directory at %@", cacheFolder);
        }
    });
    
    return cacheFolder;
}

#pragma mark - QKPlayerProtocol

- (void)play
{
    [_player play];
}

- (void)pause
{
    [_player pause];
}

- (void)resume
{
    [_player resume];
}

- (void)stop
{
    [_player stop];
}

- (void)setVolume:(float)volume
{
    [_player setVolume:volume];
}

- (BOOL)isPlaying
{
    return _player.isPlaying;
}

- (BOOL)isPaused
{
    return _player.isPaused;
}

- (BOOL)isWaiting
{
    return _player.isWaiting;
}

- (BOOL)isSeekable
{
    return _player.isSeekable;
}

- (double)duration
{
    return _player.duration;
}

- (double)durationCanPlay
{
    return 0.0;
}

- (double)progress
{
    return _player.progress;
}

- (BOOL)seekToTime:(double)newSeekTime
{
    // need rewrite
    return [_player seekToTime:newSeekTime];
}


@end  // DDNetAudioPlayer




























