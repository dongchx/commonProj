//
//  CPConsole.m
//  commonProj
//
//  Created by dongchx on 7/27/17.
//  Copyright © 2017 dongchx. All rights reserved.
//

#import "CPConsole.h"

@interface CPConsole () <UITextViewDelegate>

@end

@implementation CPConsole

- (instancetype)init
{
    if (self = [super init]) {
        self.backgroundColor = [UIColor blackColor];
        self.textColor = [UIColor whiteColor];
        self.delegate = self;
    }
    
    return self;
}

- (void)log:(NSString *)logStr
{
    void (^blk)(void) = ^(void) {
        if (self.text && self.text.length > 0) {
            NSString *text =
            [NSString stringWithFormat:@"%@\n%@",
             self.text, [self logWithHeader:logStr]];
            
            self.text = text;
        }
        else {
            self.text = [self logWithHeader:logStr];
        }
        
        if (self.contentSize.height - self.bounds.size.height <= 0) {
            return;
        }
        
        CGPoint bottomOffset = CGPointMake(0,self.contentSize.height - self.bounds.size.height);
        [self setContentOffset:bottomOffset animated:YES];
    };
    
    dispatch_async(dispatch_get_main_queue(), blk);
}

- (NSString *)logWithHeader:(NSString *)logStr
{
    return [NSString stringWithFormat:@"%@:%@", [NSDate date], logStr];
}

- (BOOL)textViewShouldBeginEditing:(UITextView *)textView
{
    [textView resignFirstResponder];
    
    return NO;
}

@end



















