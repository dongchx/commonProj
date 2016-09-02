//
//  QKAudioUnitOutputRecorder.h
//  QQKala
//
//  Created by frost on 12-7-9.
//  Copyright (c) 2012年 frost. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AudioToolbox/AudioToolbox.h>

@interface QKAudioUnitOutputRecorder : NSObject
{
    BOOL                mFileOpen;
    BOOL                mClientFormatSet;
    BOOL                mIsStart;
    AudioUnit           mAudioUnit;
    NSString            *mOutputFilePath;
    @public
    ExtAudioFileRef     mOutputFileRef;
    UInt32              mBusNumber;
}
@property (nonatomic, readonly, retain)NSString         *outputFilePath;

- (id)initWithAudioUnit:(AudioUnit)au outputFilePath:(NSString*)filePath audioFileTypeID:(AudioFileTypeID)fileType audioFormat:(AudioStreamBasicDescription)format busNumber:(UInt32)busNumber;

- (void)start;
- (void)stop;
- (void)close;

@end
