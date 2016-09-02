//
//  ReachabilityManager.h
//  QZone
//
//  Created by Zhao Yongpeng on 10-11-4.
//  Copyright 2010 tencent. All rights reserved.
//


#import <Foundation/Foundation.h>
#import <SystemConfiguration/SystemConfiguration.h>

#define kReachabilityChangedNotification @"kReachabilityChangedNotification"

typedef enum {
	NotReachable = 0,
	ReachableViaWiFi,
	ReachableViaWWAN
} NetworkStatus;


@interface ReachabilityManager: NSObject
{
	SCNetworkReachabilityRef	reachabilityRef;
	NetworkStatus							networkStatus;
    BOOL                        isNotNeedAlert;
}

@property (nonatomic) NetworkStatus networkStatus;

+ (ReachabilityManager*)sharedInstance;
//开始监听手机联网能力变化事件
- (BOOL)startNotifier;
- (void)stopNotifier;
- (void)reachabilityChanged:(SCNetworkReachabilityFlags)flags;
- (BOOL)isThroughWifi;
- (BOOL)isThroughGPRS ;
- (BOOL)CurrentNetworkStatus;
- (BOOL)isNetWorkAvailable;

@end

