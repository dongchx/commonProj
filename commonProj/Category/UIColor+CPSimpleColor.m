//
//  UIColor+CPSimpleColor.m
//  commonProj
//
//  Created by dongchx on 8/19/16.
//  Copyright © 2016 dongchx. All rights reserved.
//

#import "UIColor+CPSimpleColor.h"

@implementation UIColor (CPSimpleColor)

+ (UIColor *)colorWithHex:(NSInteger)hexValue
{
    return [self colorWithHex:hexValue alpha:1.0];
}

+ (UIColor *)colorWithHex:(NSInteger)hexValue alpha:(CGFloat)alpha
{
    return [UIColor colorWithRed:((float)((hexValue & 0xFF0000) >> 16))/255.0
                           green:((float)((hexValue & 0xFF00) >> 8))/255.0
                            blue:((float)((hexValue & 0xFF)))/255.0
                           alpha:alpha];
}

@end
