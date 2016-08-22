//
//  UIView+CPFrame.h
//  commonProj
//
//  Created by dongchx on 8/22/16.
//  Copyright © 2016 dongchx. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface UIView (CPFrame)

@property (nonatomic) CGFloat viewWidth;
@property (nonatomic) CGFloat viewHeight;
@property (nonatomic) CGFloat viewX;
@property (nonatomic) CGFloat viewY;
@property (nonatomic) CGFloat centerX;
@property (nonatomic) CGFloat centerY;

- (CGFloat)viewMaxX;
- (CGFloat)viewMaxY;

@end
