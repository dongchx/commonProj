//
//  QKSingEngine.m
//  QQKala
//
//  Created by frost on 12-6-20.
//  Copyright (c) 2012年 Tencent. All rights reserved.
//

#import "QKSingEngine.h"
#import "AudioEngineHelper.h"
#import "QKMultichannelAudioPlayer.h"
#import "QKFileMixerAudioPlayer.h"
#import "QKFileAudioPlayer.h"
#import "QKNetAudioPlayer.h"
#import "QKAUAudioPlayer.h"
#import "QKEvaluator.h"
#import "FileUtility.h"
#import "NSDate+Date2String.h"
#import "ASBDUtility.h"
#import "QKReverbEffect.h"
#import "QKReverbEffect2.h"
#import "PublicConfig.h"

// ---------------------------------------------
// varaiable declaration
// ---------------------------------------------
static QKSingEngine* s_singEngine_Instance = nil;
static NSString* kUnderLine = @"_";
const SoundChannel kAccompanimentChannel = SoundChannelRight;
const UInt64 kCriticalSpace = 100 * 1024 * 1024;    // 100MB
NSString *const QKSingEngineErrorDomain = @"com.tencent.QKSingEngineErrorDomain";
NSString *const QKSingSynthesizeErrorDomain = @"com.tencent.QKSingSynthesizeErrorDomain";

static ReverbEffectParam g_reverb_effects[] = {
    {3,{85, 100,120},200},
    {3,{50, 75, 100},200},
    {3,{75, 105,185},300},
    {3,{120,150,180},300},
    {3,{120,140,160},400},
    {3,{130,150,170},400},
    {3,{140,170,200},400},
    {3,{170,200,240},400},
    {3,{120,140,160},500},
    {3,{130,150,170},500}};

static const NSUInteger kReverEffectCount = sizeof(g_reverb_effects) / sizeof(ReverbEffectParam);
static const NSUInteger kDefaultReverbEffectIndex = 9;

// ---------------------------------------------
// QKSingEngineDelegateHolder class
// ---------------------------------------------
@interface QKSingEngineDelegateHolder : NSObject 
{
@private
    id<QKSingEngineDelegate>               _delegate;
}
@property (nonatomic, assign) id<QKSingEngineDelegate> delegate;
@end

@implementation QKSingEngineDelegateHolder
@synthesize delegate = _delegate;
@end

// ---------------------------------------------
// AudioEngineHelper private category
// ---------------------------------------------
@interface QKSingEngine()
@property (nonatomic, readwrite, retain)QKAudioTrack     *currentAudioTrack;
@property (nonatomic, readwrite, retain)QKAudioTrack     *synthesizeSourceAudioTrack;
@property (nonatomic, readwrite, retain)NSString         *currentRecordFilePath;
@property (nonatomic, readwrite, retain)NSString         *currentOutputFilePath;

- (void)registerNotifications;
- (void)unRegisterNotifications;
- (void)onInterruptStart;
- (void)onInterruptEnd;
- (void)startBackgroundTask;
- (void)onHeadSetPlugedin;
- (void)onHeadSetPlugedout;
- (void)onPlaybackStateChanged:(id)notification;
- (NSString*)generateRecordFileNameForAudioTrack:(QKAudioTrack*)audioTrack;
- (NSString*)generateOutputFileNameForAudioTrack:(QKAudioTrack*)audioTrack;
- (NSString*)generateMixFileNameForAudioTrack:(QKAudioTrack*)audioTrack;
- (void)releaseAudioPlayer;
- (NSUInteger)getReverbEffectIndex;

/* QKSingEngineDelegate Callback */
- (void)onVolumeChanged:(NSNotification*)notification;
- (void)onPlayEventChanged:(PlayEventType)type description:(NSString*)desc;
- (void)onDiskSpaceLessThan:(UInt64)spaceInBytes toSingAudioTrack:(QKAudioTrack*)audioTrack;
- (void)onFailedToSing:(QKAudioTrack*)audioTrack error:(NSInteger)error;
- (void)onProcessAudioTrackComplete:(QKAudioTrack*)audioTrack;

/* QKSingSynthesizeDelegate Callback */
- (void)onSynthesizeAudioTrack:(QKAudioTrack*)audioTrack didFinishWithOutput:(QKAudioTrack*)output;
- (void)onSynthesizeAudioTrack:(QKAudioTrack*)audioTrack didFailWithError:(NSInteger)errorCode;
- (void)onSynthesizeAudioTrack:(QKAudioTrack*)audioTrack didMakeProgress:(CGFloat)progress;
@end


// ---------------------------------------------
// QKSingEngine implementation
// ---------------------------------------------
@implementation QKSingEngine
@synthesize currentAudioTrack = mCurrentAudioTrack;
@synthesize synthesizeSourceAudioTrack = mSynthesizeSourceAudioTrack;
@synthesize evaluateDelegate = mEvaluateDelagate;
@synthesize synthesizeDelegate = mSynthesizeDelegate;
@synthesize currentRecordFilePath = mCurrentRecordFilePath;
@synthesize currentOutputFilePath = mCurrentOutputFilePath;
@synthesize criticalSpace = mCriticalSpace;

+ (QKSingEngine*)sharedInstance
{
    if (nil == s_singEngine_Instance) 
    {
        @synchronized(self)
        {
            if (nil == s_singEngine_Instance) 
            {
                s_singEngine_Instance = [[self alloc]init];
            }
        }
    }
	return s_singEngine_Instance;
}

