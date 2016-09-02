//
//  QKFileAudioPlayer.m
//  QQKala
//
//  Created by frost on 12-6-15.
//  Copyright (c) 2012年 Tencent. All rights reserved.
//

#import "QKFileAudioPlayer.h"

static BOOL kNewAudioTrackActive = NO;
static UInt32 kNewAudioBufferSizeBytes = 0x10000; // 64k

NSString * const NewAudioTrackFinishedPlayingNotification = @"NewAudioTrackFinishedPlayingNotification";

// ---------------------------------------------
// forward declaration
// Audio Queue callback
// ---------------------------------------------
static void propertyListenerCallback(void *inUserData, AudioQueueRef queueObject, AudioQueuePropertyID propertyID);
static void BufferCallback(void *inUserData, AudioQueueRef inAQ, AudioQueueBufferRef buffer);

// ---------------------------------------------
// QKFileAudioPlayer private category
// ---------------------------------------------
@interface QKFileAudioPlayer(Private)

- (double)calculatedBitRate;
- (void)reportFailWithError:(AudioStreamerErrorCode)anErrorCode;
- (void)reportFailOnMainThread;
- (BOOL)isFinishing;
- (void)callbackForBuffer:(AudioQueueBufferRef)buffer;
- (UInt32)readPacketsIntoBuffer:(AudioQueueBufferRef)buffer;
- (void)playBackIsRunningStateChanged;
- (void)postTrackFinishedPlayingNotification:(id) object;

@end

// ---------------------------------------------
// QKFileAudioPlayer implementation
// ---------------------------------------------
@implementation QKFileAudioPlayer

#pragma mark life cycle

- (id)initWithFilePath:(NSString*)path
{
	if (path == nil) return nil;
	if(!(self = [super init])) return nil;
    
	UInt32 size, maxPacketSize;
	char *cookie;
	int i;

	filePath= [[NSURL alloc] initFileURLWithPath: path];
	
	// try to open up the file using the specified path
	OSStatus error1 =AudioFileOpenURL((CFURLRef)filePath, kAudioFileReadPermission, 0, &audioFile);
	if (noErr != error1)
	{
		return nil;
	}
	
	// get the data format of the file
	size = sizeof(asbd);
	AudioFileGetProperty(audioFile, kAudioFilePropertyDataFormat, &size, &asbd);
	packetBufferSize = asbd.mBytesPerPacket;
	size = sizeof(bitRate);
	AudioFileGetProperty(audioFile, kAudioFilePropertyBitRate, &size, &bitRate);
	size = sizeof(packetsCount);
	AudioFileGetProperty(audioFile, kAudioFilePropertyAudioDataPacketCount, &size, &packetsCount);
	
	//Get file length
	UInt32 propertySize = sizeof(fileDuration);
	AudioFileGetProperty(audioFile, kAudioFilePropertyEstimatedDuration, &propertySize, &fileDuration);
	
	sampleRate = asbd.mSampleRate;
	packetDuration = asbd.mFramesPerPacket / sampleRate;
	
	// create a new playback queue using the specified data format and buffer callback
	AudioQueueNewOutput(&asbd, BufferCallback, self, nil, nil, 0, &audioQueue);
	
	// calculate number of packets to read and allocate space for packet descriptions if needed
	if (asbd.mBytesPerPacket == 0 || asbd.mFramesPerPacket == 0)
	{
		// Ask Core Audio to give us a conservative estimate of the largest packet
		size = sizeof(maxPacketSize);
		AudioFileGetProperty(audioFile, kAudioFilePropertyPacketSizeUpperBound, &size, &maxPacketSize);
		if (maxPacketSize > kNewAudioBufferSizeBytes)
		{
			/*Limitation for the maximum buffer size*/
			maxPacketSize = kNewAudioBufferSizeBytes;
		}
		// calculate how many packs to read
		numPacketsToRead = kNewAudioBufferSizeBytes / maxPacketSize;
        if (numPacketsToRead > 200) 
        {
            numPacketsToRead = 200;
        }
	}
	else
	{
		// constant bitrate
		numPacketsToRead = kNewAudioBufferSizeBytes / asbd.mBytesPerPacket;
        if (numPacketsToRead > 200) 
        {
            numPacketsToRead = 200;
        }
	}
	
	// see if file uses a magic cookie (a magic cookie is meta data which some formats use)
	AudioFileGetPropertyInfo(audioFile, kAudioFilePropertyMagicCookieData, &size, nil);
	if (size > 0)
	{
		// copy the cookie data from the file into the audio queue
		cookie = malloc(sizeof(char) * size);
		AudioFileGetProperty(audioFile, kAudioFilePropertyMagicCookieData, &size, cookie);
		AudioQueueSetProperty(audioQueue, kAudioQueueProperty_MagicCookie, cookie, size);
		free(cookie);
	}
	
	// we want to know when the playing state changes so we can properly dispose of the audio queue when it's done
	AudioQueueAddPropertyListener(audioQueue, kAudioQueueProperty_IsRunning, propertyListenerCallback, self);
	
	// allocate and prime buffers with some data
	for (i = 0; i < NUM_QUEUE_BUFFERS; i++)
	{
		AudioQueueAllocateBuffer(audioQueue, kNewAudioBufferSizeBytes, &audioQueueBuffer[i]);
		if ([self readPacketsIntoBuffer:audioQueueBuffer[i]] == 0)
		{
			// this might happen if the file was so short that it needed less buffers than we planned on using
			break;
		}
	}
	trackClosed = NO;
	trackEnded = NO;
	kNewAudioTrackActive = YES;
    [self registerPlayStateChangeNotification];
	return self;
}

