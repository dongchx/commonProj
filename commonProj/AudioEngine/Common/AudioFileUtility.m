//
//  AudioFileUtility.m
//  QQKala
//
//  Created by frost on 12-6-20.
//  Copyright (c) 2012年 Tencent. All rights reserved.
//

#import "AudioFileUtility.h"
#import <AudioToolbox/AudioFile.h>

NSString * AudioFileUtilityErrorDomain = @"com.tencent.AudioFileUtilityErrorDomain";

@implementation AudioFileUtility

+ (NSTimeInterval)getAudioFileDurationInSeconds:(NSString*)audioFilePath error:(NSError **)outError
{
    outError = outError ? outError : &(NSError*){nil};
    
    NSURL *audioFileUrl = [NSURL fileURLWithPath:audioFilePath isDirectory:NO];
    AudioFileID audioFileID;
    OSStatus result = AudioFileOpenURL((CFURLRef)audioFileUrl, kAudioFileReadPermission, 0, &audioFileID);
    
    if (noErr != result)
    {
        NSDictionary *userInfo = [NSDictionary dictionaryWithObject:@"Couldn't open the source file" forKey:NSLocalizedDescriptionKey];
        
        *outError = [NSError errorWithDomain:AudioFileUtilityErrorDomain 
                                        code:kAudioFileNotOpenError 
                                    userInfo:userInfo];
        
        return 0;
    }
    double duration = 0;
    UInt32 size = sizeof(duration);
    result = AudioFileGetProperty(audioFileID, kAudioFilePropertyEstimatedDuration, &size, &duration);
    if (noErr != result)
    {
        NSDictionary *userInfo = [NSDictionary dictionaryWithObject:@"Couldn't open the source file" forKey:NSLocalizedDescriptionKey];
        
        *outError = [NSError errorWithDomain:AudioFileUtilityErrorDomain 
                                        code:result 
                                    userInfo:userInfo];
    }
    
    AudioFileClose(audioFileID);
    return duration;
}
@end
