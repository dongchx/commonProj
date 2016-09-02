//
//  CPHomePageVC.m
//  commonProj
//
//  Created by dongchx on 8/23/16.
//  Copyright © 2016 dongchx. All rights reserved.
//

#import "CPHomePageVC.h"
#import "CPAudioMainVC.h"

@interface CPHomePageVC ()
<UITableViewDelegate, UITableViewDataSource>

@property (nonatomic, strong) UITableView       *tableView;
@property (nonatomic, strong) NSArray           *tableData;

@end

@implementation CPHomePageVC

- (void)viewDidLoad {
    [super viewDidLoad];
    
    [self loadTableData];
    [self setupSubviews:self.view];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    
}

- (void)setupSubviews:(__weak UIView *)parentView
{
    UITableView *tableView = [[UITableView alloc] init];
    tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    tableView.delegate = self;
    tableView.dataSource = self;
    tableView.backgroundColor = [UIColor colorWithHex:0xffffff];
    [parentView addSubview:tableView];
    
    [tableView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.edges.equalTo(parentView);
    }];
    
    _tableView = tableView;
}

- (void)loadTableData
{
    _tableData = @[
                   @"AutoCellHeight",
                   @"Audio",
                   ];
}

#pragma mark - tableViewDelegate

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView
 numberOfRowsInSection:(NSInteger)section
{
    return _tableData.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView
         cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *reuseId = @"reuseId";
    
    CPHomePageCell *cell = [tableView dequeueReusableCellWithIdentifier:reuseId];
    
    if (!cell) {
        cell = [[CPHomePageCell alloc] initWithStyle:UITableViewCellStyleDefault
                                     reuseIdentifier:reuseId];
    }
    
    cell.title = _tableData[indexPath.row];
    
    return cell;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return 50.;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [tableView deselectRowAtIndexPath:indexPath animated:NO];
    
    if (indexPath.row == 1) {
        UIViewController *VC = [[CPAudioMainVC alloc] init];
        [self.navigationController pushViewController:VC animated:YES];
    }
}

@end // CPHomePageVC



@implementation CPHomePageCell
{
    UILabel *_titleLabel;
}

- (instancetype)initWithStyle:(UITableViewCellStyle)style
              reuseIdentifier:(NSString *)reuseIdentifier
{
    if (self = [super initWithStyle:style
                    reuseIdentifier:reuseIdentifier]) {
        self.contentView.backgroundColor = [UIColor colorWithHex:0x999999];
        UIView *bgView = [[UIView alloc] init];
        bgView.backgroundColor = [UIColor colorWithHex:0xffffff];
        [self.contentView addSubview:bgView];
        
        [bgView mas_makeConstraints:^(MASConstraintMaker *make) {
            make.edges.equalTo(self.contentView).insets(UIEdgeInsetsMake(0, 0, 7.0, 0));
        }];
        
        [self setupSubviews:bgView];
        
    }
    return self;
}

- (void)setupSubviews:(__weak UIView *)parentView
{
    UILabel *titleLabel = [[UILabel alloc] init];
    titleLabel.font = [UIFont systemFontOfSize:20];
    titleLabel.textColor = [UIColor blackColor];
    titleLabel.backgroundColor = [UIColor colorWithHex:0xffffff];
    [parentView addSubview:titleLabel];
    
    [titleLabel mas_makeConstraints:^(MASConstraintMaker *make) {
        make.edges.equalTo(parentView).insets(UIEdgeInsetsMake(0, 16., 0., 16.));
    }];
    
    _titleLabel = titleLabel;
}

- (NSString *)title
{
    return _titleLabel.text;
}

- (void)setTitle:(NSString *)title
{
    _titleLabel.text = title;
}

@end // CPHomePageCell











































