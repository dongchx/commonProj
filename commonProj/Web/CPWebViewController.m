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
    
    [self.navigationController setNavigationBarHidden:YES];
}

#pragma mark - subviews

- (void)setupSubviews:(UIView *)parentView
{
    parentView.backgroundColor = UIColor.blackColor;
    _webView = [[UIWebView alloc] initWithFrame:CGRectMake(0, 0, parentView.viewWidth, parentView.viewHeight)];
    [parentView addSubview:_webView];
    _webView.backgroundColor = UIColor.whiteColor;
}

- (void)fullScreen
{
    
}

#pragma mark - webview delegate

- (void)webViewDidStartLoad:(UIWebView *)webView
{
    
}

- (void)webViewDidFinishLoad:(UIWebView *)webView
{
    
}

- (void)webView:(UIWebView *)webView didFailLoadWithError:(NSError *)error
{
    
}

@end
