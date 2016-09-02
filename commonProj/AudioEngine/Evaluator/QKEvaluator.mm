//
//  QKEvaluator.m
//  QQKala
//
//  Created by frost on 12-8-21.
//  Copyright (c) 2012年 Tencent. All rights reserved.
//

#import "QKEvaluator.h"
#import "PublicConfig.h"
#import "QKAudioTrack.h"

#define EvalSing_TONE_TYPE_SENTENCE                0
#define EvalSing_TONE_TYPE_ALL                     1 

// ---------------------------------------------
// QKEvaluator private category
// ---------------------------------------------
@interface QKEvaluator()

- (NSInteger)createEvaluator;
- (void)releaseEvaluator;
- (NSInteger)setSampleRate:(UInt32)sampleRate;

/* token*/
- (void)startThreadToLoadTokens:(NSString*)tokenFile;
- (void)loadTokensFromFile:(NSString*)tokenFilePath;
- (void)loadTokensFailed;
- (void)loadTokensSuccess;
- (void)destoryTokens;
- (void)cleanLoadThread;
- (NSInteger)configTokens;

/* evaluate*/
- (void)createAndStartProcessingThread;
- (void)runStep;
- (void)cancelThread;
- (void)processingThreadProc;
- (void)cleanProcessingThread;
- (void)onResultAvaliable;
- (NSUInteger)processSentenceResult:(NSUInteger)result;
- (NSUInteger)processAllResult:(NSUInteger)result;
- (void)cleanSentenceScoreArray;

- (void)reportError:(EvaluatorErrorType)error;
- (void)reportReadyToEvaluate;


@end

@implementation QKEvaluator
@synthesize evaluateDelegate = mEvaluateDelegate;
@synthesize sentenseScoreArray = mSentenseScoreArray;
@synthesize resultingScore = mResultingScore;
@synthesize haveResultingScore = mHaveResultingScore;
@synthesize isAllEvaluated;

#pragma mark life cycle
- (id)init
{
    self = [super init];
	if (self) 
	{
        // nothing to do here
	}
	return self;
}

- (void)dealloc
{
    [self cleanAndReset];
    [super dealloc];
}

#pragma mark public function
- (void)createAndConfigEvaluator:(NSString*)tokenFilePath sampleRate:(UInt32)sampleRate
{
    mSentenses = 0;
    if (nil != tokenFilePath)
    {
        NSInteger status = [self createEvaluator];
        if (EvalSing_OK == status && NULL != mSingHandle)
        {
            status = [self setSampleRate:sampleRate];
            if (EvalSing_OK == status)
            {
                [self startThreadToLoadTokens:tokenFilePath];
            }
            else
            {
                [self reportError:EvaluatorInvalidSampleRate];
            }
        }
        else
        {
            [self reportError:EvaluatorHandleInValid];
        }
    }
    else
    {
        [self reportError:EvaluatorHandleInValid];
    }
}

- (NSInteger)appendData:(char*)data numSamples:(int)numSamples
{
    if (NULL != mSingHandle && mInternalThreadRunning) 
    {
        int status;
        status = evalSing_AppendData(mSingHandle, data, numSamples);
        [self performSelector:@selector(runStep) onThread:mInternalProcessingThread withObject:nil waitUntilDone:NO];
        return status;
    }
    return EvalSing_OK;
}

- (void)startEvaluate
{
    //clean if necessary
    [self cleanProcessingThread];
    [self cleanSentenceScoreArray];
    
    // create and start processing thread
    [self createAndStartProcessingThread];
    
    // initialize score containers
    mSentenseScoreArray = [[NSMutableArray alloc] initWithCapacity:8];
    mResultingScore = 0;
    mHaveResultingScore = NO;
}

