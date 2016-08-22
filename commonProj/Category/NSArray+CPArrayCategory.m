//
//  NSArray+CPArrayCategory.m
//  commonProj
//
//  Created by dongchx on 8/22/16.
//  Copyright © 2016 dongchx. All rights reserved.
//

#import "NSArray+CPArrayCategory.h"

@implementation NSArray (CPArrayCategory)

- (id)objectSafeAtIndex:(NSUInteger)index
{
    if (index > self.count) {
        return nil;
    }
    
    return [self objectAtIndex:index];
}

@end
