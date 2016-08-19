//
//  ViewController.m
//  commonProj
//
//  Created by dongchx on 8/18/16.
//  Copyright © 2016 dongchx. All rights reserved.
//

#import "ViewController.h"

@interface ViewController ()

@property (nonatomic, strong) UITableView *tableView;

@end

@implementation ViewController

- (void)dealloc
{
    
}

- (void)viewDidLoad
{
    [super viewDidLoad];
}

- (void)initTabelView
{
    UITableView *tableView = [[UITableView alloc] init];
    tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    [self.view addSubview: tableView];
    
    _tableView = tableView;
}

@end
