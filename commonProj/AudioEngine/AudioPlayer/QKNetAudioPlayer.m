//
//  QKNetAudioPlayer.m
//  QQKala
//
//  Created by frost on 12-6-15.
//  Copyright (c) 2012年 Tencent. All rights reserved.
//

#import "QKNetAudioPlayer.h"
#import "ReachabilityManager.h"
#import "PublicConfig.h"
#import <pthread.h>

#define BitRateEstimationMaxPackets 5000
#define BitRateEstimationMinPackets 50

// ---------------------------------------------
// forward declaration
// Audio Queue callback
// ---------------------------------------------
static void MyAudioQueueOutputCallback(void* inClientData, AudioQueueRef inAQ, AudioQueueBufferRef inBuffer);
static void MyAudioQueueIsRunningCallback(void *inUserData, AudioQueueRef inAQ, AudioQueuePropertyID inID);
static void MyPropertyListenerProc(	void *							inClientData,
                            AudioFileStreamID				inAudioFileStream,
                            AudioFileStreamPropertyID		inPropertyID,
                            UInt32 *						ioFlags);
static void MyPacketsProc(				void *							inClientData,
                   UInt32							inNumberBytes,
                   UInt32							inNumberPackets,
                   const void *					inInputData,
                   AudioStreamPacketDescription	*inPacketDescriptions);

// ---------------------------------------------
// forward declaration
// CFReadStream callback
// ---------------------------------------------
static void ASReadStreamCallBack(CFReadStreamRef aStream,
                          CFStreamEventType eventType,
                          void* inClientInfo);

// ---------------------------------------------
// QKNetAudioPlayer private category
// ---------------------------------------------
@interface QKNetAudioPlayer ()

- (NSString *)URLEncodedString:(NSString *)aUrl;
- (char*)FindHost:(char*)URL :(int *)nLen;
- (double)calculatedBitRate;
- (void)reportFailWithError:(AudioStreamerErrorCode)anErrorCode;
- (void)reportFailOnMainThread;
- (BOOL)isFinishing;
- (void)createQueue;
- (void)startInternal;
- (BOOL)openReadStream;
- (void)httpTimer:(id)aSender;
- (void)internalSeekToTime:(double)newSeekTime;
- (void)internalRestartReadStream;
- (BOOL)reopenReadStream;
- (BOOL)runLoopShouldExit;


- (void)handlePropertyChangeForFileStream:(AudioFileStreamID)inAudioFileStream
                     fileStreamPropertyID:(AudioFileStreamPropertyID)inPropertyID
                                  ioFlags:(UInt32 *)ioFlags;

- (void)handleAudioPackets:(const void *)inInputData
               numberBytes:(UInt32)inNumberBytes
             numberPackets:(UInt32)inNumberPackets
        packetDescriptions:(AudioStreamPacketDescription *)inPacketDescriptions;

- (void)handleBufferCompleteForQueue:(AudioQueueRef)inAQ
                              buffer:(AudioQueueBufferRef)inBuffer;

- (void)handlePropertyChangeForQueue:(AudioQueueRef)inAQ
                          propertyID:(AudioQueuePropertyID)inID;

- (void)enqueueBuffer;
- (void)handleReadFromStream:(CFReadStreamRef)aStream
                   eventType:(CFStreamEventType)eventType;

@end

// ---------------------------------------------
// QKNetAudioPlayer implementation
// ---------------------------------------------
@implementation QKNetAudioPlayer
@synthesize bitRate;
@synthesize httpHeaders;

#pragma mark life cycle
- (id)initWithNetURL:(NSString *)aURL
{
	if ( !aURL )
		return nil;
	self = [super init];
	if (self != nil)
	{
		url = [[NSURL URLWithString:[self URLEncodedString:aURL]] retain];
		[self registerPlayStateChangeNotification];
        totalbytes = 0; 
	}

	return self;
}

- (void)dealloc
{
	[self unRegisterPlayStateChangeNotification];
	[self stop];
	[url release];
	[super dealloc];
}

#pragma mark public function

// Generates a first guess for the file type based on the file's extension
//
// Parameters:
//    fileExtension - the file extension
//
// returns a file type hint that can be passed to the AudioFileStream
//
+ (AudioFileTypeID)hintForFileExtension:(NSString *)fileExtension
{
	AudioFileTypeID fileTypeHint = kAudioFileMP3Type;
	if ([fileExtension isEqual:@"mp3"])
	{
		fileTypeHint = kAudioFileMP3Type;
	}
	else if ([fileExtension isEqual:@"wav"])
	{
		fileTypeHint = kAudioFileWAVEType;
	}
	else if ([fileExtension isEqual:@"aifc"])
	{
		fileTypeHint = kAudioFileAIFCType;
	}
	else if ([fileExtension isEqual:@"aiff"])
	{
		fileTypeHint = kAudioFileAIFFType;
	}
	else if ([fileExtension isEqual:@"m4a"])
	{
		fileTypeHint = kAudioFileM4AType;
	}
	else if ([fileExtension isEqual:@"mp4"])
	{
		fileTypeHint = kAudioFileMPEG4Type;
	}
	else if ([fileExtension isEqual:@"caf"])
	{
		fileTypeHint = kAudioFileCAFType;
	}
	else if ([fileExtension isEqual:@"aac"])
	{
		fileTypeHint = kAudioFileAAC_ADTSType;
	}
	return fileTypeHint;
}

#pragma mark private category
- (NSString *)URLEncodedString:(NSString *)aUrl
{

	NSString *result =
    [(NSString *)CFURLCreateStringByAddingPercentEscapes(
                                                         nil,
                                                         (CFStringRef)aUrl,
                                                         NULL,
                                                         NULL,
                                                         kCFStringEncodingUTF8) autorelease];
	return result;
}

- (char*)FindHost:(char*)URL :(int *)nLen
{
	if( URL == NULL) 
	{
		return NULL ;
	}
	char * pSrc = URL ;
	char * pStart = strstr(pSrc, "http://");
	if (pStart == NULL)	
	{
		*nLen = 0 ;
		return NULL ;
	}
	pStart += strlen("http://");
	int nTmpLen = strlen(URL) - (pStart - pSrc) ;
	if( nTmpLen <= 0 )
	{
		*nLen = 0 ;
		return NULL ;
	}
	char cDstChar ;
	int nCharCount = 0 ;
	bool bFindEnd = false ;
	while (nTmpLen)
	{
		cDstChar = pStart[nCharCount] ;
		switch ( cDstChar )
		{
			case '/':
			case ':':
			case '?':
				bFindEnd = true ;
				break ;
		}
		if( bFindEnd )
			break ;
		nTmpLen -- ;
		nCharCount ++ ;
	}
	*nLen = nCharCount ;
	return pStart ;
}

// returns the bit rate, if known. Uses packet duration times running bits per
//   packet if available, otherwise it returns the nominal bitrate. Will return
//   zero if no useful option available.
//
- (double)calculatedBitRate
{
    if (packetDuration && processedPacketsCount > BitRateEstimationMinPackets)
    {
        double averagePacketByteSize = processedPacketsSizeTotal / processedPacketsCount;
        return 8.0 * averagePacketByteSize / packetDuration;
    }
    
	if (bitRate)
	{
		return (double)bitRate;
	}
	return 0;
}

