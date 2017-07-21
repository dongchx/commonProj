//
//  DDNetAudioPlayer.h
//  commonProj
//
//  Created by dongchx on 10/20/16.
//  Copyright © 2016 dongchx. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "QKPlayerProtocol.h"

@interface DDNetAudioPlayer : NSObject<QKPlayerProtocol>

+ (instancetype)player;

- (void)startWithUrl:(NSString *)urlString;

@end
