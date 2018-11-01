//
//  V3KeystoreValidatorTests.swift
//  tokenTests
//
//  Created by James Chen on 2018/02/16.
//  Copyright © 2018 ConsenLabs. All rights reserved.
//

import XCTest
@testable import TokenCore

class V3KeystoreValidatorTests: TestCase {
  func testValidate() {
    let data = TestHelper.loadJSON(filename: "v3-pbkdf2-testpassword")
    let jsonObj = try! data.tk_toJSON()
    let validator = V3KeystoreValidator(jsonObj)
    XCTAssert(validator.isValid)
    XCTAssertNoThrow(try validator.validate())
  }

  func testInvalidVersion() {
    let data = TestHelper.loadJSON(filename: "v3-incorrect-version")
    let jsonObj = try! data.tk_toJSON()
    let validator = V3KeystoreValidator(jsonObj)
    XCTAssertFalse(validator.isValid)
  }

  func testNoCryptoNode() {
    let data = """
    {
      "version": 3,
      "address": "008aeeda4d805471df9b2a5b0f38a0c3bcba786b",
      "cryptola": ""
    }
    """
    let jsonObj = try! data.tk_toJSON()
    let validator = V3KeystoreValidator(jsonObj)
    XCTAssertFalse(validator.isValid)
  }

  func testValidateReturn() {
    let data = TestHelper.loadJSON(filename: "v3-pbkdf2-testpassword")
    
    do {
      let jsonObj = try data.tk_toJSON()
      let validator = V3KeystoreValidator(jsonObj)
      let result = try validator.validate()
      XCTAssertMapEqual(try! data.tk_toJSON(), result)
    } catch {
      XCTFail("No throw!")
    }
  }

  func testValidateThrow() {
    let data = TestHelper.loadJSON(filename: "v3-incorrect-version")
    
    do {
      let jsonObj = try data.tk_toJSON()
      let validator = V3KeystoreValidator(jsonObj)
      _ = try validator.validate()
      XCTFail()
    } catch let err {
      XCTAssertEqual(KeystoreError.invalid.localizedDescription, err.localizedDescription)
    }
  }
}
