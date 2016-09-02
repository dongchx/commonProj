//
//  QKAUAudioPlayer.m
//  QQKala
//
//  Created by frost on 12-7-6.
//  Copyright (c) 2012年 __MyCompanyName__. All rights reserved.
//

#import "QKAUAudioPlayer.h"
#import "AudioEngineHelper.h"
#import "ASBDUtility.h"
#import "PublicConfig.h"

#define kIOUintOutputElement                0 // I/O unit output element number, like "o"(output)
#define kMixerBusAudioFile                  0 // mixer bus 0, input from file

// ---------------------------------------------
// QKAUAudioPlayer private category
// ---------------------------------------------
@interface QKAUAudioPlayer(Private)
- (void)setupASBD:(NSInteger)sampleRate;
- (void)configAUGraph;
- (void)obtainSourceUrlsFromFile:(NSString*)fileName;
- (void)cancelLoadAudioBuffer;
- (void)loadAudioBuffer;
- (void)loadAudioBufferProcessingThread;
- (void)loadAudioBufferCompletion;


/*Private function for stop and cleanup*/
- (void)stopAndcleanUp;
- (void)stopAUGraphAndClenup;
- (void)cleanPlaybackResource;
- (void)cleanSoundStruct;
- (void)cleanSourceUrl;
- (void)disposeSourceAudioFile;

/**/
- (void)stopOnPlayBackDidFinish;

- (BOOL)isFinishing;
- (void)reportFailWithError:(AudioStreamerErrorCode)anErrorCode;
- (void)reportFailOnMainThread;
@end

// ---------------------------------------------
// forward declaration
// ---------------------------------------------
static OSStatus	audioinputCallback(
                                   void						*inRefCon, 
                                   AudioUnitRenderActionFlags 	*ioActionFlags, 
                                   const AudioTimeStamp 		*inTimeStamp, 
                                   UInt32 						inBusNumber, 
                                   UInt32 						inNumberFrames, 
                                   AudioBufferList 			*ioData);
// ---------------------------------------------
// QKAUAudioPlayer implementation
// ---------------------------------------------
@implementation QKAUAudioPlayer

#pragma mark life cycle

- (id)initWithAudioFile:(NSString*)filePath
{
    if (nil != filePath) 
    {
        if(!(self = [super init])) return nil;
        [self obtainSourceUrlsFromFile:filePath];
        [self loadAudioBuffer];
        [self configAUGraph];
        [self registerPlayStateChangeNotification];
        return self;
    }
	return nil;
}

- (void)dealloc
{
    [self unRegisterPlayStateChangeNotification];
    [self stopAndcleanUp];
    [super dealloc];
}

#pragma mark Private
- (void)setupASBD:(NSInteger)sampleRate
{
    //............................................................................
    // set stream format
    [ASBDUtility setAudioUnitASBD:&mStereoStreamFormat numChannels:2 sampleRate:sampleRate];
    [ASBDUtility setAudioUnitASBD:&mMonoStreamFormat numChannels:1 sampleRate:sampleRate];
    [ASBDUtility setCanonical:&mSInt16CanonicalStereoFormat numChannels:2 sampleRate:sampleRate isInterleaved:NO];
    [ASBDUtility setCanonical:&mSInt16CanonicalMonoFormat numChannels:1 sampleRate:sampleRate isInterleaved:NO];
}