- (NSInteger)forceEndEvaluate
{
    if (NULL != mSingHandle) 
    {
        [self cleanProcessingThread];
        int status = evalSing_EndData(mSingHandle, &mResultingScore);
        if (EvalSing_OK == status) 
        {
            mHaveResultingScore = YES;
            mResultingScore = [self processAllResult:mResultingScore];
        }
        [self releaseEvaluator];
        return status;
    }
    return EvalSing_OK;
}

- (BOOL)isAllEvaluated
{
    if (nil != mSentenseScoreArray && mSentenses > 0)
    {
        return mSentenses == [mSentenseScoreArray count];
    }
    return NO;
}
#pragma mark Private Category
- (NSInteger)createEvaluator
{
    [self releaseEvaluator];
    
    int status;
    
    int size = 0;
    evalSing_Create(mSingHandle, &size);
    mSingHandle = (SING_HANDLE)malloc(size);
    if (NULL == mSingHandle)
    {
        return EVAL_OUT_OF_MEMORY;
    }
    status = evalSing_Create(mSingHandle, &size);
    return status;
}

- (void)releaseEvaluator
{
    if (NULL != mSingHandle)
    {
        free(mSingHandle);
        mSingHandle = NULL;
    }
}

- (NSInteger)setSampleRate:(UInt32)sampleRate
{
    if (NULL != mSingHandle) 
    {
        int status;
        status = evalSing_SetParam(mSingHandle, 0, sampleRate);
        return status;
    }
    return EvalSing_OK;
}

- (void)startThreadToLoadTokens:(NSString*)tokenFile
{
    if (nil == mInternalLoadTokenThread) 
    {
        NSAssert([[NSThread currentThread] isEqual:[NSThread mainThread]],
                 @"create load thread can only be started from the main thread.");
        
        mInternalLoadTokenThread =[[NSThread alloc] initWithTarget:self 
                                                          selector:@selector(loadTokensFromFile:) 
                                                             object:tokenFile];
        mCancelLoad = NO;
        mLoading = YES;
        [mInternalLoadTokenThread start];
    }
}

