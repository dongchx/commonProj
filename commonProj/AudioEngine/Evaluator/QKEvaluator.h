//
//  QKEvaluator.h
//  QQKala
//
//  Created by frost on 12-8-21.
//  Copyright (c) 2012年 Tencent. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "sing_api.h"
#import "AudioCommonDefine.h"

#define EVAL_OUT_OF_MEMORY          (0x80001001)
@class QKAudioTrack;
@protocol QKAudioEvaluatorDelegate;

enum 
{
    EvaluatorNoError = 0,
    EvaluatorHandleInValid,
    EvaluatorLoadTokensFailed,
    EvaluatorInvalidSampleRate,
    EvaluatorHandleInitFailed
};
typedef NSInteger EvaluatorErrorType;

@interface QKEvaluator : NSObject
{
    SING_HANDLE                         mSingHandle;
    id<QKAudioEvaluatorDelegate>          mEvaluateDelegate;
    
    NSThread                            *mInternalLoadTokenThread;
    BOOL                                mLoading;
    BOOL                                mCancelLoad;
    SongToken                           *mSongToken;
    NSInteger                           mSentenses;
    
    NSThread                            *mInternalProcessingThread;
    BOOL                                mInternalThreadRunning;
    BOOL                                mIsInternalThreadShouldExit;
    
    NSMutableArray                      *mSentenseScoreArray;
    int                                 mResultingScore;
    BOOL                                mHaveResultingScore;
    EvaluatorErrorType                  mErrorType;
}

@property (nonatomic, assign)id<QKAudioEvaluatorDelegate>     evaluateDelegate;
@property (nonatomic, readonly)NSMutableArray               *sentenseScoreArray;
@property (nonatomic, readonly)int                          resultingScore;
@property (nonatomic, readonly)BOOL                         haveResultingScore;
@property (nonatomic, readonly)BOOL                         isAllEvaluated;

- (void)createAndConfigEvaluator:(NSString*)tokenFilePath sampleRate:(UInt32)sampleRate;

- (NSInteger)appendData:(char*)data numSamples:(int)numSamples;
- (void)startEvaluate;
- (NSInteger)forceEndEvaluate;
- (void)clear;
- (void)cleanAndReset;

@end


// QKAudioEvaluatorDelegate Protocol
@protocol QKAudioEvaluatorDelegate <NSObject>

- (void)audioEvaluatorReadyToEvaluate:(QKEvaluator*)audioEvaluator;

- (void)audioEvaluatorFailedToEvaluate:(QKEvaluator*)audioEvaluator error:(EvaluatorErrorType)error;

- (void)evaluateResult:(NSInteger)score withType:(EvaluateResultType)type tokenIndex:(NSInteger)index amplitudeType:(AmplitudeType)amplitudeType;
@end
