//
//  UITableViewCell+CPAutoSizingCategory.m
//  commonProj
//
//  Created by dongchx on 8/19/16.
//  Copyright © 2016 dongchx. All rights reserved.
//

#import "UITableViewCell+CPAutoSizingCategory.h"
#import <objc/runtime.h>

@implementation UITableViewCell (CPAutoSizingCategory)

- (void)setAutoSizingWidthConstraint:(NSLayoutConstraint *)autoSizingWidthConstraint {
    objc_setAssociatedObject(self, @selector(autoSizingWidthConstraint), autoSizingWidthConstraint, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (NSLayoutConstraint *)autoSizingWidthConstraint {
    return objc_getAssociatedObject(self, @selector(autoSizingWidthConstraint));
}

- (void)addToSuperViewAsAutoSizingCell:(UIView *)superview {
    for (UILabel *label in [self autoSizingLabels]) {
        [label setContentHuggingPriority:0
                                 forAxis:UILayoutConstraintAxisVertical];
    }
    
    self.hidden = YES;
    self.translatesAutoresizingMaskIntoConstraints = NO;
    self.contentView.translatesAutoresizingMaskIntoConstraints = NO;
    [superview addSubview:self];
}

- (CGFloat)autoSizingHeightWithTargetTableView:(UITableView *)tableView {
    CGFloat
    tableViewWidth = tableView.bounds.size.width;
    if (0. == tableViewWidth) { return 0.; }
    
    UIView
    *contentView = self.contentView;
    
    NSLayoutConstraint
    *width = self.autoSizingWidthConstraint;
    if (nil == width) {
        width = [NSLayoutConstraint constraintWithItem:contentView attribute:NSLayoutAttributeWidth
                                             relatedBy:NSLayoutRelationEqual
                                                toItem:nil attribute:NSLayoutAttributeNotAnAttribute
                                            multiplier:1. constant:tableViewWidth];
        [contentView addConstraint:width];
        self.autoSizingWidthConstraint = width;
    }
    width.constant = tableViewWidth;
    
    [contentView setNeedsLayout];
    [contentView layoutIfNeeded];
    
    for (UILabel *label in [self autoSizingLabels]) {
        label.preferredMaxLayoutWidth = label.bounds.size.width;
    }
    
    CGSize
    size = [contentView systemLayoutSizeFittingSize:UILayoutFittingCompressedSize];
    
    return size.height + 1.;
}

- (NSArray *)autoSizingLabels {
    return nil;
}


@end
