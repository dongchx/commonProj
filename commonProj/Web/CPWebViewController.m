//
//  CPWebViewController.m
//  commonProj
//
//  Created by dongchenxi on 2018/12/24.
//  Copyright © 2018 dongchx. All rights reserved.
//

#import "CPWebViewController.h"
#import <WebKit/WebKit.h>
#import <TTBSPatch/TTBSPatch.h>
//#import <mach/mach_init.h>
//#import <mach/mach_host.h>
//#import <mach/host_info.h>
#include <sys/sysctl.h>
#import "CPProc.h"

@interface CPWebViewController () <UIWebViewDelegate, WKUIDelegate, WKNavigationDelegate>
//@property (nonatomic, strong) UIWebView *webView;
@property (nonatomic, strong) WKWebView *webView;
@property (nonatomic, strong) UIBarButtonItem *redBtn;
@property (nonatomic, strong) UIBarButtonItem *greBtn;
@end

@implementation CPWebViewController

- (void)dealloc {
    [NSNotificationCenter.defaultCenter removeObserver:self];
}

- (instancetype)init
{
    if (self = [super init]) {
        [self setupSubviews:self.view];
//        [self registerNotifications];
//        [self patch];
    }
    
    return self;
}

- (void)patch {
    NSString *file = @"/Users/dongchenxi/Desktop";
    NSString *o = [file stringByAppendingPathComponent:@"app.1000098.6"];
    NSString *p = [file stringByAppendingPathComponent:@"app.1000098.7_"];
    NSString *t = [file stringByAppendingPathComponent:@"t"];
    
    [TTBSPatch patchWithOriginFilePath:o
                        targetFilePath:t
                         patchFilePath:p];
}

- (void)registerNotifications {
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(didEnterBackground)
                                                 name:UIApplicationDidEnterBackgroundNotification
                                               object:nil];
//    [[NSNotificationCenter defaultCenter] addObserver:self
//                                             selector:@selector(willEnterForeground)
//                                                 name:UIApplicationWillEnterForegroundNotification
//                                               object:nil];
}

- (void)didEnterBackground {
    [self handleRedBtnAction:nil];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
}

#pragma mark - subviews

- (void)setupSubviews:(UIView *)parentView
{
    parentView.backgroundColor = UIColor.whiteColor;
//    _webView = [[UIWebView alloc] initWithFrame:CGRectMake(0, 0, parentView.viewWidth, parentView.viewHeight)];
//    [parentView addSubview:_webView];
//    _webView.backgroundColor = UIColor.whiteColor;
//
//    self.webView.scrollView.scrollEnabled = NO;
//
//    NSString *Str = [NSString stringWithFormat:@"<iframe frameborder=\"0\" width=\"359\" height=\"200\" src=\"//m.baidu.com\" allowfullscreen></iframe>"];
//
//    [_webView loadHTMLString:Str baseURL:nil];
    WKWebViewConfiguration *config = [WKWebViewConfiguration new];
    config.allowsInlineMediaPlayback = YES;
    config.mediaTypesRequiringUserActionForPlayback = WKAudiovisualMediaTypeNone;

    _webView = [[WKWebView alloc] initWithFrame:CGRectZero configuration:config];
    _webView.UIDelegate = self;
    _webView.navigationDelegate = self;
    _webView.backgroundColor = [UIColor lightGrayColor];
//    _webView.opaque = NO;
    _webView.hidden = NO;
    _webView.scrollView.bounces = NO;
    _webView.frame = parentView.bounds;
    if (@available(iOS 11.0, *)) {
        _webView.scrollView.contentInsetAdjustmentBehavior = UIScrollViewContentInsetAdjustmentNever;
    }
    [parentView addSubview:_webView];
    
    // btns
    _redBtn = [[UIBarButtonItem alloc] initWithTitle:@"red"
                                               style:UIBarButtonItemStylePlain
                                              target:self
                                              action:@selector(handleRedBtnAction:)];
//    _redBtn.frame = CGRectMake(20, 100, 50, 50);
//    _redBtn.backgroundColor = UIColor.redColor;
//    [_redBtn addTarget:self
//                action:@selector(handleRedBtnAction:)
//      forControlEvents:UIControlEventTouchUpInside];
    
    _greBtn = [[UIBarButtonItem alloc] initWithTitle:@"gre"
                                               style:UIBarButtonItemStylePlain
                                              target:self
                                              action:@selector(handleGreBtnAction:)];
    self.navigationItem.rightBarButtonItems = @[_redBtn, _greBtn];
//    _greBtn.frame = CGRectMake(100, 100, 50, 50);
//    _greBtn.backgroundColor = UIColor.greenColor;
//    [_greBtn addTarget:self
//                action:@selector(handleGreBtnAction:)
//      forControlEvents:UIControlEventTouchUpInside];
}

