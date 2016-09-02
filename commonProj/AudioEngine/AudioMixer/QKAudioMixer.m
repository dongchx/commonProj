//
//  QKAudioMixer.m
//  QQKala
//
//  Created by frost on 12-6-6.
//  Copyright (c) 2012年 Tencent. All rights reserved.
//

#import "QKAudioMixer.h"
#import "ASBDUtility.h"
#import "PublicConfig.h"
#import "FileUtility.h"

#define NEW_BUFFER_SIZE 327680        //320k
NSString *const AudioMixerErrorDomain = @"com.tencent.AudioMixerErrorDomain";

// ---------------------------------------------
// QKAudioMixer Private declaration
// ---------------------------------------------
@interface QKAudioMixer()
@property (nonatomic, readwrite, assign) SoundChannel                channel1;
@property (nonatomic, readwrite, retain) NSString                    *sourceAudioFilePath1;
@property (nonatomic, readwrite, retain) NSString                    *sourceAudioFilePath2;
@property (nonatomic, readwrite, retain) NSString                    *mixAudioFilePath;


- (void)processingThread;
- (void)failedWithError:(NSInteger)errorCode;

- (void)reportErrorAndCleanup:(NSError*)error;
- (void)reportCompletion;
- (void)reportProgress:(NSNumber*)progress;
- (void)cancelProcessingThread;
@end

// ---------------------------------------------
// QKAudioMixer implementation
// ---------------------------------------------
@implementation QKAudioMixer
@synthesize delegate = mDelegate;
@synthesize channel1 = mChannel1;
@synthesize sourceAudioFilePath1 = mSourceAudioFilePath1;
@synthesize sourceAudioFilePath2 = mSourceAudioFilePath2;
@synthesize mixAudioFilePath = mMixAudioFilePath;

#pragma mark lifecycle

- (id)init
{
    if ( !(self = [super init]) ) return nil;
    
    mCondition = [[NSCondition alloc] init];
    
    return self;
}

- (void)dealloc 
{
    [self cancelProcessingThread];
    [mCondition release];
    self.sourceAudioFilePath1 = nil;
    self.sourceAudioFilePath2 = nil;
    self.mixAudioFilePath = nil;
    [super dealloc];
}

#pragma mark public implementation
// deprecated
- (NSInteger)mix:(NSString*)file1 file2:(NSString*)file2 mixfile:(NSString*)mixfile mixAudioSampleRate:(UInt32)sampleRate
{
    OSStatus status, close_status;
    
	NSURL *url1 = [NSURL fileURLWithPath:file1];
	NSURL *url2 = [NSURL fileURLWithPath:file2];
	NSURL *mixURL = [NSURL fileURLWithPath:mixfile];
    
	AudioFileID inAudioFile1 = NULL;
	AudioFileID inAudioFile2 = NULL;
	AudioFileID mixAudioFile = NULL;
	
	char *buffer1 = NULL;
	char *buffer2 = NULL;
	char *mixbuffer = NULL;	
    
    //open source files
	status = AudioFileOpenURL((CFURLRef)url1, kAudioFileReadPermission, 0, &inAudioFile1);
    if (status)
	{
		goto reterr;
	}	
    
	status = AudioFileOpenURL((CFURLRef)url2, kAudioFileReadPermission, 0, &inAudioFile2);
    if (status)
	{
		goto reterr;
	}
    
	// Verify that file contains pcm data at 44 kHz
    AudioStreamBasicDescription inputDataFormat;
	UInt32 propSize = sizeof(inputDataFormat);
    
	bzero(&inputDataFormat, sizeof(inputDataFormat));
    status = AudioFileGetProperty(inAudioFile1, kAudioFilePropertyDataFormat,
								  &propSize, &inputDataFormat);
    
    if (status)
	{
		goto reterr;
	}

	// Do the same for file2
    AudioStreamBasicDescription inputDataFormat2;
	propSize = sizeof(inputDataFormat2);
    
	bzero(&inputDataFormat2, sizeof(inputDataFormat2));
    status = AudioFileGetProperty(inAudioFile2, kAudioFilePropertyDataFormat,
								  &propSize, &inputDataFormat2);
    
    if (status)
	{
		goto reterr;
	}

    // verify that file1 and file2 has same data format
    if ((inputDataFormat.mFormatID == inputDataFormat2.mFormatID) &&
        (inputDataFormat.mSampleRate == inputDataFormat2.mSampleRate) &&
        (inputDataFormat.mChannelsPerFrame == inputDataFormat2.mChannelsPerFrame) &&
        (inputDataFormat.mBitsPerChannel == inputDataFormat2.mBitsPerChannel) &&
        (inputDataFormat.mFormatFlags == inputDataFormat2.mFormatFlags)
        ) 
    {
        // no-op when file1 and file2 has same data format
    } 
    else 
    {
        status = kAudioFileUnsupportedFileTypeError;
        goto reterr;
    }
    
    // set data format for output (mix) file
    [ASBDUtility setASBD:&inputDataFormat formatID:kAudioFormatLinearPCM numChannels:2 sampleRate:sampleRate];
    
	// Both input files validated, open output (mix) file
	status = AudioFileCreateWithURL((CFURLRef)mixURL, kAudioFileCAFType, &inputDataFormat,
									kAudioFileFlags_EraseFile, &mixAudioFile);
    if (status)
	{
		goto reterr;
	}
    
	// Read buffer of data from each file
    
	buffer1 = malloc(NEW_BUFFER_SIZE);
	assert(buffer1);
	buffer2 = malloc(NEW_BUFFER_SIZE);
	assert(buffer2);
	mixbuffer = malloc(NEW_BUFFER_SIZE);
	assert(mixbuffer);
    
	SInt64 packetNum1 = 0;
	SInt64 packetNum2 = 0;
	SInt64 mixpacketNum = 0;
    
    // Get Packets
    SInt64 packetsCount1 = 0;
    UInt32 size = sizeof(SInt64);
    AudioFileGetProperty(inAudioFile1, kAudioFilePropertyAudioDataPacketCount, &size, &packetsCount1);
    SInt64 packetsCount2 = 0;
    AudioFileGetProperty(inAudioFile2, kAudioFilePropertyAudioDataPacketCount, &size, &packetsCount2);
    
    SInt64 max_mix_packetsCount = MIN(packetsCount1, packetsCount2);
    SInt64 left_mix_packetsCount = max_mix_packetsCount;
    
	UInt32 numPackets1;
	UInt32 numPackets2;
    
	while (TRUE)
    {
		// Read a chunks
		UInt32 bytesRead;
        
        // the num of packets to read
		numPackets1 = NEW_BUFFER_SIZE / inputDataFormat.mBytesPerPacket;
        numPackets2 = numPackets1 = MIN(numPackets1, left_mix_packetsCount);
        
        // read a chunk of input1
		status = AudioFileReadPackets(inAudioFile1,
									  false,
									  &bytesRead,
									  NULL,
									  packetNum1,
									  &numPackets1,
									  buffer1);
        
		if (status) 
        {
			goto reterr;
		}
        
		// if buffer was not filled, fill with zeros
//		if (bytesRead < BUFFER_SIZE)
//        {
//			bzero(buffer1 + bytesRead, (BUFFER_SIZE - bytesRead));
//		}
		packetNum1 += numPackets1;
        
        // read a chunk of input2
		status = AudioFileReadPackets(inAudioFile2,
									  false,
									  &bytesRead,
									  NULL,
									  packetNum2,
									  &numPackets2,
									  buffer2);
        
		if (status) 
        {
			goto reterr;
		}
        
		// if buffer was not filled, fill with zeros
//		if (bytesRead < BUFFER_SIZE) 
//        {
//			bzero(buffer2 + bytesRead, (BUFFER_SIZE - bytesRead));
//		}		
		packetNum2 += numPackets2;
        
        // calulate left max packets count
        int minNumPackets = MIN(numPackets1, numPackets2);
        left_mix_packetsCount -= minNumPackets;
        
        // if no left packets, conversion is finished
        if (left_mix_packetsCount == 0) 
        {
            break;
        }

		// Write pcm data to output file
		int numSamples = (minNumPackets * inputDataFormat.mBytesPerPacket) / sizeof(int16_t);
        

        [QKAudioMixer mixBuffers:(const int16_t *)buffer1 buffer2:(const int16_t *)buffer2 mixbuffer:(int16_t *) mixbuffer mixbufferNumSamples:numSamples];
        

        
		// write the mixed packets to the output file
        
		UInt32 packetsWritten = minNumPackets;
        
		status = AudioFileWritePackets(mixAudioFile,
                                       FALSE,
                                       (minNumPackets * inputDataFormat.mBytesPerPacket),
                                       NULL,
                                       mixpacketNum,
                                       &packetsWritten,
                                       mixbuffer);
        
		if (status) 
        {
			goto reterr;
		}
		
		if (packetsWritten != minNumPackets) 
        {
			status = kAudioFileInvalidPacketOffsetError;
			goto reterr;
		}
        
		mixpacketNum += packetsWritten;
	}	
    
reterr:
	if (inAudioFile1 != NULL) 
    {
		close_status = AudioFileClose(inAudioFile1);
		assert(close_status == 0);
	}
	if (inAudioFile2 != NULL)
    {
		close_status = AudioFileClose(inAudioFile2);
		assert(close_status == 0);
	}
	if (mixAudioFile != NULL) 
    {
		close_status = AudioFileClose(mixAudioFile);
		assert(close_status == 0);
	}
	if (buffer1 != NULL)
    {
		free(buffer1);
	}
	if (buffer2 != NULL)
    {
		free(buffer2);
	}
	if (mixbuffer != NULL)
    {
		free(mixbuffer);
	}
    
	return status;
}

