//
//  UITableViewCell+CPAutoSizingCategory.h
//  commonProj
//
//  Created by dongchx on 8/19/16.
//  Copyright © 2016 dongchx. All rights reserved.
//

#import <UIKit/UIKit.h>

@protocol CPAutoSizableTableViewCell <NSObject>

@property (readwrite, nonatomic) NSLayoutConstraint *autoSizingWidthConstraint;
- (NSArray *)autoSizingLabels;
- (void)addToSuperViewAsAutoSizingCell:(UIView *)superview;
- (CGFloat)autoSizingHeightWithTargetTableView:(UITableView *)tableView;

@end


@interface UITableViewCell (CPAutoSizingCategory)
<CPAutoSizableTableViewCell>

@end
