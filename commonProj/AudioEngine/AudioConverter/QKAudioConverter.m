//
//  QKAudioConverter.m
//  QQKala
//
//  Created by frost on 12-6-6.
//  Copyright (c) 2012年 Tencent. All rights reserved.
//

#import "ASBDUtility.h"
#import "AudioCommonDefine.h"
#import "QKAudioConverter.h"
#import "FileUtility.h"


NSString *const AudioConverterErrorDomain = @"com.tencent.AudioConverterErrorDomain";

#if !TARGET_IPHONE_SIMULATOR
static BOOL _aac_codec_available;
static BOOL _aac_codec_available_set = NO;
#endif

// ---------------------------------------------
// QKAudioConverter private category
// ---------------------------------------------
@interface QKAudioConverter ()
@property (nonatomic, readwrite, retain) NSString *source;
@property (nonatomic, readwrite, retain) NSString *destination;

- (void)registerInterruptionNotification;
- (void)unregisterInterruptionNotification;
- (void)interrupt;
- (void)resume;
- (void)reportErrorAndCleanup:(NSError*)error;
- (void)reportCompletion;
- (void)reportProgress:(NSNumber*)progress;
@end


// ---------------------------------------------
// QKAudioConverter @implementation
// ---------------------------------------------
@implementation QKAudioConverter

@synthesize delegate = mDelegate;
@synthesize source = mSource;
@synthesize destination = mDestination;
@synthesize audioFormat = mAudioFormat;


+ (BOOL)isAACConverterAvaliable {
#if TARGET_IPHONE_SIMULATOR
    return YES;
#else
    if ( _aac_codec_available_set ) return _aac_codec_available;
    
    // get an array of AudioClassDescriptions for all installed encoders for the given format 
    // the specifier is the format that we are interested in - this is 'aac ' in our case
    UInt32 encoderSpecifier = kAudioFormatMPEG4AAC;
    UInt32 size;
    
    if (noErr != AudioFormatGetPropertyInfo(kAudioFormatProperty_Encoders, sizeof(encoderSpecifier), &encoderSpecifier, &size) ) return NO;
    
    UInt32 numEncoders = size / sizeof(AudioClassDescription);
    AudioClassDescription encoderDescriptions[numEncoders];
    
    if ( noErr != AudioFormatGetProperty(kAudioFormatProperty_Encoders, sizeof(encoderSpecifier), &encoderSpecifier, &size, encoderDescriptions) ) 
    {
        _aac_codec_available_set = YES;
        _aac_codec_available = NO;
        return NO;
    }
    
    for (UInt32 i=0; i < numEncoders; ++i) 
    {
        if ( encoderDescriptions[i].mSubType == kAudioFormatMPEG4AAC && encoderDescriptions[i].mManufacturer == kAppleHardwareAudioCodecManufacturer ) 
        {
            _aac_codec_available_set = YES;
            _aac_codec_available = YES;
            return YES;
        }
    }
    
    _aac_codec_available_set = YES;
    _aac_codec_available = NO;
    return NO;
#endif
}

#pragma mark life cycle
- (id)initWithSource:(NSString*)sourcePath destination:(NSString*)destinationPath
{
    if ( !(self = [super init]) ) return nil;
    
    self.source = sourcePath;
    self.destination = destinationPath;
    mCondition = [[NSCondition alloc] init];
    
    return self;
}

- (void)dealloc 
{
    [self cancel];
    [mCondition release];
    self.source = nil;
    self.destination = nil;
    [super dealloc];
}