- (void)configAUGraph
{
    OSStatus result = noErr;
    AURenderCallbackStruct callbackStruct;
    //............................................................................
    // Create a new audio processing graph.
    result = NewAUGraph (&mProcessingGraph);
    if (noErr != result) 
    {
        [self reportFailWithError:AS_AU_GRAPH_CREATION_FAILED];
        return;
    }
    
    //............................................................................
    // Specify the audio unit component descriptions for the audio units to be
    //    added to the graph.
    
    // I/O unit
    AudioComponentDescription iOUnitDescription;
    iOUnitDescription.componentType          = kAudioUnitType_Output;
    iOUnitDescription.componentSubType       = kAudioUnitSubType_RemoteIO;
    iOUnitDescription.componentManufacturer  = kAudioUnitManufacturer_Apple;
    iOUnitDescription.componentFlags         = 0;
    iOUnitDescription.componentFlagsMask     = 0;
    
    // Multichannel mixer unit
    AudioComponentDescription MixerUnitDescription;
    MixerUnitDescription.componentType          = kAudioUnitType_Mixer;
    MixerUnitDescription.componentSubType       = kAudioUnitSubType_MultiChannelMixer;
    MixerUnitDescription.componentManufacturer  = kAudioUnitManufacturer_Apple;
    MixerUnitDescription.componentFlags         = 0;
    MixerUnitDescription.componentFlagsMask     = 0;
    
    //............................................................................
    // Add nodes to the audio processing graph.
    
    AUNode   iONode;         // node for I/O unit
    AUNode   mixerNode;      // node for Multichannel Mixer unit
    
    // Add the nodes to the audio processing graph
    result =    AUGraphAddNode (
                                mProcessingGraph,
                                &iOUnitDescription,
                                &iONode);
    
    if (noErr != result) 
    {
        [self reportFailWithError:AS_AU_GRAPH_CREATION_FAILED];
        return;
    }
    
    
    result =    AUGraphAddNode (
                                mProcessingGraph,
                                &MixerUnitDescription,
                                &mixerNode
                                );
    
    if (noErr != result) 
    {
        [self reportFailWithError:AS_AU_GRAPH_CREATION_FAILED];
        return;
    }
    
    //............................................................................
    // Open the audio processing graph
    
    // Following this call, the audio units are instantiated but not initialized
    //    (no resource allocation occurs and the audio units are not in a state to
    //    process audio).
    result = AUGraphOpen (mProcessingGraph);
    
    if (noErr != result) 
    {
        [self reportFailWithError:AS_AU_GRAPH_CREATION_FAILED];
        return;
    }
    
    //............................................................................
    // Obtain the io unit instance from its corresponding node
    
    result =    AUGraphNodeInfo (
                                 mProcessingGraph,
                                 iONode,
                                 NULL,
                                 &mIOUnit
                                 );
    
    if (noErr != result) 
    {
        [self reportFailWithError:AS_AU_GRAPH_CREATION_FAILED];
        return;
    }
    
    //............................................................................
    // Obtain the mixer unit instance from its corresponding node.
    
    result =    AUGraphNodeInfo (
                                 mProcessingGraph,
                                 mixerNode,
                                 NULL,
                                 &mMixerUnit
                                 );
    
    if (noErr != result) 
    {
        [self reportFailWithError:AS_AU_GRAPH_CREATION_FAILED];
        return;
    }
    
    //............................................................................
    // Multichannel Mixer unit Setup
    
    UInt32 busCount   = 1;    // bus count for mixer unit input
    
    result = AudioUnitSetProperty (
                                   mMixerUnit,
                                   kAudioUnitProperty_ElementCount,
                                   kAudioUnitScope_Input,
                                   0,
                                   &busCount,
                                   sizeof (busCount)
                                   );
    
    if (noErr != result) 
    {
        [self reportFailWithError:AS_AU_GRAPH_CREATION_FAILED];
        return;
    }
    
    // Increase the maximum frames per slice allows the mixer unit to accommodate the
    //    larger slice size used when the screen is locked.
    UInt32 maximumFramesPerSlice = 4096;
    
    result = AudioUnitSetProperty (
                                   mMixerUnit,
                                   kAudioUnitProperty_MaximumFramesPerSlice,
                                   kAudioUnitScope_Global,
                                   0,
                                   &maximumFramesPerSlice,
                                   sizeof (maximumFramesPerSlice)
                                   );
    
    if (noErr != result) 
    {
        [self reportFailWithError:AS_AU_GRAPH_CREATION_FAILED];
        return;
    }
    
    // Apply format for mixer file bus (input bus 0)
    result = AudioUnitSetProperty (
                                   mMixerUnit,
                                   kAudioUnitProperty_StreamFormat,
                                   kAudioUnitScope_Input,
                                   kMixerBusAudioFile,
                                   &mClientStreamFormat,
                                   sizeof (mClientStreamFormat)
                                   );
    
    if (noErr != result) 
    {
        [self reportFailWithError:AS_AU_GRAPH_CREATION_FAILED];
        return;
    }
    
    // Apply format for mixer output
    result = AudioUnitSetProperty (
                                   mMixerUnit,
                                   kAudioUnitProperty_StreamFormat,
                                   kAudioUnitScope_Output,
                                   0,
                                   &mStereoStreamFormat,
                                   sizeof (mStereoStreamFormat)
                                   );
    
    if (noErr != result) 
    {
        [self reportFailWithError:AS_AU_GRAPH_CREATION_FAILED];
        return;
    }
    
    // Attach the input render callback
    callbackStruct.inputProc        = &audioinputCallback;
    callbackStruct.inputProcRefCon  = self;
    
    result = AUGraphSetNodeInputCallback (
                                          mProcessingGraph,
                                          mixerNode,
                                          kMixerBusAudioFile,
                                          &callbackStruct
                                          );
    
    if (noErr != result) 
    {
        [self reportFailWithError:AS_AU_GRAPH_CREATION_FAILED];
        return;
    }
    

    //............................................................................
    // Connect the nodes of the audio processing graph
    AUGraphConnectNodeInput (
                                      mProcessingGraph,
                                      mixerNode,            // source node is Mixer
                                      0,                    // source node output bus number
                                      iONode,               // destination node
                                      kIOUintOutputElement  // desintation node input bus number
                                      );
    
    //............................................................................
    // Initialize audio processing graph
    result = AUGraphInitialize (mProcessingGraph);
    
    if (noErr != result) 
    {
        [self reportFailWithError:AS_AU_GRAPH_CREATION_FAILED];
        return;
    }
}

