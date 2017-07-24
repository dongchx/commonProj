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

#pragma mark - subviews

- (void)setupSubviews:(UIView *)parentView
{
    
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
    // NSObject 方法 PS:苹果认为并不安全
    [self performSelectorInBackground:@selector(runNSThread) withObject:nil];
}

- (void)runNSThread
{
    
}

#pragma mark - GCD

- (void)mainQueue
{
    // 主线程任务
    dispatch_async(dispatch_get_main_queue(), ^{
        for (int i = 0; i < 10; i++) {
            NSLog(@"主线程任务_mainQueue_1:%d", i);
        }
    });
    
    NSLog(@"The end");
}

- (void)privateSyncQueue
{
    // 创建串行队列
    dispatch_queue_t queue =  dispatch_queue_create("com.gcd.dongchx.syncqueue", NULL);
    
    // 私有串行队列任务1
    dispatch_async(queue, ^{
        for (int i = 0; i < 10; i++) {
            NSLog(@"私有串行队列任务1_i:%d", i);
        }
    });
    
    // 私有串行队列任务2
    dispatch_async(queue, ^{
        for (int i = 0; i < 10; i++) {
            NSLog(@"私有串行队列任务2_i:%d", i);
        }
    });
    
    NSLog(@"The end");
}

- (void)globalQueue
{
    // 全局并行队列
    dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    
    // 创建私有并行队列
//    dispatch_queue_t pQueue = dispatch_queue_create("com.asyncqueue.gcd.dongch", DISPATCH_QUEUE_CONCURRENT);
    
    // 全局并行队列任务1
    dispatch_async(queue, ^{
        for (int i = 0; i < 10; i++) {
            NSLog(@"全局并行队列任务1_i:%d", i);
            [NSThread sleepForTimeInterval:0.5];
        }
    });
    
    // 全局并行队列任务2
    dispatch_async(queue, ^{
        for (int i = 0; i < 10; i++) {
            NSLog(@"全局并行队列任务2_i:%d", i);
            [NSThread sleepForTimeInterval:0.5];
        }
    });
    
    // 同步任务
    dispatch_sync(queue, ^{
        for (int i = 0; i < 10; i++) {
            NSLog(@"全局并行队列任务3_sync_i:%d", i);
            [NSThread sleepForTimeInterval:0.5];
        }
    });
    
    dispatch_sync(queue, ^{
        for (int i = 0; i < 10; i++) {
            NSLog(@"全局并行队列任务4_sync_i:%d", i);
            [NSThread sleepForTimeInterval:0.5];
        }
    });
    
    NSLog(@"The end");
}

- (void)dispathcAfter
{
    // dispatch_afer
    // 只是延迟提交block到queue，不是延时立刻执行
    double delayInSeconds = 2.0;
    dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t) (delayInSeconds * NSEC_PER_SEC));
    dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
        NSLog(@"dispatch_afer_done");
    });
}

- (void)dispatchBarrier
{
    // 创建私有并行队列
    dispatch_queue_t queue =
    dispatch_queue_create("com.gcd.dongchx.asyncqueue", DISPATCH_QUEUE_CONCURRENT);
    
    // 全局并行队列任务1
    dispatch_async(queue, ^{
        for (int i = 0; i < 10; i++) {
            NSLog(@"全局并行队列任务1_i:%d", i);
            [NSThread sleepForTimeInterval:0.5];
        }
    });
    
    //
    dispatch_barrier_async(queue, ^{
        for (int i = 0 ; i < 10; i++) {
            NSLog(@"全局并行队列任务_barrier_i:%d", i);
        }
    });
    
    // 全局并行队列任务2
    dispatch_async(queue, ^{
        for (int i = 0; i < 10; i++) {
            NSLog(@"全局并行队列任务2_i:%d", i);
            [NSThread sleepForTimeInterval:0.5];
        }
    });
    
    NSLog(@"The end");
}

- (void)dispatchApply
{
    NSArray *array = @[@"0", @"1",@"2",@"3",@"4",@"5",];
    
    dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    
    // 会阻塞主线程
    dispatch_apply(array.count, queue, ^(size_t i) {
        NSLog(@"dispatch_apply_%ld:%@",i, [array objectAtIndex:i]);
    });
    
    NSLog(@"The end");
}

- (void)dispatchGroupsWait
{
    dispatch_queue_t concurrentQueue =
    dispatch_queue_create("com.gcd.dongchx.asyncqueue",DISPATCH_QUEUE_CONCURRENT);
    dispatch_group_t group = dispatch_group_create();
    
    //在group中添加队列的block
    dispatch_group_async(group, concurrentQueue, ^{
        for (int i = 0; i < 10; i++) {
            NSLog(@"dipatch_groups_1_i:%d", i);
            [NSThread sleepForTimeInterval:0.5];
        }
    });
    dispatch_group_async(group, concurrentQueue, ^{
        for (int i = 0; i < 10; i++) {
            NSLog(@"dipatch_groups_2_i:%d", i);
            [NSThread sleepForTimeInterval:0.5];
        }
    });
    dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
    NSLog(@"dispatch_group_wait_The end");
}

- (void)dispatchGroupsNotify
{
    dispatch_queue_t concurrentQueue =
    dispatch_queue_create("com.gcd.dongchx.asyncqueue",DISPATCH_QUEUE_CONCURRENT);
    dispatch_group_t group = dispatch_group_create();
    
    //在group中添加队列的block
    dispatch_group_async(group, concurrentQueue, ^{
        for (int i = 0; i < 10; i++) {
            NSLog(@"dipatch_groups_1_i:%d", i);
            [NSThread sleepForTimeInterval:0.5];
        }
    });
    dispatch_group_async(group, concurrentQueue, ^{
        for (int i = 0; i < 10; i++) {
            NSLog(@"dipatch_groups_2_i:%d", i);
            [NSThread sleepForTimeInterval:0.5];
        }
    });
    
    dispatch_group_notify(group, dispatch_get_main_queue(), ^{
        NSLog(@"dispatch_group_notify_The end");
    });
}

- (void)dispatchSemaphore
{
    // 信号量
    //
    // 创建semophore
    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSLog(@"start");
        [NSThread sleepForTimeInterval:3.f];
        NSLog(@"semaphore +1");
        dispatch_semaphore_signal(semaphore); //+1 semaphore
    });
    
    dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
    NSLog(@"dispatch_semaphore_continue");
}

#pragma mark - NSOperation & NSOperationQueue

@end


