- (void)loadTokensFromFile:(NSString*)tokenFilePath
{
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    BOOL loadsuccess = NO;
    BOOL error = NO;
    BOOL hasFile = NO;
    FILE* fin = NULL;
    if (nil != tokenFilePath)
    {
        hasFile = YES;
        fin = fopen([tokenFilePath UTF8String], "rb");
        if (!fin)
        {
            error = YES;
            goto clean;
        }
        
        mSongToken = (SongToken*) malloc(sizeof(SongToken));
        if (NULL == mSongToken) 
        {
            error = YES;
            goto clean;
        }
        memset(mSongToken, 0, sizeof(SongToken));
        
        if (fread((char*)&mSongToken->nSentence, sizeof(uint16_t), 1, fin) != 1)
        {
            error = YES;
            goto clean;
        }
        
        if (!mSongToken->nSentence)
        {
            mSongToken->pSentenceToken = NULL;
            error = YES;
            goto clean;
        } 
        else 
        {
            mSentenses = mSongToken->nSentence;
            mSongToken->pSentenceToken = (SentenceToken*)malloc(mSongToken->nSentence * sizeof(SentenceToken));
            if (!mSongToken->pSentenceToken) 
            {
                error = YES;
                goto clean;
            }
            memset(mSongToken->pSentenceToken, 0, mSongToken->nSentence * sizeof(SentenceToken));
        }
        
        int i, j, k;
        for (i = 0; i < mSongToken->nSentence; i++)
        {
            if (fread((char*)&mSongToken->pSentenceToken[i].nStartTime, sizeof(uint32_t), 1, fin) != 1)
            {
                error = YES;
                goto clean;
            }
            
            if (fread((char*)&mSongToken->pSentenceToken[i].nDuration, sizeof(uint16_t), 1, fin) != 1) 
            {
                error = YES;
                goto clean;
            }
            
            if (fread((char*)&mSongToken->pSentenceToken[i].nWord, sizeof(uint16_t), 1, fin) != 1) 
            {
                error = YES;
                goto clean;
            }
            
            if (!mSongToken->pSentenceToken[i].nWord)
            {
                mSongToken->pSentenceToken[i].pWordToken = NULL;
            } 
            else 
            {
                mSongToken->pSentenceToken[i].pWordToken =
                (WordToken*)malloc(mSongToken->pSentenceToken[i].nWord * sizeof(WordToken));
                if (!mSongToken->pSentenceToken[i].pWordToken) 
                {
                    error = YES;
                    goto clean;
                }
                memset(mSongToken->pSentenceToken[i].pWordToken, 0, mSongToken->pSentenceToken[i].nWord * sizeof(WordToken));
            }
            
            for (j = 0; j < mSongToken->pSentenceToken[i].nWord; j++) 
            {
                if (fread((char*)&mSongToken->pSentenceToken[i].pWordToken[j].nTone, sizeof(uint16_t), 1, fin) != 1) 
                {
                    error = YES;
                    goto clean;
                }
                
                if (!mSongToken->pSentenceToken[i].pWordToken[j].nTone)
                {
                    mSongToken->pSentenceToken[i].pWordToken[j].pToneToken = NULL;
                } 
                else
                {
                    mSongToken->pSentenceToken[i].pWordToken[j].pToneToken =
                    (ToneToken*)malloc(mSongToken->pSentenceToken[i].pWordToken[j].nTone * sizeof(ToneToken));
                    if (!mSongToken->pSentenceToken[i].pWordToken[j].pToneToken) 
                    {
                        error = YES;
                        goto clean;
                    }
                    memset(mSongToken->pSentenceToken[i].pWordToken[j].pToneToken, 0,
                           mSongToken->pSentenceToken[i].pWordToken[j].nTone * sizeof(ToneToken));
                }
                for (k = 0; k < mSongToken->pSentenceToken[i].pWordToken[j].nTone; k++) 
                {
                    if (fread((char*)&mSongToken->pSentenceToken[i].pWordToken[j].pToneToken[k].nPitch, sizeof(uint16_t), 1, fin) != 1) 
                    {
                        error = YES;
                        goto clean;
                    }
                    
                    if (fread((char*)&mSongToken->pSentenceToken[i].pWordToken[j].pToneToken[k].nDuration, sizeof(uint16_t), 1, fin) != 1)
                    {
                        error = YES;
                        goto clean;
                    }
                }
            }
        }
    }

clean:
    if (NULL != fin)
    {
        fclose(fin);
        fin = NULL;
    }
    
    if (hasFile)
    {
        if (error)
        {
            loadsuccess = NO;
        }
        else
        {
            loadsuccess = YES;
        }
    }
    
    mLoading = NO;
    if (loadsuccess)
    {
        [self performSelectorOnMainThread:@selector(loadTokensSuccess) withObject:nil waitUntilDone:NO];
    }
    else
    {
        [self performSelectorOnMainThread:@selector(loadTokensFailed) withObject:nil waitUntilDone:NO];
    }
    [pool release];
}

- (void)loadTokensFailed
{
    [self cleanLoadThread];
    [self destoryTokens];
    [self reportError:EvaluatorLoadTokensFailed];
}

- (void)loadTokensSuccess
{
    [self cleanLoadThread];
    NSInteger status = [self configTokens];
    QKLog(@"configTokens status = %x",status);
    [self destoryTokens];
    if(EvaluatorNoError == status)
    {
        [self reportReadyToEvaluate];
    }
    else
    {
        [self reportError:EvaluatorHandleInitFailed];
    }
}

