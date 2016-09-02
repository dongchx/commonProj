//
//  QKMultichannelAudioPlayer.m
//  QQKala
//
//  Created by frost on 12-6-13.
//  Copyright (c) 2012年 Tencent. All rights reserved.
//

#import <Accelerate/Accelerate.h>			// for vdsp functions
#import "QKMultichannelAudioPlayer.h"
#import "AudioEngineHelper.h"
#import "ASBDUtility.h"
#import "PublicConfig.h"
#import "FileUtility.h"
#import "QKAudioSynthesizeProcessor.h"
#import "QKEvaluator.h"


#define kIOUintInputElement       1 // I/O unit input element number, like "i"(input)
#define kIOUintOutputElement      0 // I/O unit output element number, like "o"(output)

#define kMixerBusAudioFile        0 // mixer bus 0, input from file
#define kMixerBusMic              1 // mixer bus 1, input from mic

const float kEpsinon = 0.001;

const int kScratchBufferSize = 10240;

// ---------------------------------------------
// QKMultichannelAudioPlayer private category
// ---------------------------------------------
@interface QKMultichannelAudioPlayer()
@property (nonatomic, readwrite, retain)NSString        *recordFilePath;
@property (nonatomic, assign)void                       *recordBuffer;

/* set up asbd used by QKMultichannelAudioPlayer*/
- (void)setupASBD:(NSInteger)sampleRate;

/* Audio unit processing graph used to playing & recording*/
- (void)configAUGraph;

/**/
- (void)configRecordFile:(NSString*)fileName fileType:(AudioFileTypeID)type destinationASBD:(AudioStreamBasicDescription*)destinationASBD clientASBD:(AudioStreamBasicDescription*)clientASBD;



/* Private function for read audio buffer from source file specified*/
- (void)cancelReadAudioBuffer;
- (void)loadAudioBufferFromFile:(NSString*)audioFileName;
- (void)loadAudioBufferProcessingThread;
- (void)loadAudioBufferCompletion;

/* Private function for stop and cleanup*/
- (void)stopAndcleanUp;
- (void)stopAUGraphAndClenup;
- (void)cleanPlaybackResource;
- (void)cleanRecordResource;
- (void)cleanSoundStruct;
- (void)cleanRecordBuffer;

/**/
- (void)stopOnPlayBackDidFinish;

- (BOOL)isFinishing;
- (void)reportFailWithError:(AudioStreamerErrorCode)anErrorCode;
- (void)reportFailOnMainThread;

@end

// ---------------------------------------------
// forward declaration
// ---------------------------------------------
static OSStatus	recordingCallback(
							void						*inRefCon, 
							AudioUnitRenderActionFlags 	*ioActionFlags, 
							const AudioTimeStamp 		*inTimeStamp, 
							UInt32 						inBusNumber, 
							UInt32 						inNumberFrames, 
							AudioBufferList 			*ioData);

static OSStatus	audioinputCallback(
                                 void						*inRefCon, 
                                 AudioUnitRenderActionFlags 	*ioActionFlags, 
                                 const AudioTimeStamp 		*inTimeStamp, 
                                 UInt32 						inBusNumber, 
                                 UInt32 						inNumberFrames, 
                                 AudioBufferList 			*ioData);


// ---------------------------------------------
// QKMultichannelAudioPlayer implementation
// ---------------------------------------------
@implementation QKMultichannelAudioPlayer

@synthesize recordFilePath = mRecordFileName;
@synthesize recordBuffer = mRecordBuffer;
@synthesize audioProcessor = mSynthesizeProcessor;
@synthesize evaluator = mEvaluator;

#pragma mark life cycle

- (id)initWithAudioFile:(NSString*)filePath recordFilePath:(NSString*)recordFilePath
{
    if (nil != filePath) 
    {
        if(!(self = [super init])) return nil;
        mRecordGain = 1.0;
        [self loadAudioBufferFromFile:filePath];
        [self configAUGraph];
//        [self configRecordFile:recordFilePath fileType:kAudioFileCAFType destinationASBD:&mRecordFormat clientASBD:&mRecordFormat];

        self.recordBuffer = malloc(kScratchBufferSize * sizeof(float));
        [self registerPlayStateChangeNotification];
        return self;
    }
	return nil;
}

