//
//  CPThreadViewController.m
//  commonProj
//
//  Created by dongchx on 7/21/17.
//  Copyright © 2017 dongchx. All rights reserved.
//
//  参考文献
//  http://www.jianshu.com/p/0b0d9b1f1f19

#import "CPThreadViewController.h"

#import <pthread.h>


@interface CPThreadViewController ()

@end

@implementation CPThreadViewController

#pragma mark - lifeCycle

- (void)dealloc
{
    
}

- (void)viewDidLoad
{
    [super viewDidLoad];
}

#pragma mark - pthread

- (void)createPthread
{
    pthread_t thread;
    
    // 创建一个线程并执行
    pthread_create(&thread, NULL, start, NULL);
    
}

void *start(void *data)
{
    NSLog(@"%@", [NSThread currentThread]);
    
    return NULL;
}

#pragma mark - NSThread

- (void)createNSThread
{
    
    NSThread *thread = [[NSThread alloc] initWithTarget:self
                                               selector:@selector(runNSThread)
                                                 object:nil];
    thread.threadPriority = 1.0; // 线程优先级
    
    [thread start];
}

- (void)backgroundRun
{
    // NSObject 方法 PS:苹果认为不安全
    [self performSelectorInBackground:@selector(runNSThread) withObject:nil];
}

- (void)runNSThread
{
    
}

// 从此开始有了 任务 和 队列 的概念
#pragma mark - GCD



#pragma mark - NSOperation & NSOperationQueue

@end


























