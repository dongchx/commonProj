//
//  CPMemoryViewController.m
//  commonProj
//
//  Created by dongchenxi on 2019/7/24.
//  Copyright © 2019 dongchx. All rights reserved.
//

#import "CPMemoryViewController.h"

@interface CPMemoryViewController ()

@end

@implementation CPMemoryViewController

extern uintptr_t _objc_rootRetainCount(id obj);
extern void _objc_autoreleasePoolPrint(void);

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    [self setupSubviews:self.view];
    [self test];
}

#pragma mark - subviews

- (void)setupSubviews:(UIView *)superview
{
    superview.backgroundColor = UIColor.whiteColor;
}

#pragma mark -

- (void)test
{
//    @autoreleasepool {
//        id __autoreleasing obj = [NSObject new];
//        NSLog(@"obj=%@", obj);
//    }
//
//    id obj = [NSObject new];
//    @autoreleasepool {
//        id __autoreleasing o = obj;
//        NSLog(@"retain count = %lu", _objc_rootRetainCount(obj));
//    }
//
//    NSLog(@"retain count = %lu", _objc_rootRetainCount(obj));
//
//    id obj = [NSObject new];
//    @autoreleasepool {
//        id __weak wobj = obj;
//        NSLog(@"retain count = %lu", _objc_rootRetainCount(obj));
//        NSLog(@"1 %@", wobj);
//        NSLog(@"retain count = %lu", _objc_rootRetainCount(obj));
//        NSLog(@"2 %@", wobj);
//        NSLog(@"retain count = %lu", _objc_rootRetainCount(obj));
//    }
    
//    NSAutoreleasePool *aPool  = [[NSAutoreleasePool alloc] init];
//    id obj = [NSObject new];
//    NSLog(@"retain count = %lu", _objc_rootRetainCount(obj));
//    [obj autorelease];
//    [obj release];
//    NSLog(@"retain count = %lu", _objc_rootRetainCount(obj));
//    [aPool release];
    
    id obj = [NSObject new];
    id __unsafe_unretained usObj = obj;
    NSLog(@"retain count = %lu", _objc_rootRetainCount(obj));
    
    @autoreleasepool {
        id __autoreleasing aObj = obj;
        NSLog(@"retain count = %lu", _objc_rootRetainCount(obj));
    }
    
}

@end
