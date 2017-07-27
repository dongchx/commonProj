//
//  CPConsole.m
//  commonProj
//
//  Created by dongchx on 7/27/17.
//  Copyright © 2017 dongchx. All rights reserved.
//

#import "CPConsole.h"

@implementation CPConsole

- (instancetype)init
{
    if (self = [super init]) {
        
    }
    
    return self;
}

- (void)log:(NSString *)logStr
{
    if (self.text) {
        NSString *text =
        [NSString stringWithFormat:@"%@\n%@",
         self.text, [self logWithHeader:logStr]];
        
        self.text = text;
    }
    else {
        self.text = [self logWithHeader:logStr];
    }
}

- (NSString *)logWithHeader:(NSString *)logStr
{
    return [NSString stringWithFormat:@"%@ %@", [NSDate date], logStr];
}

@end



