#pragma mark life cycle

- (id)init
{
    self = [super init];
	if (self) 
	{
        mDelegates = [[NSMutableArray alloc] initWithCapacity:8];
        self.criticalSpace = kCriticalSpace;
        [self setReverbEffectIndex:kDefaultReverbEffectIndex];
        [self registerNotifications];
        [AudioEngineHelper sharedInstance].delegate = self;
	}
	return self;
}

- (void)dealloc
{
    [self unRegisterNotifications];
    self.currentAudioTrack = nil;
    self.synthesizeSourceAudioTrack = nil;
    self.currentRecordFilePath = nil;
    self.currentOutputFilePath = nil;
    [mSynthesizeDestinationAudioTrack release];
    [mAudioPlayer release];
    [mEvaluator release];
    [mSynthesizeProcessor release];
    [mOutputConverter release];
    
    [self removeAllSingEngineDelegates];
    [mDelegates release];
    [super dealloc];
}

#pragma mark delegate API
- (void)addSingEngineDelegate:(id<QKSingEngineDelegate>)delegate
{
    QKSingEngineDelegateHolder *dHolder = [[QKSingEngineDelegateHolder alloc] init];
    dHolder.delegate = delegate;
    [mDelegates addObject:dHolder];
    [dHolder release];
}

- (void)removeSingEngineDelegate:(id<QKSingEngineDelegate>)delegate
{
    if (nil != mDelegates) 
    {
        for (int i = 0, count = [mDelegates count]; i < count; ++i) 
        {
            QKSingEngineDelegateHolder *dHolder = [mDelegates objectAtIndex:i];
            if (delegate == dHolder.delegate) 
            {
                [mDelegates removeObject:dHolder];
                break;
            }
        }
    }
}

- (void)removeAllSingEngineDelegates
{
    if (mDelegates && [mDelegates count]>0) 
    {
        [mDelegates removeAllObjects];
    }
}

#pragma mark core API
- (void)singAudioTrack:(QKAudioTrack*)audioTrack
{
    // only accompaniment file can be used to sing
    if (nil != audioTrack 
        && AudioTrackTypeAccompanimentFile == audioTrack.type) 
    {
        //............................................................................
        // Prepare.
        // check & set right audio category
        [[AudioEngineHelper sharedInstance] checkAudioCategoryForPlayAndRecord];
        
        // retain the audio track object
        self.currentAudioTrack = audioTrack;
        
        // release resource
        [self releaseAudioPlayer];
        
        // check if has enough space to generate recording file
        UInt64 freeCachesSpace = [FileUtility getFreeSpaceInBytes];
        if (freeCachesSpace < self.criticalSpace) 
        {
            [self onDiskSpaceLessThan:self.criticalSpace toSingAudioTrack:self.currentAudioTrack];
            return;
        }

        // check the file exist
        if (![FileUtility isFileExistAtPath:self.currentAudioTrack.filePath])
        {
            [self onPlayEventChanged:PlayEventErrorOfNoFile description:nil];
            return;
        }
        
        // prepare file name for recording voic
        NSString* recordFileName = [self generateRecordFileNameForAudioTrack:audioTrack];
        NSString* recordFilePath = [FileUtility getfilePathInCachesDirectoryFromFileName:recordFileName];
        self.currentRecordFilePath = recordFilePath;
        
        // prepare output file name for output
        NSString* outputFileName = [self generateOutputFileNameForAudioTrack:audioTrack];
        NSString* outputFilePath = [FileUtility getfilePathInCachesDirectoryFromFileName:outputFileName];
        self.currentOutputFilePath = outputFilePath;
        
        //............................................................................
        // get the right audio player
        mAudioPlayer = [[QKMultichannelAudioPlayer alloc] initWithAudioFile:self.currentAudioTrack.filePath recordFilePath:self.currentRecordFilePath];
        mAudioPlayer.delegate = self;
        
        // error handle
        if (nil == mAudioPlayer)
        {
            [self onPlayEventChanged:PlayEventError description:nil];
            return;
        }
        
        // adjust multichannel audio player
        QKMultichannelAudioPlayer *multichannelAudioPlayer = (QKMultichannelAudioPlayer*)mAudioPlayer;
        [multichannelAudioPlayer setAccompanimentChannel:kAccompanimentChannel];
        [multichannelAudioPlayer changeAudioBusGain:1.0];
        if (![[AudioEngineHelper sharedInstance] hasHeadSet]) 
        {
            [multichannelAudioPlayer enableVoiceInputBus:NO];
        }
        
        mCurrentSampleRate = [multichannelAudioPlayer getRecordFormat].mSampleRate;
        
        //............................................................................
        // processor
        [mSynthesizeProcessor release];
        mSynthesizeProcessor = [[QKAudioSynthesizeProcessor alloc] init];
        mSynthesizeProcessor.delegate = self;
        
        // config processor
        AudioStreamBasicDescription playerOutputASBD = [multichannelAudioPlayer getOutputFormat];
        AudioFileTypeID fileType = kAudioFileCAFType;
        [ASBDUtility setASBD:&mOutputFormat formatID:kAudioFormatLinearPCM numChannels:2 sampleRate:playerOutputASBD.mSampleRate];
//        mOutputFormat = playerOutputASBD;
        [mSynthesizeProcessor configOutputFile:self.currentOutputFilePath fileType:fileType destinationASBD:mOutputFormat clientASBD:playerOutputASBD];

        // set audio effect
        
        QKAudioEffect *audioEffect = nil;
#if 1
        NSUInteger reverbIndex = [self getReverbEffectIndex];
        audioEffect = [[QKReverbEffect alloc] initWithReverbTime:g_reverb_effects[reverbIndex].reverbTime numDelays:g_reverb_effects[reverbIndex].delays delayTimes:g_reverb_effects[reverbIndex].delayTimes inSignalSampleRate:mCurrentSampleRate];
#else
        audioEffect = [[QKReverbEffect2 alloc] initWithChannels:1 inSignalSampleRate:mCurrentSampleRate];
#endif
        mSynthesizeProcessor.useEffectForSource1 = YES;
        [mSynthesizeProcessor setAudioEffectForSource1:audioEffect];
        [audioEffect release];
        
        // Assgin audio processor for multichannelAudioPlayer
        multichannelAudioPlayer.audioProcessor = mSynthesizeProcessor;

        //............................................................................
        // evaluator
        [mEvaluator release];      // release if necessary
        mEvaluator = [[QKEvaluator alloc] init];
        mEvaluator.evaluateDelegate = self;
        [mEvaluator createAndConfigEvaluator:audioTrack.tokenFilePath sampleRate:mCurrentSampleRate];
        
        //............................................................................
        // waiting to play
    }
}

