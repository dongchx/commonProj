//
//  TTBSPatch.m
//  TTBSPatch
//
//  Created by dongchenxi on 2019/12/27.
//

#import "TTBSPatch.h"
#import "bspatch.h"

@implementation TTBSPatch

+ (BOOL)patchWithOriginFilePath:(NSString *)originFilePath
                 targetFilePath:(NSString *)targetFilePath
                  patchFilePath:(NSString *)patchFilePath {
    NSAssert(originFilePath && targetFilePath && patchFilePath,
             @"patch file path can not be nil");

    if (originFilePath == nil
        || targetFilePath == nil
        || patchFilePath == nil) {
        return NO;
    }

    const char *argv[4];
    argv[0] = "bspatch";
    argv[1] = [originFilePath UTF8String];
    argv[2] = [targetFilePath UTF8String];
    argv[3] = [patchFilePath UTF8String];
    int result = bspatch(4, argv);
    return 0 == result ? YES : NO;
}

@end
