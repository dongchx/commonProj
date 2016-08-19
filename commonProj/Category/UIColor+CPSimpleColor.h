//
//  UIColor+CPSimpleColor.h
//  commonProj
//
//  Created by dongchx on 8/19/16.
//  Copyright © 2016 dongchx. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface UIColor (CPSimpleColor)

+ (UIColor *)colorWithHex:(NSInteger)hexValue;
+ (UIColor *)colorWithHex:(NSInteger)hexValue alpha:(CGFloat)alpha;

@end