- (void)reSing
{
    [self releaseAudioPlayer];
    
    if (nil != mSynthesizeProcessor)
    {
        [mSynthesizeProcessor cancelProcess];
    }
    
    if (nil != self.currentAudioTrack)
    {
        [self singAudioTrack:self.currentAudioTrack];
    }
}

- (void)playback
{
    if (nil != mSynthesizeProcessor)
    {
        [mSynthesizeProcessor cancelProcess];
    }
    
    if (nil != self.currentAudioTrack
        && nil != self.currentOutputFilePath) 
    {
        // check & set right audio category
        [[AudioEngineHelper sharedInstance] resetAudioCategoryForPlayOnly];
        
        // release resource
        [self releaseAudioPlayer];
        
        if (![FileUtility isFileExistAtPath:self.currentOutputFilePath])
        {
            [self onPlayEventChanged:PlayEventErrorOfNoFile description:nil];
            return;
        }
        
        // get the right audio player
//        mAudioPlayer = [[QKFileAudioPlayer alloc] initWithFilePath:self.currentOutputFilePath];
        mAudioPlayer = [[QKAUAudioPlayer alloc] initWithAudioFile:self.currentOutputFilePath];
        mAudioPlayer.delegate = self;
        
        // error handle
        if (nil == mAudioPlayer)
        {
            [self onPlayEventChanged:PlayEventError description:nil];
            return;
        }
        
        // play
        [mAudioPlayer play];
        [self startBackgroundTask];
        [self onPlayEventChanged:PlayEventAudioTrackChanged description:nil];
    }
}

- (void)playAudioTrack:(QKAudioTrack*)audioTrack
{
    if (nil != audioTrack) 
    {
        // check & set right audio category
        [[AudioEngineHelper sharedInstance] resetAudioCategoryForPlayOnly];
        
        // retain the audio track object
        self.currentAudioTrack = audioTrack;
        
        // release resource
        [self releaseAudioPlayer];
        
        // get the right audio player
        switch (audioTrack.type)
        {
            case AudioTrackTypeNetwork:
                mAudioPlayer = [[QKNetAudioPlayer alloc] initWithNetURL:self.currentAudioTrack.url];
                mAudioPlayer.delegate = self;
                break;
                
            case AudioTrackTypeAccompanimentFile:
                if (![FileUtility isFileExistAtPath:self.currentAudioTrack.filePath])
                {
                    [self onPlayEventChanged:PlayEventErrorOfNoFile description:nil];                 
                    return;
                }
                mAudioPlayer = [[QKFileAudioPlayer alloc] initWithFilePath:self.currentAudioTrack.filePath];
                mAudioPlayer.delegate = self;
                break;
                
            case AudioTrackTypeSynthesizedFile:
                if (![FileUtility isFileExistAtPath:self.currentAudioTrack.filePath])
                {
                    [self onPlayEventChanged:PlayEventErrorOfNoFile description:nil]; 
                    return;
                }
                mAudioPlayer = [[QKFileAudioPlayer alloc] initWithFilePath:self.currentAudioTrack.filePath];
                mAudioPlayer.delegate = self;
                break;
                
            default:
                break;
        }
        
        // error handle
        if (nil == mAudioPlayer)
        {
            [self onPlayEventChanged:PlayEventError description:nil];
            return;
        }
        
        // play
        [mAudioPlayer play];
        [self startBackgroundTask];
        [self onPlayEventChanged:PlayEventAudioTrackChanged description:nil];
    }
}

- (BOOL)isSinging
{
    if (mIsSinging
        && nil != mAudioPlayer
        && [mAudioPlayer isKindOfClass:[QKMultichannelAudioPlayer class]]
        /*&& mAudioPlayer.state == AS_PLAYING_AND_RECORDING*/)
    {
        return YES;
    }
    return NO;
}