- (void)reportFailWithError:(AudioStreamerErrorCode)anErrorCode
{
    @synchronized(self)
	{
		if (self.errorCode != AS_NO_ERROR)
		{
			// Only set the error once.
			return;
		}

		self.errorCode = anErrorCode;

        if ([[NSThread currentThread] isEqual:[NSThread mainThread]])
        {
            [self reportFailOnMainThread];
        }
        else 
        {
            [self
             performSelectorOnMainThread:@selector(reportFailOnMainThread)
             withObject:nil 
             waitUntilDone:NO];
        }

	}
}

- (void)reportFailOnMainThread
{
    if (self.state == AS_PLAYING ||
        self.state == AS_PAUSED  ||
        self.state == AS_BUFFERING)
    {
        self.state = AS_STOPPING;
        self.stopReason = AS_STOPPING_ERROR;
        isNotAllowSeek = YES;
        AudioQueueStop(audioQueue,  true);
    }
    else if (self.state == AS_WAITING_FOR_DATA )
    {
        self.state = AS_STOPPING;
        self.stopReason = AS_STOPPING_NO_DATA;
    } 
    if ( AS_AUDIO_QUEUE_START_FAILED == self.errorCode ) 
    { 
        self.state = AS_STOPPING;
        self.stopReason = AS_STOPPING_ERROR;
    }
    
    [self failedWithError:self.errorCode];
}

// returns YES if the audio has reached a stopping condition.
//
- (BOOL)isFinishing
{
	@synchronized (self)
	{
		if ((self.errorCode != AS_NO_ERROR && self.state != AS_INITIALIZED) ||
			((/*self.state == AS_STOPPING ||*/ self.state == AS_STOPPED) &&
             self.stopReason != AS_STOPPING_TEMPORARILY))
		{
			return YES;
		}
	}
	
	return NO;
}

// Method to create the AudioQueue from the parameters gathered by the
// AudioFileStream.
//
// Creation is deferred to the handling of the first audio packet (although
// it could be handled any time after kAudioFileStreamProperty_ReadyToProducePackets
// is true).
//
- (void)createQueue
{
	sampleRate = asbd.mSampleRate;
	packetDuration = asbd.mFramesPerPacket / sampleRate;
	
	// create the audio queue
	err = AudioQueueNewOutput(&asbd, MyAudioQueueOutputCallback, self, NULL, NULL, 0, &audioQueue);

	if (err)
	{
		[self reportFailWithError:AS_AUDIO_QUEUE_CREATION_FAILED];
		return;
	}
	
	// start the queue if it has not been started already
	// listen to the "isRunning" property
	err = AudioQueueAddPropertyListener(audioQueue, kAudioQueueProperty_IsRunning, MyAudioQueueIsRunningCallback, self);
	if (err)
	{
		[self reportFailWithError:AS_AUDIO_QUEUE_ADD_LISTENER_FAILED];
		return;
	}
	
	// get the packet size if it is available
	UInt32 sizeOfUInt32 = sizeof(UInt32);
	err = AudioFileStreamGetProperty(audioFileStream, kAudioFileStreamProperty_PacketSizeUpperBound, &sizeOfUInt32, &packetBufferSize);
	if (err || packetBufferSize == 0)
	{
		err = AudioFileStreamGetProperty(audioFileStream, kAudioFileStreamProperty_MaximumPacketSize, &sizeOfUInt32, &packetBufferSize);
		if (err || packetBufferSize == 0)
		{
			// No packet size available, just use the default
			packetBufferSize = kAQDefaultBufSize;
		}
        packetBufferSize = kAQDefaultBufSize;
	}
    
	// allocate audio queue buffers
	for (unsigned int i = 0; i < kNumAQBufs; ++i)
	{
		err = AudioQueueAllocateBuffer(audioQueue, packetBufferSize, &audioQueueBuffer[i]);
		if (err)
		{
			[self reportFailWithError:AS_AUDIO_QUEUE_BUFFER_ALLOCATION_FAILED];
			return;
		}
	}
    
	// get the cookie size
	UInt32 cookieSize;
	Boolean writable;
	OSStatus ignorableError;
	ignorableError = AudioFileStreamGetPropertyInfo(audioFileStream, kAudioFileStreamProperty_MagicCookieData, &cookieSize, &writable);
	if (ignorableError)
	{
		return;
	}
    
	// get the cookie data
	void* cookieData = calloc(1, cookieSize);
	ignorableError = AudioFileStreamGetProperty(audioFileStream, kAudioFileStreamProperty_MagicCookieData, &cookieSize, cookieData);
	if (ignorableError)
	{
		return;
	}
    
	// set the cookie on the queue.
	ignorableError = AudioQueueSetProperty(audioQueue, kAudioQueueProperty_MagicCookie, cookieData, cookieSize);
	free(cookieData);
	if (ignorableError)
	{
		return;
	}
}

// This is the start method for the AudioStream thread. This thread is created
// because it will be blocked when there are no audio buffers idle (and ready
// to receive audio data).
//
// Activity in this thread:
//	- Creation and cleanup of all AudioFileStream and AudioQueue objects
//	- Receives data from the CFReadStream
//	- AudioFileStream processing
//	- Copying of data from AudioFileStream into audio buffers
//  - Stopping of the thread because of end-of-file
//	- Stopping due to error or failure
//
// Activity *not* in this thread:
//	- AudioQueue playback and notifications (happens in AudioQueue thread)
//  - Actual download of NSURLConnection data (NSURLConnection's thread)
//	- Creation of the AudioStreamer (other, likely "main" thread)
//	- Invocation of -start method (other, likely "main" thread)
//	- User/manual invocation of -stop (other, likely "main" thread)
//
// This method contains bits of the "main" function from Apple's example in
// AudioFileStreamExample.
//
- (void)startInternal
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	@synchronized(self)
	{
		if ( httpTimer ) 
		{
			[httpTimer invalidate];
			httpTimer = nil;
		}
		tryHttpCount = 0;
		
        // check state
		if (self.state != AS_STARTING_FILE_THREAD)
		{
			if (self.state != AS_STOPPING &&
                self.state != AS_STOPPED)
			{
			}
			self.state = AS_INITIALIZED;
			[pool release];
			return;
		}
		
		// initialize a mutex and condition so that we can block on buffers in use.
		pthread_mutex_init(&queueBuffersMutex, NULL);
		pthread_cond_init(&queueBufferReadyCondition, NULL);
		
		if (![self openReadStream])
		{
			goto cleanup;
		}
	}
	
	httpTimer = [NSTimer scheduledTimerWithTimeInterval:20.0 target:self 
                                                selector:@selector(httpTimer:) userInfo:nil repeats:YES];
	
	// Process the run loop until playback is finished or failed.
	BOOL isRunning = YES;
	do
	{
		isRunning = [[NSRunLoop currentRunLoop]
                     runMode:NSDefaultRunLoopMode
                     beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.25]];
		
		@synchronized(self) 
		{
			if ((seekWasRequested)&&(!isNotAllowSeek)) 
			{
				[self internalSeekToTime:requestedSeekTime];
				seekWasRequested = NO;
			}
			else if (restartWasRequested) 
			{
				[self internalRestartReadStream];
				restartWasRequested = NO;
			}
		}
		
		// If there are no queued buffers, we need to check here since the
		// handleBufferCompleteForQueue:buffer: should not change the state
		// (may not enter the synchronized section).
		if (buffersUsed == 0 && self.state == AS_PLAYING && !isStreamEnd)
		{
			err = AudioQueuePause(audioQueue);
			if (err)
			{
                [self reportFailWithError:AS_AUDIO_QUEUE_PAUSE_FAILED];
				return;
			}
			self.state = AS_BUFFERING;
		}
        
		if (  ( self.state == AS_PLAYING 
               || AS_PAUSED == self.state )    
            && httpTimer )
        {
			[httpTimer invalidate];
			httpTimer = nil;
		}
	} while (isRunning && ![self runLoopShouldExit]);
	
