//
//  TTBSPatch.h
//  TTBSPatch
//
//  Created by dongchenxi on 2019/12/27.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface TTBSPatch : NSObject

/**
 @param originFile  The absolute path of file will be patched
 @param targetFile  The absolute path of the new file will be created
 @param patchFile   The patch file's absolute path
 @return patch success or fail
 */
+ (BOOL)patchWithOriginFilePath:(NSString *)originFilePath
                 targetFilePath:(NSString *)targetFilePath
                  patchFilePath:(NSString *)patchFilePath;


@end

NS_ASSUME_NONNULL_END
