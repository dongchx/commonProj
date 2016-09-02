//
//  ASBDUtility.m
//  QQKala
//
//  Created by frost on 12-6-6.
//  Copyright (c) 2012年 Tencent. All rights reserved.
//

#import "PublicConfig.h"
#import "ASBDUtility.h"

@implementation ASBDUtility

+ (void)setASBD:(AudioStreamBasicDescription*)audioFormatPtr formatID:(UInt32) formatID numChannels:(NSUInteger)numChannels sampleRate:(UInt32)sampleRate
{
    if (NULL != audioFormatPtr)
    {
        bzero(audioFormatPtr, sizeof(AudioStreamBasicDescription));
        
        audioFormatPtr->mFormatID = formatID;
        switch (formatID) 
        {
            case kAudioFormatLinearPCM:
            {
                audioFormatPtr->mFormatFlags = kAudioFormatFlagsNativeEndian |kLinearPCMFormatFlagIsSignedInteger | kLinearPCMFormatFlagIsPacked;
                audioFormatPtr->mBitsPerChannel = 16;
                audioFormatPtr->mChannelsPerFrame = numChannels;
                audioFormatPtr->mFramesPerPacket = 1;
                audioFormatPtr->mBytesPerPacket = audioFormatPtr->mBytesPerFrame = (audioFormatPtr->mBitsPerChannel / 8) * audioFormatPtr->mChannelsPerFrame;
                audioFormatPtr->mSampleRate = sampleRate;//44100.0
                
                break;
            }
            case kAudioFormatALaw:
            case kAudioFormatULaw:
            {
                audioFormatPtr->mFormatFlags = 0;
                audioFormatPtr->mBitsPerChannel = 8;
                audioFormatPtr->mChannelsPerFrame = 1;
                audioFormatPtr->mFramesPerPacket = 1;
                audioFormatPtr->mBytesPerPacket = 1;
                audioFormatPtr->mBytesPerFrame = 1;
                audioFormatPtr->mSampleRate = 8000.0;
                break;
            }
            case kAudioFormatAppleIMA4:
            {
                audioFormatPtr->mFormatFlags = 0;
                audioFormatPtr->mBitsPerChannel = 0;
                audioFormatPtr->mChannelsPerFrame = numChannels;        // 1
                audioFormatPtr->mFramesPerPacket = 64;
                audioFormatPtr->mBytesPerPacket = 68;
                audioFormatPtr->mSampleRate = sampleRate;
                break;
            }
            case kAudioFormatAppleLossless:
            {
                audioFormatPtr->mFormatFlags = 0;
                audioFormatPtr->mBitsPerChannel = 0;
                audioFormatPtr->mChannelsPerFrame = 1;
                audioFormatPtr->mFramesPerPacket = 4096;
                audioFormatPtr->mBytesPerPacket = 0;
                audioFormatPtr->mBytesPerFrame = 0;
                audioFormatPtr->mSampleRate = sampleRate;
                break;
            }
            case kAudioFormatMPEG4AAC:
            {
                audioFormatPtr->mFormatFlags = kMPEG4Object_AAC_Main;
                audioFormatPtr->mBitsPerChannel = 0;
                audioFormatPtr->mChannelsPerFrame = numChannels;    // 1
                audioFormatPtr->mFramesPerPacket = 1024;
                audioFormatPtr->mBytesPerPacket = 0;
                audioFormatPtr->mSampleRate = sampleRate;
                break;
            }
            default:
                break;
        }
    }
}

+ (void)setCanonical:(AudioStreamBasicDescription*)audioFormatPtr numChannels:(NSUInteger)numChannels sampleRate:(UInt32)sampleRate isInterleaved:(BOOL)isInterleaved
{
    if (NULL != audioFormatPtr) 
    {
        bzero(audioFormatPtr, sizeof(AudioStreamBasicDescription));
        
        size_t bytesPerSample = sizeof (AudioSampleType);
        
        audioFormatPtr->mFormatID          = kAudioFormatLinearPCM;
        audioFormatPtr->mFormatFlags       = kAudioFormatFlagsCanonical;
        audioFormatPtr->mFramesPerPacket   = 1;
        audioFormatPtr->mBytesPerFrame     = bytesPerSample;
        audioFormatPtr->mChannelsPerFrame  = numChannels;   // 1 indicates mono, 2 stereo
        audioFormatPtr->mBitsPerChannel    = 8 * bytesPerSample;
        audioFormatPtr->mSampleRate        = sampleRate;
        
        if (isInterleaved)
        {
            audioFormatPtr->mBytesPerPacket = audioFormatPtr->mBytesPerFrame = numChannels * bytesPerSample;
        }
        else 
        {
            audioFormatPtr->mBytesPerPacket = audioFormatPtr->mBytesPerFrame = bytesPerSample;
            audioFormatPtr->mFormatFlags |= kAudioFormatFlagIsNonInterleaved;
        }
    }
}

+ (void)setAudioUnitASBD:(AudioStreamBasicDescription *)audioFormatPtr numChannels:(NSUInteger)numChannels sampleRate:(UInt32)sampleRate
{
    if (NULL != audioFormatPtr) 
    {
        bzero(audioFormatPtr, sizeof(AudioStreamBasicDescription));
        
        size_t bytesPerSample = sizeof (AudioUnitSampleType);
        
        audioFormatPtr->mFormatID          = kAudioFormatLinearPCM;
        audioFormatPtr->mFormatFlags       = kAudioFormatFlagsAudioUnitCanonical;
        audioFormatPtr->mBytesPerPacket    = bytesPerSample;
        audioFormatPtr->mFramesPerPacket   = 1;
        audioFormatPtr->mBytesPerFrame     = bytesPerSample;
        audioFormatPtr->mChannelsPerFrame  = numChannels;   // 1 indicates mono, 2 stereo
        audioFormatPtr->mBitsPerChannel    = 8 * bytesPerSample;
        audioFormatPtr->mSampleRate        = sampleRate;
    }
}

+ (void)printASBD:(AudioStreamBasicDescription) asbd
{
    char formatIDString[5];
    UInt32 formatID = CFSwapInt32HostToBig (asbd.mFormatID);
    bcopy (&formatID, formatIDString, 4);
    formatIDString[4] = '\0';
    
    QKLog (@"  Sample Rate:         %10.0f",  asbd.mSampleRate);
    QKLog (@"  Format ID:           %10s",    formatIDString);
    QKLog (@"  Format Flags:        %10X",    (uint)asbd.mFormatFlags);
    QKLog (@"  Bytes per Packet:    %10d",    (uint)asbd.mBytesPerPacket);
    QKLog (@"  Frames per Packet:   %10d",    (uint)asbd.mFramesPerPacket);
    QKLog (@"  Bytes per Frame:     %10d",    (uint)asbd.mBytesPerFrame);
    QKLog (@"  Channels per Frame:  %10d",    (uint)asbd.mChannelsPerFrame);
    QKLog (@"  Bits per Channel:    %10d",    (uint)asbd.mBitsPerChannel);
}
@end