cleanup:
    
	@synchronized(self)
	{
		if ( httpTimer ) 
		{
			[httpTimer invalidate];
			httpTimer = nil;
		}
		//
		// Cleanup the read stream if it is still open
		//
		if (stream)
		{
			CFReadStreamClose(stream);
			CFRelease(stream);
			stream = nil;
		}
		
		//
		// Close the audio file strea,
		//
		if (audioFileStream)
		{
			err = AudioFileStreamClose(audioFileStream);
			audioFileStream = nil;
			if (err)
			{
				[self reportFailWithError:AS_FILE_STREAM_CLOSE_FAILED];
			}
		}

		//
		// Dispose of the Audio Queue
		//
		if (audioQueue)
		{
			isNotAllowSeek = YES;
			err = AudioQueueDispose(audioQueue, true);
			audioQueue = nil;
			if (err)
			{
				[self reportFailWithError:AS_AUDIO_QUEUE_DISPOSE_FAILED];
			}
		}
		
		pthread_mutex_destroy(&queueBuffersMutex);
		pthread_cond_destroy(&queueBufferReadyCondition);
        
		[httpHeaders release];
		httpHeaders = nil;
		bytesFilled = 0;
		packetsFilled = 0;
		seekByteOffset = 0;
		packetBufferSize = 0;
		self.state = AS_INITIALIZED;
		[internalThread release];
		internalThread = nil;
	}
	[pool release];
}

// Open the audioFileStream to parse data and the fileHandle as the data
// source.
//
- (BOOL)openReadStream
{
	@synchronized(self)
	{
		NSAssert([[NSThread currentThread] isEqual:internalThread],
                 @"File stream download must be started on the internalThread");
		NSAssert(stream == nil, @"Download stream already initialized");
		
		// Create the HTTP GET request
		CFHTTPMessageRef message= CFHTTPMessageCreateRequest(NULL, (CFStringRef)@"GET", (CFURLRef)url, kCFHTTPVersion1_1);

        // Set headers
		CFHTTPMessageSetHeaderFieldValue(message, CFSTR("Cookie"),(CFStringRef)(@"qqmusic_fromtag=18"));
		int Hostlen = 0;
		int *tPtr = &Hostlen;
		unsigned char *tHostPtr =(unsigned char *)[self FindHost:(char*)[[url absoluteString] UTF8String]:tPtr];
		NSString *tHost =[[NSString alloc] initWithBytes:(const unichar *)tHostPtr length:Hostlen encoding:NSUTF8StringEncoding]; 
		CFHTTPMessageSetHeaderFieldValue(message, CFSTR("Referer"),(CFStringRef)(tHost));
		[tHost release];
        
		// If we are creating this request to seek to a location, set the
		// requested byte range in the headers.
		if (fileLength > 0 && seekByteOffset > 0)
		{
            CFHTTPMessageSetHeaderFieldValue(message, CFSTR("Range"),
                                             (CFStringRef)[NSString stringWithFormat:@"bytes=%d-%d", seekByteOffset, fileLength]);
			discontinuous = YES;
		}
		
		// Create the read stream that will receive data from the HTTP request
		stream = CFReadStreamCreateForHTTPRequest(NULL, message);
		CFRelease(message);
		
		// Enable stream redirection
		if (CFReadStreamSetProperty(
                                    stream,
                                    kCFStreamPropertyHTTPShouldAutoredirect,
                                    kCFBooleanTrue) == false)
		{
            [self reportFailWithError:AS_AUDIO_QUEUE_START_FAILED];
			return NO;
		}
		
		// Handle SSL connections
		if( [[url absoluteString] rangeOfString:@"https"].location != NSNotFound )
		{
			NSDictionary *sslSettings =
            [NSDictionary dictionaryWithObjectsAndKeys:
             (NSString *)kCFStreamSocketSecurityLevelNegotiatedSSL, kCFStreamSSLLevel,
             [NSNumber numberWithBool:YES], kCFStreamSSLAllowsExpiredCertificates,
             [NSNumber numberWithBool:YES], kCFStreamSSLAllowsExpiredRoots,
             [NSNumber numberWithBool:YES], kCFStreamSSLAllowsAnyRoot,
             [NSNumber numberWithBool:NO], kCFStreamSSLValidatesCertificateChain,
             [NSNull null], kCFStreamSSLPeerName,
             nil];
            
			CFReadStreamSetProperty(stream, kCFStreamPropertySSLSettings, sslSettings);
		}
		
		// We're now ready to receive data
		self.state = AS_WAITING_FOR_DATA;
        isStreamEnd = NO;
        
		// Open the stream
		if (!CFReadStreamOpen(stream))
		{
			CFRelease(stream);
            stream = nil;
            self.stopReason = AS_STOPPING_ERROR;
            [self reportFailWithError:AS_AUDIO_QUEUE_START_FAILED];
			return NO;
		}
		
		// Set our callback function to receive the data
		CFStreamClientContext context = {0, self, NULL, NULL, NULL};
		CFReadStreamSetClient(
                              stream,
                              kCFStreamEventHasBytesAvailable |
                              kCFStreamEventErrorOccurred |
                              kCFStreamEventEndEncountered,
                              ASReadStreamCallBack,
                              &context);
		CFReadStreamScheduleWithRunLoop(stream, CFRunLoopGetCurrent(), kCFRunLoopCommonModes);
	}
	return YES;
}

- (void)httpTimer:(id)aSender
{
	[httpTimer invalidate];
	httpTimer = nil;
	[self reportFailWithError:AS_NETWORK_CONNECTION_FAILED];
}