#pragma mark convert
// convert
- (BOOL)convertToAudioFormat:(UInt32)formatID audioSampleRate:(AudioSampleRate)sampleRate audioFileType:(AudioFileTypeID)audioFileTypeID deleteOnSuccess:(BOOL)delOnSucc
{
    if (!mProcessing) 
    {
        UInt32 size = sizeof(mPriorMixOverrideValue);
        AudioSessionGetProperty(kAudioSessionProperty_OverrideCategoryMixWithOthers, &size, &mPriorMixOverrideValue);
        
        // disable mix
        if (mPriorMixOverrideValue) 
        {
            UInt32 allowMixing = NO;
            AudioSessionSetProperty(kAudioSessionProperty_OverrideCategoryMixWithOthers, sizeof (allowMixing), &allowMixing);
        }
        
        mFormatID = formatID;
        mSampleRate = sampleRate;
        mFileTypeID = audioFileTypeID;
        mDeleteOnSucc = delOnSucc;
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
// cancel convert
- (void)cancel
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
    
    // restore kAudioSessionProperty_OverrideCategoryMixWithOthers value
    if (mPriorMixOverrideValue) 
    {
        UInt32 allowMixing = mPriorMixOverrideValue;
        AudioSessionSetProperty(kAudioSessionProperty_OverrideCategoryMixWithOthers, sizeof (allowMixing), &allowMixing);
    }
}

#pragma mark Private Category

- (void)registerInterruptionNotification
{
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(interrupt) name:kAudioSessionBeginInterruptionNotification object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(resume) name:kAudioSessionEndInterruptionNotification object:nil];
}

- (void)unregisterInterruptionNotification
{
    [[NSNotificationCenter defaultCenter] removeObserver: self name: kAudioSessionBeginInterruptionNotification object: nil];
    
    [[NSNotificationCenter defaultCenter] removeObserver: self name: kAudioSessionEndInterruptionNotification object: nil];
}

- (void)interrupt
{
    [mCondition lock];
    mInterrupted = YES;
    [mCondition unlock];
}

- (void)resume
{
    [mCondition lock];
    mInterrupted = NO;
    [mCondition signal];
    [mCondition unlock];
}

- (void)reportErrorAndCleanup:(NSError*)error 
{
    [FileUtility removeItemAtPath:mDestination];
    
    if (mPriorMixOverrideValue) 
    {
        UInt32 allowMixing = mPriorMixOverrideValue;
        AudioSessionSetProperty(kAudioSessionProperty_OverrideCategoryMixWithOthers, sizeof (allowMixing), &allowMixing);
    }
    
    if (nil != self.delegate) 
    {
        [self.delegate audioConverter:self didFailWithError:error];
    }
}

- (void)reportCompletion 
{
    if ( mPriorMixOverrideValue) 
    {
        UInt32 allowMixing = mPriorMixOverrideValue;
        AudioSessionSetProperty(kAudioSessionProperty_OverrideCategoryMixWithOthers, sizeof (allowMixing), &allowMixing);
    }
    
    if (mDeleteOnSucc)
    {
        [FileUtility removeItemAtPath:mSource];
    }
    
    if (nil != self.delegate) 
    {
        [self.delegate audioConverterdidFinishConversion:self];
    }
}

- (void)reportProgress:(NSNumber*)progress 
{
    if (nil != self.delegate && [self.delegate respondsToSelector:@selector(audioConverter:didMakeProgress:)]) 
    {
        [self.delegate audioConverter:self didMakeProgress:[progress floatValue]];
    }
}