- (BOOL)startThreadToMix:(NSString*)file1 soundChannel:(SoundChannel)channel file2:(NSString*)file2 mixfile:(NSString*)mixfile mixAudioFileType:(AudioFileTypeID)audioFileTypeID
  mixAudioFormat:(UInt32)formatID numChannels:(NSInteger)numChannels
{
    if (!mProcessing && nil != file1 
        && nil != file2 && nil != mixfile) 
    {
        self.sourceAudioFilePath1 = file1;
        self.sourceAudioFilePath2 = file2;
        self.mixAudioFilePath = mixfile;
        self.channel1 = channel;
        
        mFormatID = formatID;
        mFileTypeID = audioFileTypeID;
        mChannels = numChannels;
        mCancelled = NO;
        mProcessing = YES;
        
        if (nil != mInternalProcessingThread)
        {
            [mInternalProcessingThread release];
        }
        mInternalProcessingThread =[[NSThread alloc] initWithTarget:self 
                                                     selector:@selector(processingThread) 
                                                       object:nil];
        [mInternalProcessingThread start];

        return YES;
    }
    return NO;
}

- (BOOL)isWorking
{
    return mProcessing;
}

- (void)cancel
{
    [self cancelProcessingThread];
}

- (NSInteger)mix:(NSString*)file1 soundChannel:(SoundChannel)channel file2:(NSString*)file2 mixfile:(NSString*)mixfile mixAudioFileType:(AudioFileTypeID)audioFileTypeID
  mixAudioFormat:(AudioStreamBasicDescription)asbd
{
    OSStatus status, close_status;
    
	NSURL *url1 = [NSURL fileURLWithPath:file1];
	NSURL *url2 = [NSURL fileURLWithPath:file2];
	NSURL *mixURL = [NSURL fileURLWithPath:mixfile];
    
    ExtAudioFileRef inAudioFile1 = NULL;
    ExtAudioFileRef inAudioFile2 = NULL;
    ExtAudioFileRef mixAudioFile = NULL;
    
    AudioStreamBasicDescription     SInt16StereoFormat;
    AudioStreamBasicDescription     SInt16MonoFormat;
    
    [ASBDUtility setCanonical:&SInt16StereoFormat numChannels:2 sampleRate:AudioSampleRate44K isInterleaved:NO];
    [ASBDUtility setCanonical:&SInt16MonoFormat numChannels:1 sampleRate:AudioSampleRate44K isInterleaved:NO];
	
	char *buffer1left   = NULL;
    char *buffer1right  = NULL;
	char *buffer2left   = NULL;
    char *buffer2right  = NULL;
	char *mixbuffer     = NULL;	
    
    AudioBufferList *bufferList1 = NULL;
    AudioBufferList *bufferList2 = NULL;
    AudioBufferList *mixbufferList = NULL;
    
    //............................................................................
    // open source files
    status = ExtAudioFileOpenURL((CFURLRef)url1, &inAudioFile1);
    if (status)
	{
		goto reterr;
	}	
    
    status = ExtAudioFileOpenURL((CFURLRef)url2, &inAudioFile2);
    if (status)
	{
		goto reterr;
	}
    
    //............................................................................
    // get data format of input files
    
    // get data format of file 1
    AudioStreamBasicDescription inputDataFormat1;
	UInt32 propSize = sizeof(inputDataFormat1);
	bzero(&inputDataFormat1, sizeof(inputDataFormat1));
    status = ExtAudioFileGetProperty(inAudioFile1, kExtAudioFileProperty_FileDataFormat, &propSize, &inputDataFormat1);
    if (status)
	{
		goto reterr;
	}
    
    // get data format of file 2
    AudioStreamBasicDescription inputDataFormat2;
	propSize = sizeof(inputDataFormat2);
	bzero(&inputDataFormat2, sizeof(inputDataFormat2));
    status = ExtAudioFileGetProperty(inAudioFile2, kExtAudioFileProperty_FileDataFormat, &propSize, &inputDataFormat2);

    if (status)
	{
		goto reterr;
	}
	

    //............................................................................
    // Assign the appropriate stream data format
    AudioStreamBasicDescription clientDataFormat1;
    if (2 == inputDataFormat1.mChannelsPerFrame) 
    {
        clientDataFormat1 = SInt16StereoFormat;
    }
    else if (1 == inputDataFormat1.mChannelsPerFrame) 
    {
        clientDataFormat1 = SInt16MonoFormat;
    } 
    else 
    {
        status = kAudioFileUnsupportedFileTypeError;
        goto reterr;
    }
    
    status =    ExtAudioFileSetProperty (
                                         inAudioFile1,
                                         kExtAudioFileProperty_ClientDataFormat,
                                         sizeof (clientDataFormat1),
                                         &clientDataFormat1
                                         );
    
    if (status)
	{
		goto reterr;
	}
    
    // do the same for input file 2
    AudioStreamBasicDescription clientDataFormat2;
    if (2 == inputDataFormat2.mChannelsPerFrame) 
    {
        clientDataFormat2 = SInt16StereoFormat;
    }
    else if (1 == inputDataFormat2.mChannelsPerFrame) 
    {
        clientDataFormat2 = SInt16MonoFormat;
    } 
    else 
    {
        status = kAudioFileUnsupportedFileTypeError;
        goto reterr;
    }
    
    status =    ExtAudioFileSetProperty (
                                         inAudioFile2,
                                         kExtAudioFileProperty_ClientDataFormat,
                                         sizeof (clientDataFormat2),
                                         &clientDataFormat2
                                         );
    
    if (status)
	{
		goto reterr;
	}
    
    // verify that file1 and file2 has same data format
    if ((clientDataFormat1.mFormatID == clientDataFormat2.mFormatID) &&
        (clientDataFormat1.mSampleRate == clientDataFormat2.mSampleRate) &&
        (clientDataFormat1.mBitsPerChannel == clientDataFormat2.mBitsPerChannel) &&
        (clientDataFormat1.mFormatFlags == clientDataFormat2.mFormatFlags)
        ) 
    {
        // no-op when file1 and file2 has same data format
    } 
    else 
    {
        status = kAudioFileUnsupportedFileTypeError;
        goto reterr;
    }

    //............................................................................
	// Both input files validated, open output (mix) file
    status = ExtAudioFileCreateWithURL((CFURLRef)mixURL, audioFileTypeID, &asbd, NULL, kAudioFileFlags_EraseFile, &mixAudioFile);
    if (status)
	{
		goto reterr;
	}
    
    status = ExtAudioFileSetProperty(mixAudioFile, kExtAudioFileProperty_ClientDataFormat, sizeof(SInt16MonoFormat), &SInt16MonoFormat);
    if (status)
	{
		goto reterr;
	}
    
    //............................................................................
	// allocate buffer list
    bufferList1 = (AudioBufferList *) malloc (
                                             sizeof (AudioBufferList) + sizeof (AudioBuffer) * (clientDataFormat1.mChannelsPerFrame - 1)
                                             );
    if (NULL == bufferList1) 
    {
        QKLog (@"*** malloc failure for allocating bufferList1 memory"); 
        status = -1;
        goto reterr;
    }
    
    bufferList2 = (AudioBufferList *) malloc (
                                              sizeof (AudioBufferList) + sizeof (AudioBuffer) * (clientDataFormat2.mChannelsPerFrame - 1)
                                              );
    if (NULL == bufferList2) 
    {
        QKLog (@"*** malloc failure for allocating bufferList2 memory"); 
        status = -1;
        goto reterr;
    }
    
    mixbufferList = (AudioBufferList *) malloc (
                                                sizeof (AudioBufferList) + sizeof (AudioBuffer) );
    if (NULL == mixbufferList) 
    {
        QKLog (@"*** malloc failure for allocating mixbufferList memory"); 
        status = -1;
        goto reterr;
    }
    
    //............................................................................
	// allocate buffer
	buffer1left = malloc(NEW_BUFFER_SIZE);
    if (NULL == buffer1left)
    {
        QKLog (@"*** malloc failure for allocating buffer1left memory");
        status = -1;
        goto reterr;
    }
    
	buffer2left = malloc(NEW_BUFFER_SIZE);
    if (NULL == buffer2left)
    {
        QKLog (@"*** malloc failure for allocating buffer2left memory");
        status = -1;
        goto reterr;
    }
    
	mixbuffer = malloc(NEW_BUFFER_SIZE);
    if (NULL == mixbuffer)
    {
        QKLog (@"*** malloc failure for allocating mixbuffer memory");
        status = -1;
        goto reterr;
    }
    
    //............................................................................
	// config buffer list
    AudioBuffer emptyBuffer = {0};
    size_t arrayIndex;
    
    bufferList1->mNumberBuffers = clientDataFormat1.mChannelsPerFrame;
    for (arrayIndex = 0; arrayIndex < clientDataFormat1.mChannelsPerFrame; ++arrayIndex)
    {
        bufferList1->mBuffers[arrayIndex] = emptyBuffer;
    }
    bufferList1->mBuffers[0].mNumberChannels  = 1;
    bufferList1->mBuffers[0].mDataByteSize    = NEW_BUFFER_SIZE;
    bufferList1->mBuffers[0].mData            = buffer1left;
    if (2 == clientDataFormat1.mChannelsPerFrame)
    {
        buffer1right = malloc(NEW_BUFFER_SIZE);
        if (NULL == buffer1right) 
        {
            QKLog (@"*** malloc failure for allocating buffer1right memory"); 
            status = -1;
            goto reterr;
        }
        
        bufferList1->mBuffers[1].mNumberChannels  = 1;
        bufferList1->mBuffers[1].mDataByteSize    = NEW_BUFFER_SIZE;
        bufferList1->mBuffers[1].mData            = buffer1right;
    }
    
    bufferList2->mNumberBuffers = clientDataFormat2.mChannelsPerFrame;
    for (arrayIndex = 0; arrayIndex < clientDataFormat2.mChannelsPerFrame; ++arrayIndex)
    {
        bufferList2->mBuffers[arrayIndex] = emptyBuffer;
    }
    bufferList2->mBuffers[0].mNumberChannels  = 1;
    bufferList2->mBuffers[0].mDataByteSize    = NEW_BUFFER_SIZE;
    bufferList2->mBuffers[0].mData            = buffer2left;
    if (2 == clientDataFormat2.mChannelsPerFrame)
    {
        buffer2right = malloc(NEW_BUFFER_SIZE);
        if (NULL == buffer2right) 
        {
            QKLog (@"*** malloc failure for allocating buffer2right memory"); 
            status = -1;
            goto reterr;
        }
        
        bufferList2->mBuffers[1].mNumberChannels  = 1;
        bufferList2->mBuffers[1].mDataByteSize    = NEW_BUFFER_SIZE;
        bufferList2->mBuffers[1].mData            = buffer2right;
    }
    
    mixbufferList->mNumberBuffers = 1;
    mixbufferList->mBuffers[0] = emptyBuffer;
    mixbufferList->mBuffers[0].mNumberChannels  = 1;
    mixbufferList->mBuffers[0].mDataByteSize    = NEW_BUFFER_SIZE;
    mixbufferList->mBuffers[0].mData            = mixbuffer;

    //............................................................................
	// get frame counts
    UInt64 frameCount1 = 0;
    UInt64 frameCount2 = 0;
    UInt32 size = sizeof(UInt64);

    status =    ExtAudioFileGetProperty (
                                         inAudioFile1,
                                         kExtAudioFileProperty_FileLengthFrames,
                                         &size,
                                         &frameCount1
                                         );
    if (status)
    {
        goto reterr;
    }
    
    status =    ExtAudioFileGetProperty (
                                         inAudioFile2,
                                         kExtAudioFileProperty_FileLengthFrames,
                                         &size,
                                         &frameCount2
                                         );
    if (status)
    {
        goto reterr;
    }

    //............................................................................
	// calculate frames need to mix
    UInt64 frameCountNeedToMix = MIN(frameCount1, frameCount2);
    UInt64 leftFramesToMix = frameCountNeedToMix;
    
    UInt32 frameNum1 = 0;
	UInt32 frameNum2 = 0;
    UInt64 frameOffset1 = 0;
    UInt64 frameOffset2 = 0;
    
	while (TRUE)
    {
        bufferList1->mBuffers[0].mDataByteSize    = NEW_BUFFER_SIZE;
        if (2 == clientDataFormat1.mChannelsPerFrame)
        {
            bufferList1->mBuffers[1].mDataByteSize    = NEW_BUFFER_SIZE;
        }
        
        bufferList2->mBuffers[0].mDataByteSize    = NEW_BUFFER_SIZE;
        if (2 == clientDataFormat2.mChannelsPerFrame)
        {
            bufferList2->mBuffers[1].mDataByteSize    = NEW_BUFFER_SIZE;
        }
        
        // the num of frame to read
		frameNum1 = NEW_BUFFER_SIZE / clientDataFormat1.mBytesPerFrame;
        frameNum2 = frameNum1 = MIN(frameNum1, leftFramesToMix);
        
        // read a chunk from input file 1
        status = ExtAudioFileRead(inAudioFile1, &frameNum1, bufferList1);
        if (status) 
        {
            goto reterr;
        }
		frameOffset1 += frameNum1;
        
        // read a chunk from input file 2
        status = ExtAudioFileRead(inAudioFile2, &frameNum2, bufferList2);
        if (status) 
        {
            goto reterr;
        }
		frameOffset2 += frameNum2;

        
        // calulate how many frames used to mix
        int numFrameToMix = MIN(frameNum1, frameNum2);
        
        // if no frame to mix, read finish
        if (numFrameToMix == 0) 
        {
            break;
        }
        
		// Write pcm data to output file
		int numSamples = (numFrameToMix * SInt16MonoFormat.mBytesPerFrame) / sizeof(int16_t);
        
        // do mix
        if (SoundChannelRight == channel && NULL != buffer1right)
        {
            [QKAudioMixer mixBuffers:(const int16_t *)buffer1right buffer2:(const int16_t *)buffer2left mixbuffer:(int16_t *) mixbuffer mixbufferNumSamples:numSamples];
        }
        else
        {
            [QKAudioMixer mixBuffers:(const int16_t *)buffer1left buffer2:(const int16_t *)buffer2left mixbuffer:(int16_t *) mixbuffer mixbufferNumSamples:numSamples];
        }

        // write the mixed frames to tue output file
        mixbufferList->mBuffers[0].mDataByteSize    = numFrameToMix * SInt16MonoFormat.mBytesPerFrame;
        
        status = ExtAudioFileWrite(mixAudioFile, numFrameToMix, mixbufferList);
        if ( status == kExtAudioFileError_CodecUnavailableInputConsumed)
        {
            /*
             Returned when ExtAudioFileWrite was interrupted. You must stop calling
             ExtAudioFileWrite. If the underlying audio converter can resume after an
             interruption (see kAudioConverterPropertyCanResumeFromInterruption), you must
             wait for an EndInterruption notification from AudioSession, and call AudioSessionSetActive(true)
             before resuming. In this situation, the buffer you provided to ExtAudioFileWrite was successfully
             consumed and you may proceed to the next buffer
             */
        } 
        else if ( status == kExtAudioFileError_CodecUnavailableInputNotConsumed )
        {
            /*
             Returned when ExtAudioFileWrite was interrupted. You must stop calling
             ExtAudioFileWrite. If the underlying audio converter can resume after an
             interruption (see kAudioConverterPropertyCanResumeFromInterruption), you must
             wait for an EndInterruption notification from AudioSession, and call AudioSessionSetActive(true)
             before resuming. In this situation, the buffer you provided to ExtAudioFileWrite was not
             successfully consumed and you must try to write it again
             */
            
            // seek back to last offset before last read so we can try again after the interruption
            frameOffset1 -= numFrameToMix;
            frameOffset2 -= numFrameToMix;
            ExtAudioFileSeek(inAudioFile1, frameOffset1);
            ExtAudioFileSeek(inAudioFile2, frameOffset2);
        } 
        else if ( noErr != status )
        {
            goto reterr;
        }
        
        // if no frames left to mix, mixing is finish
        leftFramesToMix -= numFrameToMix;
        if (leftFramesToMix == 0)
        {
            break;
        }
	}	
    
reterr:
    // close file if necessary
	if (inAudioFile1 != NULL) 
    {
		close_status = ExtAudioFileDispose(inAudioFile1);
		assert(close_status == 0);
	}
	if (inAudioFile2 != NULL)
    {
		close_status = ExtAudioFileDispose(inAudioFile2);
		assert(close_status == 0);
	}
	if (mixAudioFile != NULL) 
    {
		close_status = ExtAudioFileDispose(mixAudioFile);
		assert(close_status == 0);
	}
    
    // free memory for buffers
	if (buffer1left != NULL)
    {
		free(buffer1left);
	}
    if (buffer1right != NULL)
    {
		free(buffer1right);
	}
	if (buffer2left != NULL)
    {
		free(buffer2left);
	}
    if (buffer2right != NULL)
    {
		free(buffer2right);
	}
	if (mixbuffer != NULL)
    {
		free(mixbuffer);
	}
    
    // free buffer for bufferlist
    if (NULL != bufferList1) 
    {
        free(bufferList1);
    }
    
    if (NULL != bufferList2) 
    {
        free(bufferList2);
    }
    
    if (NULL != mixbufferList) 
    {
        free(mixbufferList);
    }
    
	return status;
}
#pragma mark QKAudioMixer Private
#define mixSamples(a,b) (\
(a) < 0 && (b) < 0 ? \
    ((int)(a) + (int)(b)) - (((int)(a) * (int)(b)) / INT16_MIN) : \
