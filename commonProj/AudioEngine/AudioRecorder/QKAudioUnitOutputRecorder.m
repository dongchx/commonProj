//
//  QKAudioUnitOutputRecorder.m
//  QQKala
//
//  Created by frost on 12-7-9.
//  Copyright (c) 2012年 __MyCompanyName__. All rights reserved.
//

#import "QKAudioUnitOutputRecorder.h"


// ---------------------------------------------
// forward declaration
// ---------------------------------------------
static OSStatus renderNotificationCallback(
                                           void						*inRefCon, 
                                           AudioUnitRenderActionFlags 	*ioActionFlags, 
                                           const AudioTimeStamp 		*inTimeStamp, 
                                           UInt32 						inBusNumber, 
                                           UInt32 						inNumberFrames, 
                                           AudioBufferList 			*ioData);

// ---------------------------------------------
// QKAudioUnitOutputRecorder private category
// ---------------------------------------------
@interface QKAudioUnitOutputRecorder()
@property (nonatomic, readwrite, retain)NSString        *outputFilePath;
@end

@implementation QKAudioUnitOutputRecorder
@synthesize outputFilePath = mOutputFilePath;

#pragma mark life cycle
- (id)initWithAudioUnit:(AudioUnit)au outputFilePath:(NSString*)filePath audioFileTypeID:(AudioFileTypeID)fileType audioFormat:(AudioStreamBasicDescription)format busNumber:(UInt32)busNumber
{
    if ( !(self = [super init]) ) return nil;
    
    mAudioUnit = au;
    self.outputFilePath = filePath;
    mBusNumber = busNumber;
    
    CFURLRef url = CFURLCreateWithFileSystemPath(NULL, (CFStringRef)self.outputFilePath, kCFURLPOSIXPathStyle, false);
    OSStatus err = ExtAudioFileCreateWithURL(url, fileType, &format, NULL, kAudioFileFlags_EraseFile, &mOutputFileRef);
    CFRelease(url);
    if (noErr == err)
    {
        mFileOpen = YES;
    }
    return self;
}

- (void)dealloc
{
    self.outputFilePath = nil;
    [self close];
    [super dealloc];
}

#pragma mark public function
- (void)start
{
    if (mFileOpen && !mIsStart)
    {
        if (!mClientFormatSet)
        {
            AudioStreamBasicDescription clientFormat;
            UInt32 size = sizeof(clientFormat);
            AudioUnitGetProperty(mAudioUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Output, mBusNumber, &clientFormat, &size);
            ExtAudioFileSetProperty(mOutputFileRef, kExtAudioFileProperty_ClientDataFormat, size, &clientFormat);
            mClientFormatSet = YES;
        }
        
        ExtAudioFileWriteAsync(mOutputFileRef, 0, NULL);
        AudioUnitAddRenderNotify(mAudioUnit, renderNotificationCallback, self);
        mIsStart = YES;
    }
}

- (void)stop
{
    if (mFileOpen && mIsStart)
    {
        AudioUnitRemoveRenderNotify(mAudioUnit, renderNotificationCallback, self);
        mIsStart = NO;
    }
}

- (void)close
{
    if (NULL != mOutputFileRef)
    {
        ExtAudioFileDispose(mOutputFileRef);
        mOutputFileRef = NULL;
    }
}  
@end

// ---------------------------------------------
// render notification callback
// ---------------------------------------------
static OSStatus renderNotificationCallback(
                                           void						*inRefCon, 
                                           AudioUnitRenderActionFlags 	*ioActionFlags, 
                                           const AudioTimeStamp 		*inTimeStamp, 
                                           UInt32 						inBusNumber, 
                                           UInt32 						inNumberFrames, 
                                           AudioBufferList 			*ioData)
{
    if (*ioActionFlags & kAudioUnitRenderAction_PostRender)
    {
        QKAudioUnitOutputRecorder* recorder = (QKAudioUnitOutputRecorder*)inRefCon;
        if (recorder->mBusNumber == inBusNumber)
        {
            ExtAudioFileWriteAsync(recorder->mOutputFileRef, inNumberFrames, ioData);
        }
    }
    return noErr;
}