#pragma mark processing Thread
- (void)processingThread 
{
    NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
    
    // set thread priority
    [[NSThread currentThread] setThreadPriority:1.1];
    
    BOOL failed = NO;
    OSStatus err = noErr;
    ExtAudioFileRef sourceFile = NULL;
    ExtAudioFileRef destinationFile = NULL;
    AudioStreamBasicDescription sourceFormat;
    AudioStreamBasicDescription convertFormat;
    AudioStreamBasicDescription destinationFormat;
    UInt8 *buffer = NULL;
    
    // open source file & get data format of source file
    if ( mSource ) 
    {
        // open source file
        err = ExtAudioFileOpenURL((CFURLRef)[NSURL fileURLWithPath:mSource], &sourceFile);
        if (err)
        {
            [self performSelectorOnMainThread:@selector(reportErrorAndCleanup:)
                                   withObject:[NSError errorWithDomain:AudioConverterErrorDomain
                                                                  code:QKAudioConverterSourceFileError
                                                              userInfo:nil]
                                waitUntilDone:NO];
            failed = YES;
            goto errLabel;
        }
        assert(sourceFile);

        // get source data format
        UInt32 size = sizeof(sourceFormat);
        err = ExtAudioFileGetProperty(sourceFile, kExtAudioFileProperty_FileDataFormat, &size, &sourceFormat);
        
        if (err)
        {
            [self performSelectorOnMainThread:@selector(reportErrorAndCleanup:)
                                   withObject:[NSError errorWithDomain:AudioConverterErrorDomain
                                                                  code:QKAudioConverterFormatError
                                                              userInfo:nil]
                                waitUntilDone:NO];
            failed = YES;
            goto errLabel;
        }
    }
    else
    {
        [self performSelectorOnMainThread:@selector(reportErrorAndCleanup:)
                               withObject:[NSError errorWithDomain:AudioConverterErrorDomain
                                                              code:QKAudioConverterSourceFileNotExistError
                                                          userInfo:nil]
                            waitUntilDone:NO];
        failed = YES;
        goto errLabel;
    }
    
    
    // config data format
    NSInteger numChannels = sourceFormat.mChannelsPerFrame;
    AudioSampleRate sampleRate = mSampleRate;   // AudioSampleRate44K by default
    if (mFormatID == kAudioFormatAppleIMA4) 
    {
        [ASBDUtility setASBD:&destinationFormat formatID:kAudioFormatAppleIMA4 numChannels:numChannels sampleRate:sampleRate];
	} 
    else if (mFormatID == kAudioFormatMPEG4AAC) 
    {
        [ASBDUtility setASBD:&destinationFormat formatID:kAudioFormatMPEG4AAC numChannels:numChannels sampleRate:sampleRate];
	} 
    else if (mFormatID == kAudioFormatAppleLossless) 
    {
        [ASBDUtility setASBD:&destinationFormat formatID:kAudioFormatAppleLossless numChannels:numChannels sampleRate:sampleRate];
	} 
    else if (mFormatID == kAudioFormatLinearPCM) 
    {
        [ASBDUtility setASBD:&destinationFormat formatID:kAudioFormatLinearPCM numChannels:numChannels sampleRate:sampleRate];	
	} 
    else 
    {
        [self performSelectorOnMainThread:@selector(reportErrorAndCleanup:)
                               withObject:[NSError errorWithDomain:AudioConverterErrorDomain
                                                              code:QKAudioConverterInvalidDestinationFormat
                                                          userInfo:nil]
                            waitUntilDone:NO];
        failed = YES;
        goto errLabel;
	}

    // check destination format is valid
    UInt32 size = sizeof(destinationFormat);
    err = AudioFormatGetProperty(kAudioFormatProperty_FormatInfo, 0, NULL, &size, &destinationFormat);
    
    if (err)
    {
        [self performSelectorOnMainThread:@selector(reportErrorAndCleanup:)
                               withObject:[NSError errorWithDomain:AudioConverterErrorDomain
                                                              code:QKAudioConverterInvalidDestinationFormat
                                                          userInfo:nil]
                            waitUntilDone:NO];
        failed = YES;
        goto errLabel;
    }
    
    // create destination file
    err = ExtAudioFileCreateWithURL((CFURLRef)[NSURL fileURLWithPath:mDestination], mFileTypeID, &destinationFormat, NULL, kAudioFileFlags_EraseFile, &destinationFile);
    
    if (err) 
    {
        [self performSelectorOnMainThread:@selector(reportErrorAndCleanup:)
                               withObject:[NSError errorWithDomain:AudioConverterErrorDomain
                                                              code:QKAudioConverterDestinationFileCreateError
                                                          userInfo:nil]
                            waitUntilDone:NO];
        failed = YES;
        goto errLabel;
    }

    // excluding from backup if necessary
    [FileUtility addSkipBackupAttributeToItemAtURL:[NSURL fileURLWithPath:mDestination]];
    
    // config conver format
    [ASBDUtility setASBD:&convertFormat formatID:kAudioFormatLinearPCM numChannels:numChannels sampleRate:sampleRate];	
    
    size = sizeof(convertFormat);
    if ( (sourceFile && noErr != ExtAudioFileSetProperty(sourceFile, kExtAudioFileProperty_ClientDataFormat, size, &convertFormat) )
        || noErr != ExtAudioFileSetProperty(destinationFile, kExtAudioFileProperty_ClientDataFormat, size, &convertFormat)
        ) 
    {
        [self performSelectorOnMainThread:@selector(reportErrorAndCleanup:)
                               withObject:[NSError errorWithDomain:AudioConverterErrorDomain
                                                              code:QKAudioConverterFormatError
                                                          userInfo:[NSDictionary dictionaryWithObject:NSLocalizedString(@"Couldn't setup intermediate conversion format", @"") forKey:NSLocalizedDescriptionKey]]
                            waitUntilDone:NO];
        failed = YES;
        goto errLabel;
    }
    
    // Get the underlying AudioConverterRef
    AudioConverterRef converter;
    size = sizeof(converter);
    err = ExtAudioFileGetProperty(destinationFile, kExtAudioFileProperty_AudioConverter, &size, &converter);
    
    if (err) 
    {
        failed = YES;
        goto errLabel;
    }
    
    
    // Handle the case of reading from a mono input file and writing to a stereo
	// output file by setting up a channel map. The mono output is duplicated
	// in the left and right channel.
    
    if (2 == destinationFormat.mChannelsPerFrame 
        && 1 == sourceFormat.mChannelsPerFrame)
    {
        SInt32 channelMap[2] = { 0, 0 };
        
        err = AudioConverterSetProperty(converter, kAudioConverterChannelMap, sizeof(channelMap), channelMap);
        
        if (err)
        {
            failed = YES;
            goto errLabel;
        }
    }
    
    // Get canResume property
    BOOL canResumeFromInterruption = YES;
    UInt32 canResume = 0;
    size = sizeof(canResume);
    if ( noErr != AudioConverterGetProperty(converter, kAudioConverterPropertyCanResumeFromInterruption, &size, &canResume) ) 
    {
        canResumeFromInterruption = (BOOL)canResume;
    }
    
    // Get Frames
    SInt64 lengthInFrames = 0;
    size = sizeof(lengthInFrames);
    ExtAudioFileGetProperty(sourceFile, kExtAudioFileProperty_FileLengthFrames, &size, &lengthInFrames);
    
    // check if need report progress or not
    BOOL reportProgress = lengthInFrames > 0 && (nil != self.delegate) && [self.delegate respondsToSelector:@selector(audioConverter:didMakeProgress:)];
    NSTimeInterval lastProgressReport = [NSDate timeIntervalSinceReferenceDate];
    
    // 320k buffer
    UInt32 bufferByteSize = 327680;
    buffer = malloc(bufferByteSize);
    if (NULL == buffer)
    {
        failed = YES;
        goto errLabel;
    }
    
    SInt64 sourceFrameOffset = 0;
    AudioBufferList fillBufList;
    fillBufList.mNumberBuffers = 1;
    fillBufList.mBuffers[0].mNumberChannels = convertFormat.mChannelsPerFrame;
    fillBufList.mBuffers[0].mDataByteSize = bufferByteSize;
    fillBufList.mBuffers[0].mData = buffer;
    // do convert
    while ( !mCancelled 
           && ![[NSThread currentThread] isCancelled])
    {
        fillBufList.mBuffers[0].mDataByteSize = bufferByteSize;
        
        UInt32 numFrames = bufferByteSize / convertFormat.mBytesPerFrame;
        err = ExtAudioFileRead(sourceFile, &numFrames, &fillBufList);
        if ( noErr != err ) 
        {
            [self performSelectorOnMainThread:@selector(reportErrorAndCleanup:)
                                   withObject:[NSError errorWithDomain:AudioConverterErrorDomain
                                                                  code:QKAudioConverterSourceFileReadError
                                                              userInfo:nil]
                                waitUntilDone:NO];
            failed = YES;
            goto errLabel;
        }

        // If no frames were returned, conversion is finished
        if ( !numFrames ) 
        {
            break;
        }
        
        sourceFrameOffset += numFrames;
        
        // wait until interuption ends
        [mCondition lock];
        BOOL wasInterrupted = mInterrupted;
        while ( mInterrupted ) {
            [mCondition wait];
        }
        [mCondition unlock];
        
        if ( wasInterrupted && !canResumeFromInterruption )
        {
            [self performSelectorOnMainThread:@selector(reportErrorAndCleanup:)
                                   withObject:[NSError errorWithDomain:AudioConverterErrorDomain
                                                                  code:QKAudioConverterUnrecoverableInterruptionError
                                                              userInfo:nil]
                                waitUntilDone:NO];
            failed = YES;
            goto errLabel;
        }
        
        OSStatus status = ExtAudioFileWrite(destinationFile, numFrames, &fillBufList);
        
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
            sourceFrameOffset -= numFrames;
            ExtAudioFileSeek(sourceFile, sourceFrameOffset);
        } 
        else if ( noErr != status )
        {
            [self performSelectorOnMainThread:@selector(reportErrorAndCleanup:)
                                   withObject:[NSError errorWithDomain:AudioConverterErrorDomain
                                                                  code:QKAudioConverterDestinationFileWriteError
                                                              userInfo:nil]
                                waitUntilDone:NO];
            failed = YES;
            goto errLabel;
        }
        
        // report progress
        if ( reportProgress 
            && ([NSDate timeIntervalSinceReferenceDate]-lastProgressReport > 0.1 
                || sourceFrameOffset == lengthInFrames))
        {
            lastProgressReport = [NSDate timeIntervalSinceReferenceDate];
            [self performSelectorOnMainThread:@selector(reportProgress:) withObject:[NSNumber numberWithFloat:(double)sourceFrameOffset/lengthInFrames] waitUntilDone:NO];
        }
    }

