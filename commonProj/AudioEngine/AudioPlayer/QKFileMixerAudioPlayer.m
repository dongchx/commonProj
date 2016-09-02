//
//  QKFileMixerAudioPlayer.m
//  QQKala
//
//  Created by frost on 12-6-26.
//  Copyright (c) 2012年 Tencent. All rights reserved.
//

#import "QKFileMixerAudioPlayer.h"
#import "AudioEngineHelper.h"
#import "ASBDUtility.h"
#import "PublicConfig.h"

#define kIOUintOutputElement                0 // I/O unit output element number, like "o"(output)
#define kMixerBusAudioFile                  0 // mixer bus 0, input from file
#define kMixerBusRecordFile                 1 // mixer bus 1, input from record file

// ---------------------------------------------
// QKFileMixerAudioPlayer private category
// ---------------------------------------------
@interface QKFileMixerAudioPlayer(Private)
- (void)setupASBD;
- (void)configAUGraph;
- (void)obtainSourceUrlsFromFile1:(NSString*)fileName1 file2:(NSString*)fileName1;
- (void)cancelLoadAudioBuffers;
- (void)loadAudioBuffers;
- (void)loadAudioBufferProcessingThread1;
- (void)loadAudioBufferProcessingThread2;
- (void)loadAudioBufferCompletion1;
- (void)loadAudioBufferCompletion2;

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
// QKFileMixerAudioPlayer implementation
// ---------------------------------------------
@implementation QKFileMixerAudioPlayer

#pragma mark life cycle

