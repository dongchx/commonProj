//
//  NSString+CPSize.m
//  commonProj
//
//  Created by dongchx on 15/08/2017.
//  Copyright © 2017 dongchx. All rights reserved.
//

#import "NSString+CPSize.h"

@implementation NSString (CPSize)

- (CGSize)textSizeWithFont:(UIFont*)font{
    
    return [self sizeWithAttributes:@{NSFontAttributeName:font}];
}

/**
 根据字体、行数、行间距和constrainedWidth计算文本占据的size
 **/
- (CGSize)textSizeWithFont:(UIFont*)font
             numberOfLines:(NSInteger)numberOfLines
               lineSpacing:(CGFloat)lineSpacing
          constrainedWidth:(CGFloat)constrainedWidth
          isLimitedToLines:(BOOL *)isLimitedToLines{
    
    if (self.length == 0) {
        return CGSizeZero;
    }
    
    CGFloat defaultMargin = ceil(font.lineHeight - font.pointSize);
    lineSpacing -= defaultMargin;
    
    CGFloat oneLineHeight = font.lineHeight;
    CGSize textSize =
    [self boundingRectWithSize:CGSizeMake(constrainedWidth, MAXFLOAT)
                       options:NSStringDrawingUsesLineFragmentOrigin
                    attributes:@{NSFontAttributeName:font}
                       context:nil].size;
    
    CGFloat rows = textSize.height / oneLineHeight;
    CGFloat realHeight = oneLineHeight;
    
    // 0 不限制行数
    if (numberOfLines == 0) {
        if (rows >= 1) {
            realHeight = (rows * oneLineHeight) + (rows - 1) * lineSpacing;
        }
    }else{
        if (rows > numberOfLines) {
            rows = numberOfLines;
            if (isLimitedToLines) {
                *isLimitedToLines = YES;  //被限制
            }
        }
        realHeight = (rows * oneLineHeight) + (rows - 1) * lineSpacing;
    }
    
    return CGSizeMake(constrainedWidth, realHeight);
}

@end
