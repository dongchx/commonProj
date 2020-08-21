//
//  CPProc.h
//  commonProj
//
//  Created by dongchenxi on 2020/8/21.
//  Copyright © 2020 dongchx. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <mach/mach_types.h>

NS_ASSUME_NONNULL_BEGIN

@interface CPProc : NSObject
{
    @public mach_task_basic_info_data_t basic;
}

@property (assign) pid_t pid;
@property (assign) pid_t ppid;
@property (assign) unsigned int ports;
@property (strong) NSString *pName;
@property (strong) NSString *name;
@property (strong) NSString *executable;
@property (strong) NSString *args;
@property (strong) NSDictionary *app;

- (instancetype)initWithKinfo:(struct kinfo_proc *)ki;

@end

NS_ASSUME_NONNULL_END
