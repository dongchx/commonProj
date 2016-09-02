//
//  QKAudioRecorder.m
//  QQKala
//
//  Created by frost on 12-6-6.
//  Copyright (c) 2012年 Tencent. All rights reserved.
//

#import "ASBDUtility.h"
#import "AudioCommonDefine.h"
#import "QKAudioRecorder.h"

#define kBufferDurationSeconds .5

// ---------------------------------------------
// QKAudioRecorder private category
// ---------------------------------------------
@interface QKAudioRecorder(Private)
- (int)computeBufferSizeWithFormat:(AudioStreamBasicDescription*)format duration:(float)seconds;
- (void)copyEncoderCookieToFile;
//- (void)setupAudioFormat:(UInt32)inFormatID withSampleRate:(UInt32)sampleRate;
@end

// ---------------------------------------------
// AudioQueue Input Callback
// ---------------------------------------------
#pragma mark AudioQueue Input Callback
static void MyInputBufferHandler(	void *								inUserData,
                                 AudioQueueRef						inAQ,
                                 AudioQueueBufferRef					inBuffer,
                                 const AudioTimeStamp *				inStartTime,
                                 UInt32								inNumPackets,
                                 const AudioStreamPacketDescription*	inPacketDesc)
{
    QKAudioRecorder *aqr = (QKAudioRecorder *)inUserData;
    
    if (inNumPackets > 0)
    {
        // write packets to file
        
        OSStatus err = AudioFileWritePackets(aqr.recordFile, FALSE, inBuffer->mAudioDataByteSize,inPacketDesc, aqr.recordPacket, &inNumPackets, inBuffer->mAudioData);
        
        if (noErr == err) 
        {
            aqr.recordPacket += inNumPackets;
        }
    }
    
    // if we're not stopping, re-enqueue the buffe so that it gets filled again
    if ([aqr isRecording])
    {
        AudioQueueEnqueueBuffer(inAQ, inBuffer, 0, NULL);
    }
    
}
// ---------------------------------------------
// QKAudioRecorder implementation
// ---------------------------------------------
@implementation QKAudioRecorder

@synthesize recordFile = mRecordFile;
@synthesize recordPacket = mRecordPacket;
@synthesize queue = mQueue;

#pragma mark lifecycle
- (id)init
{
    if (self = [super init])
    {
        // nothing to do here
        mState = ARStateStoped;
    }
    return self;
}

- (void)dealloc
{
    AudioQueueDispose(mQueue, TRUE);
	AudioFileClose(mRecordFile);
	if (mFileName) CFRelease(mFileName);
    [super dealloc];
}

#pragma mark QKRecorderProtocol implementation
- (void)startRecord:(CFStringRef)inRecordFile format:(UInt32)formatID sampleRate:(UInt32)sampleRate
{
    formatID = kAudioFormatLinearPCM;
    sampleRate = AudioSampleRate44K;
    
    int i, bufferByteSize;
	UInt32 size;
	CFURLRef url;
    
    NSInteger err = noErr;
	
	@try {		
		mFileName = CFStringCreateCopy(kCFAllocatorDefault, inRecordFile);
        
		// specify the recording format
//		[self setupAudioFormat:formatID withSampleRate:sampleRate];
        [ASBDUtility setASBD:&mRecordFormat formatID:formatID numChannels:2 sampleRate:sampleRate];
        
		
		// create the queue
        err = AudioQueueNewInput(
                                          &mRecordFormat,
                                          MyInputBufferHandler,
                                          self ,
                                          NULL , NULL ,
                                          0 , &mQueue);
		
		// get the record format back from the queue's audio converter --
		// the file may require a more specific stream description than was necessary to create the encoder.
		mRecordPacket = 0;
        
		size = sizeof(mRecordFormat);
        err = AudioQueueGetProperty(mQueue, kAudioQueueProperty_StreamDescription,	
                                    &mRecordFormat, &size);
        

        
		url = CFURLCreateWithString(kCFAllocatorDefault, (CFStringRef)mFileName, NULL);
		
		// create the audio file
        err = AudioFileCreateWithURL(url, kAudioFileCAFType, &mRecordFormat, kAudioFileFlags_EraseFile,&mRecordFile);
		CFRelease(url);
		
		// copy the cookie first to give the file object as much info as we can about the data going in
		// not necessary for pcm, but required for some compressed audio
		[self copyEncoderCookieToFile];
		
		// allocate and enqueue buffers
		bufferByteSize = [self computeBufferSizeWithFormat:&mRecordFormat duration :kBufferDurationSeconds];	// enough bytes for half a second
		for (i = 0; i < kNumberRecordBuffers; ++i)
        {
            err = AudioQueueAllocateBuffer(mQueue, bufferByteSize, &mBuffers[i]);
            err = AudioQueueEnqueueBuffer(mQueue, mBuffers[i], 0, NULL);
		}
        
		// start the queue
		err = AudioQueueStart(mQueue, NULL);
        mState = ARStateRecording;
	}
	@catch (...) 
    {
	}
    @finally {
    }
}

