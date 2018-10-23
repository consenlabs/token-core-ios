//
//  AppErrorTests.swift
//  TokenCoreTests
//
//  Created by James Chen on 2018/03/28.
//  Copyright © 2018 ConsenLabs. All rights reserved.
//

import XCTest
@testable import TokenCore

class AppErrorTests: XCTestCase {
  func testMessage() {
    let error: AppError = PasswordError.incorrect
    XCTAssertEqual(error.message, PasswordError.incorrect.rawValue)
  }
}