- (void)obtainSourceUrlsFromFile:(NSString*)fileName
{
    if (nil != fileName)
    {
        // clean if necessary
        [self cleanSourceUrl];
        
        // get audio file urls
        NSURL *audioFileUrl = [NSURL fileURLWithPath:fileName isDirectory:NO];
        sourceURL = (CFURLRef) [audioFileUrl retain];
    }
}

- (void)cancelLoadAudioBuffer
{
    if (nil != mInternalReadThread)
    {
        if (!mReadComplete)
        {
            [self performSelector:@selector(cancelLoadAudioBufferProc) onThread:mInternalReadThread withObject:nil waitUntilDone:YES];
        }
        // wait until reading processing thread exit
        while (mReading)
        {
            [NSThread sleepForTimeInterval:0.01];
        }
    }
    
    if (mBufferList)
    {
        free(mBufferList);
        mBufferList = NULL;
    }
    if (mBuffer1)
    {
        free(mBuffer1);
        mBuffer1 = NULL;
    }
    if (mBuffer2)
    {
        free(mBuffer2);
        mBuffer2 = NULL;
    }
}

//	used by internal Read Thread to force thread exit
- (void)cancelLoadAudioBufferProc
{
    mCancelReadSource = YES;
}

- (void)loadAudioBuffer
{
    // Open an audio file and associate it with the extended audio file object.
    OSStatus result = ExtAudioFileOpenURL (sourceURL, &mSourceAudioFile);
    
    if (noErr != result || NULL == mSourceAudioFile) 
        return;
    
    // Get the audio file's duration
    AudioFileID audioFileID;
    UInt32 size = sizeof(audioFileID);
    ExtAudioFileGetProperty(mSourceAudioFile, kExtAudioFileProperty_AudioFile, &size, &audioFileID);
    
    UInt32 propertySize = sizeof(mDuration);
    AudioFileGetProperty(audioFileID, kAudioFilePropertyEstimatedDuration, &propertySize, &mDuration);
    
    // Get the audio file's length in frames.
    UInt64 totalFramesInFile = 0;
    UInt32 frameLengthPropertySize = sizeof (totalFramesInFile);
    
    result =    ExtAudioFileGetProperty (
                                         mSourceAudioFile,
                                         kExtAudioFileProperty_FileLengthFrames,
                                         &frameLengthPropertySize,
                                         &totalFramesInFile
                                         );
    
    if (noErr != result) 
        return;
    
    // Assign the frame count to the soundStruct instance variable
    soundStruct.sampleNumber = mFrameReadOffset;
    soundStruct.frameCount = totalFramesInFile;
    
    // Get the audio file's number of channels.
    AudioStreamBasicDescription fileAudioFormat = {0};
    UInt32 formatPropertySize = sizeof (fileAudioFormat);
    
    result =    ExtAudioFileGetProperty (
                                         mSourceAudioFile,
                                         kExtAudioFileProperty_FileDataFormat,
                                         &formatPropertySize,
                                         &fileAudioFormat
                                         );
    
    if (noErr != result) 
        return;
    
    UInt32 channelCount = fileAudioFormat.mChannelsPerFrame;
    [self setupASBD:fileAudioFormat.mSampleRate];
    
    
    // Init circular buffer to hold the left channel or mono, audio data
    TPCircularBufferInit(&soundStruct.audioBufferLeft,kAudioBufferLength);
    
    // init circular buffer right if necessary
    
    if (2 == channelCount)
    {
        soundStruct.isStereo = YES;
        TPCircularBufferInit(&soundStruct.audioBufferRight,kAudioBufferLength);
        mClientStreamFormat = mSInt16CanonicalStereoFormat;
    } 
    else if (1 == channelCount) 
    {
        soundStruct.isStereo = NO;
        mClientStreamFormat = mSInt16CanonicalMonoFormat;
        
    } 
    else 
    {
        ExtAudioFileDispose (mSourceAudioFile);
        mSourceAudioFile = NULL;
        return;
    }
    
    // Assign the appropriate mixer input bus stream data format to the extended audio 
    //        file object. This is the format used for the audio data placed into the audio 
    //        buffer in the SoundStruct data structure, which is in turn used in the 
    //        inputRenderCallback callback function.
    
    result =    ExtAudioFileSetProperty (
                                         mSourceAudioFile,
                                         kExtAudioFileProperty_ClientDataFormat,
                                         sizeof (mClientStreamFormat),
                                         &mClientStreamFormat
                                         );
    
    if (noErr != result) 
        return;
    
    // Allocate memory for read file
    mBufferList = (AudioBufferList *) malloc (
                                             sizeof (AudioBufferList) + sizeof (AudioBuffer) * (channelCount - 1)
                                             );
    
    if (NULL == mBufferList) 
    {
        QKLog (@"*** malloc failure for allocating bufferList memory"); 
        return;
    }
    
    // buffer
    UInt32 bufferByteSize = kAudioBufferLengthPerReading;
    mBuffer1 = malloc(bufferByteSize);
    if (NULL == mBuffer1) 
    {
        QKLog (@"*** malloc failure for allocating buffer1 memory"); 
        return;
    }	
    
    // initialize the mNumberBuffers member
    mBufferList->mNumberBuffers = channelCount;
    
    // initialize the mBuffers member to 0
    AudioBuffer emptyBuffer = {0};
    size_t arrayIndex;
    for (arrayIndex = 0; arrayIndex < channelCount; ++arrayIndex)
    {
        mBufferList->mBuffers[arrayIndex] = emptyBuffer;
    }
    
    UInt64 sourceFrameOffset = mFrameReadOffset;
    // set up the AudioBuffer structs in the buffer list
    mBufferList->mBuffers[0].mNumberChannels  = 1;
    mBufferList->mBuffers[0].mDataByteSize    = bufferByteSize;
    mBufferList->mBuffers[0].mData            = mBuffer1;
    
    if (2 == channelCount)
    {
        mBuffer2 = malloc(bufferByteSize);
        if (NULL == mBuffer2) 
        {
            QKLog (@"*** malloc failure for allocating buffer2 memory"); 
            return;
        }
        
        mBufferList->mBuffers[1].mNumberChannels  = 1;
        mBufferList->mBuffers[1].mDataByteSize    = bufferByteSize;
        mBufferList->mBuffers[1].mData            = mBuffer2;
    }
    
    OSStatus err = ExtAudioFileSeek(mSourceAudioFile, sourceFrameOffset);
    if ( noErr != err ) 
    {
        return;
    }
    
    mCancelReadSource = NO;
    mReadComplete = NO;
    mReading = YES;
    
    if (nil != mInternalReadThread)
    {
        [mInternalReadThread release];
    }
    mInternalReadThread =[[NSThread alloc] initWithTarget:self 
                                                 selector:@selector(loadAudioBufferProcessingThread) 
                                                   object:nil];
    [mInternalReadThread start];
}

