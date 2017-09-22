//
//  CPCoreGraphicsViewController.m
//  commonProj
//
//  Created by dongchx on 22/09/2017.
//  Copyright © 2017 dongchx. All rights reserved.
//

#import "CPCoreGraphicsViewController.h"
#import "CPCoreGraphicsTView.h"

@interface CPCoreGraphicsViewController ()

@property (nonatomic, strong) CPCoreGraphicsTView *tView;

@end

@implementation CPCoreGraphicsViewController

+ (void)initialize
{
    [self initializeSizes];
}

#pragma mark - lc

- (void)viewDidLoad
{
    [super viewDidLoad];
}

#pragma mark - subviews

- (void)setupSubviews:(UIView *)parentView
{
    
}

#pragma mark - size

static struct Size
{
    struct {
        UIEdgeInsets edges;
        CGSize size;
    } tView;
    
}*_sizes;

+ (void)initializeSizes
{
    _sizes = malloc(sizeof(struct Size));
    *_sizes = (struct Size) {
        .tView = {
            .edges = {
                .left = 15,
                .right = 15,
                .top = 15,
                .bottom = 15,
            },
            .size = {
                .width  = 100,
                .height = 60,
            }
        },
    };
}

@end






















