#pragma mark processing API
- (void)synthesizeAudioTrack:(QKAudioTrack*)audioTrack outPutFilePath:(NSString*)filePath
{
    if (nil != audioTrack)
    {
        // retain the audio track to mix
        self.synthesizeSourceAudioTrack = audioTrack;
        
        // cancel process if necessary
        if (nil != mSynthesizeProcessor)
        {
            [mSynthesizeProcessor cancelProcess];
        }
        
        if ([FileUtility isFileExistAtPath:self.currentOutputFilePath]) 
        {
            if (mOutputConverter)
            {
                [mOutputConverter release];
                mOutputConverter = nil;
            }
            
            if (nil != filePath)
            {
                // generate synthesize audio track
                if (mSynthesizeDestinationAudioTrack) 
                {
                    [mSynthesizeDestinationAudioTrack release];
                }
                mSynthesizeDestinationAudioTrack = [[QKAudioTrack alloc] init];
                mSynthesizeDestinationAudioTrack.type = AudioTrackTypeSynthesizedFile;
                mSynthesizeDestinationAudioTrack.musicID = self.synthesizeSourceAudioTrack.musicID;
                mSynthesizeDestinationAudioTrack.songName = self.synthesizeSourceAudioTrack.songName;
                mSynthesizeDestinationAudioTrack.artistName = self.synthesizeSourceAudioTrack.artistName;
                mSynthesizeDestinationAudioTrack.albumName = self.synthesizeSourceAudioTrack.albumName;
                mSynthesizeDestinationAudioTrack.filePath = filePath;
                
                

                if (mOutputFormat.mFormatID == kAudioFormatMPEG4AAC)
                {
                    BOOL suc = [FileUtility copyFileFrom:self.currentOutputFilePath toDestinationPath:filePath];

                    if(suc)
                    {
                        [self onSynthesizeAudioTrack:self.synthesizeSourceAudioTrack didFinishWithOutput:mSynthesizeDestinationAudioTrack];
                    }
                    else
                    {
                        [self onSynthesizeAudioTrack:self.synthesizeSourceAudioTrack didFailWithError:QKSynthesizeDestinationCopyFailedError];
                    }
                }
                else
                {
                    // initialize converts to convert
                    mOutputConverter = [[QKAudioConverter alloc] initWithSource:self.currentOutputFilePath destination:filePath];
                    mOutputConverter.delegate = self;
                    
                    
                    // start to convert outputFile
                    [mOutputConverter convertToAudioFormat:kAudioFormatAppleIMA4 audioSampleRate:mCurrentSampleRate audioFileType:kAudioFileCAFType deleteOnSuccess:NO];
                }
            }
            else
            {
                [self onSynthesizeAudioTrack:audioTrack didFailWithError:QKSynthesizeDestinationInvObjError];
            }
        }
        else
        {
            [self onSynthesizeAudioTrack:audioTrack didFailWithError:QKSynthesizeSourceNotExistError];
        }
    }
    else
    {
        [self onSynthesizeAudioTrack:audioTrack didFailWithError:QKSynthesizeSourceInvObjError];
    }
}

- (void)cancelSynthesize
{
    if (nil != mOutputConverter)
    {
        // cancel
        [mOutputConverter cancel];
        
        // reset
        [mOutputConverter release];
        mOutputConverter = nil;
    }
    
    self.synthesizeSourceAudioTrack = nil;
    
    // delete files if necessary
    if (nil != mSynthesizeDestinationAudioTrack)
    {
        [FileUtility removeItemAtPath:mSynthesizeDestinationAudioTrack.filePath];
        [FileUtility removeItemAtPath:mSynthesizeDestinationAudioTrack.recordFilePath];
        [mSynthesizeDestinationAudioTrack release];
        mSynthesizeDestinationAudioTrack = nil;
    }
    
}
#pragma mark universal API
- (AudioStreamerErrorCode)currentError
{
    if (nil != mAudioPlayer) 
	{
		return mAudioPlayer.errorCode;
	}
    return AS_NO_ERROR;
}

- (AudioStreamerState)currentState
{
    if (nil != mAudioPlayer) 
	{
		return mAudioPlayer.state;
	}
    return AS_INITIALIZED;
}

- (void)pause
{
    if (nil != mAudioPlayer) 
	{
		[ mAudioPlayer pause];
	}
}

- (void)resume
{
    if (nil != mAudioPlayer) 
	{
		[ mAudioPlayer resume];
	}
}

- (void)stop
{
    if (nil != mAudioPlayer)
    {
        [mAudioPlayer stop];
        
        if ([mAudioPlayer isKindOfClass:[QKMultichannelAudioPlayer class]])
        {
            mIsSinging = NO;
            if (nil != mEvaluator)
            {
                [mEvaluator clear];
            }
        }
    }
}

- (float)volume
{
    return [[AudioEngineHelper sharedInstance] currentVolume];
}

- (void)setVolume:(float)volume
{
    if (nil != mAudioPlayer) 
	{
		[ mAudioPlayer setVolume:volume];
	}
}

- (BOOL)isPlaying
{
    if (nil != mAudioPlayer)
    {
        return [mAudioPlayer isPlaying];
    }
    return NO;
}

- (BOOL)isRecording
{
    if (nil != mAudioPlayer &&
        [mAudioPlayer isKindOfClass:[QKMultichannelAudioPlayer class]])
    {
        return mAudioPlayer.state == AS_PLAYING_AND_RECORDING;
    }
    return NO;
}

