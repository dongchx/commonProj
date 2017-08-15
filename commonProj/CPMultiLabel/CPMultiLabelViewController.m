//
//  CPMultiLabelViewController.m
//  commonProj
//
//  Created by dongchx on 15/08/2017.
//  Copyright © 2017 dongchx. All rights reserved.
//

#import "CPMultiLabelViewController.h"
#import "Masonry.h"
#import "CPMultiTextCell.h"

static NSString *cellReuseId = @"cellReuserId";

@interface CPMultiLabelViewController ()
<UITableViewDelegate, UITableViewDataSource>

@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) NSMutableArray *dataSource;
@property (nonatomic, assign) NSInteger lines;

@end

@implementation CPMultiLabelViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.lines = 2;
    
    NSArray *contentArr = [[NSMutableArray alloc]initWithObjects:
                           @"在iOS中，有时候显示文本，需要设置文本的行间距、指定显示行数、文本内容超出显示行数，省略结尾部分的内容以……方式省略。这些都可以使用UILabel来是实现，前提是你扩展了UILabel这方面的特性。",
                           @"这个Demo是使用UITableView组织文本的显示。每一个cell可以显示title和content，cell中先指定content文本显示3行，行间距是5.0f。",
                           @"如果content文本用3行不能全部显示，文本下面出现“显示文本”按钮，点击“显示全文”按钮，可以展开全部文本，此时按钮变成“收起全文”；点击按钮可以收起全文，依旧显示3行，按钮恢复成“显示全文”。",
                           @"如果content文本用3行可以全部显示，不会出现按钮。",
                           @"content显示的文本可以设置行数值，行间距值，收起全文和展开全文都是利用**UILabel的扩展特性**来实现的。content显示的文本可以设置行数值，行间距值，收起全文和展开全文都是利用**UILabel的扩展特性**来实现的。",nil];
    
    for (int i = 0; i < contentArr.count; i++) {
        CPMultiTextCellModel *model =
        [[CPMultiTextCellModel alloc] initWithContent:contentArr[i]
                                         contentLines:3
                                               isOpen:YES];
        
        [self.dataSource addObject:model];
    }
    
    [self setupSubviews:self.view];
}

- (NSMutableArray *)dataSource{
    
    if (!_dataSource) {
        _dataSource = [NSMutableArray array];
    }
    return _dataSource;
}

#pragma mark - subviews

- (void)setupSubviews:(UIView *)parentView
{
    UITableView *tableView =
    [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
    [parentView addSubview:tableView];
    
    tableView.delegate = self;
    tableView.dataSource = self;
    
    [tableView registerClass:CPMultiTextCell.class
      forCellReuseIdentifier:cellReuseId];
    
    [tableView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.edges.equalTo(parentView)
        .insets(UIEdgeInsetsMake(kCPNaviBarHeight, 0, 0, 0));
    }];
    
    tableView.backgroundColor = [UIColor greenColor];
    
    _tableView = tableView;
}

#pragma mark - tableViewDataSource

- (NSInteger)tableView:(UITableView *)tableView
 numberOfRowsInSection:(NSInteger)section
{
    return self.dataSource.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView
         cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    CPMultiTextCell *cell =
    [tableView dequeueReusableCellWithIdentifier:cellReuseId];
    
    __weak typeof(self) weakSelf = self;
    [cell setOpenContentBlock:^(CPMultiTextCellModel *cellModel){
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (cellModel.isOpen) {
            cellModel.contentLines = 0;  //0,不限制行数
        }else{
            cellModel.contentLines = 3;     //3,3行
        }
        NSInteger newxtRow = (indexPath.row + 1) >= [self.dataSource count] - 1 ?  [self.dataSource count] - 1 :(indexPath.row + 1);
        [strongSelf.tableView reloadRowsAtIndexPaths:@[[NSIndexPath indexPathForRow:newxtRow  inSection:indexPath.section]] withRowAnimation:UITableViewRowAnimationFade];
    }];
    
    [cell setCellModel:[self.dataSource objectAtIndex:indexPath.row]];
    
    return cell;
}

- (CGFloat)     tableView:(UITableView *)tableView
  heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return
    [CPMultiTextCell cellHeightWithModel:
     [self.dataSource objectAtIndex:indexPath.row]];
}

#pragma mark - tableViewDelegate

@end