( (a) > 0 && (b) > 0 ? \
    ((int)(a) + (int)(b)) - (((int)(a) * (int)(b)) / INT16_MAX) : \
    ((a) + (b))))
//inline SInt16 mixSamples(SInt16 a, SInt16 b)
//{
//    return 
//            a < 0 && b < 0 ?
//                ((int)a + (int)b) - (((int)a * (int)b) / INT16_MIN) :
//            ( a > 0 && b > 0 ?
//                ((int)a + (int)b) - (((int)a * (int)b) / INT16_MAX)
//             :
//                (a + b));
//}

+ (void)mixBuffers:(const int16_t*)buffer1 buffer2:(const int16_t*)buffer2 mixbuffer:(int16_t *)mixbuffer mixbufferNumSamples:(int)mixbufferNumSamples
{
    for (int i = 0 ; i < mixbufferNumSamples; i++) 
    {
#if 0
		int32_t mixed = (int32_t)buffer1[i] + (int32_t)buffer2[i];
        
        //钳位法
		if (mixed > INT16_MAX) 
        {
            mixbuffer[i] = INT16_MAX;
		} 
        else if (mixed < INT16_MIN)
        {
            mixbuffer[i] = INT16_MIN;
        }
        else 
        {
			mixbuffer[i] = (int16_t) mixed;
		}
#else
        mixbuffer[i] = mixSamples(buffer1[i], buffer2[i]);
#endif
	}
}

