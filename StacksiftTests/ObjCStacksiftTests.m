//
//  ObjCStacksiftTests.m
//  ObjCStacksiftTests
//
//  Created by Matthew Massicotte on 2021-09-14.
//

#import <XCTest/XCTest.h>
@import Stacksift;

@interface ObjCStacksiftTests : XCTestCase

@end

@implementation ObjCStacksiftTests

- (void)testCreateConfiguration {
    StacksiftConfiguration* config = [[StacksiftConfiguration alloc] initWithAPIKey:@"key"];

    XCTAssertEqual(@"key", config.APIKey);
}

- (void)testStartMethods {
    StacksiftConfiguration* config = [[StacksiftConfiguration alloc] initWithAPIKey:@"key"];

    config.monitor = MonitorMetricKitOnly;

    [Stacksift startWithConfiguration:config];
}

@end
