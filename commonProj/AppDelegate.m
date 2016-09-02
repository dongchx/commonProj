//
//  AppDelegate.m
//  commonProj
//
//  Created by dongchx on 8/18/16.
//  Copyright © 2016 dongchx. All rights reserved.
//

#import "AppDelegate.h"
#import "CPHomePageVC.h"
#import "CPAudioEngine.h"

@interface AppDelegate ()

@end

@implementation AppDelegate


- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    
    CPHomePageVC *VC = [[CPHomePageVC alloc] init];
    UINavigationController *navi = [[UINavigationController alloc] initWithRootViewController:VC];
    self.window.rootViewController = navi;
    [self.window makeKeyAndVisible];
    
    NSError* error;
    [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayback error:&error];
    
    return YES;
}

- (void)applicationWillResignActive:(UIApplication *)application {
    // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
    // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
    
    NSLog(@"顽强的打出一行字告诉你我要挂起了！！");
    [CPAudioEngine sharedInstance].isBackground = YES;
    if ([[CPAudioEngine sharedInstance] isPlaying]) {
        [[UIApplication sharedApplication] beginReceivingRemoteControlEvents];
        [self becomeFirstResponder];
    }
    
}

- (void)applicationDidEnterBackground:(UIApplication *)application {
    // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
    // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
}

- (void)applicationWillEnterForeground:(UIApplication *)application {
    // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
    [CPAudioEngine sharedInstance].isBackground = NO;
}

- (void)applicationDidBecomeActive:(UIApplication *)application {
    // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
}

- (void)applicationWillTerminate:(UIApplication *)application {
    // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
}

- (void)remoteControlReceivedWithEvent:(UIEvent *)event {
    [[CPAudioEngine sharedInstance] remoteremoteControlReceivedWithEvent:event];
}

- (void)startBackgroundTask
{
    UIBackgroundTaskIdentifier newTaskId = UIBackgroundTaskInvalid;
    newTaskId = [[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler:^{
        if (bgTaskId != UIBackgroundTaskInvalid)
        {
            [[UIApplication sharedApplication] endBackgroundTask:bgTaskId];
        }
        bgTaskId = UIBackgroundTaskInvalid;}];
    
    if (newTaskId != UIBackgroundTaskInvalid && bgTaskId != UIBackgroundTaskInvalid)
    {
        [[UIApplication sharedApplication] endBackgroundTask:bgTaskId];
    }
    
    bgTaskId = newTaskId;
}

@end




