- (void)processingThread
{
    NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
    
    // set thread priority
    [[NSThread currentThread] setThreadPriority:1.1];
    
    OSStatus status, close_status;
    
    ExtAudioFileRef inAudioFile1 = NULL;
    ExtAudioFileRef inAudioFile2 = NULL;
    ExtAudioFileRef mixAudioFile = NULL;
    
    AudioStreamBasicDescription     inputDataFormat1;
    AudioStreamBasicDescription     inputDataFormat2;
    AudioStreamBasicDescription     destinationFormat;
    AudioStreamBasicDescription     SInt16StereoFormat;
    AudioStreamBasicDescription     SInt16MonoFormat;
    
    UInt32 propSize = sizeof(inputDataFormat1);
    
    [ASBDUtility setCanonical:&SInt16StereoFormat numChannels:2 sampleRate:AudioSampleRate44K isInterleaved:NO];
    [ASBDUtility setCanonical:&SInt16MonoFormat numChannels:1 sampleRate:AudioSampleRate44K isInterleaved:NO];
	
    
	char *buffer1left   = NULL;
    char *buffer1right  = NULL;
	char *buffer2left   = NULL;
    char *buffer2right  = NULL;
	char *mixbuffer     = NULL;	
    
    AudioBufferList *bufferList1 = NULL;
    AudioBufferList *bufferList2 = NULL;
    AudioBufferList *mixbufferList = NULL;
    
    //............................................................................
    // open source files & get data format of source file
    if (nil != self.sourceAudioFilePath1 && nil != self.sourceAudioFilePath2) 
    {
        //
        // open source file 1 & get data format
        status = ExtAudioFileOpenURL((CFURLRef)[NSURL fileURLWithPath:self.sourceAudioFilePath1], &inAudioFile1);
        if (status)
        {
            [self failedWithError:QKAudioMixerSourceFileError];
            goto errLabel;
        }
        
        
        
        bzero(&inputDataFormat1, propSize);
        status = ExtAudioFileGetProperty(inAudioFile1, kExtAudioFileProperty_FileDataFormat, &propSize, &inputDataFormat1);
        
        if (status)
        {
            [self failedWithError:QKAudioMixerFormatError];
            goto errLabel;
        }
        
        //
        // open source file 2 & get data format
        status = ExtAudioFileOpenURL((CFURLRef)[NSURL fileURLWithPath:self.sourceAudioFilePath2], &inAudioFile2);
        if (status)
        {
            [self failedWithError:QKAudioMixerSourceFileError];
            goto errLabel;
        }
        
        bzero(&inputDataFormat2, propSize);
        status = ExtAudioFileGetProperty(inAudioFile2, kExtAudioFileProperty_FileDataFormat, &propSize, &inputDataFormat2);
        
        if (status)
        {
            [self failedWithError:QKAudioMixerFormatError];
            goto errLabel;
        }
    }
    else
    {
        [self failedWithError:QKAudioMixerSourceFileNotExistError];
        goto errLabel;
    }
    
    //............................................................................
    // Assign the appropriate stream data format
    AudioStreamBasicDescription clientDataFormat1;
    if (2 == inputDataFormat1.mChannelsPerFrame) 
    {
        clientDataFormat1 = SInt16StereoFormat;
    }
    else if (1 == inputDataFormat1.mChannelsPerFrame) 
    {
        clientDataFormat1 = SInt16MonoFormat;
    } 
    else 
    {
        [self failedWithError:QKAudioMixerUnsupportedFileTypeError];
        goto errLabel;
    }
    
    status =    ExtAudioFileSetProperty (
                                         inAudioFile1,
                                         kExtAudioFileProperty_ClientDataFormat,
                                         sizeof (clientDataFormat1),
                                         &clientDataFormat1
                                         );
    
    if (status)
	{
        [self failedWithError:QKAudioMixerFormatError];
		goto errLabel;
	}
    
    // do the same for input file 2
    AudioStreamBasicDescription clientDataFormat2;
    if (2 == inputDataFormat2.mChannelsPerFrame) 
    {
        clientDataFormat2 = SInt16StereoFormat;
    }
    else if (1 == inputDataFormat2.mChannelsPerFrame) 
    {
        clientDataFormat2 = SInt16MonoFormat;
    } 
    else 
    {
        [self failedWithError:QKAudioMixerUnsupportedFileTypeError];
        goto errLabel;
    }
    
    status =    ExtAudioFileSetProperty (
                                         inAudioFile2,
                                         kExtAudioFileProperty_ClientDataFormat,
                                         sizeof (clientDataFormat2),
                                         &clientDataFormat2
                                         );
    
    if (status)
	{
        [self failedWithError:QKAudioMixerFormatError];
		goto errLabel;
	}
    
    // verify that file1 and file2 has same data format
    if ((clientDataFormat1.mFormatID == clientDataFormat2.mFormatID) &&
        (clientDataFormat1.mSampleRate == clientDataFormat2.mSampleRate) &&
        (clientDataFormat1.mBitsPerChannel == clientDataFormat2.mBitsPerChannel) &&
        (clientDataFormat1.mFormatFlags == clientDataFormat2.mFormatFlags)
        ) 
    {
        // no-op when file1 and file2 has same data format
    } 
    else 
    {
        [self failedWithError:QKAudioMixerFormatError];
        goto errLabel;
    }
    
    //............................................................................
    // config data format
    if (mFormatID == kAudioFormatAppleIMA4) 
    {
        [ASBDUtility setASBD:&destinationFormat formatID:kAudioFormatAppleIMA4 numChannels:1 sampleRate:AudioSampleRate44K];
	} 
    else if (mFormatID == kAudioFormatMPEG4AAC) 
    {
        [ASBDUtility setASBD:&destinationFormat formatID:kAudioFormatMPEG4AAC numChannels:1 sampleRate:AudioSampleRate44K];
	} 
    else if (mFormatID == kAudioFormatAppleLossless) 
    {
        [ASBDUtility setASBD:&destinationFormat formatID:kAudioFormatAppleLossless numChannels:1 sampleRate:AudioSampleRate44K];
	} 
    else if (mFormatID == kAudioFormatLinearPCM) 
    {
        [ASBDUtility setASBD:&destinationFormat formatID:kAudioFormatLinearPCM numChannels:1 sampleRate:AudioSampleRate44K];	
	} 
    else 
    {
        [self failedWithError:QKAudioMixerInvalidDestinationFormat];
        goto errLabel;
	}
    
    // check destination format is valid
    status = AudioFormatGetProperty(kAudioFormatProperty_FormatInfo, 0, NULL, &propSize, &destinationFormat);
    
    if (status)
    {
        [self failedWithError:QKAudioMixerInvalidDestinationFormat];
        goto errLabel;
    }
    
    //............................................................................
	// Both input files validated, open output (mix) file
    status = ExtAudioFileCreateWithURL((CFURLRef)[NSURL fileURLWithPath:self.mixAudioFilePath], mFileTypeID, &destinationFormat, NULL, kAudioFileFlags_EraseFile, &mixAudioFile);
    if (status)
	{
        [self failedWithError:QKAudioMixerDestinationFileCreateError];
		goto errLabel;
	}
    
    // excluding from backup if necessary
    [FileUtility addSkipBackupAttributeToItemAtURL:[NSURL fileURLWithPath:self.mixAudioFilePath]];
    
    status = ExtAudioFileSetProperty(mixAudioFile, kExtAudioFileProperty_ClientDataFormat, sizeof(SInt16MonoFormat), &SInt16MonoFormat);
    if (status)
	{
        [self failedWithError:QKAudioMixerFormatError];
		goto errLabel;
	}
    
    //............................................................................
	// allocate buffer list
    bufferList1 = (AudioBufferList *) malloc (
                                              sizeof (AudioBufferList) + sizeof (AudioBuffer) * (clientDataFormat1.mChannelsPerFrame - 1)
                                              );
    if (NULL == bufferList1) 
    {
        QKLog (@"*** malloc failure for allocating bufferList1 memory"); 
        [self failedWithError:QKAudioMixerOutofMemoryError];
        goto errLabel;
    }
    
    bufferList2 = (AudioBufferList *) malloc (
                                              sizeof (AudioBufferList) + sizeof (AudioBuffer) * (clientDataFormat2.mChannelsPerFrame - 1)
                                              );
    if (NULL == bufferList2) 
    {
        QKLog (@"*** malloc failure for allocating bufferList2 memory"); 
        [self failedWithError:QKAudioMixerOutofMemoryError];
        goto errLabel;
    }
    
    mixbufferList = (AudioBufferList *) malloc (
                                                sizeof (AudioBufferList) + sizeof (AudioBuffer) );
    if (NULL == mixbufferList) 
    {
        QKLog (@"*** malloc failure for allocating mixbufferList memory"); 
        [self failedWithError:QKAudioMixerOutofMemoryError];
        goto errLabel;
    }
    
    //............................................................................
	// allocate buffer
	buffer1left = malloc(NEW_BUFFER_SIZE);
    if (NULL == buffer1left)
    {
        QKLog (@"*** malloc failure for allocating buffer1left memory");
        [self failedWithError:QKAudioMixerOutofMemoryError];
        goto errLabel;
    }
    
	buffer2left = malloc(NEW_BUFFER_SIZE);
    if (NULL == buffer2left)
    {
        QKLog (@"*** malloc failure for allocating buffer2left memory");
        [self failedWithError:QKAudioMixerOutofMemoryError];
        goto errLabel;
    }
    
	mixbuffer = malloc(NEW_BUFFER_SIZE);
    if (NULL == mixbuffer)
    {
        QKLog (@"*** malloc failure for allocating mixbuffer memory");
        [self failedWithError:QKAudioMixerOutofMemoryError];
        goto errLabel;
    }
    
    //............................................................................
	// config buffer list
    AudioBuffer emptyBuffer = {0};
    size_t arrayIndex;
    
    bufferList1->mNumberBuffers = clientDataFormat1.mChannelsPerFrame;
    for (arrayIndex = 0; arrayIndex < clientDataFormat1.mChannelsPerFrame; ++arrayIndex)
    {
        bufferList1->mBuffers[arrayIndex] = emptyBuffer;
    }
    bufferList1->mBuffers[0].mNumberChannels  = 1;
    bufferList1->mBuffers[0].mDataByteSize    = NEW_BUFFER_SIZE;
    bufferList1->mBuffers[0].mData            = buffer1left;
    if (2 == clientDataFormat1.mChannelsPerFrame)
    {
        buffer1right = malloc(NEW_BUFFER_SIZE);
        if (NULL == buffer1right) 
        {
            QKLog (@"*** malloc failure for allocating buffer1right memory"); 
            [self failedWithError:QKAudioMixerOutofMemoryError];
            goto errLabel;
        }
        
        bufferList1->mBuffers[1].mNumberChannels  = 1;
        bufferList1->mBuffers[1].mDataByteSize    = NEW_BUFFER_SIZE;
        bufferList1->mBuffers[1].mData            = buffer1right;
    }
    
    bufferList2->mNumberBuffers = clientDataFormat2.mChannelsPerFrame;
    for (arrayIndex = 0; arrayIndex < clientDataFormat2.mChannelsPerFrame; ++arrayIndex)
    {
        bufferList2->mBuffers[arrayIndex] = emptyBuffer;
    }
    bufferList2->mBuffers[0].mNumberChannels  = 1;
    bufferList2->mBuffers[0].mDataByteSize    = NEW_BUFFER_SIZE;
    bufferList2->mBuffers[0].mData            = buffer2left;
    if (2 == clientDataFormat2.mChannelsPerFrame)
    {
        buffer2right = malloc(NEW_BUFFER_SIZE);
        if (NULL == buffer2right) 
        {
            QKLog (@"*** malloc failure for allocating buffer2right memory");
            [self failedWithError:QKAudioMixerOutofMemoryError];
            goto errLabel;
        }
        
        bufferList2->mBuffers[1].mNumberChannels  = 1;
        bufferList2->mBuffers[1].mDataByteSize    = NEW_BUFFER_SIZE;
        bufferList2->mBuffers[1].mData            = buffer2right;
    }
    
    mixbufferList->mNumberBuffers = 1;
    mixbufferList->mBuffers[0] = emptyBuffer;
    mixbufferList->mBuffers[0].mNumberChannels  = 1;
    mixbufferList->mBuffers[0].mDataByteSize    = NEW_BUFFER_SIZE;
    mixbufferList->mBuffers[0].mData            = mixbuffer;
    
    //............................................................................
	// get frame counts
    UInt64 frameCount1 = 0;
    UInt64 frameCount2 = 0;
    UInt32 dataSize = sizeof(UInt64);
    
    status =    ExtAudioFileGetProperty (
                                         inAudioFile1,
                                         kExtAudioFileProperty_FileLengthFrames,
                                         &dataSize,
                                         &frameCount1
                                         );
    if (status)
    {
        [self failedWithError:QKAudioMixerGetPropertyFailedError];
        goto errLabel;
    }
    
    status =    ExtAudioFileGetProperty (
                                         inAudioFile2,
                                         kExtAudioFileProperty_FileLengthFrames,
                                         &dataSize,
                                         &frameCount2
                                         );
    if (status)
    {
        [self failedWithError:QKAudioMixerGetPropertyFailedError];
        goto errLabel;
    }
    
    //............................................................................
	// calculate frames need to mix
    UInt64 frameCountNeedToMix = MIN(frameCount1, frameCount2);
    UInt64 leftFramesToMix = frameCountNeedToMix;
    
    UInt32 frameNum1 = 0;
	UInt32 frameNum2 = 0;
    UInt64 frameOffset1 = 0;
    UInt64 frameOffset2 = 0;
    UInt64 mixFrameOffset = 0;
    
    // check if need report progress or not
    BOOL reportProgress = frameCountNeedToMix > 0 && (nil != self.delegate) && [self.delegate respondsToSelector:@selector(audioMixer:didMakeProgress:)];
    NSTimeInterval lastProgressReport = [NSDate timeIntervalSinceReferenceDate];
    
	while (!mCancelled
           && ![[NSThread currentThread] isCancelled])
    {
        bufferList1->mBuffers[0].mDataByteSize    = NEW_BUFFER_SIZE;
        if (2 == clientDataFormat1.mChannelsPerFrame)
        {
            bufferList1->mBuffers[1].mDataByteSize    = NEW_BUFFER_SIZE;
        }
        
        bufferList2->mBuffers[0].mDataByteSize    = NEW_BUFFER_SIZE;
        if (2 == clientDataFormat2.mChannelsPerFrame)
        {
            bufferList2->mBuffers[1].mDataByteSize    = NEW_BUFFER_SIZE;
        }
        
        // the num of frame to read
		frameNum1 = NEW_BUFFER_SIZE / clientDataFormat1.mBytesPerFrame;
        frameNum2 = frameNum1 = MIN(frameNum1, leftFramesToMix);
        
        // read a chunk from input file 1
        status = ExtAudioFileRead(inAudioFile1, &frameNum1, bufferList1);
        if (status) 
        {
            [self failedWithError:QKAudioMixerSourceFileReadError];
            goto errLabel;
        }
		frameOffset1 += frameNum1;
        
        // read a chunk from input file 2
        status = ExtAudioFileRead(inAudioFile2, &frameNum2, bufferList2);
        if (status) 
        {
            [self failedWithError:QKAudioMixerSourceFileReadError];
            goto errLabel;
        }
		frameOffset2 += frameNum2;
        
        
        // calulate how many frames used to mix
        int numFrameToMix = MIN(frameNum1, frameNum2);
        
        // if no frame to mix, read finish
        if (numFrameToMix == 0) 
        {
            break;
        }
        
		// Write pcm data to output file
		int numSamples = (numFrameToMix * SInt16MonoFormat.mBytesPerFrame) / sizeof(int16_t);
        
        // do mix
        if (SoundChannelRight == self.channel1 && NULL != buffer1right)
        {
            [QKAudioMixer mixBuffers:(const int16_t *)buffer1right buffer2:(const int16_t *)buffer2left mixbuffer:(int16_t *) mixbuffer mixbufferNumSamples:numSamples];
        }
        else
        {
            [QKAudioMixer mixBuffers:(const int16_t *)buffer1left buffer2:(const int16_t *)buffer2left mixbuffer:(int16_t *) mixbuffer mixbufferNumSamples:numSamples];
        }
        
        // write the mixed frames to tue output file
        mixbufferList->mBuffers[0].mDataByteSize    = numFrameToMix * SInt16MonoFormat.mBytesPerFrame;
        
        status = ExtAudioFileWrite(mixAudioFile, numFrameToMix, mixbufferList);
        mixFrameOffset += numFrameToMix;
        
        if ( status == kExtAudioFileError_CodecUnavailableInputConsumed)
        {
            /*
             Returned when ExtAudioFileWrite was interrupted. You must stop calling
             ExtAudioFileWrite. If the underlying audio converter can resume after an
             interruption (see kAudioConverterPropertyCanResumeFromInterruption), you must
             wait for an EndInterruption notification from AudioSession, and call AudioSessionSetActive(true)
             before resuming. In this situation, the buffer you provided to ExtAudioFileWrite was successfully
             consumed and you may proceed to the next buffer
             */
        } 
        else if ( status == kExtAudioFileError_CodecUnavailableInputNotConsumed )
        {
            /*
             Returned when ExtAudioFileWrite was interrupted. You must stop calling
             ExtAudioFileWrite. If the underlying audio converter can resume after an
             interruption (see kAudioConverterPropertyCanResumeFromInterruption), you must
             wait for an EndInterruption notification from AudioSession, and call AudioSessionSetActive(true)
             before resuming. In this situation, the buffer you provided to ExtAudioFileWrite was not
             successfully consumed and you must try to write it again
             */
            
            // seek back to last offset before last read so we can try again after the interruption
            mixFrameOffset -= numFrameToMix;
            frameOffset1 -= numFrameToMix;
            frameOffset2 -= numFrameToMix;
            ExtAudioFileSeek(inAudioFile1, frameOffset1);
            ExtAudioFileSeek(inAudioFile2, frameOffset2);
        } 
        else if ( noErr != status )
        {
            [self failedWithError:QKAudioMixerDestinationFileWriteError];
            goto errLabel;
        }

        // report progress
        if ( reportProgress 
            && ([NSDate timeIntervalSinceReferenceDate]-lastProgressReport > 0.1 
                || mixFrameOffset == frameCountNeedToMix))
        {
            lastProgressReport = [NSDate timeIntervalSinceReferenceDate];
            [self performSelectorOnMainThread:@selector(reportProgress:) withObject:[NSNumber numberWithFloat:(double)mixFrameOffset/frameCountNeedToMix] waitUntilDone:NO];
        }
        
        // if no frames left to mix, mixing is finish
        leftFramesToMix -= numFrameToMix;
        if (leftFramesToMix == 0)
        {
            break;
        }
	}

errLabel:
    // close file if necessary
	if (inAudioFile1 != NULL) 
    {
		close_status = ExtAudioFileDispose(inAudioFile1);
        inAudioFile1 = NULL;
		assert(close_status == 0);
	}
	if (inAudioFile2 != NULL)
    {
		close_status = ExtAudioFileDispose(inAudioFile2);
        inAudioFile2 = NULL;
		assert(close_status == 0);
	}
	if (mixAudioFile != NULL) 
    {
		close_status = ExtAudioFileDispose(mixAudioFile);
        mixAudioFile = NULL;
		assert(close_status == 0);
	}
    
    // free memory for buffers
	if (buffer1left != NULL)
    {
		free(buffer1left);
	}
    if (buffer1right != NULL)
    {
		free(buffer1right);
	}
	if (buffer2left != NULL)
    {
		free(buffer2left);
	}
    if (buffer2right != NULL)
    {
		free(buffer2right);
	}
	if (mixbuffer != NULL)
    {
		free(mixbuffer);
	}
    
    // free buffer for bufferlist
    if (NULL != bufferList1) 
    {
        free(bufferList1);
    }
    
    if (NULL != bufferList2) 
    {
        free(bufferList2);
    }
    
    if (NULL != mixbufferList) 
    {
        free(mixbufferList);
    }
    
    if ( mCancelled 
        || [[NSThread currentThread] isCancelled]) 
    {
        [FileUtility removeItemAtPath:self.mixAudioFilePath];
    } 
    else 
    {
        [self performSelectorOnMainThread:@selector(reportCompletion) withObject:nil waitUntilDone:NO];
    }
    
    [pool release];
    mProcessing = NO;
}

