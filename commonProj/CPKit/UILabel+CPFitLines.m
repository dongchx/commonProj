//
//  UILabel+CPFitLines.m
//  commonProj
//
//  Created by dongchx on 15/08/2017.
//  Copyright © 2017 dongchx. All rights reserved.
//

#import "UILabel+CPFitLines.h"
#import "NSString+CPSize.h"
#import <objc/runtime.h>

@implementation UILabel (CPFitLines)

- (void)setCp_containtsWidth:(CGFloat)cp_containtsWidth
{
    objc_setAssociatedObject(self, @selector(cp_containtsWidth),
                             @(cp_containtsWidth),
                             OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (CGFloat)cp_containtsWidth
{
    return
    [objc_getAssociatedObject(self, @selector(cp_containtsWidth)) floatValue];
}

- (void)setCp_lineSpacing:(CGFloat)cp_lineSpacing
{
    objc_setAssociatedObject(self, @selector(cp_lineSpacing),
                             @(cp_lineSpacing),
                             OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (CGFloat)cp_lineSpacing
{
    return
    [objc_getAssociatedObject(self, @selector(cp_lineSpacing)) floatValue];
}

- (BOOL)cp_adjustTextToFitLines:(NSInteger)numberOfLines
{
    if (!self.text || self.text.length == 0) {
        return NO;
    }
    
    self.numberOfLines = numberOfLines;
    BOOL isLimitedToLines = NO;
    
    CGSize textSize = [self.text textSizeWithFont:self.font
                                    numberOfLines:self.numberOfLines
                                      lineSpacing:self.cp_lineSpacing
                                 constrainedWidth:self.cp_containtsWidth
                                 isLimitedToLines:&isLimitedToLines];
    
    //单行的情况
    if (fabs(textSize.height - self.font.lineHeight) < 0.00001f) {
        self.cp_lineSpacing = 0.0f;
    }
    
    //设置文字的属性
    NSMutableAttributedString * attributedString =
    [[NSMutableAttributedString alloc] initWithString:self.text];
    
    NSMutableParagraphStyle * paragraphStyle = [[NSMutableParagraphStyle alloc] init];
    [paragraphStyle setLineSpacing:self.cp_lineSpacing];
    paragraphStyle.lineBreakMode = NSLineBreakByTruncatingTail;
    
    [attributedString addAttribute:NSParagraphStyleAttributeName value:paragraphStyle
                             range:NSMakeRange(0, [self.text length])];
    [attributedString addAttribute:NSForegroundColorAttributeName
                             value:self.textColor
                             range:NSMakeRange(0, [self.text length])];
    [attributedString addAttribute:NSFontAttributeName value:self.font
                             range:NSMakeRange(0, [self.text length])];
    
    
    [self setAttributedText:attributedString];
    self.bounds = CGRectMake(0, 0, textSize.width, textSize.height);
    return isLimitedToLines;
}

@end