- (void)dealloc
{
    [self unRegisterPlayStateChangeNotification];
    [self stopAndcleanUp];
    self.recordFilePath = nil;
    self.audioProcessor = nil;
    self.evaluator = nil;
    [super dealloc];
}

#pragma mark public function
- (void)setDefaultChannel:(SoundChannel)channel
{
    mCurrentChannel = channel;
}

- (void)setAccompanimentChannel:(SoundChannel)channel
{
    mAccompanimentChannel = channel;
}

- (AudioStreamBasicDescription)getRecordFormat
{
    return mRecordFormat;
}

- (AudioStreamBasicDescription)getOutputFormat
{
    return mOutputFormat;
}

- (float)getcurrentVolume
{
    if (NULL != mProcessingGraph && NULL != mMixerUnit) 
    {
        float volPct = 0.0f;
        OSStatus result = AudioUnitGetParameter (
                                                 mMixerUnit,
                                                 kMultiChannelMixerParam_Volume,
                                                 kAudioUnitScope_Input,
                                                 kMixerBusMic,
                                                 &volPct
                                                 );
        if (noErr != result)
        {
            QKLog(@"enableVoiceInputBus,error %ld", result);
            return 0.0;
        }
        return volPct;
    }
    return 0.0;
}
#pragma mark Private

