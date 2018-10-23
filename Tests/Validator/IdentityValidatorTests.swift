//
//  IdentityValidatorTests.swift
//  tokenTests
//
//  Created by James Chen on 2018/02/16.
//  Copyright © 2018 ConsenLabs. All rights reserved.
//

import XCTest
@testable import TokenCore

class IdentityValidatorTests: TestCase {
  func testValidate() {
    let validator = IdentityValidator()
    XCTAssert(validator.isValid)
    XCTAssertNoThrow(try validator.validate())
  }

  func testValidateReturn() {
    let validator = IdentityValidator()
    do {
      let result = try validator.validate()
      XCTAssertEqual(result.identifier, Identity.currentIdentity!.identifier)
    } catch {
      XCTFail("No throw!")
    }
  }

  func testInvalidIdentifier() {
    let validator = IdentityValidator(Identity.currentIdentity!.identifier + "-copy")
    XCTAssertFalse(validator.isValid)
    XCTAssertThrowsError(try validator.validate())
  }
}
