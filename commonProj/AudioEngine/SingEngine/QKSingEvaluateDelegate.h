//
//  QKSingEvaluateDelegate.h
//  QQKala
//
//  Created by frost on 12-6-25.
//  Copyright (c) 2012年 Tencent. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "AudioCommonDefine.h"

@protocol QKSingEvaluateDelegate <NSObject>

/*
 @discussion                this callback fired when a result avaliable
 @param score               result score
 @param type                result type
 @param amplitudeType       amplitude tip for a sentence result, valid only when type is EvaluateResultTypeSentense
 */
- (void)evaluateResult:(NSInteger)score withType:(EvaluateResultType)type tokenIndex:(NSInteger)index amplitudeType:(AmplitudeType)amplitudeType;

@end