- (void)destoryTokens
{
    if(NULL != mSongToken)
    {
        int i, j;
        if (NULL != mSongToken->pSentenceToken)
        {
            for (i = 0; i < mSongToken->nSentence; ++i) 
            {
                if (NULL != mSongToken->pSentenceToken[i].pWordToken) 
                {
                    for (j = 0; j < mSongToken->pSentenceToken[i].nWord; j++)
                    {
                        if (NULL != mSongToken->pSentenceToken[i].pWordToken[j].pToneToken) 
                        {
                            free(mSongToken->pSentenceToken[i].pWordToken[j].pToneToken);
                            mSongToken->pSentenceToken[i].pWordToken[j].pToneToken = NULL;
                        }
                    }
                    
                    free(mSongToken->pSentenceToken[i].pWordToken);
                    mSongToken->pSentenceToken[i].pWordToken = NULL;
                }
            }
            
            free(mSongToken->pSentenceToken);
            mSongToken->pSentenceToken = NULL;
        }
        
        free(mSongToken);
        mSongToken = NULL;
    }
}

- (void)cleanLoadThread
{
    if (nil != mInternalLoadTokenThread)
    {
        mCancelLoad = YES;
        [mInternalLoadTokenThread cancel];
        while (mLoading) 
        {
            [NSThread sleepForTimeInterval:0.01];
        }
        [mInternalLoadTokenThread release];
        mInternalLoadTokenThread = nil;
    }
}

- (NSInteger)configTokens
{
    if (NULL != mSingHandle)
    {
        if (NULL != mSongToken)
        {
            int status = evalSing_InitEvalObj(mSingHandle, mSongToken);
            return status;
        }
        return EvaluatorLoadTokensFailed;
    }
    return EvaluatorHandleInValid;
}

- (void)createAndStartProcessingThread
{
    if (nil == mInternalProcessingThread) 
    {
        NSAssert([[NSThread currentThread] isEqual:[NSThread mainThread]],
                 @"create processing thread can only be started from the main thread.");
        
        mInternalProcessingThread =[[NSThread alloc] initWithTarget:self 
                                                           selector:@selector(processingThreadProc) 
                                                             object:nil];
        mIsInternalThreadShouldExit = NO;
        mInternalThreadRunning = YES;
        [mInternalProcessingThread start];
    }
}

- (void)runStep
{
    int status = evalSing_RunStep(mSingHandle);
    
    if(EvalSing_RESULT == status)
    {
        [self performSelectorOnMainThread:@selector(onResultAvaliable) withObject:nil waitUntilDone:NO];
    }
}

- (void)cancelThread
{
    mIsInternalThreadShouldExit = YES;
}

- (void)processingThreadProc
{
    [NSThread setThreadPriority:1.1];
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    
    // .......................................................
    // add a dummy port
    NSRunLoop *runLoop = [NSRunLoop currentRunLoop];
    NSMachPort *dummyPort = [[NSMachPort alloc] init];	
    [runLoop addPort:dummyPort forMode:NSDefaultRunLoopMode];
    [dummyPort release];
    
    while (!mIsInternalThreadShouldExit
           && ![[NSThread currentThread] isCancelled])
    {
        [runLoop runMode:NSDefaultRunLoopMode beforeDate:[NSDate distantFuture]];
    }
    mInternalThreadRunning = NO;
    [pool release];
}

- (void)cleanProcessingThread
{
    if (nil != mInternalProcessingThread)
    {
        [self performSelector:@selector(cancelThread) onThread:mInternalProcessingThread withObject:nil waitUntilDone:YES];
        // wait until reading processing thread exit
        while (mInternalThreadRunning)
        {
            [NSThread sleepForTimeInterval:0.01];
        }
        [mInternalProcessingThread release];
        mInternalProcessingThread = nil;
    }
}

