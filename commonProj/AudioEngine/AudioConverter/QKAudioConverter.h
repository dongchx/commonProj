//
//  QKAudioConverter.h
//  QQKala
//
//  Created by frost on 12-6-6.
//  Copyright (c) 2012年 Tencent. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AudioToolbox/AudioToolbox.h>
#import "AudioCommonDefine.h"
//#import <AudioToolbox/ExtendedAudioFile.h>



@protocol QKAudioConverterDelegate;


@interface QKAudioConverter : NSObject
{
    @private
    id<QKAudioConverterDelegate>    mDelegate;
    NSString                        *mSource;
    NSString                        *mDestination;
    AudioStreamBasicDescription     mAudioFormat;
    
    UInt32                          mFormatID;
    AudioSampleRate                 mSampleRate;
    AudioFileTypeID                 mFileTypeID;
    BOOL                            mProcessing;
    BOOL                            mCancelled;
    BOOL                            mInterrupted;
    BOOL                            mDeleteOnSucc;
    NSCondition                     *mCondition;
    NSThread                        *mInternalProcessingThread;
    UInt32                          mPriorMixOverrideValue;
}

@property (nonatomic, assign) id<QKAudioConverterDelegate>          delegate;
@property (nonatomic, readonly, retain) NSString                    *source;
@property (nonatomic, readonly, retain) NSString                    *destination;
@property (nonatomic, readonly, assign) AudioStreamBasicDescription audioFormat;

// check if aac converter avaliable or not, since iPhone 3gs, aac codec is avaliable.
+ (BOOL)isAACConverterAvaliable;

- (id)initWithSource:(NSString*)sourcePath destination:(NSString*)destinationPath;

// convert
- (BOOL)convertToAudioFormat:(UInt32)formatID audioSampleRate:(AudioSampleRate)sampleRate audioFileType:(AudioFileTypeID)audioFileTypeID deleteOnSuccess:(BOOL)delOnSucc;

- (BOOL)isWorking;

// cancel convert
- (void)cancel;

// Util methods that invoke convertTo with
// commonly used arguments. Handy for converting
// to a caff or a IMA4 compressed caff file.

+ (OSStatus) convertToCaff:(NSString*)inPath
				   outPath:(NSString*)outPath;

+ (OSStatus) convertToCaff:(NSString*)inPath
				   outPath:(NSString*)outPath
			   numChannels:(NSInteger)numChannels;

+ (OSStatus) convertToIMA4Caff:(NSString*)inPath
					   outPath:(NSString*)outPath;
+ (OSStatus) convertToIMA4Caff:(NSString*)inPath
					   outPath:(NSString*)outPath
				   numChannels:(NSInteger)numChannels;

+ (OSStatus) convertToALACCaff:(NSString*)inPath
					   outPath:(NSString*)outPath;

+ (OSStatus) convertToALACCaff:(NSString*)inPath
					   outPath:(NSString*)outPath
				   numChannels:(NSInteger)numChannels;

+ (OSStatus) convertToAACCaff:(NSString*)inPath
                      outPath:(NSString*)outPath;

+ (OSStatus) convertToAACCaff:(NSString*)inPath
                      outPath:(NSString*)outPath
                  numChannels:(NSInteger)numChannels;

+ (OSStatus) convertToAACM4A:(NSString*)inPath
                     outPath:(NSString*)outPath;

+ (OSStatus) convertToAACM4A:(NSString*)inPath
                     outPath:(NSString*)outPath
                 numChannels:(NSInteger)numChannels;

// Convert from the input file type to the type indicated by the
// audioFileTypeID and mFormatID arguments. Currently, only
// the values kAudioFormatLinearPCM and kAudioFormatAppleIMA4
// are supported for the mFormatID argument. The audioFileTypeID
// is typically kAudioFileCAFType, but other formats like
// kAudioFileWAVEType will also work. If 2 is passed for numChannels
// and the input file is mono, then a stereo file is created
// by duplicating the mono data in each stereo track. If 1 is passed
// for numChannels and the input file is stereo, then a mono file
// is created from *only* the left channel, a mix of the right and left
// channels is not possible with this API.

+ (OSStatus) convertTo:(NSString*)inPath
			   outPath:(NSString*)outPath
	   audioFileTypeID:(AudioFileTypeID)audioFileTypeID
			 mFormatID:(UInt32)mFormatID
		   numChannels:(NSInteger)numChannels;

// Return string that describes a result code

+ (NSString*) commonExtAudioResultCode:(OSStatus)code;

// Lookup type of audio data contained inside a caff file

+ (OSStatus) getCaffAudioFormatID:(NSString*)filePath fileFormatIDPtr:(UInt32*)fileFormatIDPtr;

// Returns TRUE if type of audio inside caff file is ALAC (apple lossless)

+ (BOOL) isALACAudioFormat:(NSString*)filePath;
@end

// QKAudioConverterDelegate Protocol
@protocol QKAudioConverterDelegate <NSObject>

- (void)audioConverterdidFinishConversion:(QKAudioConverter*)audioConverter;
- (void)audioConverter:(QKAudioConverter*)audioConverter didFailWithError:(NSError*)error;

@optional
- (void)audioConverter:(QKAudioConverter *)audioConverter didMakeProgress:(CGFloat)progress;
@end
