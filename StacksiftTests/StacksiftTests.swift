//
//  StacksiftTests.swift
//  StacksiftTests
//
//  Created by Matthew Massicotte on 2021-09-14.
//

import XCTest
@testable import Stacksift

class StacksiftTests: XCTestCase {
    func testMetricKitMonitoring() throws {
        let monitor = Stacksift.Monitor.inProcessOnly

        XCTAssertTrue(monitor.impactEnabled)
        XCTAssertFalse(monitor.metricKitEnabled)
    }

    func testStartMethods() throws {
        let config = Stacksift.Configuration(APIKey: "key")

        config.monitor = .metricKitOnly

        Stacksift.start(configuration: config)
    }
}
