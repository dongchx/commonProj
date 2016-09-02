//
//  QKAudioSynthesizeProcessor.m
//  QQKala
//
//  Created by frost on 12-8-17.
//  Copyright (c) 2012年 Tencent. All rights reserved.
//

#import "QKAudioSynthesizeProcessor.h"
#import "PublicConfig.h"
#import "FileUtility.h"
#import "QKAudioMixer.h"
#import "AudioCommonDefine.h"
#import "ASBDUtility.h"
#import "QKAudioEffect.h"

// ---------------------------------------------
// QKAudioSynthesizeProcessor private category
// ---------------------------------------------
@interface QKAudioSynthesizeProcessor()

@property (nonatomic, readwrite) TPCircularBuffer        *ptrSourceBuffer1;
@property (nonatomic, readwrite) TPCircularBuffer        *ptrSourceBuffer2;
@property (nonatomic, readwrite, retain)QKAudioEffect    *audioEffectForSource1;
@property (nonatomic, readwrite, retain)QKAudioEffect    *audioEffectForSource2;
@property (nonatomic, readwrite, retain)NSString         *outputFilePath;

- (void)synthesizeProcessingThread;
- (void)doProcess;
- (void)cancelThread;
- (void)cleanSourceBuffer;
- (void)synthesizeComplete;
- (void)doSetSourceBufferDrain;

/* Effect*/
- (void)cleanEffect;
@end

// ---------------------------------------------
// QKAudioSynthesizeProcessor private category
// ---------------------------------------------
@implementation QKAudioSynthesizeProcessor

@synthesize delegate = mDelegate;
@synthesize ptrSourceBuffer1;
@synthesize ptrSourceBuffer2;
@synthesize useEffectForSource1 = mUseEffectForSource1;
@synthesize useEffectForSource2 = mUseEffectForSource2;
@synthesize audioEffectForSource1 = mAudioEffectForSource1;
@synthesize audioEffectForSource2 = mAudioEffectForSource2;
@synthesize outputFilePath = mOutputFilePath;

#pragma mark life cycle

- (id)init
{
    if (self = [super init])
    {
        // Init circular buffer to hold the data of audio file
        TPCircularBufferInit(&mSourceBuffer1,kProcessingBufferTotalLenght);
        self.ptrSourceBuffer1 = &mSourceBuffer1;
        
        // Init circular buffer to hold the data of voice input
        TPCircularBufferInit(&mSourceBuffer2,kProcessingBufferTotalLenght);
        self.ptrSourceBuffer2 = &mSourceBuffer2;
    }
    return self;
}

- (void)dealloc
{
    [self cancelProcess];
    self.outputFilePath = nil;
    [super dealloc];
}

#pragma mark Public API
- (void)configOutputFile:(NSString*)fileName fileType:(AudioFileTypeID)type destinationASBD:(AudioStreamBasicDescription)destinationASBD clientASBD:(AudioStreamBasicDescription)clientASBD
{
    self.outputFilePath = fileName;
    mOutputFileTypeID = type;
    mOutputFormat = destinationASBD;
    mSourceFormat = clientASBD;
}

- (void)startThreadToProcess
{
    mCancelSynthesize = NO;
    mSynthesizeComplete = NO;
    mSourceBufferDrain = NO;
    mSynthesizing = YES;
    
    if (nil != mInternalSynthesizeThread)
    {
        [mInternalSynthesizeThread release];
    }
    mInternalSynthesizeThread =[[NSThread alloc] initWithTarget:self 
                                                       selector:@selector(synthesizeProcessingThread) 
                                                         object:nil];
    [mInternalSynthesizeThread start];
}

- (void)cancelProcess
{
    @synchronized(self)
    {
        if (nil != mInternalSynthesizeThread)
        {
            [self performSelector:@selector(cancelThread) onThread:mInternalSynthesizeThread withObject:nil waitUntilDone:YES];
            // wait until reading processing thread exit
            while (mSynthesizing)
            {
                [NSThread sleepForTimeInterval:0.01];
            }
        }
    }

    [self cleanEffect];
    [self cleanSourceBuffer];
}

- (void)cancelThread
{
    mCancelSynthesize = YES;
}

- (void)produceBytesForSourceBuffer1:(const void*)src bufferLength:(NSInteger)len
{
    TPCircularBufferProduceBytes(&mSourceBuffer1, src, len);
    if (mSourceBuffer1.fillCount >= kBufferLengthToProcess)
    {
        [self performSelector:@selector(doProcess) onThread:mInternalSynthesizeThread withObject:nil waitUntilDone:NO];
    }
}