- (void)seekToTime:(double)second
{
    if (nil != mAudioPlayer)
    {
        if ([mAudioPlayer isSeekable]) 
        {
            [mAudioPlayer seekToTime:second];
        }
    }
}

- (double)progressTime
{
    if (nil != mAudioPlayer)
    {
        return [mAudioPlayer progress];
    }
    return 0.0;
}

- (double)durationTime
{
    if (nil != mAudioPlayer)
    {
        return [mAudioPlayer duration];
    }
    return 0.0;
}

#pragma mark Audio Effect API
- (NSUInteger)getReverbEffectCount
{
    return kReverEffectCount;
}

- (void)setReverbEffectIndex:(NSUInteger)index
{
    if (index < kReverEffectCount)
    {
        mReverbEffectIndex = index;
    }
}

- (NSUInteger)getReverbEffectIndex
{
    if (mReverbEffectIndex < kReverEffectCount)
    {
        return mReverbEffectIndex;
    }
    return 0;
}

#pragma mark multi channel control API

- (void)switchToOriginal:(BOOL)isOriginal
{
    if (nil != mAudioPlayer &&
        [mAudioPlayer isKindOfClass:[QKMultichannelAudioPlayer class]])
    {
        SoundChannel channel = SoundChannelLeft;
        if (isOriginal)
        {
            channel = (kAccompanimentChannel == SoundChannelLeft) ? SoundChannelRight : SoundChannelLeft;
        }
        else
        {
            channel = (kAccompanimentChannel == SoundChannelLeft) ? SoundChannelLeft : SoundChannelRight;
        }
        
        QKMultichannelAudioPlayer *multichannelAudioPlayer = (QKMultichannelAudioPlayer*)mAudioPlayer;
        [multichannelAudioPlayer switchAudioChannel:channel];
    }
}

- (BOOL)isOriginal
{
    BOOL isOriginal = NO;
    if (nil != mAudioPlayer &&
        [mAudioPlayer isKindOfClass:[QKMultichannelAudioPlayer class]])
    {
        QKMultichannelAudioPlayer *multichannelAudioPlayer = (QKMultichannelAudioPlayer*)mAudioPlayer;
        isOriginal = !([multichannelAudioPlayer getCurrentAudioChannel] == kAccompanimentChannel);
    }
    return isOriginal;
}

- (void)switchAudioChannel:(SoundChannel)channel
{
    if (nil != mAudioPlayer &&
        [mAudioPlayer isKindOfClass:[QKMultichannelAudioPlayer class]])
    {
        QKMultichannelAudioPlayer *multichannelAudioPlayer = (QKMultichannelAudioPlayer*)mAudioPlayer;
        [multichannelAudioPlayer switchAudioChannel:channel];
    }
}

- (SoundChannel)getCurrentAudioChannel
{
    if (nil != mAudioPlayer &&
        [mAudioPlayer isKindOfClass:[QKMultichannelAudioPlayer class]])
    {
        QKMultichannelAudioPlayer *multichannelAudioPlayer = (QKMultichannelAudioPlayer*)mAudioPlayer;
        return [multichannelAudioPlayer getCurrentAudioChannel];
    }
    return SoundChannelLeft;
}

- (void)enableVoiceInputBus:(BOOL)enable
{
    if (nil != mAudioPlayer &&
        [mAudioPlayer isKindOfClass:[QKMultichannelAudioPlayer class]])
    {
        QKMultichannelAudioPlayer *multichannelAudioPlayer = (QKMultichannelAudioPlayer*)mAudioPlayer;
        [multichannelAudioPlayer enableVoiceInputBus:enable];
    }
}

- (void)changeVoiceInputBusGain:(Float32)gain
{
    if (nil != mAudioPlayer &&
        [mAudioPlayer isKindOfClass:[QKMultichannelAudioPlayer class]])
    {
        QKMultichannelAudioPlayer *multichannelAudioPlayer = (QKMultichannelAudioPlayer*)mAudioPlayer;
        [multichannelAudioPlayer changeVoiceInputBusGain:gain];
    }
}

- (Float32)getVoiceInputBusGain
{
    if (nil != mAudioPlayer &&
        [mAudioPlayer isKindOfClass:[QKMultichannelAudioPlayer class]])
    {
        QKMultichannelAudioPlayer *multichannelAudioPlayer = (QKMultichannelAudioPlayer*)mAudioPlayer;
        return [multichannelAudioPlayer getVoiceInputBusGain];
    }
    return 0.0;
}

- (void)changeAudioBusGain:(Float32)gain
{
    if (nil != mAudioPlayer &&
        [mAudioPlayer isKindOfClass:[QKMultichannelAudioPlayer class]])
    {
        QKMultichannelAudioPlayer *multichannelAudioPlayer = (QKMultichannelAudioPlayer*)mAudioPlayer;
        [multichannelAudioPlayer changeAudioBusGain:gain];
    }
}

- (Float32)getAudioBusGain
{
    if (nil != mAudioPlayer &&
        [mAudioPlayer isKindOfClass:[QKMultichannelAudioPlayer class]])
    {
        QKMultichannelAudioPlayer *multichannelAudioPlayer = (QKMultichannelAudioPlayer*)mAudioPlayer;
        return [multichannelAudioPlayer getAudioBusGain];
    }
    return 0.0;
}

