//
//  UILabel+CPFitLines.h
//  commonProj
//
//  Created by dongchx on 15/08/2017.
//  Copyright © 2017 dongchx. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface UILabel (CPFitLines)

@property (nonatomic, assign) CGFloat cp_containtsWidth;
@property (nonatomic, assign) CGFloat cp_lineSpacing;

/**
 文本适应于指定的行数
 @return 文本是否被numberOfLines限制
 */
- (BOOL)cp_adjustTextToFitLines:(NSInteger)numberOfLines;

@end