// Called from our internal runloop to reopen the stream at a seeked location
//
- (void)internalSeekToTime:(double)newSeekTime
{
	lastProgress=newSeekTime;
	if ([self calculatedBitRate] == 0.0 || fileLength <= 0)
	{
		return;
	}
	//
	// Calculate the byte offset for seeking
	//
	seekByteOffset = dataOffset +
    (newSeekTime / self.duration) * (fileLength - dataOffset);
    
	//
	// Attempt to leave 1 useful packet at the end of the file (although in
	// reality, this may still seek too far if the file has a long trailer).
	//
	if (seekByteOffset > fileLength - 2 * packetBufferSize)
	{
		seekByteOffset = fileLength - 2 * packetBufferSize;
	}
	
	//
	// Store the old time from the audio queue and the time that we're seeking
	// to so that we'll know the correct time progress after seeking.
	//
	seekTime = newSeekTime;
	
	//
	// Attempt to align the seek with a packet boundary
	//
	double calculatedBitRate = [self calculatedBitRate];
	if (packetDuration > 0 &&
		calculatedBitRate > 0)
	{
		UInt32 ioFlags = 0;
		SInt64 packetAlignedByteOffset;
		SInt64 seekPacket = floor(newSeekTime / packetDuration);
		err = AudioFileStreamSeek(audioFileStream, seekPacket, &packetAlignedByteOffset, &ioFlags);
		if (!err && !(ioFlags & kAudioFileStreamSeekFlag_OffsetIsEstimated))
		{
			seekTime -= ((seekByteOffset - dataOffset) - packetAlignedByteOffset) * 8.0 / calculatedBitRate;
			seekByteOffset = packetAlignedByteOffset + dataOffset;
		}
	}
    
	// Close the current read straem
	if (stream)
	{
		CFReadStreamClose(stream);
		CFRelease(stream);
		stream = nil;
	}
	
	totalbytes = 0;
    
	// Stop the audio queue
	self.state = AS_STOPPING;
	self.stopReason = AS_STOPPING_TEMPORARILY;
	isNotAllowSeek = YES;
    
	err = AudioQueueStop(audioQueue,  true);
	if (err)
	{
        [self reportFailWithError:AS_AUDIO_QUEUE_STOP_FAILED];
		return;
	}
    
	// Re-open the file stream. It will request a byte-range starting at
	// seekByteOffset.
	[self openReadStream];
}

// Called from our internal runloop to reopen the stream at a seeked location
//
- (void)internalRestartReadStream
{
	if ([self calculatedBitRate] == 0.0 || fileLength <= 0)
	{
		return;
	}

	// Attempt to leave 1 useful packet at the end of the file (although in
	// reality, this may still seek too far if the file has a long trailer).
	if (endByteOffset > fileLength - 2 * packetBufferSize)
	{
		endByteOffset = fileLength - 2 * packetBufferSize;
	}

	// Close the current read straem
	if (stream)
	{
		CFReadStreamClose(stream);
		CFRelease(stream);
		stream = nil;
	}
	
	// Re-open the file stream. It will request a byte-range starting at
	// seekByteOffset.
	[self reopenReadStream];
}

// Open the audioFileStream to parse data and the fileHandle as the data
// source.
//
- (BOOL)reopenReadStream
{
	@synchronized(self)
	{
		NSAssert([[NSThread currentThread] isEqual:internalThread],
                 @"File stream download must be started on the internalThread");
		NSAssert(stream == nil, @"Download stream already initialized");
		

		// Create the HTTP GET request
		CFHTTPMessageRef message= CFHTTPMessageCreateRequest(NULL, (CFStringRef)@"GET", (CFURLRef)url, kCFHTTPVersion1_1);
        
        // set headers
		CFHTTPMessageSetHeaderFieldValue(message, CFSTR("Cookie"),(CFStringRef)(@"qqmusic_fromtag=18"));
		int Hostlen = 0;
		int *tPtr = &Hostlen;
		unsigned char *tHostPtr =(unsigned char *)[self FindHost:(char*)[[url absoluteString] UTF8String]:tPtr];
		NSString *tHost =[[NSString alloc] initWithBytes:(const unichar *)tHostPtr length:Hostlen encoding:NSUTF8StringEncoding]; 
		CFHTTPMessageSetHeaderFieldValue(message, CFSTR("Referer"),(CFStringRef)(tHost));
		[tHost release];
        
		// If we are creating this request to seek to a location, set the
		// requested byte range in the headers.
		if (fileLength > 0 && endByteOffset > 0)
		{
            CFHTTPMessageSetHeaderFieldValue(message, CFSTR("Range"),
                                             (CFStringRef)[NSString stringWithFormat:@"bytes=%d-%d", endByteOffset, fileLength]);
			discontinuous = YES;
		}
		
		// Create the read stream that will receive data from the HTTP request
		stream = CFReadStreamCreateForHTTPRequest(NULL, message);
		CFRelease(message);
		
		// Enable stream redirection
		if (CFReadStreamSetProperty(
                                    stream,
                                    kCFStreamPropertyHTTPShouldAutoredirect,
                                    kCFBooleanTrue) == false)
		{
            [self reportFailWithError:AS_AUDIO_QUEUE_START_FAILED];
			return NO;
		}
		
		// Handle SSL connections
		if( [[url absoluteString] rangeOfString:@"https"].location != NSNotFound )
		{
			NSDictionary *sslSettings =
			[NSDictionary dictionaryWithObjectsAndKeys:
			 (NSString *)kCFStreamSocketSecurityLevelNegotiatedSSL, kCFStreamSSLLevel,
			 [NSNumber numberWithBool:YES], kCFStreamSSLAllowsExpiredCertificates,
			 [NSNumber numberWithBool:YES], kCFStreamSSLAllowsExpiredRoots,
			 [NSNumber numberWithBool:YES], kCFStreamSSLAllowsAnyRoot,
			 [NSNumber numberWithBool:NO], kCFStreamSSLValidatesCertificateChain,
			 [NSNull null], kCFStreamSSLPeerName,
			 nil];
			
			CFReadStreamSetProperty(stream, kCFStreamPropertySSLSettings, sslSettings);
		}
		
        // We're now ready to receive data
		self.state = AS_WAITING_FOR_DATA;
        isStreamEnd = NO;
        
		// Open the stream
		if (!CFReadStreamOpen(stream))
		{
			CFRelease(stream);
			stream = nil;
			self.stopReason = AS_STOPPING_ERROR;
            [self reportFailWithError:AS_AUDIO_QUEUE_START_FAILED];
			return NO;
		}
		
		// Set our callback function to receive the data
		CFStreamClientContext context = {0, self, NULL, NULL, NULL};
		CFReadStreamSetClient(
                              stream,
                              kCFStreamEventHasBytesAvailable | kCFStreamEventErrorOccurred | kCFStreamEventEndEncountered,
                              ASReadStreamCallBack,
                              &context);
		CFReadStreamScheduleWithRunLoop(stream, CFRunLoopGetCurrent(), kCFRunLoopCommonModes);
	}
	return YES;
}

// returns YES if the run loop should exit.
//
- (BOOL)runLoopShouldExit
{
	@synchronized(self)
	{
		if (self.errorCode != AS_NO_ERROR ||
			(self.state == AS_STOPPED &&
             self.stopReason != AS_STOPPING_TEMPORARILY))
		{
			return YES;
		}
	}
	return NO;
}

