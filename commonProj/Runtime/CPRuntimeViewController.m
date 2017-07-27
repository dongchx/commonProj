//
//  CPRuntimeViewController.m
//  commonProj
//
//  Created by dongchx on 7/26/17.
//  Copyright © 2017 dongchx. All rights reserved.
//

#import "CPRuntimeViewController.h"
#import <objc/runtime.h>
#import "CPConsole.h"
#import "Masonry.h"

@interface CPRuntimeViewController ()

@property (nonatomic, strong) CPConsole *console;

@end

@implementation CPRuntimeViewController

+ (void)load
{
    NSLog(@"CPRuntimeViewController Load;");
}

+ (void)initialize
{
    
}

#pragma mark - lifeCycle

- (void)dealloc
{
    
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    [self setupSubviews:self.view];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    NSLog(@"CPRuntimeViewController willAppear;");
}

- (void)setupSubviews:(UIView *)parentView
{
    CPConsole *console = [[CPConsole alloc] init];
    [parentView addSubview:console];
    
    [console mas_makeConstraints:^(MASConstraintMaker *make) {
        
    }];
}

#pragma mark - runtime API

- (void)changeName
{
    // 动态更改变量的值
    CPRuntimePerson *p = [[CPRuntimePerson alloc] init];
    NSLog(@"oldPropertyName:%@", p.pName);
    
    unsigned int count = 0;
    Ivar *ivar = class_copyIvarList(p.class, &count);
    
    for (int i = 0; i < count; i++) {
        Ivar var = ivar[i];
        const char *varName = ivar_getName(var);
        NSString *name = [NSString stringWithUTF8String:varName];
        
        // 注意属性和变量的区别 下划线
        if ([name isEqualToString:@"_pName"]) {
            object_setIvar(p, var, @"newName");
            break;
        }
    }
    NSLog(@"newPropertyName:%@", p.pName);
}

- (void)addMethod
{
    // 存疑
    CPRuntimePerson *p = [[CPRuntimePerson alloc] init];
    
    Method newMethod = class_getInstanceMethod(self.class, @selector(doSomething));
    IMP newMethodImp = method_getImplementation(newMethod);
    
    class_addMethod(p.class, @selector(newMethod), newMethodImp, method_getTypeEncoding(newMethod));
    
    if ([p respondsToSelector:@selector(newMethod)]) {
        [p performSelector:@selector(newMethod)];
    }
    else {
        NSLog(@"addMethodFail");
    }
    
}

- (void)doSomething
{
    NSLog(@"propertyDoSomething");
}

- (void)newMethod
{
    
}

@end


@implementation CPRuntimePerson

- (instancetype)init
{
    if (self = [super init]) {
        self.pName = @"defaultName";
    }
    
    return self;
}

@end


@interface UIViewController (CPMethodSwizzling)
@end

/*
 
 +load 和 +initialize 是 Objective-C runtime 会自动调用的两个类方法。
 但是它们被调用的时机却是有差别的，+load 方法是在类被加载的时候调用的，
 而 +initialize 方法是在类或它的子类收到第一条消息之前被调用的，
 这里所指的消息包括实例方法和类方法的调用。也就是说 +initialize 方法是以懒加载的方式被调用的，
 如果程序一直没有给某个类或它的子类发送消息，那么这个类的 +initialize 方法是永远不会被调用的。
 此外 +load 方法还有一个非常重要的特性，那就是子类、父类和分类中的 +load 方法的实现是被区别对待的。
 换句话说在 Objective-C runtime 自动调用 +load 方法时，
 分类中的 +load 方法并不会对主类中的 +load 方法造成覆盖。
 综上所述，+load 方法是实现 Method Swizzling 逻辑的最佳“场所”。
 
*/

@implementation UIViewController (CPMethodSwizzling)

+ (void)load
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        Class cls = [self class];
        
        SEL originalSelector = @selector(viewWillAppear:);
        SEL swizzledSelector = @selector(cpms_viewWillAppear:);
        
        Method originalMethod = class_getInstanceMethod(cls, originalSelector);
        Method swizzledMethod = class_getInstanceMethod(cls, swizzledSelector);
        
        BOOL success =
        class_addMethod(cls, originalSelector,
                        method_getImplementation(swizzledMethod),
                        method_getTypeEncoding(swizzledMethod));
        
        if (success) {
            class_replaceMethod(cls, swizzledSelector,
                                method_getImplementation(originalMethod),
                                method_getTypeEncoding(originalMethod));
        }
        else {
            method_exchangeImplementations(originalMethod, swizzledMethod);
        }
    });
}

#pragma mark - Method Swizzling

- (void)cpms_viewWillAppear:(BOOL)animated
{
    [self cpms_viewWillAppear:animated];
    NSLog(@"CPMethodSwizzling_swizzled;");
}

@end

#pragma mark - 关联对象 AssociatedObjects

@interface CPRuntimeViewController (AssociatedObjects)

@property (assign, nonatomic) NSString *associatedObject_assign;
@property (strong, nonatomic) NSString *associatedObject_retain;
@property (copy,   nonatomic) NSString *associatedObject_copy;

@end

@implementation CPRuntimeViewController (AssociatedObjects)

- (NSString *)associatedObject_assign
{
    return objc_getAssociatedObject(self, _cmd);
}

- (void)setAssociatedObject_assign:(NSString *)associatedObject_assign
{
    objc_setAssociatedObject(self, @selector(associatedObject_assign),
                             associatedObject_assign, OBJC_ASSOCIATION_ASSIGN);
}

- (NSString *)associatedObject_retain
{
    return objc_getAssociatedObject(self, _cmd);
}

- (void)setAssociatedObject_retain:(NSString *)associatedObject_retain
{
    objc_setAssociatedObject(self, @selector(associatedObject_retain),
                             associatedObject_retain, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (NSString *)associatedObject_copy
{
    return objc_getAssociatedObject(self, _cmd);
}

- (void)setAssociatedObject_copy:(NSString *)associatedObject_copy
{
    objc_setAssociatedObject(self, @selector(associatedObject_copy),
                             associatedObject_copy, OBJC_ASSOCIATION_COPY_NONATOMIC);
}


@end





