- (void)failedWithError:(NSInteger)errorCode
{
    [self performSelectorOnMainThread:@selector(reportErrorAndCleanup:)
                           withObject:[NSError errorWithDomain:AudioMixerErrorDomain
                                                          code:errorCode
                                                      userInfo:nil]
                        waitUntilDone:NO];
}

- (void)reportErrorAndCleanup:(NSError*)error 
{
    [FileUtility removeItemAtPath:mMixAudioFilePath];
    
    if (nil != self.delegate) 
    {
        [self.delegate audioMixer:self didFailWithError:error];
    }
}

- (void)reportCompletion 
{
    if (nil != self.delegate) 
    {
        [self.delegate audioMixerdidFinishMix:self];
    }
}

- (void)reportProgress:(NSNumber*)progress 
{
    if (nil != self.delegate && [self.delegate respondsToSelector:@selector(audioMixer:didMakeProgress:)]) 
    {
        [self.delegate audioMixer:self didMakeProgress:[progress floatValue]];
    }
}

- (void)cancelProcessingThread
{
    mCancelled = YES;
    
    if (nil != mInternalProcessingThread)
    {
        [mInternalProcessingThread cancel];
        // wait until reading processing thread exit
        while (mProcessing)
        {
            [NSThread sleepForTimeInterval:0.01];
        }
        [mInternalProcessingThread release];
        mInternalProcessingThread = nil;
    }
}
@end
