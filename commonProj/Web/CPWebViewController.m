//
//  CPWebViewController.m
//  commonProj
//
//  Created by dongchenxi on 2018/12/24.
//  Copyright © 2018 dongchx. All rights reserved.
//

#import "CPWebViewController.h"

@interface CPWebViewController () <UIWebViewDelegate>
@property (nonatomic, strong) UIWebView *webView;
@end

@implementation CPWebViewController

- (instancetype)init
{
    if (self = [super init]) {
        [self setupSubviews:self.view];
    }
    
    return self;
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
    _webView = [[UIWebView alloc] initWithFrame:CGRectMake(0, 0, parentView.viewWidth, parentView.viewHeight)];
    [parentView addSubview:_webView];
    _webView.backgroundColor = UIColor.whiteColor;
    
    self.webView.scrollView.scrollEnabled = NO;
    
    NSString *Str = [NSString stringWithFormat:@"<iframe frameborder=\"0\" width=\"359\" height=\"200\" src=\"//m.baidu.com\" allowfullscreen></iframe>"];
    
    [_webView loadHTMLString:Str baseURL:nil];

}

- (void)fullScreen
{
    
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