- (void)dealloc
{
	[self unRegisterPlayStateChangeNotification];
	if (filePath) 
	{
		[filePath release];
		filePath = nil;
	}
	[super dealloc];
}

#pragma mark private category

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
		
        // set error code
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

- (BOOL)isFinishing
{
	@synchronized (self)
	{
		if ((self.errorCode != AS_NO_ERROR && self.state != AS_INITIALIZED) ||
            ((self.state == AS_STOPPING || self.state == AS_STOPPED) &&
             self.stopReason != AS_STOPPING_TEMPORARILY))
		{
			return YES;
		}
        
	}
	return NO;
}

- (void)callbackForBuffer:(AudioQueueBufferRef) buffer
{
	// I guess it's possible for the callback to continue to be called since this is in another thread, so to be safe,
	// don't do anything else if the track is closed, and also don't bother reading anymore packets if the track ended
	if (trackClosed || trackEnded)
		return;
	
	if ([self readPacketsIntoBuffer:buffer] == 0)
	{
        // set it to stop, but let it play to the end, where the property listener will pick up that it actually finished
        AudioQueueStop(audioQueue, NO);
        trackEnded = YES;
        return;
	}
}

- (UInt32)readPacketsIntoBuffer:(AudioQueueBufferRef)buffer
{
	UInt32 numBytes, numPackets;
	// read packets into buffer from file
	numPackets = numPacketsToRead;
	AudioFileReadPackets(audioFile, NO, &numBytes, packetDescs, packetIndex, &numPackets, buffer->mAudioData);
	if (numPackets > 0)
	{
		// - End Of File has not been reached yet since we read some packets, so enqueue the buffer we just read into
		// the audio queue, to be played next
		// - (packetDescs ? numPackets : 0) means that if there are packet descriptions (which are used only for Variable
		// BitRate data (VBR)) we'll have to send one for each packet, otherwise zero
		buffer->mAudioDataByteSize = numBytes;
		AudioQueueEnqueueBuffer(audioQueue, buffer, (packetDescs ? numPackets : 0), packetDescs);
		
		// move ahead to be ready for next time we need to read from the file
		packetIndex += numPackets;
	}
	return numPackets;
}

- (void)playBackIsRunningStateChanged
{
	if (trackEnded)
	{
		self.state = AS_STOPPED;
		self.stopReason = AS_STOPPING_EOF;
		// go ahead and close the track now
		trackClosed = YES;
		AudioQueueDispose(audioQueue, YES);
        audioQueue = NULL;
		AudioFileClose(audioFile);
		kNewAudioTrackActive = NO;

		// we're not in the main thread during this callback, so enqueue a message on the main thread to post notification
		// that we're done, or else the notification will have to be handled in this thread, making things more difficult
		[self performSelectorOnMainThread:@selector(postTrackFinishedPlayingNotification:) withObject:nil waitUntilDone:NO];
		self.state = AS_INITIALIZED;
	}
}

