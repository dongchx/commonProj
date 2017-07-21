//
//  QRAudioTrack.h
//  commonProj
//
//  Created by dongchx on 12/21/16.
//  Copyright © 2016 dongchx. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "DOUAudioFile.h"

@protocol QRAudioFile <DOUAudioFile>



@end

@interface QRAudioTrack : NSObject<QRAudioFile>

@property (nonatomic, strong) NSString *artist;
@property (nonatomic, strong) NSString *title;
@property (nonatomic, strong) NSURL    *audioFileURL;

@end
