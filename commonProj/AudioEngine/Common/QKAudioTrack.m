//
//  QKAudioTrack.m
//  QQKala
//
//  Created by frost on 12-6-14.
//  Copyright (c) 2012年 Tencent. All rights reserved.
//

#import "QKAudioTrack.h"

// ---------------------------------------------
// QKAudioTrack implementation
// ---------------------------------------------
@implementation QKAudioTrack

@synthesize type = mType;
@synthesize musicID = mMusicID;
@synthesize songName = mSongName;
@synthesize artistName = mArtistName;
@synthesize albumName = mAlbumName;
@synthesize trackStatus = mTrackStatus;
@synthesize fileSize = mFileSize;
@synthesize url = mUrl;
@synthesize filePath = mFilePath;
@synthesize recordFilePath = mRecordFilePath;
@synthesize tokenFilePath = mTokenFilePath;
@synthesize sortNum = mSortNum;
@synthesize albumUrl = mAlbumUrl;
@synthesize isPlaying = mIsPlaying;
@synthesize duration = mDuration;
@synthesize cover = mCover;

#pragma mark life cycle
- (id)init
{
    if (self = [super init])
    {
    }
    return self;
}

- (void)dealloc
{
    self.musicID = nil;
    self.songName = nil;
    self.artistName = nil;
    self.albumName = nil;
    self.url = nil;
    self.filePath = nil;
    self.recordFilePath = nil;
    self.tokenFilePath = nil;
    self.albumUrl = nil;
    
    [super dealloc];
}

#pragma mark override from spuer class
- (BOOL)isEqual:(id)obj
{
	if (self == obj)
	{
		return YES;
	}
	if (obj) 
	{
		if (![obj isKindOfClass:[QKAudioTrack class]])
		{
			return NO; 
		}
		QKAudioTrack *audioTrack = (QKAudioTrack *) obj;

		return (self.type ==audioTrack.type) && [self.musicID isEqualToString:audioTrack.musicID];
	}
    return NO;
}

#pragma mark NSCoding protocol
- (void)encodeWithCoder:(NSCoder *)aCoder
{
	//todo
}

- (id)initWithCoder:(NSCoder *)aDecoder
{
	self = [super init];
	if (self != nil) 
	{
		//todo
	}
	return self;
}
@end