- (id)initWithAudioFile:(NSString*)filePath audioFile2:(NSString*)filePath2
{
    if (nil != filePath && nil != filePath2) 
    {
        if(!(self = [super init])) return nil;
        [self setupASBD];
        [self obtainSourceUrlsFromFile1:filePath file2:filePath2];
        [self loadAudioBuffers];
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

#pragma mark 
- (void)setAudioFileChannel:(SoundChannel)channel
{
    mAudioFileSoundChannel = channel;
}
#pragma mark Private
- (void)setupASBD
{
    //............................................................................
    // set stream format
    [ASBDUtility setAudioUnitASBD:&mStereoStreamFormat numChannels:2 sampleRate:AudioSampleRate44K];
    [ASBDUtility setAudioUnitASBD:&mMonoStreamFormat numChannels:1 sampleRate:AudioSampleRate44K];
    [ASBDUtility setCanonical:&mSInt16CanonicalStereoFormat numChannels:2 sampleRate:AudioSampleRate44K isInterleaved:NO];
    [ASBDUtility setCanonical:&mSInt16CanonicalMonoFormat numChannels:1 sampleRate:AudioSampleRate44K isInterleaved:NO];
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
    
    UInt32 busCount   = 2;    // bus count for mixer unit input
    
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
                                   &mClientStreamFormat[0],
                                   sizeof (mClientStreamFormat[0])
                                   );
    
    if (noErr != result) 
    {
        [self reportFailWithError:AS_AU_GRAPH_CREATION_FAILED];
        return;
    }
    
    // Apply format for mixer record file bus (input bus 1)
    result = AudioUnitSetProperty (
                                   mMixerUnit,
                                   kAudioUnitProperty_StreamFormat,
                                   kAudioUnitScope_Input,
                                   kMixerBusRecordFile,
                                   &mClientStreamFormat[1],
                                   sizeof (mClientStreamFormat[1])
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
    
    // Attach the callback for record file bus
    callbackStruct.inputProc        = &audioinputCallback;
    callbackStruct.inputProcRefCon  = self;
    
    result = AUGraphSetNodeInputCallback (
                                          mProcessingGraph,
                                          mixerNode,
                                          kMixerBusRecordFile,
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

- (void)obtainSourceUrlsFromFile1:(NSString*)fileName1 file2:(NSString*)fileName2
{
    if (nil != fileName1 && nil != fileName2)
    {
        // clean if necessary
        [self cleanSourceUrl];
        
        // get audio file urls
        NSURL *audioFileUrl1 = [NSURL fileURLWithPath:fileName1 isDirectory:NO];
        sourceURL[0] = (CFURLRef) [audioFileUrl1 retain];
        
        NSURL *audioFileUrl2 = [NSURL fileURLWithPath:fileName2 isDirectory:NO];
        sourceURL[1] = (CFURLRef) [audioFileUrl2 retain];
    }
}

- (void)cancelLoadAudioBuffers
{
    for (int i = 0; i < NUM_FILES; ++i)  
    {
        mCancelReadSource[i] = YES;
        
        if (nil != mInternalReadThread[i])
        {
            [mInternalReadThread[i] cancel];
            // wait until reading processing thread exit
            while (mReading[i])
            {
                [NSThread sleepForTimeInterval:0.01];
            }
            [mInternalReadThread[i] release];
            mInternalReadThread[i] = nil;
        }
    }
}

- (void)loadAudioBuffers
{
    // load audio files
    for (int audioFile = 0; audioFile < NUM_FILES; ++audioFile) 
    {
        // Open an audio file and associate it with the extended audio file object.
        OSStatus result = ExtAudioFileOpenURL (sourceURL[audioFile], &mSourceAudioFile[audioFile]);
        
        if (noErr != result || NULL == mSourceAudioFile[audioFile]) 
            return;
        
        // Get the audio file's duration
        AudioFileID audioFileID;
        UInt32 size = sizeof(audioFileID);
        ExtAudioFileGetProperty(mSourceAudioFile[audioFile], kExtAudioFileProperty_AudioFile, &size, &audioFileID);
        
        UInt32 propertySize = sizeof(mDuration[audioFile]);
        AudioFileGetProperty(audioFileID, kAudioFilePropertyEstimatedDuration, &propertySize, &mDuration[audioFile]);
        
        // Get the audio file's length in frames.
        UInt64 totalFramesInFile = 0;
        UInt32 frameLengthPropertySize = sizeof (totalFramesInFile);
        
        result =    ExtAudioFileGetProperty (
                                             mSourceAudioFile[audioFile],
                                             kExtAudioFileProperty_FileLengthFrames,
                                             &frameLengthPropertySize,
                                             &totalFramesInFile
                                             );
        
        if (noErr != result) 
            return;
        
        // Assign the frame count to the soundStruct instance variable
        soundStruct[audioFile].sampleNumber = mFrameReadOffset;
        soundStruct[audioFile].frameCount = totalFramesInFile;
        
        // Get the audio file's number of channels.
        AudioStreamBasicDescription fileAudioFormat = {0};
        UInt32 formatPropertySize = sizeof (fileAudioFormat);
        
        result =    ExtAudioFileGetProperty (
                                             mSourceAudioFile[audioFile],
                                             kExtAudioFileProperty_FileDataFormat,
                                             &formatPropertySize,
                                             &fileAudioFormat
                                             );
        
        if (noErr != result) 
            return;
        
        UInt32 channelCount = fileAudioFormat.mChannelsPerFrame;
        
        
        // Init circular buffer to hold the left channel or mono, audio data
        TPCircularBufferInit(&soundStruct[audioFile].audioBufferLeft,kAudioBufferLength);
        
        // init circular buffer right if necessary
        
        if (2 == channelCount)
        {
            soundStruct[audioFile].isStereo = YES;
            TPCircularBufferInit(&soundStruct[audioFile].audioBufferRight,kAudioBufferLength);
            mClientStreamFormat[audioFile] = mSInt16CanonicalStereoFormat;
        } 
        else if (1 == channelCount) 
        {
            soundStruct[audioFile].isStereo = NO;
            mClientStreamFormat[audioFile] = mSInt16CanonicalMonoFormat;
            
        } 
        else 
        {
            ExtAudioFileDispose (mSourceAudioFile[audioFile]);
            mSourceAudioFile[audioFile] = NULL;
            return;
        }
        
        // Assign the appropriate mixer input bus stream data format to the extended audio 
        //        file object. This is the format used for the audio data placed into the audio 
        //        buffer in the SoundStruct data structure, which is in turn used in the 
        //        inputRenderCallback callback function.
        
        result =    ExtAudioFileSetProperty (
                                             mSourceAudioFile[audioFile],
                                             kExtAudioFileProperty_ClientDataFormat,
                                             sizeof (mClientStreamFormat[audioFile]),
                                             &mClientStreamFormat[audioFile]
                                             );
        
        if (noErr != result) 
            return;
        
        mSourceFileReadComplete[audioFile] = NO;
        mCancelReadSource[audioFile] = NO;
        mReading[audioFile] = YES;
        
        // start background thread to load audio buffer
        if (0 == audioFile) 
        {
            if (nil != mInternalReadThread[0])
            {
                [mInternalReadThread[0] release];
            }
            mInternalReadThread[0] =[[NSThread alloc] initWithTarget:self 
                                                         selector:@selector(loadAudioBufferProcessingThread1) 
                                                           object:nil];
            [mInternalReadThread[0] start];
        }
        else
        {
            if (nil != mInternalReadThread[1])
            {
                [mInternalReadThread[1] release];
            }
            mInternalReadThread[1] =[[NSThread alloc] initWithTarget:self 
                                                         selector:@selector(loadAudioBufferProcessingThread2) 
                                                           object:nil];
            [mInternalReadThread[1] start];
        }
        
    }
    
    mMeasureIndex = soundStruct[0].frameCount <= soundStruct[1].frameCount ? 0 : 1;
    mFrameCount = soundStruct[mMeasureIndex].frameCount;
}

- (void)loadAudioBufferProcessingThread1
{
    NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
    AudioBufferList *bufferList = NULL;
    UInt8 *buffer1 = NULL;
    UInt8 *buffer2 = NULL;
    
    if (NULL != mSourceAudioFile[0])
    {
        // Set up an AudioBufferList struct, which has two roles:
        //
        //        1. It gives the ExtAudioFileRead function the configuration it 
        //            needs to correctly provide the data to the buffer.
        //
        //        2. It points to the soundStructArray[audioFile].audioDataLeft buffer, so 
        //            that audio data obtained from disk using the ExtAudioFileRead function
        //            goes to that buffer
        
        // Allocate memory for the buffer list struct according to the number of 
        //    channels it represents.
        
        
        UInt32 channelCount = soundStruct[0].isStereo? 2 : 1;
        
        bufferList = (AudioBufferList *) malloc (
                                                 sizeof (AudioBufferList) + sizeof (AudioBuffer) * (channelCount - 1)
                                                 );
        
        if (NULL == bufferList) 
        {
            QKLog (@"*** malloc failure for allocating bufferList memory"); 
            goto err;
        }
        
        // buffer
        UInt32 bufferByteSize = kAudioBufferLengthPerReading;
        buffer1 = malloc(bufferByteSize);
        if (NULL == buffer1) 
        {
            QKLog (@"*** malloc failure for allocating buffer1 memory"); 
            goto err;
        }	
        
        // initialize the mNumberBuffers member
        bufferList->mNumberBuffers = channelCount;
        
        // initialize the mBuffers member to 0
        AudioBuffer emptyBuffer = {0};
        size_t arrayIndex;
        for (arrayIndex = 0; arrayIndex < channelCount; arrayIndex++)
        {
            bufferList->mBuffers[arrayIndex] = emptyBuffer;
        }
        
        SInt64 sourceFrameOffset = mFrameReadOffset;
        // set up the AudioBuffer structs in the buffer list
        bufferList->mBuffers[0].mNumberChannels  = 1;
        bufferList->mBuffers[0].mDataByteSize    = bufferByteSize;
        bufferList->mBuffers[0].mData            = buffer1;
        
        if (2 == channelCount)
        {
            buffer2 = malloc(bufferByteSize);
            if (NULL == buffer2) 
            {
                QKLog (@"*** malloc failure for allocating buffer2 memory"); 
                goto err;
            }
            
            bufferList->mBuffers[1].mNumberChannels  = 1;
            bufferList->mBuffers[1].mDataByteSize    = bufferByteSize;
            bufferList->mBuffers[1].mData            = buffer2;
        }
        
        OSStatus err = ExtAudioFileSeek(mSourceAudioFile[0], sourceFrameOffset);
        if ( noErr != err ) 
        {
            goto err;
        }
        
        while ( !mCancelReadSource[0] 
               && ![[NSThread currentThread] isCancelled])
        {
            // check if the available buffer space is enough to hold at least one cycle of the sample data
            
            if (kAudioBufferLength - soundStruct[0].audioBufferLeft.fillCount >= kAudioBufferLengthPerReading) 
            {
                bufferList->mBuffers[0].mDataByteSize    = bufferByteSize;
                if (2 == channelCount)
                {
                    bufferList->mBuffers[1].mDataByteSize    = bufferByteSize;
                }
                
                UInt32 numFrames = bufferByteSize / mClientStreamFormat[0].mBytesPerFrame;
                
                err = ExtAudioFileRead(mSourceAudioFile[0], &numFrames, bufferList);
                if ( noErr != err ) 
                {
                    goto err;
                }
                
                // If no frames were returned, read is finished
                if ( !numFrames ) 
                {
                    break;
                }
                
                sourceFrameOffset += numFrames;
                
                TPCircularBufferProduceBytes(&soundStruct[0].audioBufferLeft, bufferList->mBuffers[0].mData, bufferList->mBuffers[0].mDataByteSize);
                if (2 == channelCount)
                {
                    TPCircularBufferProduceBytes(&soundStruct[0].audioBufferRight, bufferList->mBuffers[1].mData, bufferList->mBuffers[1].mDataByteSize);
                }
            }
        }
        
        if ( !mCancelReadSource[0] ) 
        {
            [self performSelectorOnMainThread:@selector(loadAudioBufferCompletion1) withObject:nil waitUntilDone:NO];
        } 
    }
    
err:
    free (bufferList);
    if (buffer1 != NULL)
        free(buffer1);
    if (buffer2 != NULL)
        free(buffer2);
    
    [pool release];
    mReading[0] = NO;
}

- (void)loadAudioBufferProcessingThread2
{
    NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
    AudioBufferList *bufferList = NULL;
    UInt8 *buffer1 = NULL;
    UInt8 *buffer2 = NULL;
    
    if (NULL != mSourceAudioFile[1])
    {
        // Set up an AudioBufferList struct, which has two roles:
        //
        //        1. It gives the ExtAudioFileRead function the configuration it 
        //            needs to correctly provide the data to the buffer.
        //
        //        2. It points to the soundStructArray[audioFile].audioDataLeft buffer, so 
        //            that audio data obtained from disk using the ExtAudioFileRead function
        //            goes to that buffer
        
        // Allocate memory for the buffer list struct according to the number of 
        //    channels it represents.
        
        
        UInt32 channelCount = soundStruct[1].isStereo? 2 : 1;
        
        bufferList = (AudioBufferList *) malloc (
                                                 sizeof (AudioBufferList) + sizeof (AudioBuffer) * (channelCount - 1)
                                                 );
        
        if (NULL == bufferList) 
        {
            QKLog (@"*** malloc failure for allocating bufferList memory"); 
            goto err;
        }
        
        // buffer
        UInt32 bufferByteSize = kAudioBufferLengthPerReading;
        buffer1 = malloc(bufferByteSize);
        if (NULL == buffer1) 
        {
            QKLog (@"*** malloc failure for allocating buffer1 memory"); 
            goto err;
        }	
        
        // initialize the mNumberBuffers member
        bufferList->mNumberBuffers = channelCount;
        
        // initialize the mBuffers member to 0
        AudioBuffer emptyBuffer = {0};
        size_t arrayIndex;
        for (arrayIndex = 0; arrayIndex < channelCount; arrayIndex++)
        {
            bufferList->mBuffers[arrayIndex] = emptyBuffer;
        }
        
        SInt64 sourceFrameOffset = mFrameReadOffset;
        // set up the AudioBuffer structs in the buffer list
        bufferList->mBuffers[0].mNumberChannels  = 1;
        bufferList->mBuffers[0].mDataByteSize    = bufferByteSize;
        bufferList->mBuffers[0].mData            = buffer1;
        
        if (2 == channelCount)
        {
            buffer2 = malloc(bufferByteSize);
            if (NULL == buffer2) 
            {
                QKLog (@"*** malloc failure for allocating buffer2 memory"); 
                goto err;
            }
            
            bufferList->mBuffers[1].mNumberChannels  = 1;
            bufferList->mBuffers[1].mDataByteSize    = bufferByteSize;
            bufferList->mBuffers[1].mData            = buffer2;
        }
        
        OSStatus err = ExtAudioFileSeek(mSourceAudioFile[1], sourceFrameOffset);
        if ( noErr != err ) 
        {
            goto err;
        }
        
        while ( !mCancelReadSource[1] 
               && ![[NSThread currentThread] isCancelled])
        {
            // check if the available buffer space is enough to hold at least one cycle of the sample data
            
            if (kAudioBufferLength - soundStruct[1].audioBufferLeft.fillCount >= kAudioBufferLengthPerReading) 
            {
                bufferList->mBuffers[0].mDataByteSize    = bufferByteSize;
                if (2 == channelCount)
                {
                    bufferList->mBuffers[1].mDataByteSize    = bufferByteSize;
                }
                
                UInt32 numFrames = bufferByteSize / mClientStreamFormat[1].mBytesPerFrame;
                
                err = ExtAudioFileRead(mSourceAudioFile[1], &numFrames, bufferList);
                if ( noErr != err ) 
                {
                    goto err;
                }
                
                // If no frames were returned, read is finished
                if ( !numFrames ) 
                {
                    break;
                }
                
                sourceFrameOffset += numFrames;
                
                TPCircularBufferProduceBytes(&soundStruct[1].audioBufferLeft, bufferList->mBuffers[0].mData, bufferList->mBuffers[0].mDataByteSize);
                if (2 == channelCount)
                {
                    TPCircularBufferProduceBytes(&soundStruct[1].audioBufferRight, bufferList->mBuffers[1].mData, bufferList->mBuffers[1].mDataByteSize);
                }
            }
        }
        
        if ( !mCancelReadSource[1] ) 
        {
            [self performSelectorOnMainThread:@selector(loadAudioBufferCompletion2) withObject:nil waitUntilDone:NO];
        } 
    }
    
err:
    free (bufferList);
    if (buffer1 != NULL)
        free(buffer1);
    if (buffer2 != NULL)
        free(buffer2);
    
    [pool release];
    mReading[1] = NO; 
}

- (void)loadAudioBufferCompletion1
{
    mSourceFileReadComplete[0] = YES;
    ExtAudioFileDispose (mSourceAudioFile[0]);
    mSourceAudioFile[0] = NULL;
}

- (void)loadAudioBufferCompletion2
{
    mSourceFileReadComplete[1] = YES;
    ExtAudioFileDispose (mSourceAudioFile[1]);
    mSourceAudioFile[1] = NULL;
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
    [self cancelLoadAudioBuffers];
    [self disposeSourceAudioFile];
}

- (void)cleanSoundStruct
{
    for (int i = 0; i < NUM_FILES; ++i)  
    {
        soundStruct[i].sampleNumber = 0;
        soundStruct[i].frameCount = 0;
        
        TPCircularBufferCleanup(&soundStruct[i].audioBufferLeft);
        TPCircularBufferCleanup(&soundStruct[i].audioBufferRight);
    }
}

- (void)cleanSourceUrl
{
    for (int i = 0; i < NUM_FILES; ++i)  
    {
        if (NULL != sourceURL[i])
        {
            CFRelease(sourceURL[i]);
            sourceURL[i] = NULL;
        }
    }
}

- (void)disposeSourceAudioFile
{
    for (int i = 0; i < NUM_FILES; ++i)  
    {
        if (NULL != mSourceAudioFile[i])
        {
            ExtAudioFileDispose (mSourceAudioFile[i]); 
            mSourceAudioFile[i] = NULL;
        }
        
        mSourceFileReadComplete[i] = NO;
        mCancelReadSource[i] = NO;
        mDuration[i] = 0;
    }
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
        }
    }
    self.state = AS_PAUSED;
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
    if (mMeasureIndex < NUM_FILES) 
    {
        return mDuration[mMeasureIndex];
    }
    else
    {
        return mDuration[0];
    }
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
        
        // get progress
        double progress = 0;
        if (mMeasureIndex < NUM_FILES) 
        {
            progress = ((double)soundStruct[mMeasureIndex].sampleNumber / (double)soundStruct[mMeasureIndex].frameCount)*mDuration[mMeasureIndex];
        }
        else
        {
            progress = ((double)soundStruct[0].sampleNumber / (double)soundStruct[0].frameCount)*mDuration[0];
        }
        
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
    UInt64 frameCount = 0;
    if (mMeasureIndex < NUM_FILES) 
    {
        frameCount = soundStruct[mMeasureIndex].frameCount;
        mFrameReadOffset = newSeekTime * frameCount / self.duration;
    }
    else
    {
        frameCount = soundStruct[mMeasureIndex].frameCount;
        mFrameReadOffset = newSeekTime * frameCount / self.duration;
    }
    
    // stop
    self.state = AS_STOPPING;
	self.stopReason = AS_STOPPING_TEMPORARILY;
    OSStatus err = AUGraphStop(mProcessingGraph);

	if (noErr != err)
	{
		[self reportFailWithError:AS_AU_GRAPH_STOP_FAILED];
		return YES;
	}
    
    // clean & reset
    [self cleanPlaybackResource];
    [self cleanSoundStruct];
    
    // Attempt to leave 1 useful frame at the end of the file(although in
	// reality, this may still seek too far if the file has a long trailer)
    if ( mFrameReadOffset > frameCount - 2 )
	{
		self.state = AS_STOPPED;
		self.state = AS_INITIALIZED;
		self.stopReason = AS_STOPPING_EOF;
		return YES;
	}
    
    // load audio buffers
    [self loadAudioBuffers];
    
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
    QKFileMixerAudioPlayer* player = (QKFileMixerAudioPlayer*)inRefCon;
    SoundStructPtr    soundStructPointerArray = player->soundStruct;
    if (soundStructPointerArray)
    {
        BOOL isStereo = soundStructPointerArray[inBusNumber].isStereo;
        size_t bytesPerSample = player->mClientStreamFormat[inBusNumber].mBytesPerFrame;
        
        AudioUnitSampleType *outSamplesChannelLeft;
        AudioUnitSampleType *outSamplesChannelRight;
        
        outSamplesChannelLeft                 = (AudioUnitSampleType *) ioData->mBuffers[0].mData;
        if (isStereo) outSamplesChannelRight  = (AudioUnitSampleType *) ioData->mBuffers[1].mData;
        
        
        int32_t avaliableBytesLeft = 0;
        int32_t avaliableBytesRight = 0;
        // Declare variables to point to the audio buffers. Their data type must match the buffer data type.
        AudioUnitSampleType *dataInLeft = NULL;
        AudioUnitSampleType *dataInRight = NULL;
        
        dataInLeft                 = TPCircularBufferTail(&soundStructPointerArray[inBusNumber].audioBufferLeft, &avaliableBytesLeft);
        if (isStereo) dataInRight  = TPCircularBufferTail(&soundStructPointerArray[inBusNumber].audioBufferRight,&avaliableBytesRight);
        
        // copy data
        if (kMixerBusAudioFile == inBusNumber) 
        {
            if (player->mAudioFileSoundChannel == SoundChannelLeft) 
            {
                int32_t size1 = MIN(avaliableBytesLeft, inNumberFrames * bytesPerSample);
                memcpy(outSamplesChannelLeft, dataInLeft, size1);
                TPCircularBufferConsume(&soundStructPointerArray[inBusNumber].audioBufferLeft, size1);
                if (isStereo)
                {
                    memcpy(outSamplesChannelRight, dataInLeft, size1);
                    TPCircularBufferConsume(&soundStructPointerArray[inBusNumber].audioBufferRight, size1);
                }

                // update sample number
                soundStructPointerArray[inBusNumber].sampleNumber += MIN(avaliableBytesLeft/bytesPerSample, inNumberFrames);
            }
            else
            {
                int32_t size2 = MIN(avaliableBytesRight, inNumberFrames *bytesPerSample);
                memcpy(outSamplesChannelLeft, dataInRight, size2);
                TPCircularBufferConsume(&soundStructPointerArray[inBusNumber].audioBufferRight, size2);
                if (isStereo)
                {
                    memcpy(outSamplesChannelRight, dataInRight, size2);
                    TPCircularBufferConsume(&soundStructPointerArray[inBusNumber].audioBufferLeft, size2);
                }

                // update sample number
                soundStructPointerArray[inBusNumber].sampleNumber += MIN(avaliableBytesRight/bytesPerSample, inNumberFrames);
            }
        }
        else
        {
            int32_t size1 = MIN(avaliableBytesLeft, inNumberFrames * bytesPerSample);
            memcpy(outSamplesChannelLeft, dataInLeft, size1);
            TPCircularBufferConsume(&soundStructPointerArray[inBusNumber].audioBufferLeft, size1);
            if (isStereo)
            {
                memcpy(outSamplesChannelRight, dataInRight, size1);
                TPCircularBufferConsume(&soundStructPointerArray[inBusNumber].audioBufferRight, size1);
            }

            // update sample number
            soundStructPointerArray[inBusNumber].sampleNumber += MIN(avaliableBytesLeft/bytesPerSample, inNumberFrames);
        }
        
        UInt64 frameCount = player->mFrameCount;
        if (frameCount >soundStructPointerArray[inBusNumber].frameCount)
        {
            frameCount = soundStructPointerArray[inBusNumber].frameCount;
        }
        
        if ((soundStructPointerArray[inBusNumber].sampleNumber >= frameCount)
            || (avaliableBytesLeft == 0 && player->mSourceFileReadComplete[inBusNumber])) 
        {
            // Buffer is running out or playback is finised
            [player performSelectorOnMainThread:@selector(stopOnPlayBackDidFinish) withObject:nil waitUntilDone:NO];
        }
    }
    return noErr;
}