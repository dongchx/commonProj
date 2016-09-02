//
//  AudioCommonDefine.h
//  QQKala
//
//  Created by frost on 12-6-6.
//  Copyright (c) 2012年 Tencent. All rights reserved.
//

#ifndef QQKala_AudioCommonDefine_h
#define QQKala_AudioCommonDefine_h

#import "TPCircularBuffer.h"
#import "AudioCommonUtil.h"

#define NUM_QUEUE_BUFFERS 3

#define LOG_QUEUED_BUFFERS 0

#define kNumAQBufs 16			// Number of audio queue buffers we allocate.
// Needs to be big enough to keep audio pipeline
// busy (non-zero number of queued buffers) but
// not so big that audio takes too long to begin
// (kNumAQBufs * kAQBufSize of data must be
// loaded before playback will start).
//
// Set LOG_QUEUED_BUFFERS to 1 to log how many
// buffers are queued at any time -- if it drops
// to zero too often, this value may need to
// increase. Min 3, typical 8-24.

#define kAQDefaultBufSize 2048	// Number of bytes in each audio queue buffer
// Needs to be big enough to hold a packet of
// audio from the audio file. If number is too
// large, queuing of audio before playback starts
// will take too long.
// Highly compressed files can use smaller
// numbers (512 or less). 2048 should hold all
// but the largest packets. A buffer size error
// will occur if this number is too small.

#define kAQMaxPacketDescs 512	// Number of packet descriptions in our array

#define BitRateEstimationMaxPackets 5000
#define BitRateEstimationMinPackets 50

#define kAudioBufferLength              65536       // 64K
#define kAudioBufferLengthPerReading    32768       // 32K
#define kProcessingBufferTotalLenght    882000       // 640K
#define kBufferLengthToProcess          44100        // 44K


// Data structure for mono or stereo sound, to pass to the application's render callback function, 
//    which gets invoked by a Mixer unit input bus when it needs more audio to play.
typedef struct
{
    
    BOOL                 isStereo;           // set to true if there is data in the audioDataRight member
    UInt64               frameCount;         // the total number of frames in the audio data
    UInt64               sampleNumber;       // the next audio sample to play
    
    TPCircularBuffer    audioBufferLeft;
    TPCircularBuffer    audioBufferRight;
    
} SoundStruct, *SoundStructPtr;

typedef struct
{
    UInt8               major;
    UInt8               minor;
    UInt16              revision;
    UInt16              branch;
} VersionStruct, *VersionStructPtr;

/**/
enum 
{
    SoundChannelLeft = 0,
    SoundChannelRight
};
typedef NSInteger SoundChannel;

/* Audio Sample Rate*/
enum 
{
    AudioSampleRate8K  = 8000,      // 8000HZ
    AudioSampleRate11K = 11025,     // 11025HZ
    AudioSampleRate16K = 16000,     // 16000HZ
    AudioSampleRate22K = 22050,     // 22050HZ
    AudioSampleRate32K = 32000,     // 32000HZ
    AudioSampleRate44K = 44100      // 44100HZ
};
typedef NSUInteger AudioSampleRate;

/* QKSingEngine error type*/
enum  {
    QKAudioFileCopyFailedError,
    
    // below are Synthesize error code
    QKSynthesizeSourceInvObjError,
    QKSynthesizeSourceNotExistError,
    QKSynthesizeDestinationInvObjError,
    QKSynthesizeDestinationCopyFailedError,
    
    // below are Audio converter error code
    QKAudioConverterSourceFileNotExistError,
    QKAudioConverterSourceFileError,
    QKAudioConverterSourceFileReadError,
    QKAudioConverterDestinationFileCreateError,
    QKAudioConverterDestinationFileWriteError,
    QKAudioConverterFormatError,
    QKAudioConverterInvalidDestinationFormat,
    QKAudioConverterUnrecoverableInterruptionError,
    QKAudioConverterInitializationError
};

/* Player event . */
enum 
{
    PlayEventAudioTrackChanged,
    PlayEventBegin,
    PlayEventEnd,
    PlayEventProcessComplete,
    PlayEventError,
    PlayEventStateChanged,
    PlayEventBuffering,
    PlayEventBufferingFinish,
    PlayEventRenameFinish,
    PlayEventErrorOfNoFile
};
typedef NSInteger PlayEventType;


