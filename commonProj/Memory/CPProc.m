//
//  CPProc.m
//  commonProj
//
//  Created by dongchenxi on 2020/8/21.
//  Copyright © 2020 dongchx. All rights reserved.
//

#import "CPProc.h"
#include <sys/sysctl.h>
#import <mach/mach_host.h>
#import <mach/task_info.h>
#import <mach/thread_info.h>
#import <mach/mach_interface.h>
#import <mach/mach_port.h>

extern int proc_pidpath(int pid, void * buffer, uint32_t  buffersize) __OSX_AVAILABLE_STARTING(__MAC_10_5, __IPHONE_2_0);

@implementation CPProc

- (instancetype)initWithKinfo:(struct kinfo_proc *)ki {
    if (self = [super init]) {
        @autoreleasepool {
            self.pid = ki->kp_proc.p_pid;
            self.ppid = ki->kp_eproc.e_ppid;
            self.pName = [NSString stringWithFormat:@"(%s)", ki->kp_proc.p_comm];
            NSArray *args = [CPProc getArgsByKinfo:ki];
            char buffer[MAXPATHLEN];
            if (proc_pidpath(self.pid, buffer, sizeof(buffer))) {
                self.executable = [NSString stringWithUTF8String:buffer];
            } else {
                self.executable = args[0];
            }
            self.args = @"";
            for (int i = 1; i < args.count; i++) {
                self.args = [self.args stringByAppendingFormat:@" %@", args[i]];
            }
            NSString *path = [self.executable stringByDeletingLastPathComponent];
            self.app = [CPProc getAppByPath:path];
            NSString *firslCol = [[NSUserDefaults standardUserDefaults] stringForKey:@"FirstColumnStyle"];
            if (self.app) {
                NSString *ident = self.app[@"CFBundleIdentifier"];
                if ([firslCol isEqualToString:@"Bundle Identifier"])
                    self.name = ident;
                else if ([firslCol isEqualToString:@"Bundle Name"])
                    self.name = self.app[@"CFBundleName"];
                else if ([firslCol isEqualToString:@"Bundle Display Name"])
                    self.name = self.app[@"CFBundleDisplayName"];
            }
            if ([firslCol isEqualToString:@"Executable With Args"])
                self.name = [[self.executable lastPathComponent] stringByAppendingString:self.args];
            if (!self.name || [firslCol isEqualToString:@"Executable Name"])
                self.name = [self.executable lastPathComponent];
            [self updateMachInfo];
        }
    }
    return self;
}

- (void)updateMachInfo {
    if (![self.name isEqualToString:@"com.apple.WebKit.WebContent"]) {
        return;
    }
//    if (![self.name isEqualToString:@"commonProj"]) {
//        return;
//    }
    task_port_t task;
    memset(&basic, 0, sizeof(basic));

    int r = task_for_pid(mach_task_self(), self.pid, &task);
    if (r != KERN_SUCCESS) {
        NSLog(@"[debugr] %d", r);
        return;
    }
    unsigned int info_count = MACH_TASK_BASIC_INFO_COUNT;
    if (task_info(task, MACH_TASK_BASIC_INFO, (task_info_t)&basic, &info_count) == KERN_SUCCESS) {
        // TODO record max memory usage
    }
}

+ (NSDictionary *)getAppByPath:(NSString *)path {
    return [NSDictionary dictionaryWithContentsOfFile:[path stringByAppendingPathComponent:@"Info.plist"]];
}

+ (NSArray *)getArgsByKinfo:(struct kinfo_proc *)ki {
    NSArray        *args = nil;
    int            nargs, c = 0;
    static int    argmax = 0;
    char        *argsbuf, *sp, *cp;
    int            mib[3] = {CTL_KERN, KERN_PROCARGS2, ki->kp_proc.p_pid};
    size_t        size;

    if (!argmax) {
        int mib2[2] = {CTL_KERN, KERN_ARGMAX};
        size = sizeof(argmax);
        if (sysctl(mib2, 2, &argmax, &size, NULL, 0) < 0)
            argmax = 1024;
    }
    // Allocate process environment buffer
    argsbuf = (char *)malloc(argmax);
    if (argsbuf) {
        size = (size_t)argmax;
        if (sysctl(mib, 3, argsbuf, &size, NULL, 0) == 0) {
            // Skip args count
            nargs = *(int *)argsbuf;
            cp = argsbuf + sizeof(nargs);
            // Skip exec_path and trailing nulls
            for (; cp < &argsbuf[size]; cp++)
                if (!*cp) break;
            for (; cp < &argsbuf[size]; cp++)
                if (*cp) break;
            for (sp = cp; cp < &argsbuf[size] && c < nargs; cp++)
                if (*cp == '\0') c++;
            while (sp < cp && sp[0] == '/' && sp[1] == '/') sp++;
            if (sp != cp) {
                args = [[[NSString alloc] initWithBytes:sp length:(cp-sp) encoding:NSUTF8StringEncoding]
                    componentsSeparatedByString:@"\0"];
            }
        }
        free(argsbuf);
    }
    if (args)
        return args;
    ki->kp_proc.p_comm[MAXCOMLEN] = 0;    // Just in case
    return [NSArray arrayWithObject:[NSString stringWithFormat:@"(%s)", ki->kp_proc.p_comm]];
}

@end