- (void)produceBytesForSourceBuffer2:(const void*)src bufferLength:(NSInteger)len
{
    TPCircularBufferProduceBytes(&mSourceBuffer2, src, len);
}

- (void)setAudioEffectForSource1:(QKAudioEffect *)audioEffectForSource1
{
    // audio effect can not changed while processing
    if (!mSynthesizing) 
    {
        [audioEffectForSource1 retain];
        [mAudioEffectForSource1 release];
        mAudioEffectForSource1 = audioEffectForSource1;
    }
}

- (void)setAudioEffectForSource2:(QKAudioEffect *)audioEffectForSource2
{
    // audio effect can not changed while processing
    if (!mSynthesizing) 
    {
        [audioEffectForSource2 retain];
        [mAudioEffectForSource2 release];
        mAudioEffectForSource2 = audioEffectForSource2;
    }
}

- (void)setSourceBufferDrain
{
     [self performSelector:@selector(doSetSourceBufferDrain) onThread:mInternalSynthesizeThread withObject:nil waitUntilDone:NO];
}

- (void)doSetSourceBufferDrain
{
    mSourceBufferDrain = YES;
}

#pragma mark Private Category
- (void)synthesizeProcessingThread
{
    [NSThread setThreadPriority:0.9];
    NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
    
    if (nil != self.outputFilePath && 0 != self.outputFilePath.length) 
    {
        // .......................................................
        // allocate memory for buffers
        char *outBuffer = NULL;
        outBuffer = malloc(kBufferLengthToProcess);
        
        if (mMixBuffer) 
        {
            free(mMixBuffer);
            mMixBuffer = NULL;
        }
        mMixBuffer = malloc(kBufferLengthToProcess);
        
        if (mReverbBuffer)
        {
            free(mReverbBuffer);
            mReverbBuffer = NULL;
        }
        mReverbBuffer = malloc(kBufferLengthToProcess);
        memset(mReverbBuffer, 0, kBufferLengthToProcess);

        // .......................................................
        // create destination file & initialize
        CFURLRef url = CFURLCreateWithFileSystemPath(NULL, (CFStringRef)self.outputFilePath, kCFURLPOSIXPathStyle, false);
        OSStatus err = ExtAudioFileCreateWithURL(url, mOutputFileTypeID, &mOutputFormat, NULL, kAudioFileFlags_EraseFile, &mOutputFileRef);
        CFRelease(url);
        
        if (noErr != err)
        {
            if (NULL != outBuffer)
            {
                free(outBuffer);
            }
            
            if (NULL != mMixBuffer)
            {
                free(mMixBuffer);
                mMixBuffer = NULL;
            }
            if (NULL != mReverbBuffer)
            {
                free(mReverbBuffer);
                mReverbBuffer = NULL;
            }
            return;
        }
        
        // excluding from backup if necessary
        [FileUtility addSkipBackupAttributeToItemAtURL:[NSURL fileURLWithPath:self.outputFilePath]];
        
        // Inform the file what format the data is we're going to give it, 
        ExtAudioFileSetProperty(mOutputFileRef, kExtAudioFileProperty_ClientDataFormat, sizeof(AudioStreamBasicDescription), &mSourceFormat);
        
        // Get the underlying AudioConverterRef
        AudioConverterRef converter = NULL;
        UInt32 size = sizeof(converter);
        err = ExtAudioFileGetProperty(mOutputFileRef, kExtAudioFileProperty_AudioConverter, &size, &converter);
        
        if (2 == mOutputFormat.mChannelsPerFrame 
            && 1 == mSourceFormat.mChannelsPerFrame
            && NULL != converter)
        {
            SInt32 channelMap[2] = { 0, 0 };
            
            AudioConverterSetProperty(converter, kAudioConverterChannelMap, sizeof(channelMap), channelMap);
        }
        
        // Initialize async writes thus preparing it for IO
        ExtAudioFileWriteAsync(mOutputFileRef, 0, NULL);

        // .......................................................
        // init audio effect
        if (self.useEffectForSource1) 
        {
            [self.audioEffectForSource1 start];
        }
        
        // .......................................................
        // initialize AudioBufferList for synthesize processing
        mBufferList.mNumberBuffers = 1;
        
        // .......................................................
        // add a dummy port
        NSRunLoop *runLoop = [NSRunLoop currentRunLoop];
        NSMachPort *dummyPort = [[NSMachPort alloc] init];	
        [runLoop addPort:dummyPort forMode:NSDefaultRunLoopMode];
        [dummyPort release];
        
        // .......................................................
        // Synthesize Processing
        while ( !mCancelSynthesize 
               && !mSourceBufferDrain
               && ![[NSThread currentThread] isCancelled])
        {
            [runLoop runMode:NSDefaultRunLoopMode beforeDate:[NSDate distantFuture]];
        }
        
        mSynthesizing = NO;
        
        @synchronized(self)
        {
            ExtAudioFileDispose(mOutputFileRef);
            mOutputFileRef = NULL;

            
            // for testing
    //        dataInSourceBuffer1 = TPCircularBufferTail(&mSourceBuffer1, &avaliableBytesInSourceBuffer1);
    //        dataInSourceBuffer2 = TPCircularBufferTail(&mSourceBuffer2, &avaliableBytesInSourceBuffer2);
    //        QKLog(@"dataInSourceBuffer1 = %d, dataInSourceBuffer2 = %d", avaliableBytesInSourceBuffer1, avaliableBytesInSourceBuffer2);
            
            // .......................................................
            // clean memory
            if (NULL != outBuffer)
            {
                free(outBuffer);
            }
            
            if (NULL != mMixBuffer)
            {
                free(mMixBuffer);
                mMixBuffer = NULL;
            }
            if (NULL != mReverbBuffer)
            {
                free(mReverbBuffer);
                mReverbBuffer = NULL;
            }

            [self performSelectorOnMainThread:@selector(synthesizeComplete) withObject:nil waitUntilDone:NO];
            
            [mInternalSynthesizeThread release];
            mInternalSynthesizeThread = nil;
        }
    }
    else
    {
        mSynthesizing = NO;
        @synchronized(self)
        {
            [mInternalSynthesizeThread release];
            mInternalSynthesizeThread = nil;
        }
    }
    [pool release];
}

