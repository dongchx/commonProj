//
//  QKFileAudioPlayer.h
//  QQKala
//
//  Created by frost on 12-6-15.
//  Copyright (c) 2012年 Tencent. All rights reserved.
//

#import <Foundation/Foundation.h>
#include <AudioToolbox/AudioToolbox.h>
#import "QKBaseAudioPlayer.h"

@interface QKFileAudioPlayer : QKBaseAudioPlayer
{
    NSURL							*filePath;
	AudioStreamBasicDescription		asbd;	// description of the audio
	AudioStreamPacketDescription	packetDescs[kAQMaxPacketDescs]; // packet descriptions for enqueuing audio
	UInt32							packetBufferSize;
	UInt32                          bitRate;		// Bits per second in the file
	double                          sampleRate;     // Sample rate of the file (used to compare with
    // samples played by the queue for current playback
    // time)
	double		packetDuration;	// sample rate times frames per packet
	OSStatus	err;
	double		seekTime;
	UInt64		processedPacketsCount;		// number of packets accumulated for bitrate estimation
	UInt64		processedPacketsSizeTotal;	// byte size of accumulated estimation packets
	
	AudioFileID audioFile;
	NSInteger		packetOffset;
	UInt64			packetIndex;
	UInt64			packetIndexBySeek;
	UInt64			packetsCount;
	UInt32			numPacketsToRead;

	BOOL                        trackClosed;
	BOOL						trackEnded;
	AudioQueueRef				audioQueue;
	AudioQueueBufferRef         audioQueueBuffer[kNumAQBufs];		// audio queue buffers
	double						lastProgress;		// last calculated progress point
	NSTimeInterval              fileDuration;
}

@property (readonly) double progress;
@property (readonly) double duration;

- (id)initWithFilePath:(NSString*)path;
@end
