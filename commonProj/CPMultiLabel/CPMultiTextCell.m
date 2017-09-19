//
//  CPMultiTextCell.m
//  commonProj
//
//  Created by dongchx on 15/08/2017.
//  Copyright © 2017 dongchx. All rights reserved.
//

#import "CPMultiTextCell.h"
#import "CPMultiTextView.h"
#import "Masonry.h"
#import "NSString+CPSize.h"
#import "UILabel+CPFitLines.h"

#define SCREEN_HEIGHT CGRectGetHeight([[UIScreen mainScreen] bounds])
#define SCREEN_WIDTH  CGRectGetWidth([[UIScreen mainScreen] bounds])

@implementation CPMultiTextCellModel

- (instancetype)initWithContent:(NSString *)content
                   contentLines:(CGFloat)contentLines
                         isOpen:(BOOL)isOpen
{
    if (self = [super init]) {
        self.content = content;
        self.contentLines = contentLines;
        self.isOpen = isOpen;
    }
    
    return self;
}

@end



@interface CPMultiTextCell ()
{
    UILabel                 *_label;
    CPMultiTextCellModel    *_model;
    UIButton                *_openContentBtn;
}

@end

@implementation CPMultiTextCell

- (instancetype)initWithStyle:(UITableViewCellStyle)style
              reuseIdentifier:(NSString *)reuseIdentifier
{
    if (self = [super initWithStyle:style reuseIdentifier:reuseIdentifier]) {
        [self setupSubviews:self.contentView];
    }
    
    return self;
}

#pragma mark - subviews

- (void)setupSubviews:(UIView *)parentView
{
    _label = [[UILabel alloc] init];
    [parentView addSubview:_label];
    _label.font = [UIFont systemFontOfSize:kCPMultiTextViewFont];
    _label.cp_containtsWidth = SCREEN_WIDTH;
    _label.cp_lineSpacing = kCPMultiTextViewLineSpaceing;
    _label.layer.borderWidth = 1.;
    _label.layer.borderColor = [UIColor redColor].CGColor;
    
    _openContentBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    [parentView addSubview:_openContentBtn];
    
    [_openContentBtn addTarget:self
                        action:@selector(openContent:)
              forControlEvents:UIControlEventTouchUpInside];
    
    [_label mas_makeConstraints:^(MASConstraintMaker *make) {
        make.edges.equalTo(parentView);
    }];
    
    [_openContentBtn mas_makeConstraints:^(MASConstraintMaker *make) {
        make.edges.equalTo(parentView);
    }];
}

#pragma mark - date

- (void)setCellModel:(CPMultiTextCellModel *)model
{
    _model = model;
    _label.text = model.content;
    BOOL isLimitedToLines =
    [_label cp_adjustTextToFitLines:model.contentLines];
    _openContentBtn.selected = _model.isOpen;
    
    if (isLimitedToLines) {
        // 箭头
    }
}

#pragma mark - size

+ (CGFloat)cellHeightWithModel:(CPMultiTextCellModel *)model
{
    BOOL isLimitedToLines;
    CGSize textSize =
    [model.content textSizeWithFont:[UIFont systemFontOfSize:kCPMultiTextViewFont]
                      numberOfLines:model.contentLines
                        lineSpacing:kCPMultiTextViewLineSpaceing
                   constrainedWidth:SCREEN_WIDTH
                   isLimitedToLines:&isLimitedToLines];
    
    CGFloat height = textSize.height + 25;
    if (!isLimitedToLines && (model.contentLines != 0)) {
        height -= 25;
    }
    return height;
}

#pragma mark - tapAction

- (void)openContent:(UIButton *)btn
{
    if (self.openContentBlock) {
        btn.selected = !btn.selected;
        _model.isOpen = btn.selected;
        NSLog(@"%@", @(_model.isOpen));
        self.openContentBlock(_model);
        [self setCellModel:_model];
    }
}

@end


























