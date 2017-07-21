//
//  QRAudioBookPlayVC.h
//  commonProj
//
//  Created by dongchx on 12/23/16.
//  Copyright © 2016 dongchx. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>

@interface QRAudioBookPlayVC : UIViewController

//AudioSession的启动方法
extern OSStatus AudioSessionSetActive(Boolean active);
extern OSStatus AudioSessionSetActiveWithFlags(Boolean active, UInt32 inFlags);

//AVAudioSessionSession的启动方法
- (BOOL)setActive:(BOOL)active error:(NSError **)outError;
- (BOOL)setActive:(BOOL)active withOptions:(AVAudioSessionSetActiveOptions)options error:(NSError **)outError;


extern OSStatus
AudioFileStreamOpen (void * __nullable						inClientData,
                     AudioFileStream_PropertyListenerProc	inPropertyListenerProc,
                     AudioFileStream_PacketsProc				inPacketsProc,
                     AudioFileTypeID							inFileTypeHint,
                     AudioFileStreamID __nullable * __nonnull outAudioFileStream);


@end