errLabel:
	if (buffer != NULL)
		free(buffer);
    
	if (sourceFile)
		ExtAudioFileDispose(sourceFile);
    
	if (destinationFile)
		ExtAudioFileDispose(destinationFile);
    
    if ( mCancelled 
        || [[NSThread currentThread] isCancelled]
        || failed) 
    {
        [FileUtility removeItemAtPath:mDestination];
    } 
    else 
    {
        [self performSelectorOnMainThread:@selector(reportCompletion) withObject:nil waitUntilDone:NO];
    }
    
    [pool release];
    mProcessing = NO;

}


+ (OSStatus) convertToCaff:(NSString*)inPath
				   outPath:(NSString*)outPath
{
	return [self convertToCaff:inPath outPath:outPath numChannels:-1];
}

+ (OSStatus) convertToCaff:(NSString*)inPath
                   outPath:(NSString*)outPath
               numChannels:(NSInteger)numChannels
{
	return [self convertTo:inPath outPath:outPath
		   audioFileTypeID:kAudioFileCAFType
				 mFormatID:kAudioFormatLinearPCM
			   numChannels:numChannels];
}

+ (OSStatus) convertToIMA4Caff:(NSString*)inPath
					   outPath:(NSString*)outPath
{
	return [self convertToIMA4Caff:inPath outPath:outPath numChannels:-1];
}

