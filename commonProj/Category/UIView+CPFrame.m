//
//  UIView+CPFrame.m
//  commonProj
//
//  Created by dongchx on 8/22/16.
//  Copyright © 2016 dongchx. All rights reserved.
//

#import "UIView+CPFrame.h"

@implementation UIView (CPFrame)

- (void)setViewWidth:(CGFloat)viewWidth
{
    CGRect frame = self.frame;
    frame.size.width = viewWidth;
    self.frame = frame;
}

- (CGFloat)viewWidth
{
    return self.frame.size.width;
}

- (void)setViewHeight:(CGFloat)viewHeight
{
    CGRect frame = self.frame;
    frame.size.height = viewHeight;
    self.frame = frame;
}

- (CGFloat)viewHeight
{
    return self.frame.size.height;
}

- (void)setViewX:(CGFloat)viewX
{
    CGRect frame = self.frame;
    frame.origin.x = viewX;
    self.frame = frame;
}

- (CGFloat)viewX
{
    return self.frame.origin.x;
}

- (void)setViewY:(CGFloat)viewY
{
    CGRect frame = self.frame ;
    frame.origin.y = viewY;
    self.frame = frame;
}

- (CGFloat)viewY
{
    return self.frame.origin.y;
}

- (void)setCenterX:(CGFloat)centerX
{
    CGPoint center = self.center;
    center.x = centerX;
    self.center = center;
}

- (CGFloat)centerX
{
    return self.center.x;
}

- (void)setCenterY:(CGFloat)centerY
{
    CGPoint center = self.center;
    center.y = centerY;
    self.center = center;
}

- (CGFloat)centerY
{
    return self.center.y;
}

- (CGFloat)viewMaxX
{
    return CGRectGetMaxX(self.frame);
}

- (CGFloat)viewMaxY
{
    return CGRectGetMaxY(self.frame);
}


@end





