// Object method which handles implementation of MyPropertyListenerProc
//
// Parameters:
//    inAudioFileStream - should be the same as self->audioFileStream
//    inPropertyID - the property that changed
//    ioFlags - the ioFlags passed in
//
- (void)handlePropertyChangeForFileStream:(AudioFileStreamID)inAudioFileStream
                     fileStreamPropertyID:(AudioFileStreamPropertyID)inPropertyID
                                  ioFlags:(UInt32 *)ioFlags
{
	@synchronized(self)
	{
		if ([self isFinishing])
		{
			return;
		}
		
		if (inPropertyID == kAudioFileStreamProperty_ReadyToProducePackets)
		{
			discontinuous = true;
		}
		else if (inPropertyID == kAudioFileStreamProperty_DataOffset)
		{
			SInt64 offset;
			UInt32 offsetSize = sizeof(offset);
			err = AudioFileStreamGetProperty(inAudioFileStream, kAudioFileStreamProperty_DataOffset, &offsetSize, &offset);
			if (err)
			{
				[self reportFailWithError:AS_FILE_STREAM_GET_PROPERTY_FAILED];
				return;
			}
			dataOffset = offset;
			
			if (audioDataByteCount)
			{
				fileLength = dataOffset + audioDataByteCount;
			}
		}
		else if (inPropertyID == kAudioFileStreamProperty_AudioDataByteCount)
		{
			UInt32 byteCountSize = sizeof(UInt64);
			err = AudioFileStreamGetProperty(inAudioFileStream, kAudioFileStreamProperty_AudioDataByteCount, &byteCountSize, &audioDataByteCount);
			if (err)
			{
				[self reportFailWithError:AS_FILE_STREAM_GET_PROPERTY_FAILED];
				return;
			}
			fileLength = dataOffset + audioDataByteCount;
		}
		else if (inPropertyID == kAudioFileStreamProperty_DataFormat)
		{
			if (asbd.mSampleRate == 0)
			{
				UInt32 asbdSize = sizeof(asbd);
				
				// get the stream format.
				err = AudioFileStreamGetProperty(inAudioFileStream, kAudioFileStreamProperty_DataFormat, &asbdSize, &asbd);
				if (err)
				{
					[self reportFailWithError:AS_FILE_STREAM_GET_PROPERTY_FAILED];
					return;
				}
			}
		}
		else if (inPropertyID == kAudioFileStreamProperty_FormatList)
		{
			Boolean outWriteable;
			UInt32 formatListSize;
			err = AudioFileStreamGetPropertyInfo(inAudioFileStream, kAudioFileStreamProperty_FormatList, &formatListSize, &outWriteable);
			if (err)
			{
				[self reportFailWithError:AS_FILE_STREAM_GET_PROPERTY_FAILED];
				return;
			}
			
			AudioFormatListItem *formatList = malloc(formatListSize);
	        err = AudioFileStreamGetProperty(inAudioFileStream, kAudioFileStreamProperty_FormatList, &formatListSize, formatList);
			if (err)
			{
                free(formatList);
				[self reportFailWithError:AS_FILE_STREAM_GET_PROPERTY_FAILED];
				return;
			}
            
			for (int i = 0; i * sizeof(AudioFormatListItem) < formatListSize; i += sizeof(AudioFormatListItem))
			{
				AudioStreamBasicDescription pasbd = formatList[i].mASBD;
                
				if (pasbd.mFormatID == kAudioFormatMPEG4AAC_HE)
				{
					//
					// We've found HE-AAC, remember this to tell the audio queue
					// when we construct it.
					//
#if !TARGET_IPHONE_SIMULATOR
					asbd = pasbd;
#endif
					break;
				}                                
			}
			free(formatList);
		}
		else
		{
		}
	}
}

//
// Object method which handles the implementation of MyPacketsProc
//
// Parameters:
//    inInputData - the packet data
//    inNumberBytes - byte size of the data
//    inNumberPackets - number of packets in the data
//    inPacketDescriptions - packet descriptions
//
- (void)handleAudioPackets:(const void *)inInputData
               numberBytes:(UInt32)inNumberBytes
             numberPackets:(UInt32)inNumberPackets
        packetDescriptions:(AudioStreamPacketDescription *)inPacketDescriptions;
{
	@synchronized(self)
	{
		if ([self isFinishing])
		{
			return;
		}
		
		if (bitRate == 0)
		{
			//
			// m4a and a few other formats refuse to parse the bitrate so
			// we need to set an "unparseable" condition here. If you know
			// the bitrate (parsed it another way) you can set it on the
			// class if needed.
			//
			bitRate = ~0;
		}
		
		// we have successfully read the first packests from the audio stream, so
		// clear the "discontinuous" flag
		if (discontinuous)
		{
			discontinuous = false;
		}
		
		if (!audioQueue)
		{
			[self createQueue];
		}
	}
    
	// the following code assumes we're streaming VBR data. for CBR data, the second branch is used.
	if (inPacketDescriptions)
	{
		for (int i = 0; i < inNumberPackets; ++i)
		{
			SInt64 packetOffset = inPacketDescriptions[i].mStartOffset;
			SInt64 packetSize   = inPacketDescriptions[i].mDataByteSize;
			size_t bufSpaceRemaining;
			
			if (processedPacketsCount < BitRateEstimationMaxPackets)
			{
				processedPacketsSizeTotal += packetSize;
				processedPacketsCount += 1;
			}
			
			@synchronized(self)
			{
				// If the audio was terminated before this point, then
				// exit.
				if ([self isFinishing])
				{
					return;
				}
				
				if (packetSize > packetBufferSize)
				{
					[self reportFailWithError:AS_AUDIO_BUFFER_TOO_SMALL];
				}
                
				bufSpaceRemaining = packetBufferSize - bytesFilled;
			}
            
			// if the space remaining in the buffer is not enough for this packet, then enqueue the buffer.
			if (bufSpaceRemaining < packetSize)
			{
				[self enqueueBuffer];
			}
			
			@synchronized(self)
			{
				// If the audio was terminated while waiting for a buffer, then
				// exit.
				if ([self isFinishing])
				{
					return;
				}
				
				//
				// If there was some kind of issue with enqueueBuffer and we didn't
				// make space for the new audio data then back out
				//
				if (bytesFilled + packetSize >= packetBufferSize)
				{
					return;
				}
				
				// copy data to the audio queue buffer
				AudioQueueBufferRef fillBuf = audioQueueBuffer[fillBufferIndex];
				memcpy((char*)fillBuf->mAudioData + bytesFilled, (const char*)inInputData + packetOffset, packetSize);
                
				// fill out packet description
				packetDescs[packetsFilled] = inPacketDescriptions[i];
				packetDescs[packetsFilled].mStartOffset = bytesFilled;
				// keep track of bytes filled and packets filled
				bytesFilled += packetSize;
				packetsFilled += 1;
			}
			
			// if that was the last free packet description, then enqueue the buffer.
			size_t packetsDescsRemaining = kAQMaxPacketDescs - packetsFilled;
			if (packetsDescsRemaining == 0) 
			{
				[self enqueueBuffer];
			}
		}	
	}
	else
	{
		size_t offset = 0;
		while (inNumberBytes)
		{
			// if the space remaining in the buffer is not enough for this packet, then enqueue the buffer.
			size_t bufSpaceRemaining = kAQDefaultBufSize - bytesFilled;
			if (bufSpaceRemaining < inNumberBytes)
			{
				[self enqueueBuffer];
			}
			
			@synchronized(self)
			{
				// If the audio was terminated while waiting for a buffer, then
				// exit.
				if ([self isFinishing])
				{
					return;
				}
				
				bufSpaceRemaining = kAQDefaultBufSize - bytesFilled;
				size_t copySize;
				if (bufSpaceRemaining < inNumberBytes)
				{
					copySize = bufSpaceRemaining;
				}
				else
				{
					copySize = inNumberBytes;
				}
                
				//
				// If there was some kind of issue with enqueueBuffer and we didn't
				// make space for the new audio data then back out
				//
				if (bytesFilled >= packetBufferSize)
				{
					return;
				}
				
				// copy data to the audio queue buffer
				AudioQueueBufferRef fillBuf = audioQueueBuffer[fillBufferIndex];
				memcpy((char*)fillBuf->mAudioData + bytesFilled, (const char*)(inInputData + offset), copySize);
                
                
				// keep track of bytes filled and packets filled
				bytesFilled += copySize;
				packetsFilled = 0;
				inNumberBytes -= copySize;
				offset += copySize;
			}
		}
	}
}