+ (OSStatus) convertToIMA4Caff:(NSString*)inPath
                       outPath:(NSString*)outPath
                   numChannels:(NSInteger)numChannels
{
	return [self convertTo:inPath outPath:outPath
		   audioFileTypeID:kAudioFileCAFType
				 mFormatID:kAudioFormatAppleIMA4
			   numChannels:numChannels];
}

+ (OSStatus) convertToALACCaff:(NSString*)inPath
					   outPath:(NSString*)outPath
{
	return [self convertToALACCaff:inPath outPath:outPath numChannels:-1];
}

+ (OSStatus) convertToALACCaff:(NSString*)inPath
					   outPath:(NSString*)outPath
				   numChannels:(NSInteger)numChannels
{
	return [self convertTo:inPath outPath:outPath
		   audioFileTypeID:kAudioFileCAFType
				 mFormatID:kAudioFormatAppleLossless
			   numChannels:numChannels];
}

+ (OSStatus) convertToAACCaff:(NSString*)inPath
                      outPath:(NSString*)outPath
{
	return [self convertToAACCaff:inPath outPath:outPath numChannels:-1];
}

+ (OSStatus) convertToAACCaff:(NSString*)inPath
                      outPath:(NSString*)outPath
                  numChannels:(NSInteger)numChannels
{
	return [self convertTo:inPath outPath:outPath
           audioFileTypeID:kAudioFileCAFType
                 mFormatID:kAudioFormatMPEG4AAC
               numChannels:numChannels];
}

+ (OSStatus) convertToAACM4A:(NSString*)inPath
                     outPath:(NSString*)outPath
{
	return [self convertToAACM4A:inPath outPath:outPath numChannels:-1];
}

+ (OSStatus) convertToAACM4A:(NSString*)inPath
                     outPath:(NSString*)outPath
                 numChannels:(NSInteger)numChannels
{
	return [self convertTo:inPath outPath:outPath
           audioFileTypeID:kAudioFileM4AType
                 mFormatID:kAudioFormatMPEG4AAC
               numChannels:numChannels];
}

