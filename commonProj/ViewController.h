//
//  ViewController.h
//  commonProj
//
//  Created by dongchx on 8/18/16.
//  Copyright © 2016 dongchx. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface ViewController : UIViewController


@end

@interface CPAutoHeightCell : UITableViewCell

- (void)setLabelText:(NSString *)text;

@end

static const NSInteger separatorCellHeight = 8.;

@interface CPSeparatorCell : UITableViewCell

@end

