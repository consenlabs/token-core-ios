//
//  EOSAccountNameValidatorTests.swift
//  TokenCoreTests
//
//  Created by James Chen on 2018/07/04.
//  Copyright © 2018 ConsenLabs. All rights reserved.
//

import XCTest
@testable import TokenCore

class EOSAccountNameValidatorTests: XCTestCase {
  func testValidNames() {
    let accountNames = [
      "",
      "hello",
      "name1",
      "name12",
      "name12",
      "name123",
      "name1234",
      "name1245",
      "sub.one"
    ]
    accountNames.forEach { accountName in
      XCTAssert(EOSAccountNameValidator(accountName).isValid)
    }
  }

  func testInvalidNames() {
    let accountNames = [
      "1111111111111",
      "@",
      "#",
      "hello6",
      "hello7",
      "hello8",
      "hello9",
      "hello0",
      "Name"
    ]
    accountNames.forEach { accountName in
      XCTAssertFalse(EOSAccountNameValidator(accountName).isValid)
    }
  }
}
