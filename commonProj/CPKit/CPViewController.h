//
//  CPViewController.h
//  commonProj
//
//  Created by dongchx on 7/31/17.
//  Copyright © 2017 dongchx. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "CPConsole.h"

#define kCPNaviBarHeight 64
#define CPCLog(fmt, ...) [self.console log:[NSString stringWithFormat:fmt, ##__VA_ARGS__]]

@interface CPViewController : UIViewController

@end

@interface CPViewController (CPConsole)

@property (nonatomic, strong) CPConsole   *console;

- (void)setupTableViewAndConsole;
- (NSArray<NSString *> *)tableViewStringArray;
- (void)didSelectAtIndexPath:(NSIndexPath *)indexPath;

@end