// Handles the buffer completetion notification from the audio queue
//
// Parameters:
//    inAQ - the queue
//    inBuffer - the buffer
//
- (void)handleBufferCompleteForQueue:(AudioQueueRef)inAQ
                              buffer:(AudioQueueBufferRef)inBuffer
{
	unsigned int bufIndex = -1;
	for (unsigned int i = 0; i < kNumAQBufs; ++i)
	{
		if (inBuffer == audioQueueBuffer[i])
		{
			bufIndex = i;
			break;
		}
	}
	
	if (bufIndex == -1)
	{
		[self reportFailWithError:AS_AUDIO_QUEUE_BUFFER_MISMATCH];
		pthread_mutex_lock(&queueBuffersMutex);
		pthread_cond_signal(&queueBufferReadyCondition);
		pthread_mutex_unlock(&queueBuffersMutex);
		return;
	}
	
	// signal waiting thread that the buffer is free.
	pthread_mutex_lock(&queueBuffersMutex);
	inuse[bufIndex] = false;
	buffersUsed--;
    
    //
    //  Enable this logging to measure how many buffers are queued at any time.
    //
#if LOG_QUEUED_BUFFERS
    //	QKLog(@"Queued buffers: %ld", buffersUsed);
#endif
	
	pthread_cond_signal(&queueBufferReadyCondition);
	pthread_mutex_unlock(&queueBuffersMutex);
}

//
// Implementation for MyAudioQueueIsRunningCallback
//
// Parameters:
//    inAQ - the audio queue
//    inID - the property ID
//
- (void)handlePropertyChangeForQueue:(AudioQueueRef)inAQ
                          propertyID:(AudioQueuePropertyID)inID
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	@synchronized(self)
	{
		if (inID == kAudioQueueProperty_IsRunning)
		{
			if (isStreamEnd && self.state != AS_INITIALIZED)
			{
				self.state = AS_STOPPED;
			}
			else if (AS_WAITING_FOR_QUEUE_TO_START == self.state)
			{
				//
				// Note about this bug avoidance quirk:
				//
				// On cleanup of the AudioQueue thread, on rare occasions, there would
				// be a crash in CFSetContainsValue as a CFRunLoopObserver was getting
				// removed from the CFRunLoop.
				//
				// After lots of testing, it appeared that the audio thread was
				// attempting to remove CFRunLoop observers from the CFRunLoop after the
				// thread had already deallocated the run loop.
				//
				// By creating an NSRunLoop for the AudioQueue thread, it changes the
				// thread destruction order and seems to avoid this crash bug -- or
				// at least I haven't had it since (nasty hard to reproduce error!)
				//
				[NSRunLoop currentRunLoop];
				self.state = AS_PLAYING;
			}
			else
			{
			}
		}
	}
	[pool release];
}

// Called from MyPacketsProc and connectionDidFinishLoading to pass filled audio
// bufffers (filled by MyPacketsProc) to the AudioQueue for playback. This
// function does not return until a buffer is idle for further filling or
// the AudioQueue is stopped.
//
// This function is adapted from Apple's example in AudioFileStreamExample with
// CBR functionality added.
//
- (void)enqueueBuffer
{
	@synchronized(self)
	{
		if ([self isFinishing] || stream == 0)
		{
			return;
		}
		inuse[fillBufferIndex] = true;		// set in use flag
		buffersUsed++;
        //
        //  Enable this logging to measure how many buffers are queued at any time.
        //
#if LOG_QUEUED_BUFFERS
        //		QKLog(@"Queued buffersUsed++: %ld", buffersUsed);
#endif
        
		// enqueue buffer
		AudioQueueBufferRef fillBuf = audioQueueBuffer[fillBufferIndex];
		fillBuf->mAudioDataByteSize = bytesFilled;
		
		if (packetsFilled)
		{
			err = AudioQueueEnqueueBuffer(audioQueue, fillBuf, packetsFilled, packetDescs);
		}
		else
		{
			err = AudioQueueEnqueueBuffer(audioQueue, fillBuf, 0, NULL);
		}
		
		if (err)
		{
			[self reportFailWithError:AS_AUDIO_QUEUE_ENQUEUE_FAILED];
			return;
		}
        
		if (self.state == AS_BUFFERING					||
            self.state == AS_WAITING_FOR_DATA	||
            self.state == AS_FLUSHING_EOF			||
            (self.state == AS_STOPPED && self.stopReason == AS_STOPPING_TEMPORARILY))
		{
			//
			// Fill all the buffers before starting. This ensures that the
			// AudioFileStream stays a small amount ahead of the AudioQueue to
			// avoid an audio glitch playing streaming files on iPhone SDKs < 3.0
			//
			if (self.state == AS_FLUSHING_EOF || buffersUsed == kNumAQBufs - 1)
			{
				if (self.state == AS_BUFFERING)
				{
					//QKLog(@"AudioQueueStart1");
					err = AudioQueueStart(audioQueue, NULL);
					if (err)
					{
						//QKLog( @"AudioQueueStart 22" );
						[self reportFailWithError:AS_AUDIO_QUEUE_START_FAILED];
						return;
					}
					self.state = AS_PLAYING;
				}
				else
				{
					self.state = AS_WAITING_FOR_QUEUE_TO_START;
					//QKLog(@"AudioQueueStart2");
					err = AudioQueueStart(audioQueue, NULL);
					if (err)
					{
						//QKLog( @"AudioQueueStart 33" );
						[self reportFailWithError:AS_AUDIO_QUEUE_START_FAILED];
						return;
					}
					//QKLog(@"AudioQueueStart3");
					isNotAllowSeek = NO;
				}
			}
		}
        
		// go to next buffer
		if (++fillBufferIndex >= kNumAQBufs) fillBufferIndex = 0;
		bytesFilled = 0;		// reset bytes filled
		packetsFilled = 0;		// reset packets filled
	}
    
	// wait until next buffer is not in use
	pthread_mutex_lock(&queueBuffersMutex); 
	while (inuse[fillBufferIndex])
	{
		pthread_cond_wait(&queueBufferReadyCondition, &queueBuffersMutex);
	}
	pthread_mutex_unlock(&queueBuffersMutex);
}

