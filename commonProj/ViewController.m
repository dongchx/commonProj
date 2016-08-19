//
//  ViewController.m
//  commonProj
//
//  Created by dongchx on 8/18/16.
//  Copyright © 2016 dongchx. All rights reserved.
//

#import "ViewController.h"
#import <Masonry/Masonry.h>
#import "UITableViewCell+CPAutoSizingCategory.h"
#import "UIColor+CPSimpleColor.h"

@interface ViewController ()
<UITableViewDelegate, UITableViewDataSource>

@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) NSArray<NSString *> *dataArray;

@end

@implementation ViewController

- (void)dealloc
{
    
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor yellowColor];
    
    [self initTableData];
    [self initTableView:self.view];
}

- (void)initTableView:(__weak UIView *)parentView
{
    UITableView *tableView = [[UITableView alloc] init];
    tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    tableView.backgroundColor = [UIColor yellowColor];
    tableView.delegate = self;
    tableView.dataSource = self;
    [parentView addSubview:tableView];
    
    [tableView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.edges.equalTo(parentView).insets(UIEdgeInsetsMake(64., 0, 0, 0));
    }];
    
    _tableView = tableView;
}

- (void)initTableData
{
    _dataArray = @[
                   @"就一行",
                   @"要两行要两行要两行要两行要两行",
                   @"最好三行最好三行最好三行最好三行最好三行最好三行",
                   @"任意几行都可以任意几行都可以任意几行都可以任意几行都可以任意几行都可以任意几行都可以任意几行都可以",
                   @"随便了",
                   ];
}

#pragma mark - tableView delegate/datasource

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return _dataArray.count * 2 - 1;
}

- (UITableViewCell *)tableView:(UITableView *)tableView
         cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString  *separatorReuseId  = @"separatorReuseId";
    static NSString  *autoHeightReuseId = @"autoHeightReuseId";
    NSUInteger index = indexPath.row;
    
    if (index%2 != 0 ) {
        CPSeparatorCell *cell =
        [tableView dequeueReusableCellWithIdentifier:separatorReuseId];
        
        if (!cell) {
            cell = [[CPSeparatorCell alloc] initWithStyle:UITableViewCellStyleDefault
                                          reuseIdentifier:separatorReuseId];
        }
        
        return cell;
        
    }
    else {
        CPAutoHeightCell *cell =
        [tableView dequeueReusableCellWithIdentifier:autoHeightReuseId];
        
        if (!cell) {
            cell = [[CPAutoHeightCell alloc] initWithStyle:UITableViewCellStyleDefault
                                           reuseIdentifier:autoHeightReuseId];
        }
        
        [cell setLabelText:_dataArray[index/2]];
        return cell;
    }
    
    return [[UITableViewCell alloc] init];
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    NSUInteger index = indexPath.row;
    
    if (index%2 != 0) {
        return separatorCellHeight;
    }
    else {
        UITableViewCell<CPAutoSizableTableViewCell> *cell
        = [self autoSizableTableViewCell];
        
        if ([cell isKindOfClass:[CPAutoHeightCell class]]) {
            [(CPAutoHeightCell *)cell setLabelText:_dataArray[index/2]];
        }
        
        return [cell autoSizingHeightWithTargetTableView:tableView];
    }
    
    return 50.;
}

- (UITableViewCell<CPAutoSizableTableViewCell> *)autoSizableTableViewCell
{
    return [[CPAutoHeightCell alloc] initWithStyle:UITableViewCellStyleDefault
                                   reuseIdentifier:@"autoHeightReuseId"];
}

@end // ViewController



@implementation CPAutoHeightCell
{
    UILabel *_autoLabel;
}

- (instancetype)initWithStyle:(UITableViewCellStyle)style
              reuseIdentifier:(NSString *)reuseIdentifier
{
    if (self = [super initWithStyle:style reuseIdentifier:reuseIdentifier]) {
        [self setupSubviews:self.contentView];
    }
    
    return self;
}

- (void)setupSubviews:(__weak UIView *)parentView
{
    UILabel *autoLabel = [[UILabel alloc] init];
    autoLabel.numberOfLines = 0;
    autoLabel.textColor = [UIColor blackColor];
    autoLabel.backgroundColor = [UIColor greenColor];
    autoLabel.font = [UIFont systemFontOfSize:12];
    [parentView addSubview:autoLabel];
    
    [autoLabel mas_makeConstraints:^(MASConstraintMaker *make) {
//        make.edges.equalTo(parentView).
//        insets(UIEdgeInsetsMake(4, 16, 4  , parentView.bounds.size.width - 120));
        make.left.equalTo(parentView).offset(16.);
        make.right.equalTo(parentView).offset(-(parentView.bounds.size.width - 120));
        make.top.equalTo(parentView);
        make.bottom.equalTo(parentView);
    }];
    
    _autoLabel = autoLabel;
}

- (void)setLabelText:(NSString *)text
{
    _autoLabel.text = text;
}

#pragma mark - Auto Sizing

- (NSArray *)autoSizingLabels
{
    return @[_autoLabel,];
}

@end // CPAutoHeightCell



@implementation CPSeparatorCell

- (instancetype)initWithStyle:(UITableViewCellStyle)style
              reuseIdentifier:(NSString *)reuseIdentifier
{
    if (self = [super initWithStyle:style reuseIdentifier:reuseIdentifier]) {
        self.contentView.backgroundColor = [UIColor colorWithHex:0x999999];
        self.userInteractionEnabled = NO;
    }
    
    return self;
}

@end // CPSeparatorCell







