- (void)setupASBD:(NSInteger)sampleRate
{
    //............................................................................
    // set stream format
    [ASBDUtility setAudioUnitASBD:&mStereoStreamFormat numChannels:2 sampleRate:sampleRate];
    [ASBDUtility setAudioUnitASBD:&mMonoStreamFormat numChannels:1 sampleRate:sampleRate];
    
    [ASBDUtility setASBD:&mSInt16StereoFormat formatID:kAudioFormatLinearPCM numChannels:2 sampleRate:sampleRate];
    [ASBDUtility setASBD:&mSInt16MonoFormat formatID:kAudioFormatLinearPCM numChannels:1 sampleRate:sampleRate];
    [ASBDUtility setCanonical:&mSInt16CanonicalStereoFormat numChannels:2 sampleRate:sampleRate isInterleaved:NO];
    [ASBDUtility setCanonical:&mSInt16CanonicalMonoFormat numChannels:1 sampleRate:sampleRate isInterleaved:NO];
    
    mRecordFormat = mSInt16MonoFormat;
    mOutputFormat = mSInt16MonoFormat;
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
    // io uint setup
    BOOL hasMicPhone = [[AudioEngineHelper sharedInstance] hasMicPhone];
    if(hasMicPhone)
    {
        UInt32 flag = 1;
        // Enable IO for recording
        result = AudioUnitSetProperty(mIOUnit, kAudioOutputUnitProperty_EnableIO, kAudioUnitScope_Input, kIOUintInputElement, &flag, sizeof(flag));
        
        if (noErr != result) 
        {
            [self reportFailWithError:AS_AU_GRAPH_CREATION_FAILED];
            return;
        }
        
        // Apply format for IO input element (output of mic)
        result = AudioUnitSetProperty (
                                       mIOUnit,
                                       kAudioUnitProperty_StreamFormat,
                                       kAudioUnitScope_Output,
                                       kIOUintInputElement,
                                       &mRecordFormat,
                                       sizeof (mRecordFormat)
                                       );
        
        if (noErr != result) 
        {
            [self reportFailWithError:AS_AU_GRAPH_CREATION_FAILED];
            return;
        }
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
                                   &mClientStreamFormat,
                                   sizeof (mClientStreamFormat)
                                   );
    
    if (noErr != result) 
    {
        [self reportFailWithError:AS_AU_GRAPH_CREATION_FAILED];
        return;
    }
    
    if(hasMicPhone)
    {
        // Apply format for mixer mic bus (input bus 1)
        result = AudioUnitSetProperty (
                                       mMixerUnit,
                                       kAudioUnitProperty_StreamFormat,
                                       kAudioUnitScope_Input,
                                       kMixerBusMic,
                                       &mRecordFormat,
                                       sizeof (mRecordFormat)
                                       );
        
        if (noErr != result) 
        {
            [self reportFailWithError:AS_AU_GRAPH_CREATION_FAILED];
            return;
        }
    }
    
    // Apply format for mixer output
    mMixerOutputScopeFormat = mStereoStreamFormat;
    result = AudioUnitSetProperty (
                                   mMixerUnit,
                                   kAudioUnitProperty_StreamFormat,
                                   kAudioUnitScope_Output,
                                   0,
                                   &mMixerOutputScopeFormat,
                                   sizeof (mMixerOutputScopeFormat)
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
    
    if(hasMicPhone)
    {
        // Attach the callback for mic input bus
        callbackStruct.inputProc        = &recordingCallback;
        callbackStruct.inputProcRefCon  = self;
        
        result = AUGraphSetNodeInputCallback (
                                              mProcessingGraph,
                                              mixerNode,
                                              kMixerBusMic,
                                              &callbackStruct
                                              );
        
        if (noErr != result) 
        {
            [self reportFailWithError:AS_AU_GRAPH_CREATION_FAILED];
            return;
        }
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

- (void)configRecordFile:(NSString*)fileName fileType:(AudioFileTypeID)type destinationASBD:(AudioStreamBasicDescription*)destinationASBD clientASBD:(AudioStreamBasicDescription*)clientASBD
{
    self.recordFilePath = fileName;
    CFURLRef url = CFURLCreateWithFileSystemPath(NULL, (CFStringRef)self.recordFilePath, kCFURLPOSIXPathStyle, false);
    OSStatus err = ExtAudioFileCreateWithURL(url, type, destinationASBD, NULL, kAudioFileFlags_EraseFile, &mRecordFileRef);
    CFRelease(url);
    
    if (noErr != err)
    {
        [self failedWithError:AS_AU_GRAPH_RECORD_FAILED];
        return;
    }
    
    // excluding from backup if necessary
    [FileUtility addSkipBackupAttributeToItemAtURL:[NSURL fileURLWithPath:self.recordFilePath]];
    
    // Inform the file what format the data is we're going to give it, 
    err = ExtAudioFileSetProperty(mRecordFileRef, kExtAudioFileProperty_ClientDataFormat, sizeof(AudioStreamBasicDescription), clientASBD);
    if (noErr != err)
    {
        [self failedWithError:AS_AU_GRAPH_RECORD_FAILED];
        return;
    }

    // Initialize async writes thus preparing it for IO
	err = ExtAudioFileWriteAsync(mRecordFileRef, 0, NULL);
	if(noErr != err)
	{
        [self failedWithError:AS_AU_GRAPH_RECORD_FAILED];
        return;
	}
}

- (void)cancelReadAudioBuffer
{
    if (nil != mInternalReadThread)
    {
        [self performSelector:@selector(cancelLoadAudioBufferProc) onThread:mInternalReadThread withObject:nil waitUntilDone:YES];
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

- (void)loadAudioBufferFromFile:(NSString*)audioFileName
{
    if (nil != audioFileName)
    {
        if (NULL != sourceURL)
        {
            CFRelease(sourceURL);
        }
        // get audio file url
        NSURL *audioFileUrl = [NSURL fileURLWithPath:audioFileName isDirectory:NO];
        sourceURL = (CFURLRef) [audioFileUrl retain];
        
        // Open an audio file and associate it with the extended audio file object.
        OSStatus result = ExtAudioFileOpenURL (sourceURL, &mSourceAudioFile);
        
        if (noErr != result || NULL == mSourceAudioFile) 
            return;
        
        // Get the audio file's duration
        AudioFileID audioFileID;
        UInt32 size = sizeof(audioFileID);
        result = ExtAudioFileGetProperty(mSourceAudioFile, kExtAudioFileProperty_AudioFile, &size, &audioFileID);
        if (noErr != result) 
            return;
        
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
        soundStruct.sampleNumber = 0;
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
    
    if (NULL != mSourceAudioFile)
    {

        while ( !mCancelReadSource 
               && ![[NSThread currentThread] isCancelled]
               && !mReadComplete)
        {
            [runLoop runMode:NSDefaultRunLoopMode beforeDate:[NSDate distantFuture]];
        }
        
        if ( !mCancelReadSource ) 
        {
            [self performSelectorOnMainThread:@selector(loadAudioBufferCompletion) withObject:nil waitUntilDone:NO];
        } 
    }
    
err:

    [mInternalReadThread release];
    mInternalReadThread = nil;
    
    [pool release];
    mReading = NO;
}

- (void)loadAudioBufferCompletion 
{
    ExtAudioFileDispose (mSourceAudioFile);
    mSourceAudioFile = NULL;
}

- (void)stopAndcleanUp
{
    [self stopAUGraphAndClenup];
    [self cleanPlaybackResource];
    [self cleanRecordResource];
    [self cleanSoundStruct];
    [self cleanRecordBuffer];
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
        
        [self.audioProcessor setSourceBufferDrain];
    }
}

- (void)cleanPlaybackResource
{
    [self cancelReadAudioBuffer];
    
    if (NULL != sourceURL) 
    {
        CFRelease (sourceURL);
        sourceURL = NULL;
    }
    
    if (NULL != mSourceAudioFile) 
    {
        ExtAudioFileDispose (mSourceAudioFile); 
        mSourceAudioFile = NULL;
    }
    
//    mDuration = 0;
    mCancelReadSource = NO;
}

- (void)cleanRecordResource
{
    if (NULL != mRecordFileRef) 
    {
        ExtAudioFileDispose (mRecordFileRef); 
        mRecordFileRef = NULL;
    }
}

- (void)cleanSoundStruct
{
    soundStruct.sampleNumber = 0;
    soundStruct.frameCount = 0;

    TPCircularBufferCleanup(&soundStruct.audioBufferLeft);
    TPCircularBufferCleanup(&soundStruct.audioBufferRight);
}

- (void)cleanRecordBuffer
{
    if (self.recordBuffer) 
    {
        free(self.recordBuffer);
        self.recordBuffer = NULL;
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
    if ((self.errorCode == AS_NO_ERROR && self.state == AS_INITIALIZED) ||
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
    if (self.state == AS_PLAYING_AND_RECORDING ||
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
        self.state = AS_PLAYING_AND_RECORDING;
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
        self.state = AS_PLAYING_AND_RECORDING;
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
        if (self.state != AS_PLAYING_AND_RECORDING 
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
    // do not support seek
    return NO;
}

- (BOOL)seekToTime:(double)newSeekTime
{
    // do not support seek, nothing need to do
    return NO;
}

#pragma mark QKMultiChannelProtocol

- (void)switchAudioChannel:(SoundChannel)channel
{
    if (mCurrentChannel != channel)
    {
        mCurrentChannel = channel;
    }
}

- (SoundChannel)getCurrentAudioChannel
{
    return mCurrentChannel;
}

- (void)enableVoiceInputBus:(BOOL)enable
{
    if (NULL != mProcessingGraph && NULL != mMixerUnit) 
    {
        OSStatus result = AudioUnitSetParameter (
                                                 mMixerUnit,
                                                 kMultiChannelMixerParam_Enable,
                                                 kAudioUnitScope_Input,
                                                 kMixerBusMic,
                                                 enable,
                                                 0
                                                 );
        
        if (noErr != result)
        {
            QKLog(@"enableVoiceInputBus,error %ld", result);
            return;
        }
    }
}

- (void)changeVoiceInputBusGain:(Float32)gain
{
    if (NULL != mProcessingGraph && NULL != mMixerUnit) 
    {
        if (gain < 0.01)
        {
            gain = 0.01;
        }
        OSStatus result = AudioUnitSetParameter (
                                                 mMixerUnit,
                                                 kMultiChannelMixerParam_Volume,
                                                 kAudioUnitScope_Input,
                                                 kMixerBusMic,
                                                 gain,
                                                 0
                                                 );
        if (noErr != result)
        {
            QKLog(@"enableVoiceInputBus,error %ld", result);
            return;
        }
    }
}

- (Float32)getVoiceInputBusGain
{
    if (NULL != mProcessingGraph && NULL != mMixerUnit) 
    {
        float volPct = 0.0f;
        OSStatus result = AudioUnitGetParameter (
                                                 mMixerUnit,
                                                 kMultiChannelMixerParam_Volume,
                                                 kAudioUnitScope_Input,
                                                 kMixerBusMic,
                                                 &volPct
                                                 );
        if (noErr != result)
        {
            QKLog(@"getVoiceInputBusGain,error %ld", result);
            return 0.0;
        }
        return volPct;
    }
    return 0.0;
}

- (void)changeAudioBusGain:(Float32)gain
{
    if (NULL != mProcessingGraph && NULL != mMixerUnit) 
    {
        if (gain < 0.01)
        {
            gain = 0.01;
        }
        OSStatus result = AudioUnitSetParameter (
                                                 mMixerUnit,
                                                 kMultiChannelMixerParam_Volume,
                                                 kAudioUnitScope_Input,
                                                 kMixerBusAudioFile,
                                                 gain,
                                                 0
                                                 );
        if (noErr != result)
        {
            QKLog(@"enableVoiceInputBus,error %ld", result);
            return;
        }
    }
}

- (Float32)getAudioBusGain
{
    if (NULL != mProcessingGraph && NULL != mMixerUnit) 
    {
        float volPct = 0.0f;
        OSStatus result = AudioUnitGetParameter (
                                                 mMixerUnit,
                                                 kMultiChannelMixerParam_Volume,
                                                 kAudioUnitScope_Input,
                                                 kMixerBusAudioFile,
                                                 &volPct
                                                 );
        if (noErr != result)
        {
            QKLog(@"getAudioBusGain,error %ld", result);
            return 0.0;
        }
        return volPct;
    }
    return 0.0;
}

- (void)changeOputGain:(Float32)gain
{
    if (NULL != mProcessingGraph && NULL != mMixerUnit) 
    {
        if (gain < 0.01)
        {
            gain = 0.01;
        }
        OSStatus result = AudioUnitSetParameter (
                                                 mMixerUnit,
                                                 kMultiChannelMixerParam_Volume,
                                                 kAudioUnitScope_Output,
                                                 0,
                                                 gain,
                                                 0
                                                 );
        if (noErr != result)
        {
            QKLog(@"enableVoiceInputBus,error %ld", result);
            return;
        }
    }
}
@end

// ---------------------------------------------
// recording callback
// ---------------------------------------------
static OSStatus	recordingCallback(
                                  void						*inRefCon, 
                                  AudioUnitRenderActionFlags 	*ioActionFlags, 
                                  const AudioTimeStamp 		*inTimeStamp, 
                                  UInt32 						inBusNumber, 
                                  UInt32 						inNumberFrames, 
                                  AudioBufferList 			*ioData)
{
    QKMultichannelAudioPlayer* player = (QKMultichannelAudioPlayer*)inRefCon;
    
    // get input voice
    OSStatus err = AudioUnitRender(player->mIOUnit, ioActionFlags, inTimeStamp, 1, inNumberFrames, ioData);
    if (noErr != err)
    {
        return noErr;
    }
    
    // send to evaluation system
    UInt32 size = ioData->mBuffers[0].mDataByteSize;
    int sampleCount = size / 2;
    [player.evaluator appendData:ioData->mBuffers[0].mData numSamples:sampleCount];
    
//    // convert the block into float:
//    vDSP_vflt16(ioData->mBuffers[0].mData, 1, player.recordBuffer, 1, inNumberFrames);
//    
//    float desiredGain = 1.06f;
//    vDSP_vsmul(player.recordBuffer, 1, &desiredGain, player.recordBuffer, 1, inNumberFrames);
//    
//    // now convert from float to Sint16
//    vDSP_vfixr16((float *)player.recordBuffer, 1, (SInt16 *)ioData->mBuffers[0].mData, 1, inNumberFrames );
    
    // write to record file
//    err = ExtAudioFileWriteAsync(player->mRecordFileRef, inNumberFrames, ioData);

    [player.audioProcessor produceBytesForSourceBuffer1:ioData->mBuffers[0].mData bufferLength:ioData->mBuffers[0].mDataByteSize];
    
    return err;
}

// ---------------------------------------------
// audioinput callback
// ---------------------------------------------
static OSStatus	audioinputCallback(
                                   void						*inRefCon, 
                                   AudioUnitRenderActionFlags 	*ioActionFlags, 
                                   const AudioTimeStamp 		*inTimeStamp, 
                                   UInt32 						inBusNumber, 
                                   UInt32 						inNumberFrames, 
                                   AudioBufferList 			*ioData)
{
    QKMultichannelAudioPlayer* player = (QKMultichannelAudioPlayer*)inRefCon;
    SoundStructPtr    soundStructPtr              = &(player->soundStruct);
    if (soundStructPtr)
    {
        BOOL isStereo = soundStructPtr->isStereo;
        size_t bytesPerSample = player->mClientStreamFormat.mBytesPerFrame;
        
        void *outSamplesChannelLeft;
        void *outSamplesChannelRight;
        
        outSamplesChannelLeft                 = (void *) ioData->mBuffers[0].mData;
        if (isStereo) outSamplesChannelRight  = (void *) ioData->mBuffers[1].mData;
        
        
        int32_t avaliableBytesLeft = 0;
        int32_t avaliableBytesRight = 0;
        // Declare variables to point to the audio buffers. Their data type must match the buffer data type.
        void *dataInLeft = NULL;
        void *dataInRight = NULL;
        
        dataInLeft                 = TPCircularBufferTail(&soundStructPtr->audioBufferLeft, &avaliableBytesLeft);
        if (isStereo) dataInRight  = TPCircularBufferTail(&soundStructPtr->audioBufferRight,&avaliableBytesRight);
        
        void *dataForSynthesize = NULL;

        // copy data
        if (player->mCurrentChannel == SoundChannelLeft) 
        {
            int32_t samples1 = MIN(avaliableBytesLeft / bytesPerSample, inNumberFrames);
            int32_t size1 = samples1 * bytesPerSample;
            memcpy(outSamplesChannelLeft, dataInLeft, size1);
            if (isStereo)
            {
                memcpy(outSamplesChannelRight, dataInLeft, size1);
            }
            
            // produce buffer for synthesize
            dataForSynthesize = (player->mAccompanimentChannel == SoundChannelLeft) ? dataInLeft : dataInRight;
            [player.audioProcessor produceBytesForSourceBuffer2:dataForSynthesize bufferLength:size1];
            
            // consume
            TPCircularBufferConsume(&soundStructPtr->audioBufferLeft, size1);
            TPCircularBufferConsume(&soundStructPtr->audioBufferRight, size1);
            
            // update sample number
            soundStructPtr->sampleNumber += samples1;
        }
        else
        {
            int32_t samples2 = MIN(avaliableBytesRight / bytesPerSample, inNumberFrames);
            int32_t size2 = samples2 * bytesPerSample;
            memcpy(outSamplesChannelLeft, dataInRight, size2);
            if (isStereo)
            {
                memcpy(outSamplesChannelRight, dataInRight, size2);
            }
            
            // produce buffer for synthesize
            dataForSynthesize = (player->mAccompanimentChannel == SoundChannelLeft) ? dataInLeft : dataInRight;
            [player.audioProcessor produceBytesForSourceBuffer2:dataForSynthesize bufferLength:size2];
            
            // consume
            TPCircularBufferConsume(&soundStructPtr->audioBufferRight, size2);
            TPCircularBufferConsume(&soundStructPtr->audioBufferLeft, size2);
            
            // update sample number
            soundStructPtr->sampleNumber += samples2;
        }
        
        // check if need load more data
        if (kAudioBufferLength - soundStructPtr->audioBufferLeft.fillCount >= kAudioBufferLengthPerReading) 
        {
            [player performSelector:@selector(loadAudioBufferProc) onThread:player->mInternalReadThread withObject:nil waitUntilDone:NO];
        }
        
        if ((soundStructPtr->sampleNumber >= soundStructPtr->frameCount)
            || (avaliableBytesLeft == 0 && player->mReadComplete)) 
        {
            // Buffer is running out or playback is finised
            [player performSelectorOnMainThread:@selector(stopOnPlayBackDidFinish) withObject:nil waitUntilDone:NO];
        }
    }
    return noErr;
}