- (void)reload:(NSString *)urlStr {
    NSURL *url = [NSURL URLWithString:urlStr];
//    NSURL *burl = [NSURL URLWithString:@"about:blank"];
    NSURLRequest *request = [NSURLRequest requestWithURL:url];
//    NSURLRequest *breq = [NSURLRequest requestWithURL:burl];
    
//    [_webView loadRequest:breq];
    [_webView loadRequest:request];
}

- (void)handleRedBtnAction:(id)sender {
//    _webView.hidden = YES;
//    [_webView removeFromSuperview];
//    [self reload:@"http://www.google.com"];
    
    // sysctl ------------------------------------------------------------
    size_t bufSize = 0;
    int mib[4] = {CTL_KERN, KERN_PROC, KERN_PROC_ALL, 0};
    if(sysctl(mib, 4, NULL, &bufSize, NULL, 0) < 0) {
        return;
    }
    bufSize *= 2;
    struct kinfo_proc *kp = (struct kinfo_proc *)malloc(bufSize);
    int ret = sysctl(mib, 4, kp, &bufSize, NULL, 0);
    unsigned long count = bufSize / sizeof(struct kinfo_proc);
    
//    // NSProcessInfo -----------------------------------------------------
//    NSProcessInfo *procinfo = [NSProcessInfo processInfo];
    
    for (int i = 0; i < count; i++) {
        CPProc *proc =  [[CPProc alloc] initWithKinfo:&kp[i]];
        NSLog(@"[debug] n  %@, %d, %d, %llu", proc.name, proc.pid, proc.ppid, (proc->basic.resident_size/8)/1024);
//        NSLog(@"[debug] pn %@", proc.pName);
    }
    
    free(kp);
    
    NSLog(@"[debug]");
}

- (void)handleGreBtnAction:(id)sender {
    _webView.hidden = NO;
    if (!_webView.superview) {
        [self.view addSubview:_webView];
    }
    [self reload:@"http://m.baidu.com/"];
}

#pragma mark - webview delegate

- (BOOL)            webView:(UIWebView *)webView
 shouldStartLoadWithRequest:(NSURLRequest *)request
             navigationType:(UIWebViewNavigationType)navigationType
{
    NSLog(@"%@", NSStringFromSelector(_cmd));
    
    NSLog(@"%@", request.URL.absoluteString);
    
    return YES;
}

- (void)webViewDidStartLoad:(UIWebView *)webView
{
    NSLog(@"%@", NSStringFromSelector(_cmd));
}

- (void)webViewDidFinishLoad:(UIWebView *)webView
{
    NSLog(@"%@", NSStringFromSelector(_cmd));
}

- (void)webView:(UIWebView *)webView didFailLoadWithError:(NSError *)error
{
    NSLog(@"%@", NSStringFromSelector(_cmd));
}

#pragma mark - screenshot

- (void)handleButtonAction:(id)sender
{
    for (UIViewController *vc in self.navigationController.viewControllers) {
        [self isWhiteScreen:vc.view];
    }
}

- (BOOL)isWhiteScreen:(UIView *)view
{
    UIGraphicsBeginImageContextWithOptions(view.frame.size, YES, 0.0);  //NO，YES 控制是否透明
    
    [view.layer renderInContext:UIGraphicsGetCurrentContext()];
    view.layer.contents = nil;
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    CGRect myImageRect = CGRectMake(view.frame.size.width / 4, 0, view.frame.size.width / 2, view.frame.size.height);
    CGImageRef imageRef = image.CGImage;
    CGImageRef subImageRef = CGImageCreateWithImageInRect(imageRef,myImageRect);
    
    // 分配内存
    const int imageWidth = myImageRect.size.width;
    const int imageHeight = myImageRect.size.height;
    size_t    bytesPerRow = imageWidth * 4;
    uint32_t* rgbImageBuf = (uint32_t*)malloc(bytesPerRow * imageHeight);
    
    // 创建context
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGContextRef context = CGBitmapContextCreate(rgbImageBuf, imageWidth, imageHeight, 8, bytesPerRow, colorSpace,kCGBitmapByteOrder32Little | kCGImageAlphaNoneSkipLast);
    CGContextDrawImage(context, CGRectMake(0, 0, imageWidth, imageHeight), subImageRef);
    
    // 遍历像素
    int pixelNum = imageWidth * imageHeight;
    uint32_t  firstPtr = *rgbImageBuf;
    uint32_t* pCurPtr = rgbImageBuf;
    BOOL isWhite = YES;
    for (int i = 0; i < pixelNum; i+=4, pCurPtr+=4) {
        int y = memcmp(pCurPtr, &firstPtr, sizeof(firstPtr));
        if (y!=0) {
            isWhite = NO;
            break;
        }
    }
    
    if (isWhite &&
        firstPtr != 0Xffffffff &&
        firstPtr != 0Xfefffeff) {
        // 避免纯色误判
        isWhite = NO;
    }
    
    CGImageRelease(subImageRef);
    CGContextRelease(context);
    CGColorSpaceRelease(colorSpace);
    free(rgbImageBuf);
    
    return isWhite;
}

@end
