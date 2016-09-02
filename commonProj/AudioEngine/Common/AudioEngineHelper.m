//
//  AudioSessionManager.m
//  QQKala
//
//  Created by frost on 12-6-11.
//  Copyright (c) 2012年 Tencent. All rights reserved.
//

#import <AudioToolbox/AudioToolbox.h>
#import <MediaPlayer/MediaPlayer.h>
#import <AVFoundation/AVFoundation.h>
#import "AudioEngineHelper.h"
#include "PublicConfig.h"

// ---------------------------------------------
// varaiable declaration
// ---------------------------------------------
static AudioEngineHelper* s_aeh_instance = nil;
NSString *const kAudioSessionBeginInterruptionNotification = @"QK_AudioSessionBeginInterruptionNotification";
NSString *const kAudioSessionEndInterruptionNotification = @"QK_AudioSessionEndInterruptionNotification";
NSString *const kAudioRouteUnknown = @"UnknownAudioRoute";

NSString *const kAudioRouteHeadSetPlugin = @"QK_AudioRouteHeadSetPlugin";
NSString *const kAudioRouteHeadSetPlugout = @"QK_AudioRouteHeadSetPlugout";
NSString *const kVolumeChangedNotification = @"QK_VolumeChangedNotification";


// ---------------------------------------------
// forward declaration
// ---------------------------------------------
static void interruptionListener(void *inClientData, UInt32 inInterruption);
static void propertyListener(void *inClientData, AudioSessionPropertyID inID, UInt32 inDataSize, const void *inData);

// ---------------------------------------------
// AudioEngineHelper private category
// ---------------------------------------------
@interface AudioEngineHelper()

- (NSString*)audioRoute;
- (void)onAudioRouteChangedWithReason:(SInt32)reason oldRoute:(NSString*)oldRoute;
- (void)onVolumeChange:(float)newVolume;
- (void)onBeginInterruption;
- (void)onEndInterruption:(NSUInteger)flags;

@end

// ---------------------------------------------
// AudioEngineHelper implementation
// ---------------------------------------------
@implementation AudioEngineHelper
@synthesize delegate = mDelegate;


+ (AudioEngineHelper*)sharedInstance
{
    if (nil == s_aeh_instance) 
    {
        @synchronized(self)
        {
            if (nil == s_aeh_instance) 
            {
                s_aeh_instance = [[self alloc]init];
            }
        }
    }
	return s_aeh_instance;
}

- (BOOL)hasMicPhone
{
    UInt32 audioInputIsAvailabel;
    UInt32 propertySize = sizeof(audioInputIsAvailabel);
    
    OSStatus err = AudioSessionGetProperty(kAudioSessionProperty_AudioInputAvailable, &propertySize, &audioInputIsAvailabel);
    if (noErr != err) 
    {
        // errors when get property, return default value;
        return NO;
    }
    
    return (BOOL)audioInputIsAvailabel;
}

- (UInt32)inputChannelNumber
{
    UInt32 channels;
    UInt32 propertySize = sizeof(channels);
    
    OSStatus err = AudioSessionGetProperty(kAudioSessionProperty_CurrentHardwareInputNumberChannels, &propertySize, &channels);
    
    if (noErr != err)
    {
        // errors when get property, return default value;
        return 1;
    }
    
    return channels;
}

- (BOOL)hasHeadSet
{
#if TARGET_IPHONE_SIMULATOR
//    #warning Simulator mode: audio session code works only on a device
    return NO;
#else
    BOOL hasHeadSet = NO;
    CFStringRef route;
    UInt32 size = sizeof(CFStringRef);
    AudioSessionGetProperty(kAudioSessionProperty_AudioRoute, &size, &route);
    
    if ( (NULL == route) || CFStringGetLength(route) == 0 ) 
    {
        // silent mode
    }
    else
    {
        /* Known values of route:
         *
         * "Headset"                : A 3-conductor plug in the headset jack(Left, Right, Microphone + Ground)
         * "Headphone"              : A 2-conductor plug in the headset jack(Left,Right+Ground)
         * "Speaker"
         * "SpeakerAndMicrophone"
         * "HeadsetInOut"
         * "ReceiverAndMicrophone"
         * "Lineout"
         */
        NSString *routeString = (NSString*)route;
        NSRange headphoneRange = [routeString rangeOfString:@"Headphone"];
        NSRange headsetRange = [routeString rangeOfString:@"Headset"];
        
        if ( (headphoneRange.location != NSNotFound) || (headsetRange.location != NSNotFound) ) 
        {
            hasHeadSet = YES;
        }
    }
    
    if (NULL != route) 
    {
        CFRelease(route);
    }
    return hasHeadSet;
#endif
}