- (void)loadAudioBufferProc
{
    if (kAudioBufferLength - soundStruct.audioBufferLeft.fillCount >= kAudioBufferLengthPerReading) 
    {
        mBufferList->mBuffers[0].mDataByteSize    = kAudioBufferLengthPerReading;
        if (soundStruct.isStereo)
        {
            mBufferList->mBuffers[1].mDataByteSize    = kAudioBufferLengthPerReading;
        }
        
        UInt32 numFrames = kAudioBufferLengthPerReading / mClientStreamFormat.mBytesPerFrame;
        
        OSStatus err = ExtAudioFileRead(mSourceAudioFile, &numFrames, mBufferList);
        if ( noErr != err ) 
        {
            QKLog(@"ExtAudioFileRead error, %ld", err);
            return;
        }
        
        // If no frames were returned, read is finished
        if ( !numFrames ) 
        {
            mReadComplete = YES;
            return;
        }

        TPCircularBufferProduceBytes(&soundStruct.audioBufferLeft, mBufferList->mBuffers[0].mData, mBufferList->mBuffers[0].mDataByteSize);
        if (soundStruct.isStereo)
        {
            TPCircularBufferProduceBytes(&soundStruct.audioBufferRight, mBufferList->mBuffers[1].mData, mBufferList->mBuffers[1].mDataByteSize);
        }
    }
}