- (void)changeOputGain:(Float32)gain
{
    if (nil != mAudioPlayer &&
        [mAudioPlayer isKindOfClass:[QKMultichannelAudioPlayer class]])
    {
        QKMultichannelAudioPlayer *multichannelAudioPlayer = (QKMultichannelAudioPlayer*)mAudioPlayer;
        [multichannelAudioPlayer changeOputGain:gain];
    }
}
#pragma mark evaluate API

- (BOOL)getCurrentPitch:(short*)outPitch
{
//    if (nil != mAiSing)
//    {
//        return [mAiSing getCurrentPitch:outPitch];
//    }
    return NO;
}

- (BOOL)getResultingScore:(NSInteger*)outScore
{
    if (nil != mEvaluator
        && mEvaluator.haveResultingScore)
    {
        if (NULL != outScore) 
        {
            *outScore = (NSInteger)mEvaluator.resultingScore;
        }
        return YES;
    }
    return NO;
}

- (NSArray*)getSentenceScores
{
    if (nil != mEvaluator)
    {
        return mEvaluator.sentenseScoreArray;
    }
    return nil;
}

- (NSArray*)getToneScores
{
    //TODO
//    if (nil != mEvaluator)
//    {
//        return mAiSing.toneScoreArray;
//    }
    return nil;
}

- (BOOL)isAllEvaluated
{
    if (nil != mEvaluator)
    {
        return mEvaluator.isAllEvaluated;
    }
    return NO;
}

#pragma mark QKAudioEvaluatorDelegate
- (void)audioEvaluatorReadyToEvaluate:(QKEvaluator*)audioEvaluator
{
    //............................................................................
    // play
    if (mAudioPlayer &&
        [mAudioPlayer isKindOfClass:[QKMultichannelAudioPlayer class]])
    {
        QKMultichannelAudioPlayer *multichannelAudioPlayer = (QKMultichannelAudioPlayer*)mAudioPlayer;
        multichannelAudioPlayer.evaluator = mEvaluator;
        
        [mSynthesizeProcessor startThreadToProcess];
        [mAudioPlayer play];
        [mEvaluator startEvaluate];
        [self onPlayEventChanged:PlayEventAudioTrackChanged description:nil];
    }
}

- (void)audioEvaluatorFailedToEvaluate:(QKEvaluator*)audioEvaluator error:(EvaluatorErrorType)error
{
    QKLog(@"audioEvaluatorFailedToEvaluate error= %d", error);
    [self onFailedToSing:self.currentAudioTrack error:FailedToStartEvaluator];
    
    if (mAudioPlayer &&
        [mAudioPlayer isKindOfClass:[QKMultichannelAudioPlayer class]])
    {
        [mEvaluator release];
        mEvaluator = nil;
        
        [mSynthesizeProcessor startThreadToProcess];
        [mAudioPlayer play];
        [self onPlayEventChanged:PlayEventAudioTrackChanged description:nil];
    }
}

- (void)evaluateResult:(NSInteger)score withType:(EvaluateResultType)type tokenIndex:(NSInteger)index amplitudeType:(AmplitudeType)amplitudeType
{
    if (mEvaluateDelagate 
        && [mEvaluateDelagate respondsToSelector:@selector(evaluateResult:withType:tokenIndex:amplitudeType:)])
    {
        [mEvaluateDelagate evaluateResult:score withType:type tokenIndex:index amplitudeType:amplitudeType];
    }
}
#pragma mark private category

- (void)registerNotifications
{
    [[NSNotificationCenter defaultCenter] addObserver:self	
                                             selector:@selector(onHeadSetPlugedin)	 
                                                 name:kAudioRouteHeadSetPlugin 
                                               object:nil];
	
    [[NSNotificationCenter defaultCenter] addObserver:self	
                                             selector:@selector(onHeadSetPlugedout)	 
                                                 name:kAudioRouteHeadSetPlugout 
                                               object:nil];	
    
    [[NSNotificationCenter defaultCenter] addObserver:self	
                                             selector:@selector(onVolumeChanged:)	 
                                                 name:kVolumeChangedNotification 
                                               object:nil];
}

- (void)unRegisterNotifications
{
    [[NSNotificationCenter defaultCenter] removeObserver: self   
                                                    name: kAudioRouteHeadSetPlugin	
                                                  object: nil];
    
    [[NSNotificationCenter defaultCenter] removeObserver: self 
                                                    name: kAudioRouteHeadSetPlugout	
                                                  object: nil];
    
    [[NSNotificationCenter defaultCenter] removeObserver: self 
                                                    name: kVolumeChangedNotification	
                                                  object: nil];
}

