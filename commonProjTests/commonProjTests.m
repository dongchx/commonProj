//
//  commonProjTests.m
//  commonProjTests
//
//  Created by dongchx on 8/18/16.
//  Copyright © 2016 dongchx. All rights reserved.
//

#import <XCTest/XCTest.h>

@interface commonProjTests : XCTestCase

@end

@implementation commonProjTests

- (void)setUp {
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

- (void)testExample {
    // This is an example of a functional test case.
    // Use XCTAssert and related functions to verify your tests produce the correct results.
}

- (void)testPerformanceExample {
    // This is an example of a performance test case.
    [self measureBlock:^{
        // Put the code you want to measure the time of here.
    }];
}

- (void)testAssert
{
    // 1. Unconditional Fail：无条件失败当直接到达特定的代码分支指示失败时使用。
    XCTFail(@"无条件失败....");

    // 2.Boolean Tests
    BOOL a = NO;
    XCTAssert(a,@"失败时提示：a == false");
    XCTAssertTrue(a,@"失败时提示：a == false");
    XCTAssertFalse(a,@"失败时提示：a == true");

    // 3.基础数据类型
    NSInteger b = 1;
    NSInteger c = 1;
    NSInteger d = 2;
    XCTAssertEqual(b, c, @"失败时提示：b!= c");
    XCTAssertGreaterThan(d, c,@"失败时提示：d < c");
    XCTAssertEqualWithAccuracy(c, d, 1,@"失败时提示：c和d的误差的绝对值大于1");

    // 4.对象类型
    NSString *nameA = @"nameA";
    NSString *nameB = @"nameB";
    XCTAssertEqualObjects(nameA, nameB,@"失败时提示：nameA != nameB");
    XCTAssertNil(nameA,@"失败时提示：nameA != nil");
    
    // 5. Exception Tests
    NSArray *array = @[];
    XCTAssertThrows(array[0],@"失败时提示：array[0]没有抛出异常");
    XCTAssertNoThrow(array[0],@"失败时提示：array[0]抛出异常");
    XCTAssertThrowsSpecific(array[0], NSException,@"失败时提示：array[0]没有抛出NSException异常");
    XCTAssertThrowsSpecificNamed(array[0],
                                 NSException,
                                 @"NSRangeException",
                                 @"失败时提示：array[0]没有抛出名为NSRangeException的NSException异常");
}



@end