- (void)loadAudioBufferProcessingThread
{
    NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
    
    NSRunLoop *runLoop = [NSRunLoop currentRunLoop];
    NSMachPort *dummyPort = [[NSMachPort alloc] init];	
    [runLoop addPort:dummyPort forMode:NSDefaultRunLoopMode];
    [dummyPort release];
    
    [self loadAudioBufferProc];
    
    while ( !mCancelReadSource 
           && ![[NSThread currentThread] isCancelled]
           && !mReadComplete)
    {
		[runLoop runMode:NSDefaultRunLoopMode beforeDate:[NSDate distantFuture]];
    }
    
    if ( mReadComplete )
    {
        [self performSelectorOnMainThread:@selector(loadAudioBufferCompletion) withObject:nil waitUntilDone:NO];
    }
    mReading = NO;
    
    [mInternalReadThread release];
    mInternalReadThread = nil;
    
    [pool release];
}

- (void)loadAudioBufferCompletion
{
    if (NULL!= mSourceAudioFile)
    {
        ExtAudioFileDispose (mSourceAudioFile);
        mSourceAudioFile = NULL;
    }
}

- (void)stopAndcleanUp
{
    [self stopAUGraphAndClenup];
    [self cleanPlaybackResource];
    [self cleanSoundStruct];
    [self cleanSourceUrl];
}

- (void)stopAUGraphAndClenup
{
    if (NULL != mProcessingGraph)
    {
        AUGraphStop(mProcessingGraph);
        DisposeAUGraph(mProcessingGraph);
        
        mProcessingGraph = NULL;
        mMixerUnit = NULL;
        mIOUnit = NULL;
    }
}

- (void)cleanPlaybackResource
{
    [self cancelLoadAudioBuffer];
    [self disposeSourceAudioFile];
}

- (void)cleanSoundStruct
{
    soundStruct.sampleNumber = 0;
    soundStruct.frameCount = 0;
    
    TPCircularBufferCleanup(&soundStruct.audioBufferLeft);
    TPCircularBufferCleanup(&soundStruct.audioBufferRight);
}

- (void)cleanSourceUrl
{
    if (NULL != sourceURL)
    {
        CFRelease(sourceURL);
        sourceURL = NULL;
    }
}

