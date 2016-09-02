//
//  AudioFileUtility.h
//  QQKala
//
//  Created by frost on 12-6-20.
//  Copyright (c) 2012年 Tencent. All rights reserved.
//

#import <Foundation/Foundation.h>


@interface AudioFileUtility : NSObject

+ (NSTimeInterval)getAudioFileDurationInSeconds:(NSString*)audioFilePath error:(NSError **)outError;

@end