// Set flags for default audio format on iPhone OS

+ (void) _setDefaultAudioFormatFlags:(AudioStreamBasicDescription*)audioFormatPtr
						 numChannels:(NSUInteger)numChannels
{
	bzero(audioFormatPtr, sizeof(AudioStreamBasicDescription));
    
	audioFormatPtr->mFormatID = kAudioFormatLinearPCM;
	audioFormatPtr->mSampleRate = 44100.0;
	audioFormatPtr->mChannelsPerFrame = numChannels;
	audioFormatPtr->mBytesPerPacket = 2 * numChannels;
	audioFormatPtr->mFramesPerPacket = 1;
	audioFormatPtr->mBytesPerFrame = 2 * numChannels;
	audioFormatPtr->mBitsPerChannel = 16;
	audioFormatPtr->mFormatFlags = kAudioFormatFlagsNativeEndian |
    kAudioFormatFlagIsPacked | kAudioFormatFlagIsSignedInteger;	
}

// Set flags for IMA4 compressed audio (optimal size for uncompressed audio)

+ (void) _setIMA4AudioFormatFlags:(AudioStreamBasicDescription*)audioFormatPtr
                      numChannels:(NSUInteger)numChannels
{
	bzero(audioFormatPtr, sizeof(AudioStreamBasicDescription));
    
	audioFormatPtr->mFormatID = kAudioFormatAppleIMA4;
	audioFormatPtr->mSampleRate = 44100.0;
	audioFormatPtr->mChannelsPerFrame = numChannels;
	audioFormatPtr->mBytesPerPacket = 34 * numChannels;
	audioFormatPtr->mFramesPerPacket = 64;
}

+ (void) _setALACAudioFormatFlags:(AudioStreamBasicDescription*)audioFormatPtr
					  numChannels:(NSUInteger)numChannels
{
	bzero(audioFormatPtr, sizeof(AudioStreamBasicDescription));
    
	audioFormatPtr->mFormatID = kAudioFormatAppleLossless;
	audioFormatPtr->mSampleRate = 44100.0;
	audioFormatPtr->mChannelsPerFrame = numChannels;
}

+ (void) _setAACAudioFormatFlags:(AudioStreamBasicDescription*)audioFormatPtr
                     numChannels:(NSUInteger)numChannels
{
	bzero(audioFormatPtr, sizeof(AudioStreamBasicDescription));
    
	audioFormatPtr->mFormatID = kAudioFormatMPEG4AAC;
	audioFormatPtr->mFormatFlags = kMPEG4Object_AAC_Main;
	audioFormatPtr->mSampleRate = 44100.0;
	audioFormatPtr->mChannelsPerFrame = numChannels;
}

// Get a string description of common ext audio result codes

+ (NSString*) commonExtAudioResultCode:(OSStatus)code
{
	char *str;
    
	if (code == kExtAudioFileError_InvalidProperty) {
		str = "kExtAudioFileError_InvalidProperty";
	} else if (code == kExtAudioFileError_InvalidPropertySize) {
		str = "kExtAudioFileError_InvalidPropertySize";
	} else if (code == kExtAudioFileError_NonPCMClientFormat) {
		str = "kExtAudioFileError_NonPCMClientFormat";
	} else if (code == kExtAudioFileError_InvalidChannelMap) {
		str = "kExtAudioFileError_InvalidChannelMap";
	} else if (code == kExtAudioFileError_InvalidOperationOrder) {
		str = "kExtAudioFileError_InvalidOperationOrder";
	} else if (code == kExtAudioFileError_InvalidDataFormat) {
		str = "kExtAudioFileError_InvalidDataFormat";
	} else if (code == kExtAudioFileError_MaxPacketSizeUnknown) {
		str = "kExtAudioFileError_MaxPacketSizeUnknown";
	} else if (code == kExtAudioFileError_InvalidSeek) {
		str = "kExtAudioFileError_InvalidSeek";
	} else if (code == kExtAudioFileError_AsyncWriteTooLarge) {
		str = "kExtAudioFileError_AsyncWriteTooLarge";
	} else if (code == kExtAudioFileError_AsyncWriteBufferOverflow) {
		str = "kExtAudioFileError_AsyncWriteBufferOverflow";
	} else if (code == kExtAudioFileError_AsyncWriteBufferOverflow) {
		str = "kExtAudioFileError_AsyncWriteBufferOverflow";
	} else {
		str = "";
	}
    
	return [NSString stringWithFormat:@"%s", str];
}