- (void)pauseRecord
{
    if (NULL != mQueue && ARStateRecording == mState)
    {
        OSStatus status = AudioQueuePause(mQueue);
        if (noErr != status)
        {
            return;
        }
        mState = ARStateRecordPaused;
    }
}

- (void)resumeRecord
{
    if (NULL != mQueue && ARStateRecordPaused == mState) 
    {
        OSStatus status = AudioQueueStart(mQueue, NULL);
        if (noErr != status)
        {
            return;
        }
        mState = ARStateRecording;
    }
}

- (void)stopRecord
{
    // end recording
    /*OSStatus err = */AudioQueueStop(mQueue, true);	
	// a codec may update its cookie at the end of an encoding session, so reapply it to the file now
	[self copyEncoderCookieToFile];
	if (mFileName)
	{
		CFRelease(mFileName);
		mFileName = NULL;
	}
	AudioQueueDispose(mQueue, true);
    mQueue = NULL;
	AudioFileClose(mRecordFile);
    mRecordFile = NULL;
}

- (BOOL)isRecording
{
    return mState == ARStateRecording;
}

- (BOOL)isPaused
{
    return mState == ARStateRecordPaused;
}

- (AudioStreamBasicDescription)audioDataFormat
{
    return mRecordFormat;
}


#pragma mark QKAudioRecorder Private

- (int)computeBufferSizeWithFormat:(AudioStreamBasicDescription*)format duration:(float)seconds
{
    int packets, frames, bytes = 0;
    
    frames = (int)ceil(seconds * format->mSampleRate);
    
    if (format->mBytesPerFrame > 0)
    {
        bytes = frames * format->mBytesPerFrame;
    }
    else 
    {
        UInt32 maxPacketSize;
        if (format->mBytesPerPacket > 0)
        {
            maxPacketSize = format->mBytesPerPacket;	// constant packet size
        }
        else 
        {
            UInt32 propertySize = sizeof(maxPacketSize);
            AudioQueueGetProperty(mQueue, kAudioQueueProperty_MaximumOutputPacketSize, &maxPacketSize,&propertySize);
            
        }
        
        if (format->mFramesPerPacket > 0)
        {
            packets = frames / format->mFramesPerPacket;
        }
        else
        {
            packets = frames;	// worst-case scenario: 1 frame in a packet
        }
        if (packets == 0)		// sanity check
        {
            packets = 1;
        }
        bytes = packets * maxPacketSize;
    }
	return bytes;
}