- (void)initAudioSession
{
    if (!mIsConfiged) 
    {
        AVAudioSession *session = [AVAudioSession sharedInstance];
        [session setDelegate:self];

        [self resetAudioCategory];
        
        NSError *sessionError = nil;
        [session setActive:YES error:&sessionError];
        
        if (nil != sessionError)
        {
            QKLog(@"[session setActive:YES error:&error] err = %@", [sessionError description]);
        }
        else
        {
            mIsConfiged = YES;
        }
    }
}

- (void)checkAudioCategoryForPlayAndRecord
{
    mNeedRecording = YES;
    [self resetAudioCategory];
    [self resetOutputTarget];
}

- (void)resetAudioCategoryForPlayOnly
{
    mNeedRecording = NO;
    [self resetAudioCategory];
    [self resetOutputTarget];
}

- (void)registerRouteChangeEvent
{
    if (!mIsRouteChangeEventRegistered) 
    {
        AudioSessionAddPropertyListener(kAudioSessionProperty_AudioRouteChange, propertyListener, self);
        mIsRouteChangeEventRegistered = YES;
    }

}

- (void)unregisterRouteChangeEvent
{
    if (mIsRouteChangeEventRegistered) 
    {
        AudioSessionRemovePropertyListenerWithUserData(kAudioSessionProperty_AudioRouteChange, propertyListener, self);
        mIsRouteChangeEventRegistered = NO;
    }
}

- (void)registerVolumeChangeEvent
{
    if (!mIsVolumeChangeEventRegistered) 
    {
        AudioSessionAddPropertyListener(kAudioSessionProperty_CurrentHardwareOutputVolume, propertyListener, self);
        mIsVolumeChangeEventRegistered = YES;
    }
}

- (void)unregisterVolumeChangeEvent
{
    if (mIsVolumeChangeEventRegistered) 
    {
        AudioSessionRemovePropertyListenerWithUserData(kAudioSessionProperty_CurrentHardwareOutputVolume, propertyListener, self);
        mIsVolumeChangeEventRegistered = NO;
    }
}

- (void)applicationWillResignActive
{
    NSString * audioCategory = AVAudioSessionCategoryPlayback;
    mCurrentCategory = kAudioSessionCategory_MediaPlayback;
    NSError *sessionError = nil;
    [[AVAudioSession sharedInstance] setCategory:audioCategory error:&sessionError];
}

- (void)applicationDidBecomeActive
{
    [self setAudioSessionActive:false];
    [self resetAudioCategory];
    OSStatus err = [self setAudioSessionActive:true];
    
    // call again to make audio session active
    [self setAudioSessionActive:false];
    [self resetAudioCategory];
    err = [self setAudioSessionActive:true];
}
#pragma mark Private

- (NSString*)audioRoute
{
    CFStringRef route;
    UInt32 size = sizeof(CFStringRef);
    AudioSessionGetProperty(kAudioSessionProperty_AudioRoute, &size, &route);
    
    return (NULL != route && CFStringGetLength(route) > 0) ? (NSString*)route : kAudioRouteUnknown;
}

- (void)onAudioRouteChangedWithReason:(SInt32)reason oldRoute:(NSString*)oldRoute
{
    if (kAudioSessionRouteChangeReason_NewDeviceAvailable == reason) 
    {
        // plug-in headphone
        if ([self hasHeadSet]) 
        {
            [[NSNotificationCenter defaultCenter] postNotificationName:kAudioRouteHeadSetPlugin object:nil];
        }
    }
    else if (kAudioSessionRouteChangeReason_OldDeviceUnavailable == reason)
    {
        // plug-out headphone
        if (![self hasHeadSet]) 
        {
            [[NSNotificationCenter defaultCenter] postNotificationName:kAudioRouteHeadSetPlugout object:nil];
        }
    }
    
    [self resetOutputTarget];
}

- (OSStatus)setAudioSessionActive:(Boolean)active
{
    BOOL shouldActive = active ? YES : NO;
    NSError *sessionError = nil;
    [[AVAudioSession sharedInstance] setActive:shouldActive error:&sessionError];
    if (nil != sessionError)
    {
        return [sessionError code];
    }
    return noErr;
}

- (BOOL)shouldStopOnInterrupt
{
    return (mCurrentCategory == kAudioSessionCategory_PlayAndRecord) ? YES : NO;
}

- (float)currentVolume
{
    float volume = 0.0;
    UInt32 size = sizeof(float);
    OSStatus err = AudioSessionGetProperty(kAudioSessionProperty_CurrentHardwareOutputVolume, &size, &volume);
    if (noErr != err)
    {
        volume = 0.0;
    }
    return  volume;
}

- (void)hideSystemVolumeOverlay:(UIView*)superView
{
    if (nil != superView && !mIsHideSystemVolumeOverLay)
    {
        MPVolumeView * volumeView = [[MPVolumeView alloc] initWithFrame:CGRectZero];
        [superView addSubview:volumeView];
        [volumeView release];
        mIsHideSystemVolumeOverLay = YES;
    }
}

