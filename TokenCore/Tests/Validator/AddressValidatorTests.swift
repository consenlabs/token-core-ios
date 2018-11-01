//
//  AddressValidatorTests.swift
//  tokenTests
//
//  Created by James Chen on 2018/02/16.
//  Copyright © 2018 ConsenLabs. All rights reserved.
//

import XCTest
@testable import TokenCore

class AddressValidatorTests: TestCase {
  func testValidate() {
    let address = "0xF308646bd9e6808ca7BE41E3e580f8E7196C5573"
    let validator = AddressValidator(address: address)
    XCTAssert(validator.isChecksumValid)
    XCTAssert(validator.isFormatValid)
    XCTAssert(validator.isValid)
    XCTAssertNoThrow(try validator.validate())
  }

  func testValidateReturn() {
    let address = "0xF308646bd9e6808ca7BE41E3e580f8E7196C5573"
    let validator = AddressValidator(address: address)
    do {
      let result = try validator.validate()
      XCTAssertEqual(address, result)
    } catch {
      XCTFail("No throw!")
    }
  }

  func testInvalidLength() {
    let address = "0xF308646bd9e6808ca7BE41E3e580f8E7196C5573-badlength"
    let validator = AddressValidator(address: address)
    XCTAssertFalse(validator.isFormatValid)
    XCTAssertFalse(validator.isValid)
    XCTAssertThrowsError(try validator.validate())
  }

  func testInvalidCharacter() {
    let address = "0xF308646bd9e6808ca7BE41E3e580f8E7196C557G"
    let validator = AddressValidator(address: address)
    XCTAssertFalse(validator.isFormatValid)
    XCTAssertFalse(validator.isValid)
    XCTAssertThrowsError(try validator.validate())
  }

  func testInvalidChecksum() {
    let address = "0xf308646bd9e6808ca7BE41E3e580f8E7196C5573"
    let validator = AddressValidator(address: address)
    XCTAssertFalse(validator.isChecksumValid)
    XCTAssertFalse(validator.isValid)
    XCTAssertThrowsError(try validator.validate())
  }
}