+ (OSStatus) convertTo:(NSString*)inPath
			   outPath:(NSString*)outPath
	   audioFileTypeID:(AudioFileTypeID)audioFileTypeID
			 mFormatID:(UInt32)mFormatID
		   numChannels:(NSInteger)numChannels
{
    OSStatus							err = noErr;
    AudioStreamBasicDescription			inputFileFormat;
    AudioStreamBasicDescription			converterFormat;
    UInt32								thePropertySize = sizeof(inputFileFormat);
    ExtAudioFileRef						inputAudioFileRef = NULL;
    ExtAudioFileRef						outputAudioFileRef = NULL;
    AudioStreamBasicDescription			outputFileFormat;
    
#define BUFFER_SIZE 4096
	UInt8 *buffer = NULL;
    
	NSURL *inURL = [NSURL fileURLWithPath:inPath];
	NSURL *outURL = [NSURL fileURLWithPath:outPath];
    
	// Open input audio file
    
    err = ExtAudioFileOpenURL((CFURLRef)inURL, &inputAudioFileRef);
    if (err)
	{
		goto reterr;
	}
	assert(inputAudioFileRef);
    
    // Get input audio format
    
	bzero(&inputFileFormat, sizeof(inputFileFormat));
    err = ExtAudioFileGetProperty(inputAudioFileRef, kExtAudioFileProperty_FileDataFormat,
								  &thePropertySize, &inputFileFormat);
    if (err)
	{
		goto reterr;
	}
	
	// only mono or stereo audio files are supported
    
    if (inputFileFormat.mChannelsPerFrame > 2) 
	{
		err = kExtAudioFileError_InvalidDataFormat;
		goto reterr;
	}
    
	// Enable an audio converter on the input audio data by setting
	// the kExtAudioFileProperty_ClientDataFormat property. Each
	// read from the input file returns data in linear pcm format.
    
	if (numChannels == -1)
		numChannels = inputFileFormat.mChannelsPerFrame;
    
	[self _setDefaultAudioFormatFlags:&converterFormat numChannels:numChannels];
    
    err = ExtAudioFileSetProperty(inputAudioFileRef, kExtAudioFileProperty_ClientDataFormat,
								  sizeof(converterFormat), &converterFormat);
    if (err)
	{
		goto reterr;
	}
	
	// Handle the case of reading from a mono input file and writing to a stereo
	// output file by setting up a channel map. The mono output is duplicated
	// in the left and right channel.
    
	if (inputFileFormat.mChannelsPerFrame == 1 && numChannels == 2) {
		SInt32 channelMap[2] = { 0, 0 };
        
		// Get the underlying AudioConverterRef
        
		AudioConverterRef convRef = NULL;
		UInt32 size = sizeof(AudioConverterRef);
        
		err = ExtAudioFileGetProperty(inputAudioFileRef, kExtAudioFileProperty_AudioConverter, &size, &convRef);
        
		if (err)
		{
			goto reterr;
		}    
        
		assert(convRef);
        
		err = AudioConverterSetProperty(convRef, kAudioConverterChannelMap, sizeof(channelMap), channelMap);
        
		if (err)
		{
			goto reterr;
		}
	}
    
    // Output file is typically a caff file, but the user could emit some other
	// common file types. If a file exists already, it is deleted before writing
	// the new audio file.
    
	if (mFormatID == kAudioFormatAppleIMA4) {
		[self _setIMA4AudioFormatFlags:&outputFileFormat numChannels:converterFormat.mChannelsPerFrame];
	} else if (mFormatID == kAudioFormatMPEG4AAC) {
		[self _setAACAudioFormatFlags:&outputFileFormat numChannels:converterFormat.mChannelsPerFrame];
	} else if (mFormatID == kAudioFormatAppleLossless) {
		[self _setALACAudioFormatFlags:&outputFileFormat numChannels:converterFormat.mChannelsPerFrame];		
	} else if (mFormatID == kAudioFormatLinearPCM) {
		[self _setDefaultAudioFormatFlags:&outputFileFormat numChannels:converterFormat.mChannelsPerFrame];		
	} else {
		err = kExtAudioFileError_InvalidDataFormat;
		goto reterr;
	}
    
	UInt32 flags = kAudioFileFlags_EraseFile;
    
	err = ExtAudioFileCreateWithURL((CFURLRef)outURL, audioFileTypeID, &outputFileFormat,
									NULL, flags, &outputAudioFileRef);
    if (err)
	{
		// -48 means the file exists already
		goto reterr;
	}
	assert(outputAudioFileRef);
    
	// Enable converter when writing to the output file by setting the client
	// data format to the pcm converter we created earlier.
    
    err = ExtAudioFileSetProperty(outputAudioFileRef, kExtAudioFileProperty_ClientDataFormat,
								  sizeof(converterFormat), &converterFormat);
    if (err)
	{
		goto reterr;
	}
    
	// Buffer to read from source file and write to dest file
    
	buffer = malloc(BUFFER_SIZE);
	assert(buffer);	
    
	AudioBufferList conversionBuffer;
	conversionBuffer.mNumberBuffers = 1;
	conversionBuffer.mBuffers[0].mNumberChannels = inputFileFormat.mChannelsPerFrame;
	conversionBuffer.mBuffers[0].mData = buffer;
	conversionBuffer.mBuffers[0].mDataByteSize = BUFFER_SIZE;
    
	while (TRUE) 
    {
		conversionBuffer.mBuffers[0].mDataByteSize = BUFFER_SIZE;
        
		UInt32 frameCount = INT_MAX;
        
		if (inputFileFormat.mBytesPerFrame > 0)
        {
			frameCount = (conversionBuffer.mBuffers[0].mDataByteSize / inputFileFormat.mBytesPerFrame);
		}
        
		// Read a chunk of input
		err = ExtAudioFileRead(inputAudioFileRef, &frameCount, &conversionBuffer);
        
		if (err) 
        {
			goto reterr;
		}
        
		// If no frames were returned, conversion is finished
        
		if (frameCount == 0)
			break;
        
		// Write pcm data to output file
        
		err = ExtAudioFileWrite(outputAudioFileRef, frameCount, &conversionBuffer);
        
		if (err) {
			goto reterr;
		}
	}
    
reterr:
	if (buffer != NULL)
		free(buffer);
    
	if (inputAudioFileRef)
		ExtAudioFileDispose(inputAudioFileRef);
    
	if (outputAudioFileRef)
		ExtAudioFileDispose(outputAudioFileRef);
    
	return err;
}

