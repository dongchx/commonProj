//
//  CPBlockViewController.m
//  commonProj
//
//  Created by dongchenxi on 2019/7/25.
//  Copyright © 2019 dongchx. All rights reserved.
//

#import "CPBlockViewController.h"

typedef void (^blk_t)(void);

@interface CPBlockObject : NSObject

@end

@implementation CPBlockObject
@end

@interface CPBlockViewController ()
{
    blk_t _blk;
}

@property (nonatomic, weak) NSMutableArray *weakObj;

@end

@implementation CPBlockViewController

extern uintptr_t _objc_rootRetainCount(id obj);
extern void _objc_autoreleasePoolPrint(void);

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    [self setupSubviews:self.view];
    
//    [self autoVar];
//    [self useBlockArray];
//    [self useBlockVar];
    [self instanceBlock];
    [self printWeak];
}

#pragma mark - subviews

- (void)setupSubviews:(UIView *)superview
{
    superview.backgroundColor = UIColor.whiteColor;
}

#pragma mark - block

- (void)autoVar
{
    // 截获自动变量
    int var = 10;
    const char *fmt = "var = %d\n";
    void (^blk)(void) = ^{ printf(fmt, var); };
    var = 6;
    blk();
    
    var = 2;
    printf("current var = %d\n", var);
    blk();
}

- (NSArray *)blockArray
{
    int var = 10;
    return [[NSArray alloc] initWithObjects:
            ^{NSLog(@"blk0:%d", var);},
            (id)^{NSLog(@"blk1:%d", var);}, nil];
}

- (void)useBlockArray
{
    NSArray *bArray = self.blockArray;
    
    blk_t blk0 = (blk_t)[bArray objectAtIndex:0];
    blk_t blk1 = (blk_t)[bArray objectAtIndex:1];
    
    blk0();
    blk1();
}

- (void)useBlockVar
{
    __block int var = 0;
    
    void (^blk)(void) = [^{var++;} copy];
    
    var++;
    blk();
    
    NSLog(@"blk = %d", var);
}

- (void)instanceBlock
{
    NSMutableArray *obj = [NSMutableArray new];
    _weakObj = obj;
    
    NSLog(@"%ld", obj.count);
    
    blk_t blk = ^{
        [obj addObject:@(1)];
        NSLog(@"%ld", obj.count);
    };
    blk();
    
    [obj addObject:@(1)];
    NSLog(@"%ld", obj.count);
    
    blk();
    
    _blk = blk;
    
    NSLog(@"retain count = %lu", _objc_rootRetainCount(obj));
}

- (void)printWeak
{
    NSLog(@"%@", _weakObj);
    
    NSLog(@"retain count = %lu", _objc_rootRetainCount(_weakObj));
}

@end