//
// Reads data from the network file stream into the AudioFileStream
//
// Parameters:
//    aStream - the network file stream
//    eventType - the event which triggered this method
//
- (void)handleReadFromStream:(CFReadStreamRef)aStream
                   eventType:(CFStreamEventType)eventType
{
	if (aStream != stream)
	{
		// Ignore messages from old streams
		return;
	}
	
	if (eventType == kCFStreamEventErrorOccurred)
	{
        [self reportFailWithError:AS_AUDIO_DATA_NOT_FOUND];
		
	}
	else if (eventType == kCFStreamEventEndEncountered)
	{
		endByteOffset = totalbytes + seekByteOffset;
        
		if ( (endByteOffset < fileLength - 2 * packetBufferSize)&&( self.progress < self.duration - 5 ) )
		{
			restartWasRequested = YES;
			return;
		}
        
		@synchronized(self)
		{
			if ([self isFinishing])
			{
				return;
			}
		}
		
		// If there is a partially filled buffer, pass it to the AudioQueue for
		// processing
		if (bytesFilled)
		{
			if (self.state == AS_WAITING_FOR_DATA)
			{
				// Force audio data smaller than one whole buffer to play.
				self.state = AS_FLUSHING_EOF;
			}
			[self enqueueBuffer];
		}
        
		@synchronized(self)
		{
			if (self.state == AS_WAITING_FOR_DATA)
			{
				[self reportFailWithError:AS_AUDIO_DATA_NOT_FOUND];
			}
			
			// We left the synchronized section to enqueue the buffer so we
			// must check that we are !finished again before touching the
			// audioQueue
			else if (![self isFinishing])
			{
				if (audioQueue)
				{
					// Set the progress at the end of the stream
					err = AudioQueueFlush(audioQueue);
					if (err)
					{
						[self reportFailWithError:AS_AUDIO_QUEUE_FLUSH_FAILED];
						return;
					}
                    
//					self.state = AS_STOPPING;
                    isStreamEnd = YES;
					self.stopReason = AS_STOPPING_EOF;
					err = AudioQueueStop(audioQueue, false);
					if (err)
					{
						[self reportFailWithError:AS_AUDIO_QUEUE_FLUSH_FAILED];
						return;
					}
				}
				else
				{
					self.state = AS_STOPPED;
					self.stopReason = AS_STOPPING_EOF;
				}
			}
		}
	}
	else if (eventType == kCFStreamEventHasBytesAvailable)
	{
		if (!httpHeaders)
		{
			CFTypeRef message =
            CFReadStreamCopyProperty(stream, kCFStreamPropertyHTTPResponseHeader);
			httpHeaders =
            (NSDictionary *)CFHTTPMessageCopyAllHeaderFields((CFHTTPMessageRef)message);
			CFRelease(message);
			
			// Only read the content length if we seeked to time zero, otherwise
			// we only have a subset of the total bytes.
			if (seekByteOffset == 0)
			{
				fileLength = [[httpHeaders objectForKey:@"Content-Length"] integerValue];
			}
		}
        
		if (!audioFileStream)
		{
			// Attempt to guess the file type from the URL. Reading the MIME type
			// from the httpHeaders might be a better approach since lots of
			// URL's don't have the right extension.
			//
			// If you have a fixed file-type, you may want to hardcode this.
			AudioFileTypeID fileTypeHint =
            [QKNetAudioPlayer hintForFileExtension:[[url path] pathExtension]];

			// create an audio file stream parser
			err = AudioFileStreamOpen(self, MyPropertyListenerProc, MyPacketsProc, 
                                      fileTypeHint, &audioFileStream);
			if (err)
			{
				[self reportFailWithError:AS_FILE_STREAM_OPEN_FAILED];
				return;
			}
		}
		
		UInt8 bytes[kAQDefaultBufSize];
		CFIndex length;
		@synchronized(self)
		{
			if ([self isFinishing] || !CFReadStreamHasBytesAvailable(stream))
			{
				return;
			}
            
            CFIndex lengthOfStream = 0;
            CFReadStreamGetBuffer(aStream, 0, &lengthOfStream);
			
			// Read the bytes from the stream
			length = CFReadStreamRead(stream, bytes, kAQDefaultBufSize);
			
			totalbytes += length;
			
			if (length == -1)
			{
				if ( tryHttpCount <= 0  
                    && [ReachabilityManager sharedInstance].networkStatus != NotReachable ) 
				{
					tryHttpCount = 1;
					[self seekToTime: self.progress ];
				}
				else 
				{
					tryHttpCount = 0;
					
					[self reportFailWithError:AS_AUDIO_DATA_NOT_FOUND];
				}
				return;
			}
			
			tryHttpCount = 0;
			
			if (length == 0)
			{
				return;
			}

		}
        
		if (discontinuous)
		{
			err = AudioFileStreamParseBytes(audioFileStream, length, bytes, kAudioFileStreamParseFlag_Discontinuity);
			if (err)
			{
				[self reportFailWithError:AS_FILE_STREAM_PARSE_BYTES_FAILED];
				return;
			}
		}
		else
		{
			err = AudioFileStreamParseBytes(audioFileStream, length, bytes, 0);
			if (err)
			{
				[self reportFailWithError:AS_FILE_STREAM_PARSE_BYTES_FAILED];
				return;
			}
		}
	}
}
#pragma mark QKPlayerProtocol

- (void)play
{
	@synchronized (self)
	{
		if (AS_PAUSED == self.state)
		{
			[self pause];
		}
		else if (AS_INITIALIZED == self.state)
		{
			NSAssert([[NSThread currentThread] isEqual:[NSThread mainThread]],
                     @"Playback can only be started from the main thread.");
            
			notificationCenter = [[NSNotificationCenter defaultCenter] retain];
            
			self.state = AS_STARTING_FILE_THREAD;
			internalThread =[[NSThread alloc]initWithTarget:self selector:@selector(startInternal) object:nil];
            
			[internalThread start];
		}
	}
}

- (void)pause
{
	@synchronized(self)
	{
		if (NULL != audioQueue 
            && self.state != AS_STOPPING 
            && self.state != AS_STOPPED 
            && self.state != AS_PAUSED) 
		{
			err = AudioQueuePause(audioQueue);
			if (err)
			{
				[self reportFailWithError:AS_AUDIO_QUEUE_PAUSE_FAILED];
				return;
			}
		}
		self.state = AS_PAUSED;
	}
}

- (void)resume
{
	if (NULL != audioQueue 
        && AS_PAUSED == self.state) 
	{
		err = AudioQueueStart(audioQueue, NULL);
		if (err)
		{
            [self reportFailWithError:AS_AUDIO_QUEUE_START_FAILED];
			return;
		}
		self.state = AS_PLAYING;
	}
}