+ (OSStatus) getCaffAudioFormatID:(NSString*)filePath fileFormatIDPtr:(UInt32*)fileFormatIDPtr
{
	OSStatus status;
    
	NSURL *url = [NSURL fileURLWithPath:filePath];
	
	AudioFileID inAudioFile = NULL;

	status = AudioFileOpenURL((CFURLRef)url, kAudioFileReadPermission, 0, &inAudioFile);
    if (status)
	{
		goto reterr;
	}
    
	// Lookup audio file type
    
    AudioStreamBasicDescription inputDataFormat;
	UInt32 propSize = sizeof(inputDataFormat);
    
	bzero(&inputDataFormat, sizeof(inputDataFormat));
    
    status = AudioFileGetProperty(inAudioFile, kAudioFilePropertyDataFormat,
								  &propSize, &inputDataFormat);
    
	if (status)
	{
		goto reterr;
	}
    
	*fileFormatIDPtr = inputDataFormat.mFormatID;
    
reterr:
	if (inAudioFile != NULL) {
		OSStatus close_status = AudioFileClose(inAudioFile);
		assert(close_status == 0);
	}
    
	return status;
}

+ (BOOL) isALACAudioFormat:(NSString*)filePath
{
	UInt32 fileFormatID;
    
	OSStatus status = [self getCaffAudioFormatID:filePath fileFormatIDPtr:&fileFormatID];
    
    if (noErr != status)
    {
        // getCaffAudioFormatID failed
        return NO;
    }

	return (fileFormatID == kAudioFormatAppleLossless);
}

@end