- (void)onResultAvaliable
{
    if (NULL != mSingHandle && !mHaveResultingScore) 
    {
        int status;
        SingOutputToken result;
        status = evalSing_GetResult(mSingHandle, &result);
        
         if (EvalSing_OK == status
             || EvalSing_VOLUMEHIGH == status
             || EvalSing_VOLUMELOW == status)
         {
             if (nil != self.evaluateDelegate) 
             {
                 AmplitudeType amplitude = AmplitudeNormal;
                 switch (status) 
                 {
                     case EvalSing_VOLUMEHIGH:
                         amplitude = AmplitudeHigh;
                         break;
                     case EvalSing_VOLUMELOW:
                         amplitude = AmplitudeLow;
                         break;
                         
                     default:
                         amplitude = AmplitudeNormal;
                         break;
                 }
                 
                 EvaluateResultType resultType = EvaluateResultTypeSentense;
                 if (EvalSing_TONE_TYPE_SENTENCE == result.nType) 
                 {
                     result.nScore = [self processSentenceResult:result.nScore];
                     [mSentenseScoreArray addObject:[NSNumber numberWithShort:result.nScore]];
                     resultType = EvaluateResultTypeSentense;
                 }
                 else if(EvalSing_TONE_TYPE_ALL == result.nType)
                 {
                     result.nScore = [self processAllResult:result.nScore];
                     mResultingScore = result.nScore;
                     mHaveResultingScore = YES;
                     resultType = EvaluateResultTypeAll;
                     [self cleanProcessingThread];
                 }
                 
                 QKLog(@"result, type: %d, score: %d, index : %d", resultType, result.nScore, result.nIndex);

                 if (self.evaluateDelegate 
                     && [self.evaluateDelegate respondsToSelector:@selector(evaluateResult:withType:tokenIndex:amplitudeType:)])
                 {
                     [self.evaluateDelegate evaluateResult:result.nScore withType:resultType tokenIndex:result.nIndex amplitudeType:amplitude];
                 }
             }
         }
    }
}

- (NSUInteger)processSentenceResult:(NSUInteger)result
{
//    if (result > 25 && result <= 40)
//    {
//        result += 30;
//    }
//    else if (result > 41 && result <= 60)
//    {
//        result += 20;
//    }
//    else if (result > 61 && result <= 70)
//    {
//        result += 10;
//    }
//    else if (result > 71 && result <= 80)
//    {
//        result += 5;
//    }
    return result;
}

- (NSUInteger)processAllResult:(NSUInteger)result
{
//    if (result > 25 && result <= 40)
//    {
//        result += 30;
//    }
//    else if (result > 41 && result <= 60)
//    {
//        result += 20;
//    }
//    else if (result > 61 && result <= 70)
//    {
//        result += 10;
//    }
//    else if (result > 71 && result <= 80)
//    {
//        result += 5;
//    }
    return result;
}

- (void)cleanSentenceScoreArray
{
    mHaveResultingScore = NO;
    if (nil != mSentenseScoreArray) 
    {
        [mSentenseScoreArray removeAllObjects];
        [mSentenseScoreArray release];
        mSentenseScoreArray = nil;
    }
}

- (void)clear
{
    [self forceEndEvaluate];
    [self cleanLoadThread];
    [self destoryTokens];
    [self cleanProcessingThread];
}

- (void)cleanAndReset
{
    // release resource & reset
    [self forceEndEvaluate];
    [self cleanLoadThread];
    [self destoryTokens];
    [self cleanProcessingThread];
    [self cleanSentenceScoreArray];
}

- (void)reportError:(EvaluatorErrorType)error
{
    if (EvaluatorNoError != error)
    {
        mErrorType = error;
        
        if (self.evaluateDelegate 
            && [self.evaluateDelegate respondsToSelector:@selector(audioEvaluatorFailedToEvaluate:error:)]) 
        {
            [self.evaluateDelegate audioEvaluatorFailedToEvaluate:self error:mErrorType];
        }
    }
}

- (void)reportReadyToEvaluate
{
    if (self.evaluateDelegate
        && [self.evaluateDelegate respondsToSelector:@selector(audioEvaluatorReadyToEvaluate:)]) 
    {
        [self.evaluateDelegate audioEvaluatorReadyToEvaluate:self];
    }
}
@end