- (void)resetOutputTarget
{
//    UInt32 defaultToSpeaker = 1;
//    AudioSessionSetProperty(kAudioSessionProperty_OverrideCategoryDefaultToSpeaker, sizeof(UInt32), &defaultToSpeaker);
    
    BOOL hasHeadset = [self hasHeadSet];
    UInt32 audioRouteOverride = hasHeadset ? kAudioSessionOverrideAudioRoute_None : kAudioSessionOverrideAudioRoute_Speaker;
    AudioSessionSetProperty(kAudioSessionProperty_OverrideAudioRoute, sizeof(UInt32), &audioRouteOverride);
}

- (void)reduceRecordingLatency
{
    float bufferLength = 0.005; // in seconds
    AudioSessionSetProperty(kAudioSessionProperty_PreferredHardwareIOBufferDuration, sizeof(float), &bufferLength);
}

- (void)onVolumeChange:(float)newVolume
{
    [[NSNotificationCenter defaultCenter] postNotificationName:kVolumeChangedNotification object:[NSNumber numberWithFloat:newVolume]];
}

- (void)resetAudioCategory
{
    // set category
    NSString * audioCategory = AVAudioSessionCategoryPlayback;
    mCurrentCategory = kAudioSessionCategory_MediaPlayback;
    if (mNeedRecording && [self hasMicPhone])
    {
        audioCategory = AVAudioSessionCategoryPlayAndRecord;
        mCurrentCategory = kAudioSessionCategory_PlayAndRecord;
    }
    NSError *sessionError = nil;
    [[AVAudioSession sharedInstance] setCategory:audioCategory error:&sessionError];
}

- (void)onBeginInterruption
{
    if (self.delegate &&
        [self.delegate respondsToSelector:@selector(beginInterruption)])
    {
        [self.delegate beginInterruption];
    }
}

- (void)onEndInterruption:(NSUInteger)flags
{
    if (self.delegate &&
        [self.delegate respondsToSelector:@selector(endInterruptionWithFlags:)])
    {
        [self.delegate endInterruptionWithFlags:flags];
    }
}

#pragma mark AVAudioSessionDelegate
- (void)beginInterruption
{
    NSError *sessionError = nil;
    [[AVAudioSession sharedInstance] setActive:NO error:&sessionError];
    [self onBeginInterruption];
    [[NSNotificationCenter defaultCenter] postNotificationName:kAudioSessionBeginInterruptionNotification object:nil];
}

/* the interruption is over */
/* Currently the only flag is AVAudioSessionInterruptionFlags_ShouldResume. */
- (void)endInterruptionWithFlags:(NSUInteger)flags NS_AVAILABLE_IOS(4_0)
{
    if (flags & AVAudioSessionInterruptionFlags_ShouldResume)
    {
        NSError *sessionError = nil;
//        [self resetAudioCategory];
        [[AVAudioSession sharedInstance] setActive:YES error:&sessionError];
    }
    [self onEndInterruption:flags];
    [[NSNotificationCenter defaultCenter] postNotificationName:kAudioSessionEndInterruptionNotification object:nil];
}
@end

// ---------------------------------------------
// property listener
// ---------------------------------------------
static void propertyListener(void *inClientData, AudioSessionPropertyID inID, UInt32 inDataSize, const void *inData)
{    
    AudioEngineHelper *THIS = (AudioEngineHelper *)inClientData;
    
	if (inID == kAudioSessionProperty_AudioRouteChange) 
    {
        CFDictionaryRef	routeChangeDictionary = (CFDictionaryRef)inData;
        
        // get route chage reason
        CFNumberRef routeChangeReasonRef = (CFNumberRef)CFDictionaryGetValue(routeChangeDictionary, CFSTR(kAudioSession_AudioRouteChangeKey_Reason));
        UInt32 routeChangeReason = kAudioSessionRouteChangeReason_Unknown;
        if (NULL != routeChangeReasonRef)
        {
            CFNumberGetValue(routeChangeReasonRef, kCFNumberSInt32Type, &routeChangeReason);
        }
        
        // get the old route
        CFStringRef routeChangeOldRouteRef = (CFStringRef)CFDictionaryGetValue(routeChangeDictionary, CFSTR(kAudioSession_AudioRouteChangeKey_OldRoute));
        
        [THIS onAudioRouteChangedWithReason:routeChangeReason oldRoute:(NSString*)routeChangeOldRouteRef];
	}
    else if (inID == kAudioSessionProperty_CurrentHardwareOutputVolume)
    {
        float newVolume = *(float*)inData;
        [THIS onVolumeChange:newVolume];
    }
}
