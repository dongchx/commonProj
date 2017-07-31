//
//  CPViewController.m
//  commonProj
//
//  Created by dongchx on 7/31/17.
//  Copyright © 2017 dongchx. All rights reserved.
//

#import "CPViewController.h"
#import "Masonry.h"

@interface CPViewController ()
<UITableViewDelegate, UITableViewDataSource>

@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) CPConsole   *console;

@end

@implementation CPViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
}

#pragma mark - tableView & console

- (void)setupTableViewAndConsole
{
    __weak UIView *parentView = self.view;
    
    UITableView *tableView =
    [[UITableView alloc] initWithFrame:CGRectZero
                                 style:UITableViewStylePlain];
    [parentView addSubview:tableView];
    tableView.delegate = self;
    tableView.dataSource = self;
    
    CPConsole *console = [[CPConsole alloc] init];
    [parentView addSubview:console];
    
    [tableView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.right.equalTo(parentView);
        make.top.equalTo(parentView).offset(kCPNaviBarHeight);
        make.bottom.equalTo(parentView.mas_centerY);
    }];
    
    [console mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.right.bottom.equalTo(parentView);
        make.top.equalTo(parentView.mas_centerY);
    }];
    
    self.tableView = tableView;
    self.console   = console;
}

#pragma mark - UITableViewDataSource

- (NSArray<NSString *> *)tableViewStringArray
{
    // subclass override
    return
    @[];
}

- (NSInteger)tableView:(UITableView *)tableView
 numberOfRowsInSection:(NSInteger)section
{
    return self.tableViewStringArray.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView
         cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *reuseId = @"cellreuseid";
    
    UITableViewCell *cell =
    [tableView dequeueReusableCellWithIdentifier:reuseId];
    
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault
                                      reuseIdentifier:reuseId];
    }
    
    cell.textLabel.text = [self.tableViewStringArray objectAtIndex:indexPath.row];
    
    return cell;
}

- (CGFloat)     tableView:(UITableView *)tableView
  heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return 50.;
}

#pragma mark - UITableViewDelegate

- (void)didSelectAtIndexPath:(NSIndexPath *)indexPath
{
    // subclass override
}

- (void)        tableView:(UITableView *)tableView
  didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    [self didSelectAtIndexPath:indexPath];
}

@end




















