//
//  ReachabilityManager.m
//  QZone
//本类主要用于判断手机接入网络情况。能够判断
//手机是否接入网络（NotReachable），
//是否通过wifi方式接入网络（ReachableViaWiFi）
//是否通过GPRS或3G接入网络。
//
//一般本类和appdelegate类结合使用，在使用本来时，可以通过接收kReachabilityChangedNotification来监听手机接入网络变化情况，
//并能够通过networkStatus 属性来判断手机联网能力.
//
//具体用法参加iPhone QZone代码
//  Created by Zhao Yongpeng on 10-11-4.
//  Copyright 2010 tencent. All rights reserved.
//

#import "ReachabilityManager.h"


#import <sys/socket.h>
#import <netinet/in.h>
#import <netinet6/in6.h>
#import <arpa/inet.h>
#import <ifaddrs.h>
#import <netdb.h>

#import <CoreFoundation/CoreFoundation.h>


static ReachabilityManager* instance ;

static void ReachabilityCallback(SCNetworkReachabilityRef target, SCNetworkReachabilityFlags flags, void* info)
{
 
	NSCAssert(info != NULL, @"info was NULL in ReachabilityCallback");
	NSCAssert([(NSObject*) info isKindOfClass: [ReachabilityManager class]], @"info was wrong class in ReachabilityCallback");
	
	ReachabilityManager* noteObject = (ReachabilityManager*) info;
	[noteObject reachabilityChanged:flags];
}


@implementation ReachabilityManager
@synthesize networkStatus;
+ (ReachabilityManager*) sharedInstance
{
	if (instance==NULL) {
		//peacezhao 严格说，这种写法会导致内存泄露的。只不过因为本类时单例类，并且本类是和appdelegate结合使用的，不需考虑内存泄露
		instance=[[ReachabilityManager alloc] init];
	}
	return instance;
}

- (id) init
{
	if (self=[super init]) 
	{
		NSString* hostName=@"www.qq.com";
	   reachabilityRef=SCNetworkReachabilityCreateWithName(NULL, [hostName UTF8String]);
	}
	return self;
}


- (BOOL) startNotifier
{
	BOOL retVal = NO;
	
	SCNetworkReachabilityContext	context = {0, self, NULL, NULL, NULL};
	if(SCNetworkReachabilitySetCallback(reachabilityRef, ReachabilityCallback, &context))
	{
		if(SCNetworkReachabilityScheduleWithRunLoop(reachabilityRef, CFRunLoopGetCurrent(), kCFRunLoopDefaultMode))
		{
			retVal = YES;
		}
	}
	return retVal;
}

- (void) stopNotifier
{
	if(reachabilityRef!= NULL)
	{
		SCNetworkReachabilityUnscheduleFromRunLoop(reachabilityRef, CFRunLoopGetCurrent(), kCFRunLoopDefaultMode);
	}
}

- (void) dealloc
{
	[self stopNotifier];
	if(reachabilityRef!= NULL)
	{
		CFRelease(reachabilityRef);
	}
	[super dealloc];
}

//通过SCNetworkReachabilityFlags判断手机接入网络状态,具体含义见SystemConfiguration framework文档 
- (NetworkStatus) networkStatusForFlags: (SCNetworkReachabilityFlags) flags
{
	if ((flags & kSCNetworkReachabilityFlagsReachable) == 0)
	{
		return NotReachable;
	}
	
	NetworkStatus retVal = NotReachable;
	
	if ((flags & kSCNetworkReachabilityFlagsConnectionRequired) == 0)
	{
		retVal = ReachableViaWiFi;
	}
	
	
	if ((((flags & kSCNetworkReachabilityFlagsConnectionOnDemand ) != 0) ||
		 (flags & kSCNetworkReachabilityFlagsConnectionOnTraffic) != 0))
	{

		if ((flags & kSCNetworkReachabilityFlagsInterventionRequired) == 0)
		{

			retVal = ReachableViaWiFi;
		}
	}
	
	if ((flags & kSCNetworkReachabilityFlagsIsWWAN) == kSCNetworkReachabilityFlagsIsWWAN)
	{
		retVal = ReachableViaWWAN;
	}
	return retVal;
}

#pragma mark ReachabilityAppDelegate Methods

//获取手机联网状态，并且广播出去.
- (void) reachabilityChanged: (SCNetworkReachabilityFlags)flags
{
	networkStatus = [self networkStatusForFlags: flags];
	if ( networkStatus==ReachableViaWWAN )
	{
        
//		[[[[ToastView alloc] initWithString:@"当前网络为3G网络，请注意流量消耗..."] autorelease] show];
//        if ( !isNotNeedAlert )
//        {
//            UIAlertView * av = [[UIAlertView alloc] initWithTitle:nil message:NSLocalizedString(@"NetGPRSTip", nil) delegate:self cancelButtonTitle:nil otherButtonTitles:NSLocalizedString(@"Confirm", nil), nil];
//            [av show];
//            [av release];
//        }
        isNotNeedAlert = YES;
	}
    else
    {
        isNotNeedAlert = NO;
    }
	
	[[NSNotificationCenter defaultCenter] postNotificationName:kReachabilityChangedNotification object:self];
}

//peacezhao 20101112 判断是否通过wifi方式上网
- (BOOL)isThroughWifi
{
	return networkStatus==ReachableViaWiFi;
}

// 是否3G or GPRS
- (BOOL)isThroughGPRS
{
	return networkStatus==ReachableViaWWAN;;
}

- (BOOL)CurrentNetworkStatus
{
	return networkStatus;
}

- (BOOL)isNetWorkAvailable
{
	return networkStatus!=NotReachable;
}

@end