//
//  CPMultiTextView.m
//  commonProj
//
//  Created by dongchx on 15/08/2017.
//  Copyright © 2017 dongchx. All rights reserved.
//

#import "CPMultiTextView.h"
#import "UILabel+CPFitLines.h"
#import "Masonry.h"

@interface CPMultiTextView ()

@property (nonatomic, strong) UILabel *label;

@end

@implementation CPMultiTextView

- (instancetype)init
{
    if (self = [super init]) {
        [self setupSubviews:self];
    }
    
    return self;
}

#pragma mark - subviews

- (void)setupSubviews:(UIView *)parentView
{
    _label = [[UILabel alloc] init];
    [parentView addSubview:_label];
    _label.font = [UIFont systemFontOfSize:kCPMultiTextViewFont];
    _label.textColor = [UIColor blackColor];
    _label.backgroundColor = [UIColor yellowColor];
    _label.cp_lineSpacing = kCPMultiTextViewLineSpaceing;
    
    [_label mas_makeConstraints:^(MASConstraintMaker *make) {
        make.edges.equalTo(parentView);
    }];
}

#pragma mark - data

- (void)setText:(NSString *)text
{
    
}

#pragma mark - touch

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event
{
    
}

- (void)touchesEnded:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event
{
    
}

- (void)touchesCancelled:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event
{
    
}

@end











