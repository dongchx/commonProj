//
//  QKAudioTrack.h
//  QQKala
//
//  Created by frost on 12-6-14.
//  Copyright (c) 2012年 Tencent. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "AudioCommonDefine.h"

@interface QKAudioTrack : NSObject<NSCoding>
{
	AudioTrackType          mType;          // audio track type
    NSString                *mMusicID;      // identify audio track
    
	NSString                *mSongName;     // audio track info
	NSString                *mArtistName;
	NSString                *mAlbumName;
    UIImage                 *mCover;       
    
	NSInteger               mTrackStatus;
	NSInteger               mFileSize;

	NSString                *mUrl;           // remote server url for QKAudioTrackTypeNetwork
	NSString                *mFilePath;      // local file path
    
    // record file path, exist according the audio track type
    // record file may exist when audio track is type of AudioTrackTypeSynthesizedFile 
    NSString                *mRecordFilePath;   
    
    // token file path, this file is used by AiSing engine
    NSString                *mTokenFilePath;
    
	NSInteger               mSortNum;
	NSString                *mAlbumUrl;
    
	BOOL                    mIsPlaying;
	double                  mDuration;
}

@property (nonatomic, assign) AudioTrackType    type;
@property (nonatomic, retain) NSString          *musicID;
@property (nonatomic, retain) NSString          *songName;
@property (nonatomic, retain) NSString          *artistName;
@property (nonatomic, retain) NSString          *albumName;
@property (nonatomic, assign) NSInteger         trackStatus;
@property (nonatomic, assign) NSInteger         fileSize;
@property (nonatomic, retain) NSString          *url;
@property (nonatomic, retain) NSString          *filePath;
@property (nonatomic, retain) NSString          *recordFilePath;
@property (nonatomic, retain) NSString          *tokenFilePath;
@property (nonatomic, assign) NSInteger         sortNum;
@property (nonatomic, retain) NSString          *albumUrl;
@property (nonatomic, assign) BOOL              isPlaying;
@property (nonatomic, assign) double            duration;
@property (nonatomic, retain) UIImage           *cover;
@end
