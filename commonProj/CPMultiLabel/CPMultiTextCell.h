//
//  CPMultiTextCell.h
//  commonProj
//
//  Created by dongchx on 15/08/2017.
//  Copyright © 2017 dongchx. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface CPMultiTextCellModel : NSObject

@property (nonatomic, copy) NSString *content;
@property (nonatomic, assign) NSInteger contentLines;
@property (nonatomic, assign) BOOL isOpen;

- (instancetype)initWithContent:(NSString *)content
                   contentLines:(CGFloat)contentLines
                         isOpen:(BOOL)isOpen;

@end

typedef void(^CPOpenContentBlock) (CPMultiTextCellModel *cellModel);

@interface CPMultiTextCell : UITableViewCell

@property (nonatomic, copy) CPOpenContentBlock openContentBlock;

- (void)setCellModel:(CPMultiTextCellModel *)model;
+ (CGFloat)cellHeightWithModel:(CPMultiTextCellModel *)model;

@end