- (void)copyEncoderCookieToFile
{
    UInt32 propertySize;
	// get the magic cookie, if any, from the converter		
	OSStatus err = AudioQueueGetPropertySize(mQueue, kAudioQueueProperty_MagicCookie, &propertySize);
	
	// we can get a noErr result and also a propertySize == 0
	// -- if the file format does support magic cookies, but this file doesn't have one.
	if (noErr == err && propertySize > 0) 
    {
		Byte *magicCookie = new Byte[propertySize];
		UInt32 magicCookieSize;
        
        err = AudioQueueGetProperty(mQueue, kAudioQueueProperty_MagicCookie, magicCookie, &propertySize);
        
        if (noErr == err) 
        {
            magicCookieSize = propertySize;// the converter lies and tell us the wrong size
            
            // now set the magic cookie on the output file
            UInt32 willEatTheCookie = false;
            // the converter wants to give us one; will the file take it?
            err = AudioFileGetPropertyInfo(mRecordFile, kAudioFilePropertyMagicCookieData, NULL, &willEatTheCookie);
            if (err == noErr && willEatTheCookie) 
            {
                AudioFileSetProperty(mRecordFile, kAudioFilePropertyMagicCookieData, magicCookieSize, magicCookie);
            }
        }
		delete[] magicCookie;
	}
}
//- (void)setupAudioFormat:(UInt32)inFormatID withSampleRate:(UInt32)sampleRate
//{
//    memset(&mRecordFormat, 0, sizeof(mRecordFormat));
//    
//    // get hardware samplerate
//	UInt32 size = sizeof(mRecordFormat.mSampleRate);
//    OSStatus err = AudioSessionGetProperty(kAudioSessionProperty_CurrentHardwareSampleRate,&size, &mRecordFormat.mSampleRate);
//    
//    // get hardware input channels
//	size = sizeof(mRecordFormat.mChannelsPerFrame);
//    err = AudioSessionGetProperty(	kAudioSessionProperty_CurrentHardwareInputNumberChannels, &size, &mRecordFormat.mChannelsPerFrame);
//    
//	mRecordFormat.mFormatID = inFormatID;
//    switch (inFormatID) 
//    {
//        case kAudioFormatLinearPCM:
//        {
//            mRecordFormat.mFormatFlags = kLinearPCMFormatFlagIsSignedInteger | kLinearPCMFormatFlagIsPacked;
//            mRecordFormat.mBitsPerChannel = 16;
//            mRecordFormat.mChannelsPerFrame = 2;
//            mRecordFormat.mFramesPerPacket = 1;
//            mRecordFormat.mBytesPerPacket = mRecordFormat.mBytesPerFrame = (mRecordFormat.mBitsPerChannel / 8) * mRecordFormat.mChannelsPerFrame;
//            mRecordFormat.mSampleRate = sampleRate;//44100.0
//            
//            break;
//        }
//        case kAudioFormatALaw:
//        case kAudioFormatULaw:
//        {
//            mRecordFormat.mFormatFlags = 0;
//            mRecordFormat.mBitsPerChannel = 8;
//            mRecordFormat.mChannelsPerFrame = 1;
//            mRecordFormat.mFramesPerPacket = 1;
//            mRecordFormat.mBytesPerPacket = 1;
//            mRecordFormat.mBytesPerFrame = 1;
//            mRecordFormat.mSampleRate = 8000.0;
//            break;
//        }
//        case kAudioFormatAppleIMA4:
//        {
//            mRecordFormat.mFormatFlags = 0;
//            mRecordFormat.mBitsPerChannel = 0;
//            mRecordFormat.mChannelsPerFrame = 1;
//            mRecordFormat.mFramesPerPacket = 64;
//            mRecordFormat.mBytesPerPacket = 68;
//            mRecordFormat.mSampleRate = 44100.0;
//            break;
//        }
//        case kAudioFormatAppleLossless:
//        {
//            mRecordFormat.mFormatFlags = 0;
//            mRecordFormat.mBitsPerChannel = 0;
//            mRecordFormat.mChannelsPerFrame = 1;
//            mRecordFormat.mFramesPerPacket = 4096;
//            mRecordFormat.mBytesPerPacket = 0;
//            mRecordFormat.mBytesPerFrame = 0;
//            mRecordFormat.mSampleRate = 44100.0;
//            break;
//        }
//        case kAudioFormatMPEG4AAC:
//        {
//            mRecordFormat.mFormatFlags = 0;
//            mRecordFormat.mBitsPerChannel = 0;
//            mRecordFormat.mChannelsPerFrame = 1;
//            mRecordFormat.mFramesPerPacket = 1024;
//            mRecordFormat.mFramesPerPacket = 0;
//            mRecordFormat.mBytesPerPacket = 0;
//            mRecordFormat.mSampleRate = 44100.0;
//            break;
//        }
//        default:
//            break;
//    }
//}
@end