- (void)doProcess
{
    int32_t avaliableBytesInSourceBuffer1 = 0;
    int32_t avaliableBytesInSourceBuffer2 = 0;
    void *dataInSourceBuffer1 = NULL;
    void *dataInSourceBuffer2 = NULL;
    int maxProcessByte = kBufferLengthToProcess; // maxProcessByte can not bigger than kBufferLengthToProcess, 0 < maxProcessByte <= kBufferLengthToProcess
    int processingSamples = 0;
    
    
    dataInSourceBuffer1 = TPCircularBufferTail(&mSourceBuffer1, &avaliableBytesInSourceBuffer1);
    dataInSourceBuffer2 = TPCircularBufferTail(&mSourceBuffer2, &avaliableBytesInSourceBuffer2);
    
    if (avaliableBytesInSourceBuffer1 >= avaliableBytesInSourceBuffer2
        && avaliableBytesInSourceBuffer2 > maxProcessByte) 
    {
        processingSamples = MIN(maxProcessByte / sizeof(SInt16), avaliableBytesInSourceBuffer2 / sizeof(SInt16));
        int numBytes = processingSamples * sizeof(SInt16);
        
        // apply effect
        if (self.useEffectForSource1) 
        {
            [self.audioEffectForSource1 flow:dataInSourceBuffer1 outBuffer:mReverbBuffer bufferLen:numBytes];
        }
        
        [QKAudioMixer mixBuffers:(const int16_t *)dataInSourceBuffer2 buffer2:(const int16_t *)mReverbBuffer mixbuffer:(int16_t *)mMixBuffer mixbufferNumSamples:processingSamples];
        
        TPCircularBufferConsume(&mSourceBuffer1, numBytes);
        TPCircularBufferConsume(&mSourceBuffer2, numBytes);
        
        // write
        mBufferList.mBuffers[0].mData = mMixBuffer;
        mBufferList.mBuffers[0].mDataByteSize = numBytes;
        ExtAudioFileWriteAsync(mOutputFileRef, processingSamples, &mBufferList);
    }
}

- (void)cleanSourceBuffer
{
    TPCircularBufferCleanup(&mSourceBuffer1);
    TPCircularBufferCleanup(&mSourceBuffer2);
}

- (void)synthesizeComplete
{
    // clean if necessary
    [self cleanSourceBuffer];
    [self cleanEffect];
    
    if (nil != self.delegate && [self.delegate respondsToSelector:@selector(audioProcessor:didFinishWithFinishType:)])
    {
        AudioProcessorFinishType type = mSynthesizeComplete ? AudioProcessorFinishTypeComplete : AudioProcessorFinishTypeCancel;
        [self.delegate audioProcessor:self didFinishWithFinishType:type];
    }
}

- (void)cleanEffect
{
    [self.audioEffectForSource1 stop];
    [self.audioEffectForSource2 stop];
    self.audioEffectForSource1 = nil;
    self.audioEffectForSource1 = nil;
}
@end