- (void)postTrackFinishedPlayingNotification:(id) object
{
	// if we're here then we're in the main thread as specified by the callback, so now we can post notification that
	// the track is done without the notification observer(s) having to worry about thread safety and autorelease pools
	[[NSNotificationCenter defaultCenter] postNotificationName:NewAudioTrackFinishedPlayingNotification object:self];
}

#pragma mark QKPlayerProtocol

- (void)play
{
	@synchronized(self)
	{
		OSStatus result = AudioQueuePrime(audioQueue, 0, NULL );
		if (result)
		{
			[NSThread sleepForTimeInterval:0.5];
			result = AudioQueuePrime(audioQueue, 0, nil ) ;//0, nil);
			if ( result ) 
			{
				[self reportFailWithError:AS_AUDIO_QUEUE_START_FAILED];
				return;
			}
		}
		err = AudioQueueStart(audioQueue, NULL);
		if (err)
		{
			[self reportFailWithError:AS_AUDIO_QUEUE_START_FAILED];
			return;
		}
		self.state = AS_PLAYING;
	}
}

- (void)pause
{
	@synchronized(self)
	{
		if (NULL != audioQueue 
            && self.state != AS_STOPPING 
            && self.state != AS_STOPPED 
            &&  self.state != AS_PAUSED) 
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
    @synchronized(self)
    {
        if (NULL != audioQueue 
            && self.state == AS_PAUSED) 
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
}

- (void)stop
{
	// it is preferrable to call close first, if there is a problem waiting for an autorelease
	//	if (trackClosed)
	//		return;
    @synchronized(self)
    {
        if ( NULL != audioQueue 
            && self.state != AS_INITIALIZED 
            && self.state != AS_STOPPED
            && self.state != AS_STOPPING )
        {
            trackClosed = YES;
            sampleRate = 0;
            fileDuration = 0;
            self.state = AS_STOPPED;
            self.stopReason = AS_STOPPING_USER_ACTION;
            AudioQueueStop(audioQueue, YES);
            AudioQueueDispose(audioQueue, YES);
            audioQueue = NULL;
            AudioFileClose(audioFile);
            kNewAudioTrackActive = NO;
        }
    }
}

- (double)duration
{
	return fileDuration;
}

//
// progress
//
// returns the current playback progress. Will return zero if sampleRate has
// not yet been detected.
//
- (double)progress
{
	@synchronized(self)
	{
		if (NULL != audioQueue 
            && sampleRate > 0 && ![self isFinishing])
		{
			if (self.state != AS_PLAYING 
                && self.state != AS_PAUSED 
                && self.state != AS_BUFFERING 
                && self.state != AS_STOPPING)
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
	return 0.0;
}


- (BOOL)isSeekable
{
    return YES;
}

- (BOOL)seekToTime:(double)newSeekTime
{
    @synchronized(self)
    {
        if (NULL != audioQueue)
        {
            trackClosed = YES;
            if ([self calculatedBitRate] == 0.0)
            {
                return TRUE;
            }
            
            AudioStreamerState oldState = self.state;
            seekTime = newSeekTime;
            
            //
            // Attempt to align the seek with a packet boundary
            //
            double calculatedBitRate = [self calculatedBitRate];
            if (packetDuration > 0 &&
                calculatedBitRate > 0)
            {
                SInt64 seekPacket = floor(newSeekTime / packetDuration);
                packetIndex = seekPacket;
                packetIndexBySeek = packetIndex;
            }
            
            //
            // Stop the audio queue
            //
            self.state = AS_STOPPING;
            self.stopReason = AS_STOPPING_TEMPORARILY;
            err = AudioQueueStop(audioQueue, true);
            AudioQueueDispose(audioQueue, false );//YES);
            audioQueue = NULL;
            AudioFileClose(audioFile);
            if (err)
            {
                [self reportFailWithError:AS_AUDIO_QUEUE_STOP_FAILED];
                return YES;
            }
            
            if ( packetIndex > packetsCount - 2 )
            {
                self.state = AS_STOPPED;
                self.state = AS_INITIALIZED;
                self.stopReason = AS_STOPPING_EOF;
                return YES;
            }
            
            UInt32 size, maxPacketSize;
            char *cookie;
            int i;
            trackClosed = NO;
            // try to open up the file using the specified path
            OSStatus error1 =AudioFileOpenURL((CFURLRef)filePath, kAudioFileReadPermission, 0, &audioFile);
            if (noErr != error1)
            {
                return NO;
            }
            // get the data format of the file
            size = sizeof(asbd);
            AudioFileGetProperty(audioFile, kAudioFilePropertyDataFormat, &size, &asbd);
            packetBufferSize = asbd.mBytesPerPacket;
            size = sizeof(bitRate);
            AudioFileGetProperty(audioFile, kAudioFilePropertyBitRate, &size, &bitRate);
            size = sizeof(packetsCount);
            AudioFileGetProperty(audioFile, kAudioFilePropertyAudioDataPacketCount, &size, &packetsCount);
            
            //Get file length
            UInt32 propertySize = sizeof(fileDuration);
            AudioFileGetProperty(audioFile, kAudioFilePropertyEstimatedDuration, &propertySize, &fileDuration);
            
            sampleRate = asbd.mSampleRate;
            packetDuration = asbd.mFramesPerPacket / sampleRate;
            // create a new playback queue using the specified data format and buffer callback
            AudioQueueNewOutput(&asbd, BufferCallback, self, nil, nil, 0, &audioQueue);
            
            // calculate number of packets to read and allocate space for packet descriptions if needed
            if (asbd.mBytesPerPacket == 0 || asbd.mFramesPerPacket == 0)
            {
                // Ask Core Audio to give us a conservative estimate of the largest packet
                size = sizeof(maxPacketSize);
                AudioFileGetProperty(audioFile, kAudioFilePropertyPacketSizeUpperBound, &size, &maxPacketSize);
                if (maxPacketSize > kNewAudioBufferSizeBytes)
                {
                    /*Limitation for the maximum buffer size*/
                    maxPacketSize = kNewAudioBufferSizeBytes;
                }
                // calculate how many packs to read
                numPacketsToRead = kNewAudioBufferSizeBytes / maxPacketSize;
                if (numPacketsToRead > 200) 
                {
                    numPacketsToRead = 200;
                }
            }
            else
            {
                // constant bitrate
                numPacketsToRead = kNewAudioBufferSizeBytes / asbd.mBytesPerPacket;
                if (numPacketsToRead > 200) 
                {
                    numPacketsToRead = 200;
                }
            }
            
            // see if file uses a magic cookie (a magic cookie is meta data which some formats use)
            AudioFileGetPropertyInfo(audioFile, kAudioFilePropertyMagicCookieData, &size, nil);
            if (size > 0)
            {
                // copy the cookie data from the file into the audio queue
                cookie = malloc(sizeof(char) * size);
                AudioFileGetProperty(audioFile, kAudioFilePropertyMagicCookieData, &size, cookie);
                AudioQueueSetProperty(audioQueue, kAudioQueueProperty_MagicCookie, cookie, size);
                free(cookie);
            }
            
            // we want to know when the playing state changes so we can properly dispose of the audio queue when it's done
            AudioQueueAddPropertyListener(audioQueue, kAudioQueueProperty_IsRunning, propertyListenerCallback, self);
            
            packetIndex = packetIndexBySeek;
            // allocate and prime buffers with some data
            for (i = 0; i < NUM_QUEUE_BUFFERS; i++)
            {
                AudioQueueAllocateBuffer(audioQueue, kNewAudioBufferSizeBytes, &audioQueueBuffer[i]);
                if ([self readPacketsIntoBuffer:audioQueueBuffer[i]] == 0)
                {
                    // this might happen if the file was so short that it needed less buffers than we planned on using
                    break;
                }
            }
            
            trackClosed = NO;
            trackEnded = NO;
            kNewAudioTrackActive = YES;
            self.state = oldState;
            if (AS_PLAYING == oldState)
            {
                [self play];
            }
            return YES;
        }
    }
    return NO;
}

@end

#pragma mark - Audio Queue callback
static void propertyListenerCallback(void *inUserData, AudioQueueRef queueObject, AudioQueuePropertyID propertyID)
{
	// redirect back to the class to handle it there instead, so we have direct access to the instance variables
    if (propertyID == kAudioQueueProperty_IsRunning)
    {
        [(QKFileAudioPlayer*)inUserData playBackIsRunningStateChanged];
    }
}

static void BufferCallback(void *inUserData, AudioQueueRef inAQ, AudioQueueBufferRef buffer)
{
	[(QKFileAudioPlayer*)inUserData callbackForBuffer:buffer];
}
