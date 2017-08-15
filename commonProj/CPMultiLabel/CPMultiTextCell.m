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
    CPMultiTextView *_mainView;
    CPMultiTextCellModel    *_model;
    UIButton        *_openContentBtn;
}

@end

@implementation CPMultiTextCell

- (instancetype)initWithStyle:(UITableViewCellStyle)style
              reuseIdentifier:(NSString *)reuseIdentifier
{
    if (self = [super initWithStyle:style reuseIdentifier:reuseIdentifier]) {
        
    }
    
    return self;
}

#pragma mark - subviews

- (void)setupSubviews:(UIView *)parentView
{
    _mainView = [[CPMultiTextView alloc] init];
    [parentView addSubview:_mainView];
    
    _openContentBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    [parentView addSubview:_openContentBtn];
    
    [_openContentBtn addTarget:self
                        action:@selector(openContent)
              forControlEvents:UIControlEventTouchUpInside];
    
    [_mainView mas_makeConstraints:^(MASConstraintMaker *make) {
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
    _mainView.label.text = model.content;
    BOOL isLimitedToLines =
    [_mainView.label cp_adjustTextToFitLines:model.contentLines];
    
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
                   constrainedWidth:SCREEN_WIDTH - 30
                   isLimitedToLines:&isLimitedToLines];
    
    CGFloat height = textSize.height;
//    if (!isLimitedToLines && (model.contentLines != 0)) {
//        height -= 25;
//    }
    return height;
}

#pragma mark - tapAction

- (void)openContent
{
    if (self.openContentBlock) {
        _openContentBtn.selected = _openContentBtn.selected;
        _model.isOpen = _openContentBtn.selected;
        self.openContentBlock(_model);
//        [self layoutSubviewsWithModel:self.cellModel];
    }
}

@end


