- (void)disposeSourceAudioFile
{
    if (NULL != mSourceAudioFile)
    {
        ExtAudioFileDispose (mSourceAudioFile); 
        mSourceAudioFile = NULL;
    }
    
    mCancelReadSource = NO;
//    mDuration = 0;
}

- (void)stopOnPlayBackDidFinish
{
    if (NULL != mProcessingGraph) 
    {
        self.state = AS_STOPPED;
        self.stopReason = AS_STOPPING_EOF;
        [self stopAndcleanUp];
        
        self.state = AS_INITIALIZED;
    }
}

- (BOOL)isFinishing
{
    if ((self.errorCode != AS_NO_ERROR && self.state != AS_INITIALIZED) ||
        ((self.state == AS_STOPPING || self.state == AS_STOPPED) &&
         self.stopReason != AS_STOPPING_TEMPORARILY))
    {
        return YES;
    }
    
	return NO;
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
        self.state == AS_PLAYING_AND_RECORDING ||
        self.state == AS_PAUSED  ||
        self.state == AS_BUFFERING)
    {
        self.state = AS_STOPPING;
        self.stopReason = AS_STOPPING_ERROR;
    }
    else if (self.state == AS_WAITING_FOR_DATA )
    {
        self.state = AS_STOPPING;
        self.stopReason = AS_STOPPING_NO_DATA;
    }
    
    if ( AS_AU_GRAPH_START_FAILED == self.errorCode ) 
    { 
        self.state = AS_STOPPING;
        self.stopReason = AS_STOPPING_ERROR;
    }
    
    [self failedWithError:self.errorCode];
}

#pragma mark QKPlayerProtocol

- (void)play
{
    if (NULL != mProcessingGraph) 
    {
        OSStatus result = AUGraphStart (mProcessingGraph);
        if (noErr != result)
        {
            [self reportFailWithError:AS_AU_GRAPH_START_FAILED];
            return;
        }
        self.state = AS_PLAYING;
    }
}

- (void)pause
{
    if (NULL != mProcessingGraph 
        && self.state != AS_STOPPING 
        && self.state != AS_STOPPED 
        &&  self.state != AS_PAUSED) 
    {
        Boolean isRunning = false;
        OSStatus result = AUGraphIsRunning (mProcessingGraph, &isRunning);
        if (noErr != result)
        {
            [self reportFailWithError:AS_AU_GRAPH_PAUSE_FAILED];
            return;
        }
        
        if (isRunning)
        {
            result = AUGraphStop (mProcessingGraph);
            if (noErr != result)
            {
                [self reportFailWithError:AS_AU_GRAPH_PAUSE_FAILED];
                return;
            }
            self.state = AS_PAUSED;
        }
    }
}

- (void)resume
{
	if (NULL != mProcessingGraph && self.state == AS_PAUSED) 
	{
        OSStatus result = AUGraphStart (mProcessingGraph);
        if (noErr != result)
        {
            [self reportFailWithError:AS_AU_GRAPH_START_FAILED];
            return;
        }
        self.state = AS_PLAYING;
	}
}

- (void)stop
{
    if (NULL != mProcessingGraph) 
    {
        [self stopAndcleanUp];
        
        self.state = AS_STOPPED;
        self.stopReason = AS_STOPPING_USER_ACTION;
    }
}

- (double)duration
{
    return mDuration;
}

- (double)progress
{
    if (NULL != mProcessingGraph &&
        ![self isFinishing]) 
    {
        if (self.state != AS_PLAYING 
            && self.state != AS_PAUSED 
            && self.state != AS_BUFFERING 
            && self.state != AS_STOPPING)
        {
            return  mLastProgress;
        }
        
        double progress = ((double)soundStruct.sampleNumber / (double)soundStruct.frameCount)*mDuration;
        if (progress < 0.0)
        {
            progress = 0.0;
        }
        mLastProgress = progress;
        return progress;
    }
	return 0.0;
}

- (BOOL)isSeekable
{
    return YES;
}