- (void)startBackgroundTask
{
    if (![UIDevice currentDevice].multitaskingSupported)
    {
        return;
    }
    
    NSUInteger newTaskId = UIBackgroundTaskInvalid;
	newTaskId = [[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler:^
    { 
		if ( mBgTaskId != UIBackgroundTaskInvalid )
        {
			[[UIApplication sharedApplication] endBackgroundTask:mBgTaskId]; 
        }
		mBgTaskId = UIBackgroundTaskInvalid;
	} ];
	
	if (newTaskId != UIBackgroundTaskInvalid && mBgTaskId != UIBackgroundTaskInvalid)
    {
		[[UIApplication sharedApplication] endBackgroundTask: mBgTaskId];
    }
	mBgTaskId = newTaskId;
}

- (void)onHeadSetPlugedin
{
    [self enableVoiceInputBus:YES];
}

- (void)onHeadSetPlugedout
{
    [self pause];
    [self enableVoiceInputBus:NO];
}

- (void)onPlaybackStateChanged:(id)notification
{
    NSNotification* note = (NSNotification*)notification;
	QKBaseAudioPlayer *player = (QKBaseAudioPlayer *)[note object];
    switch (player.state)
    {
        case AS_STOPPED:
            if ([player isKindOfClass:[QKMultichannelAudioPlayer class]])
            {
            }
            break;
        default:
            break;
    }
}

- (NSString*)generateRecordFileNameForAudioTrack:(QKAudioTrack*)audioTrack
{
    return @"recordFile.caf";
}

- (NSString*)generateOutputFileNameForAudioTrack:(QKAudioTrack*)audioTrack
{
    return @"outputFile.caf";
}

- (NSString*)generateMixFileNameForAudioTrack:(QKAudioTrack*)audioTrack
{
    NSMutableString* fileName = [[NSMutableString alloc] init];
	[fileName appendString:audioTrack.musicID];
    [fileName appendString:kUnderLine];
    NSString* currentDateString = [[NSDate date] toString];
    [fileName appendString:currentDateString];
    [fileName appendString:@".m4a"];
	return [fileName autorelease]; 
}

- (void)releaseAudioPlayer
{
    if (nil != mAudioPlayer) 
    {
        if (AS_INITIALIZED != mAudioPlayer.state) 
		{
			[self stop];
		}
        [mAudioPlayer release];
		mAudioPlayer = nil;
    }
}

#pragma mark PlayerDelegate
- (void)player:(id<QKPlayerProtocol>)player playerEventChanged:(PlayEventType)type description:(NSString*)desc
{
    if (player != mAudioPlayer) return;
    
    // post
    [self onPlayEventChanged:type description:desc];
}

#pragma mark QKAudioConverterDelegate Callback
- (void)audioConverterdidFinishConversion:(QKAudioConverter*)audioConverter
{
    if (mOutputConverter == audioConverter)
    {
        if (nil != mSynthesizeDestinationAudioTrack) 
        {
            mSynthesizeDestinationAudioTrack.filePath = audioConverter.destination;
        }
        
        // send success message to delegate
        [self onSynthesizeAudioTrack:self.synthesizeSourceAudioTrack didFinishWithOutput:mSynthesizeDestinationAudioTrack];
        
        [mSynthesizeDestinationAudioTrack release];
        mSynthesizeDestinationAudioTrack = nil;
        self.synthesizeSourceAudioTrack = nil;
        [mOutputConverter release];
        mOutputConverter = nil;
    }
}

- (void)audioConverter:(QKAudioConverter*)audioConverter didFailWithError:(NSError*)error
{
    if (mOutputConverter == audioConverter)
    {
        // send failed message to delegate
        [self onSynthesizeAudioTrack:self.synthesizeSourceAudioTrack didFailWithError:[error code]];
        
        // clean
        if (nil != mSynthesizeDestinationAudioTrack) 
        {
            [FileUtility removeItemAtPath:mSynthesizeDestinationAudioTrack.filePath];
            [mSynthesizeDestinationAudioTrack release];
            mSynthesizeDestinationAudioTrack = nil;
        }
        self.synthesizeSourceAudioTrack = nil;
        [mOutputConverter release];
        mOutputConverter = nil;
    }
}

- (void)audioConverter:(QKAudioConverter *)audioConverter didMakeProgress:(CGFloat)progress
{
    [self onSynthesizeAudioTrack:self.synthesizeSourceAudioTrack didMakeProgress:progress];
}

#pragma mark QKAudioProcessorDelegate Callback
- (void)audioProcessor:(QKAudioSynthesizeProcessor*)audioProcessor didFinishWithFinishType:(AudioProcessorFinishType)type
{
    [self onProcessAudioTrackComplete:self.currentAudioTrack];
}

- (void)audioProcessor:(QKAudioSynthesizeProcessor*)audioProcessor didFailWithError:(NSError*)error
{
    
}

#pragma mark QKSingEngineDelegate
- (void)onVolumeChanged:(NSNotification*)notification
{
    NSNumber* number = (NSNumber*)[notification object];
    float volume = [number floatValue];
    
    if (mDelegates && [mDelegates count]>0) 
    {
        for (QKSingEngineDelegateHolder* holder in mDelegates) 
        {
            if (nil != holder.delegate 
                && [holder.delegate conformsToProtocol:@protocol(QKSingEngineDelegate)] 
                && [holder.delegate respondsToSelector:@selector(onVolumeChanged:)]) 
            {
                [holder.delegate onVolumeChanged:volume];
            }
        }
    }
}
- (void)onPlayEventChanged:(PlayEventType)type description:(NSString*)desc
{
    if (mDelegates && [mDelegates count]>0) 
    {
        for (QKSingEngineDelegateHolder* holder in mDelegates) 
        {
            if (nil != holder.delegate 
                && [holder.delegate conformsToProtocol:@protocol(QKSingEngineDelegate)] 
                && [holder.delegate respondsToSelector:@selector(playEventChanged:description:)]) 
            {
                [holder.delegate playEventChanged:type description:desc];
            }
        }
    }
    
    // handle specified event
    switch (type) 
	{
        case PlayEventAudioTrackChanged:
            if (nil != mAudioPlayer &&
                [mAudioPlayer isKindOfClass:[QKMultichannelAudioPlayer class]])
            {
                mIsSinging = YES;
            }
            else
            {
                mIsSinging = NO;
            }
            break;
        case PlayEventBegin:
            break;
            
		case PlayEventEnd:
        {
            if (nil != mAudioPlayer &&
                [mAudioPlayer isKindOfClass:[QKMultichannelAudioPlayer class]])
            {
                mIsSinging = NO;
                if (nil != mEvaluator)
                {
                    // release AiSing object resource
                    [mEvaluator clear];
                }
            }
        }
			break;
		case PlayEventBuffering:
            
			break;
		case PlayEventBufferingFinish:
            
			break;
		case PlayEventRenameFinish:
            
			break;
		case PlayEventError:
            
			break;
		case PlayEventStateChanged:
			break;
            
		case PlayEventErrorOfNoFile:
			break;
            
		default:
			break;
	}
}

- (void)onDiskSpaceLessThan:(UInt64)spaceInBytes toSingAudioTrack:(QKAudioTrack*)audioTrack
{
    if (mDelegates && [mDelegates count]>0) 
    {
        for (QKSingEngineDelegateHolder* holder in mDelegates) 
        {
            if (nil != holder.delegate 
                && [holder.delegate conformsToProtocol:@protocol(QKSingEngineDelegate)] 
                && [holder.delegate respondsToSelector:@selector(diskSpaceLessThan:toSingAudioTrack:)]) 
            {
                [holder.delegate diskSpaceLessThan:spaceInBytes toSingAudioTrack:audioTrack];
            }
        }
    }
}

- (void)onFailedToSing:(QKAudioTrack*)audioTrack error:(NSInteger)error
{
    if (mDelegates && [mDelegates count]>0) 
    {
        for (QKSingEngineDelegateHolder* holder in mDelegates) 
        {
            if (nil != holder.delegate 
                && [holder.delegate conformsToProtocol:@protocol(QKSingEngineDelegate)] 
                && [holder.delegate respondsToSelector:@selector(failedToSingAudioTrack:error:)]) 
            {
                [holder.delegate failedToSingAudioTrack:audioTrack error:error];
            }
        }
    }
}

- (void)onProcessAudioTrackComplete:(QKAudioTrack*)audioTrack
{
    if (mDelegates && [mDelegates count]>0) 
    {
        for (QKSingEngineDelegateHolder* holder in mDelegates) 
        {
            if (nil != holder.delegate 
                && [holder.delegate conformsToProtocol:@protocol(QKSingEngineDelegate)] 
                && [holder.delegate respondsToSelector:@selector(processAudioTrackComplete:)]) 
            {
                [holder.delegate processAudioTrackComplete:audioTrack];
            }
        }
    }
}

#pragma mark QKSingSynthesizeDelegate
- (void)onSynthesizeAudioTrack:(QKAudioTrack*)audioTrack didFinishWithOutput:(QKAudioTrack*)output
{
    if (nil != self.synthesizeDelegate && [self.synthesizeDelegate respondsToSelector:@selector(synthesizeAudioTrack:didFinishWithOutput:)])
    {
        [self.synthesizeDelegate synthesizeAudioTrack:audioTrack didFinishWithOutput:output];
    }
}

- (void)onSynthesizeAudioTrack:(QKAudioTrack*)audioTrack didFailWithError:(NSInteger)errorCode
{
    if (nil != self.synthesizeDelegate && [self.synthesizeDelegate respondsToSelector:@selector(synthesizeAudioTrack:didFailWithError:)])
    {
        NSError *error = [[NSError alloc] initWithDomain:QKSingSynthesizeErrorDomain code:errorCode userInfo:nil];
        [self.synthesizeDelegate synthesizeAudioTrack:audioTrack didFailWithError:error];
        [error release];
    }
}

- (void)onSynthesizeAudioTrack:(QKAudioTrack*)audioTrack didMakeProgress:(CGFloat)progress
{
    if (nil != self.synthesizeDelegate && [self.synthesizeDelegate respondsToSelector:@selector(synthesizeAudioTrack:didMakeProgress:)])
    {
        [self.synthesizeDelegate synthesizeAudioTrack:audioTrack didMakeProgress:progress];
    }
}

#pragma mark AudioEngineHelperDelegate
- (void)beginInterruption
{
    AudioEngineHelper *audioEngineHelper = [AudioEngineHelper sharedInstance];
    [audioEngineHelper setAudioSessionActive:false];
    mShouldStopOnInterrupt = [audioEngineHelper shouldStopOnInterrupt];
    
    if ([self isPlaying])
    {
        [self pause];
        mNeedResume = YES;
    }
    else
    {
        mNeedResume = NO;
    }
}

- (void)endInterruptionWithFlags:(NSUInteger)flags
{
    AudioEngineHelper *audioEngineHelper = [AudioEngineHelper sharedInstance];
    [audioEngineHelper setAudioSessionActive:false];
    OSStatus err = [audioEngineHelper setAudioSessionActive:true];

    if (mNeedResume && noErr == err)
    {
        [self resume];
    }

    mNeedResume = NO;
    mShouldStopOnInterrupt = NO;
}
@end
