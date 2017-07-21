//
//  QRAudioTrack+Provider.h
//  commonProj
//
//  Created by dongchx on 12/23/16.
//  Copyright © 2016 dongchx. All rights reserved.
//

#import "QRAudioTrack.h"

@interface QRAudioTrack (Provider)

+ (NSArray *)remoteTracks:(NSArray *)list;
+ (NSArray *)localTracks:(NSArray *)list;

@end