- (BOOL)seekToTime:(double)newSeekTime
{
    if (NULL == mProcessingGraph)
    {
        return NO;
    }
    AudioStreamerState oldState = self.state;
    // calculate frame offset by time to seeking
    UInt64 frameCount = soundStruct.frameCount;
    mFrameReadOffset = newSeekTime * frameCount / self.duration;
    
    // stop
    self.state = AS_STOPPING;
	self.stopReason = AS_STOPPING_TEMPORARILY;
    OSStatus err = AUGraphStop(mProcessingGraph);
    
	if (noErr != err)
	{
		[self reportFailWithError:AS_AU_GRAPH_STOP_FAILED];
		return NO;
	}
    
    // clean & reset
    [self cleanPlaybackResource];
    [self cleanSoundStruct];
    
    // Attempt to leave 1 useful frame at the end of the file(although in
	// reality, this may still seek too far if the file has a long trailer)
    if ( mFrameReadOffset > frameCount - 2 )
	{
        [self stopOnPlayBackDidFinish];
		return NO;
	}
    
    // load audio buffer
    [self loadAudioBuffer];
    
    self.state = oldState;
    if (AS_PLAYING == oldState)
    {
        [self play];
    }
    
    return YES;
}
@end

// ---------------------------------------------
// playback callback
// ---------------------------------------------
static OSStatus	audioinputCallback(
                                   void						*inRefCon, 
                                   AudioUnitRenderActionFlags 	*ioActionFlags, 
                                   const AudioTimeStamp 		*inTimeStamp, 
                                   UInt32 						inBusNumber, 
                                   UInt32 						inNumberFrames, 
                                   AudioBufferList 			*ioData)
{
    QKAUAudioPlayer* player = (QKAUAudioPlayer*)inRefCon;
    SoundStructPtr    soundStructPtr              = &(player->soundStruct);
    if (soundStructPtr)
    {
        BOOL              isStereo                  = soundStructPtr->isStereo;
        size_t bytesPerSample = player->mClientStreamFormat.mBytesPerFrame;
        
        AudioUnitSampleType *outSamplesChannelLeft;
        AudioUnitSampleType *outSamplesChannelRight;
        
        outSamplesChannelLeft                 = (AudioUnitSampleType *) ioData->mBuffers[0].mData;
        if (isStereo) outSamplesChannelRight  = (AudioUnitSampleType *) ioData->mBuffers[1].mData;
        
        
        int32_t avaliableBytesLeft, avaliableBytesRight;
        // Declare variables to point to the audio buffers. Their data type must match the buffer data type.
        AudioUnitSampleType *dataInLeft;
        AudioUnitSampleType *dataInRight;
        
        dataInLeft                 = TPCircularBufferTail(&soundStructPtr->audioBufferLeft, &avaliableBytesLeft);
        if (isStereo) dataInRight  = TPCircularBufferTail(&soundStructPtr->audioBufferRight,&avaliableBytesRight);
        
        // copy data
        int32_t size1 = MIN(avaliableBytesLeft, inNumberFrames * bytesPerSample);
        memcpy(outSamplesChannelLeft, dataInLeft, size1);
        TPCircularBufferConsume(&soundStructPtr->audioBufferLeft, size1);
        
        if (isStereo)
        {
            int32_t size2 = MIN(avaliableBytesRight, inNumberFrames *bytesPerSample);
            memcpy(outSamplesChannelRight, dataInRight, size2);
            TPCircularBufferConsume(&soundStructPtr->audioBufferRight, size1);
        }

        // update sample number
        soundStructPtr->sampleNumber += MIN(avaliableBytesLeft/bytesPerSample, inNumberFrames);

        // 
        if ((soundStructPtr->sampleNumber >= soundStructPtr->frameCount)
            || (avaliableBytesLeft == 0 && player->mReadComplete))
        {
            // Buffer is running out or playback is finised
            [player performSelectorOnMainThread:@selector(stopOnPlayBackDidFinish) withObject:nil waitUntilDone:NO];
        }
        else if (kAudioBufferLength - soundStructPtr->audioBufferLeft.fillCount >= kAudioBufferLengthPerReading)
        {
            // check if need load more data
            [player performSelector:@selector(loadAudioBufferProc) onThread:player->mInternalReadThread withObject:nil waitUntilDone:NO];
        }
    }
    return noErr;
}