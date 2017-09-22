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
#import <CoreText/CoreText.h>

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
    
    CGFloat defaultMargin = ceil(self.font.lineHeight - self.font.pointSize);
    CGFloat lineSpacing = self.cp_lineSpacing - defaultMargin;
    //单行的情况
    if (fabs(textSize.height - self.font.lineHeight) < 0.00001f) {
        lineSpacing = 0;
    }
    
    //设置文字的属性
    NSMutableAttributedString *attributedString =
    [[NSMutableAttributedString alloc] initWithString:self.text];
    
    NSMutableParagraphStyle *paragraphStyle = [[NSMutableParagraphStyle alloc] init];
    [paragraphStyle setLineSpacing:lineSpacing];
    paragraphStyle.lineBreakMode = NSLineBreakByTruncatingTail;
    paragraphStyle.alignment = NSTextAlignmentJustified;
    
    [attributedString addAttribute:NSParagraphStyleAttributeName
                             value:paragraphStyle
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

- (BOOL)cp_adjustAttributedTextToFitLines:(NSInteger)numberOfLines
{
    if (!self.attributedText || self.attributedText.length == 0) {
        return NO;
    }
    
    self.numberOfLines = numberOfLines;
    BOOL isLimitedToLines = NO;
    
    CGSize textSize =
    [self.attributedText.string textSizeWithFont:self.font
                                   numberOfLines:self.numberOfLines
                                     lineSpacing:self.cp_lineSpacing
                                constrainedWidth:self.cp_containtsWidth
                                isLimitedToLines:&isLimitedToLines];
    
    CGFloat defaultMargin = ceil(self.font.lineHeight - self.font.pointSize);
    CGFloat lineSpacing = self.cp_lineSpacing - defaultMargin;
    //单行的情况
    if (fabs(textSize.height - self.font.lineHeight) < 0.00001f) {
        lineSpacing = 0;
    }
    
    // 添加属性
    NSMutableAttributedString *attributedString =
    [[NSMutableAttributedString alloc] initWithAttributedString:self.attributedText];
    
    NSMutableParagraphStyle *paragraphStyle = [[NSMutableParagraphStyle alloc] init];
    paragraphStyle.lineSpacing = lineSpacing;
    paragraphStyle.lineBreakMode = NSLineBreakByTruncatingTail;
    paragraphStyle.alignment = NSTextAlignmentJustified;
    
    [attributedString addAttribute:NSParagraphStyleAttributeName
                             value:paragraphStyle
                             range:NSMakeRange(0, self.attributedText.length)];
    [attributedString addAttribute:NSForegroundColorAttributeName
                             value:self.textColor
                             range:NSMakeRange(0, self.attributedText.length)];
    [attributedString addAttribute:NSFontAttributeName
                             value:self.font
                             range:NSMakeRange(0, self.attributedText.length)];
    
    [self setAttributedText:attributedString];
    self.bounds = CGRectMake(0, 0, textSize.width, textSize.height);
    
    return isLimitedToLines;
}

//- (void)setLineBreakByTruncatingLastLineMiddle:(NSInteger)numberOfLines
//{
//    self.numberOfLines = numberOfLines;
//    if ( self.numberOfLines <= 0 ) {
//        [self cp_adjustTextToFitLines:numberOfLines];
//        return;
//    }
//    NSArray *separatedLines = [self getSeparatedLinesArray];
//    
//    NSMutableString *limitedText = [NSMutableString string];
//    if ( separatedLines.count >= self.numberOfLines ) {
//        
//        for (int i = 0 ; i < self.numberOfLines; i++) {
//            if ( i == self.numberOfLines - 1) {
//                UILabel *lastLineLabel =
//                [[UILabel alloc] initWithFrame:CGRectMake(0, 0, self.frame.size.width/2, MAXFLOAT)];
//                lastLineLabel.text = separatedLines[self.numberOfLines - 1];
//                
//                NSArray *subSeparatedLines = [lastLineLabel getSeparatedLinesArray];
//                NSString *lastLineText = [subSeparatedLines firstObject];
//                NSInteger lastLineTextCount = lastLineText.length;
//                [limitedText appendString:[NSString stringWithFormat:@"%@...",
//                                           [lastLineText substringToIndex:lastLineTextCount]]];
//            }else{
//                [limitedText appendString:separatedLines[i]];
//            }
//        }
//        
//        
//    }else{
//        [limitedText appendString:self.text];
//    }
//    
//    self.text = limitedText;
//    [self cp_adjustTextToFitLines:numberOfLines];
//}
//
//- (NSArray *)getSeparatedLinesArray
//{
//    NSString *text = self.text;
//    UIFont   *font = self.font;
//    CGRect   rect  = self.bounds;
//    
//    CTFontRef myFont =
//    CTFontCreateWithName((__bridge CFStringRef)([font fontName]),
//                         [font pointSize], NULL);
//    
//    NSMutableAttributedString *attStr =
//    [[NSMutableAttributedString alloc] initWithString:text];
//    [attStr addAttribute:(NSString *)kCTFontAttributeName
//                   value:(__bridge id)myFont
//                   range:NSMakeRange(0, attStr.length)];
//    
//    CTFramesetterRef frameSetter =
//    CTFramesetterCreateWithAttributedString((__bridge CFAttributedStringRef)attStr);
//    CGMutablePathRef path = CGPathCreateMutable();
//    CGPathAddRect(path, NULL, CGRectMake(0,0,rect.size.width,MAXFLOAT));
//    CTFrameRef frame =
//    CTFramesetterCreateFrame(frameSetter, CFRangeMake(0, 0), path, NULL);
//    
//    NSArray *lines = (__bridge NSArray *)CTFrameGetLines(frame);
//    NSMutableArray *linesArray = [[NSMutableArray alloc]init];
//    for (id line in lines){
//        CTLineRef lineRef = (__bridge CTLineRef )line;
//        CFRange lineRange = CTLineGetStringRange(lineRef);
//        NSRange range = NSMakeRange(lineRange.location, lineRange.length);
//        NSString *lineString = [text substringWithRange:range];
//        [linesArray addObject:lineString];
//    }
//    
//    return (NSArray *)linesArray;
//}

@end