- (void)stop
{
	BOOL isNeedStop = NO;
	@synchronized(self)
	{
		if (NULL != audioQueue &&
			(self.state == AS_PLAYING || 
			 self.state == AS_PAUSED  ||
			 self.state == AS_BUFFERING ) )// || self.state == AS_WAITING_FOR_QUEUE_TO_START))
		{
			isNeedStop = NO;
			self.state = AS_STOPPING;
			self.stopReason = AS_STOPPING_USER_ACTION;
			isNotAllowSeek = YES;

			err = AudioQueueStop(audioQueue, true);

			if (err)
			{
				[self reportFailWithError:AS_AUDIO_QUEUE_STOP_FAILED];
				return;
			}  
			self.state = AS_STOPPED;
			self.stopReason = AS_STOPPING_USER_ACTION;
		}
		else if (self.state != AS_INITIALIZED)
		{
			self.state = AS_STOPPED;
			self.stopReason = AS_STOPPING_USER_ACTION;
		}
		seekWasRequested = NO;
	}
	
	if ( isNeedStop )
	{

		err = AudioQueueStop(audioQueue, true);
		if (err)
		{
			[self reportFailWithError:AS_AUDIO_QUEUE_STOP_FAILED];
			return;
		}
	}
    
    // TODO
	int index = 0;
	while (self.state != AS_INITIALIZED && index < 20 )
	{
		index++;
		[NSThread sleepForTimeInterval:0.01];
	}
}

// returns YES if the audio currently playing.
//
- (BOOL)isPlaying
{
    return (	 self.state == AS_PLAYING
            || self.state ==AS_WAITING_FOR_QUEUE_TO_START
            || self.state==AS_BUFFERING 
            || self.state ==AS_WAITING_FOR_DATA);
}

// returns YES if the audio currently playing.
//
- (BOOL)isPaused
{
	if (self.state == AS_PAUSED)
	{
		return YES;
	}
	return NO;
}

// returns YES if the AudioStreamer is waiting for a state transition of some
// kind.
//
- (BOOL)isWaiting
{
	@synchronized(self)
	{
		if ([self isFinishing] ||
			self.state == AS_STARTING_FILE_THREAD||
			self.state == AS_WAITING_FOR_DATA ||
			self.state == AS_WAITING_FOR_QUEUE_TO_START ||
			self.state == AS_BUFFERING)
		{
			return YES;
		}
	}
	return NO;
}

// Calculates the duration of available audio from the bitRate and fileLength.
//
// returns the calculated duration in seconds.
//
- (double)duration
{
    if (asbd.mFormatID == kAudioFormatAppleIMA4)
    {
        if (0 != audioDataByteCount) 
        {
            return ((audioDataByteCount / asbd.mBytesPerPacket) * asbd.mFramesPerPacket)/ asbd.mSampleRate;
        }
        return 0.0;
    }
    else
    {
        double calculatedBitRate = [self calculatedBitRate];
        if (calculatedBitRate == 0 || fileLength == 0)
        {
            return 0.0;
        }
        return (fileLength - dataOffset) / (calculatedBitRate * 0.125);
    }
}

- (double)durationCanPlay
{
    return 0.0;
}

// returns the current playback progress. Will return zero if sampleRate has
// not yet been detected.
//
- (double)progress
{
	@synchronized(self)
	{
        if (NULL != audioQueue) 
        {
            if ( seekWasRequested )
            {
                return requestedSeekTime;
            }
            if (sampleRate > 0 && ![self isFinishing])
            {
                if (self.state != AS_PLAYING && self.state != AS_PAUSED && self.state != AS_BUFFERING && self.state != AS_STOPPING)
                {
                    return  lastProgress;
                }
                
                AudioTimeStamp queueTime;
                Boolean discontinuity;
                err = AudioQueueGetCurrentTime(audioQueue, NULL, &queueTime, &discontinuity);
                const OSStatus AudioQueueStopped = 0x73746F70; // 0x73746F70 is 'stop'
                if (err == AudioQueueStopped)
                {
                    return lastProgress;
                }
                
                double progress = seekTime + queueTime.mSampleTime / sampleRate;
                if (progress < 0.0)
                {
                    progress = 0.0;
                }
                
                lastProgress = progress;
                return progress;
            }
        }
	}
	return 0.0;
}

- (BOOL)isSeekable
{
    return YES;
}

// Attempts to seek to the new time. Will be ignored if the bitrate or fileLength
// are unknown.
//
// Parameters:
//    newTime - the time to seek to
//
- (BOOL)seekToTime:(double)newSeekTime
{
	@synchronized(self)
	{
        if (NULL != audioQueue)
        {
            if ( /*( seekWasRequested )||*/( isNotAllowSeek ) )
                return YES;
            seekWasRequested = YES;
            requestedSeekTime = newSeekTime;
            lastProgress=newSeekTime;
            if ( self.state == AS_PAUSED )
            {
                [self pause];
            }
            return YES;
        }
	}
    return NO;
}

@end


#pragma mark Audio Queue Callback
static void MyAudioQueueOutputCallback(void* inClientData, AudioQueueRef inAQ, AudioQueueBufferRef inBuffer)
{
    // this is called by the audio queue when it has finished decoding our data. 
	// The buffer is now free to be reused.
	QKNetAudioPlayer* streamer = (QKNetAudioPlayer*)inClientData;
	[streamer handleBufferCompleteForQueue:inAQ buffer:inBuffer];
}

static void MyAudioQueueIsRunningCallback(void *inUserData, AudioQueueRef inAQ, AudioQueuePropertyID inID)
{
    QKNetAudioPlayer* streamer = (QKNetAudioPlayer *)inUserData;
	[streamer handlePropertyChangeForQueue:inAQ propertyID:inID];
}

static void MyPropertyListenerProc(	void *							inClientData,
                            AudioFileStreamID				inAudioFileStream,
                            AudioFileStreamPropertyID		inPropertyID,
                            UInt32 *						ioFlags)
{
    // this is called by audio file stream when it finds property values
	QKNetAudioPlayer* streamer = (QKNetAudioPlayer *)inClientData;
	[streamer handlePropertyChangeForFileStream:inAudioFileStream 
                           fileStreamPropertyID:inPropertyID 
                                        ioFlags:ioFlags];
}

static void MyPacketsProc(				void *							inClientData,
                   UInt32							inNumberBytes,
                   UInt32							inNumberPackets,
                   const void *					inInputData,
                   AudioStreamPacketDescription	*inPacketDescriptions)
{
    // this is called by audio file stream when it finds packets of audio
	QKNetAudioPlayer* streamer = (QKNetAudioPlayer *)inClientData;
	[streamer handleAudioPackets:inInputData 
                     numberBytes:inNumberBytes 
                   numberPackets:inNumberPackets 
              packetDescriptions:inPacketDescriptions];
}


#pragma mark CFReadStream Callback
static void ASReadStreamCallBack(CFReadStreamRef aStream,
                                 CFStreamEventType eventType,
                                 void* inClientInfo)
{
    QKNetAudioPlayer* streamer = (QKNetAudioPlayer *)inClientInfo;
    [streamer handleReadFromStream:aStream eventType:eventType];
}