/* Play Mode . */
enum 
{
    PlayModeOne,
    PlayModeOneCycle,
    PlayModeList,
    PlayModeListCycle,
    PlayModeListShuffle,
    PlayModeListShuffleCycle
};
typedef NSInteger PlayMode;

/* Audio Track Type */
enum 
{
	AudioTrackTypeNetwork,
	AudioTrackTypeAccompanimentFile,  // 伴奏文件
	AudioTrackTypeSynthesizedFile,    // 合成音频文件
	AudioTractTypeUnknown
};
typedef NSInteger AudioTrackType;

enum 
{
    EvaluateResultTypeTone,
    EvaluateResultTypeSentense,
    EvaluateResultTypeAll
};
typedef NSInteger EvaluateResultType;

enum  
{
    AmplitudeNormal,
    AmplitudeHigh,
    AmplitudeLow
};
typedef NSInteger AmplitudeType;

/* Audio Stream State*/
typedef enum
{
	AS_INITIALIZED = 0,
	AS_STARTING_FILE_THREAD,
	AS_WAITING_FOR_DATA,
	AS_FLUSHING_EOF,
	AS_WAITING_FOR_QUEUE_TO_START,
	AS_PLAYING,
    AS_PLAYING_AND_RECORDING,
	AS_BUFFERING,
	AS_STOPPING,
	AS_STOPPED,
	AS_PAUSED
} AudioStreamerState;

/* Audio Stream Stop Reason*/
typedef enum
{
	AS_NO_STOP = 0,
	AS_STOPPING_EOF,
	AS_STOPPING_USER_ACTION,
	AS_STOPPING_ERROR,
	AS_STOPPING_TEMPORARILY,
	AS_STOPPING_NO_DATA,
} AudioStreamerStopReason;

/* Audio Stream Error Code*/
typedef enum
{
	AS_NO_ERROR = 0,
	AS_NETWORK_CONNECTION_FAILED,
	AS_FILE_STREAM_GET_PROPERTY_FAILED,
	AS_FILE_STREAM_SEEK_FAILED,
	AS_FILE_STREAM_PARSE_BYTES_FAILED,
	AS_FILE_STREAM_OPEN_FAILED,
	AS_FILE_STREAM_CLOSE_FAILED,
    AS_AU_GRAPH_CREATION_FAILED,
    AS_AU_GRAPH_RECORD_FAILED,
    AS_AU_GRAPH_START_FAILED,
    AS_AU_GRAPH_PAUSE_FAILED,
    AS_AU_GRAPH_STOP_FAILED,
	AS_AUDIO_DATA_NOT_FOUND,
	AS_AUDIO_QUEUE_CREATION_FAILED,
	AS_AUDIO_QUEUE_BUFFER_ALLOCATION_FAILED,
	AS_AUDIO_QUEUE_ENQUEUE_FAILED,
	AS_AUDIO_QUEUE_ADD_LISTENER_FAILED,
	AS_AUDIO_QUEUE_REMOVE_LISTENER_FAILED,
	AS_AUDIO_QUEUE_START_FAILED,
	AS_AUDIO_QUEUE_PAUSE_FAILED,
	AS_AUDIO_QUEUE_BUFFER_MISMATCH,
	AS_AUDIO_QUEUE_DISPOSE_FAILED,
	AS_AUDIO_QUEUE_STOP_FAILED,
	AS_AUDIO_QUEUE_FLUSH_FAILED,
	AS_AUDIO_STREAMER_FAILED,
	AS_GET_AUDIO_TIME_FAILED,
	AS_AUDIO_BUFFER_TOO_SMALL
} AudioStreamerErrorCode;

// post when state changed
extern NSString *const ASStatusChangedNotification;

// post when audio session is beging interruption, like a phone call coming
extern NSString *const kAudioSessionBeginInterruptionNotification;

// post when audio session end interruption.
extern NSString *const kAudioSessionEndInterruptionNotification;

// post when Headset plugin.
extern NSString *const kAudioRouteHeadSetPlugin;

// post when Headset plugout.
extern NSString *const kAudioRouteHeadSetPlugout;

// Unknown Audio Route
extern NSString *const kAudioRouteUnknown;

// post when volume changed.
extern NSString *const kVolumeChangedNotification;

// Error domains
extern NSString *const AudioConverterErrorDomain;
extern NSString *const AudioMixerErrorDomain;
extern NSString *const QKSingEngineErrorDomain;
#endif
