//
//  QKNetAudioPlayer.h
//  QQKala
//
//  Created by frost on 12-6-15.
//  Copyright (c) 2012年 Tencent. All rights reserved.
//

#import <Foundation/Foundation.h>
#include <AudioToolbox/AudioToolbox.h>
#import "QKBaseAudioPlayer.h"

@interface QKNetAudioPlayer : QKBaseAudioPlayer
{
    UInt32 totalbytes;
	NSURL *url;
	//
	// Special threading consideration:
	//	The audioQueue property should only ever be accessed inside a
	//	synchronized(self) block and only *after* checking that ![self isFinishing]
	//
	AudioQueueRef audioQueue;
	AudioFileStreamID audioFileStream;	// the audio file stream parser
	AudioStreamBasicDescription asbd;	// description of the audio
	NSThread *internalThread;	// the thread where the download and
    // audio file stream parsing occurs
	AudioQueueBufferRef audioQueueBuffer[kNumAQBufs];		// audio queue buffers
	AudioStreamPacketDescription packetDescs[kAQMaxPacketDescs]; // packet descriptions for enqueuing audio
	unsigned int fillBufferIndex;	// the index of the audioQueueBuffer that is being filled
	UInt32 packetBufferSize;
	size_t bytesFilled;				// how many bytes have been filled
	size_t packetsFilled;			// how many packets have been filled
	bool inuse[kNumAQBufs];			// flags to indicate that a buffer is still in use
	NSInteger buffersUsed;
	NSDictionary *httpHeaders;
	OSStatus err;
	bool discontinuous;			// flag to indicate middle of the stream
	pthread_mutex_t queueBuffersMutex;			// a mutex to protect the inuse flags
	pthread_cond_t queueBufferReadyCondition;	// a condition varable for handling the inuse flags
	CFReadStreamRef stream;
	NSNotificationCenter *notificationCenter;
	UInt32 bitRate;				// Bits per second in the file
	NSInteger dataOffset;	// Offset of the first audio packet in the stream
	NSInteger fileLength;	// Length of the file in bytes
	NSInteger endByteOffset;
	NSInteger seekByteOffset;	// Seek offset within the file in bytes
	UInt64 audioDataByteCount;  // Used when the actual number of audio bytes in
    // the file is known (more accurate than assuming
    // the whole file is audio)
	UInt64 processedPacketsCount;		// number of packets accumulated for bitrate estimation
	UInt64 processedPacketsSizeTotal;	// byte size of accumulated estimation packets
	double seekTime;
	BOOL restartWasRequested;
	BOOL seekWasRequested;
	BOOL isNotAllowSeek;
    BOOL isStreamEnd;
	double requestedSeekTime;
	double sampleRate;	// Sample rate of the file (used to compare with
    // samples played by the queue for current playback
    // time)
	double packetDuration;	// sample rate times frames per packet
	double lastProgress;		// last calculated progress point
	int  tryHttpCount;
	NSTimer*  httpTimer;
    
    //===receivedData========
    UInt32 receivedData;
}

@property (readonly) double				progress;
@property (readonly) double				duration;
@property (readwrite) UInt32			bitRate;
@property (readonly) NSDictionary       *httpHeaders;

- (id)initWithNetURL:(NSString *)aURL;
+ (AudioFileTypeID)hintForFileExtension:(NSString *)fileExtension;

@end
