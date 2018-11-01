//
//  PasswordValidatorTests.swift
//  tokenTests
//
//  Created by James Chen on 2018/02/16.
//  Copyright © 2018 ConsenLabs. All rights reserved.
//

import XCTest
@testable import TokenCore

class PasswordValidatorTests: TestCase {
  func testValidate() {
    let password = "1234!@#$"
    let validator = PasswordValidator(password)
    XCTAssert(validator.isFormatValid)
    XCTAssert(validator.isValid)
    XCTAssertNoThrow(try validator.validate())
  }

  func testValidateMap() {
    let password = "1234!@#$"
    let validator = try! PasswordValidator(["password": password])
    XCTAssert(validator.isFormatValid)
    XCTAssert(validator.isValid)
    XCTAssertNoThrow(try validator.validate())
  }

  func testInvalidMap() {
    XCTAssertThrowsError(try PasswordValidator(["abc": "abc"]))
  }

  func testValidateReturn() {
    let password = "1234!@#$"
    let validator = PasswordValidator(password)
    do {
      let result = try validator.validate()
      XCTAssertEqual(password, result)
    } catch {
      XCTFail("No throw!")
    }
  }

  func testInvalidFormat() {
    let password = "1234"
    let validator = PasswordValidator(password)
    XCTAssertFalse(validator.isFormatValid)
    XCTAssertFalse(validator.isValid)
    XCTAssertThrowsError(try validator.validate())
  }

  func testBlank() {
    let password = "1234"
    let validator = PasswordValidator(password)
    XCTAssertFalse(validator.isValid)
    XCTAssertThrowsError(try validator.validate())
  }
}
