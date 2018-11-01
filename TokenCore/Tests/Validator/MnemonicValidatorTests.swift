//
//  MnemonicValidatorTests.swift
//  tokenTests
//
//  Created by James Chen on 2018/02/16.
//  Copyright © 2018 ConsenLabs. All rights reserved.
//

import XCTest
@testable import TokenCore

class MnemonicValidatorTests: TestCase {
  func testValidate() {
    let validator = MnemonicValidator(TestData.mnemonic)
    XCTAssert(validator.isLengthValid)
    XCTAssert(validator.isWordListValid)
    XCTAssert(validator.isChecksumValid)
    XCTAssert(validator.isValid)
    XCTAssertNoThrow(try validator.validate())
  }

  func testValidateMap() {
    let validator = try! MnemonicValidator(["mnemonic": TestData.mnemonic])
    XCTAssert(validator.isLengthValid)
    XCTAssert(validator.isWordListValid)
    XCTAssert(validator.isChecksumValid)
    XCTAssert(validator.isValid)
    XCTAssertNoThrow(try validator.validate())
  }

  func testInvalidMap() {
    do {
      _ = try MnemonicValidator(["abc": "abc"])
      XCTFail()
    } catch let err {
      XCTAssertEqual(GenericError.paramError.localizedDescription, err.localizedDescription)
    }
  }

  func testValidateReturn() {
    let validator = MnemonicValidator(TestData.mnemonic)
    do {
      let result = try validator.validate()
      XCTAssertEqual(TestData.mnemonic, result)
    } catch {
      XCTFail("No throw!")
    }
  }

  func testInvalidLength() {
    (1...30).forEach { length in
      if ![12, 15, 18, 21, 24].contains(length) {
        let input = (0..<length).map({ _ in "aaa" }).joined(separator: " ")
        let validator = MnemonicValidator(input)
        XCTAssertFalse(validator.isLengthValid)
      }
    }
  }

  func testInvalidWordList() {
    let validator = MnemonicValidator("notavalidword")
    XCTAssertFalse(validator.isWordListValid)
    XCTAssertThrowsError(try validator.validate())
  }

  func testInvalidChecksum() {
    let validator = MnemonicValidator("a b c d e f g h i j k l")
    XCTAssertFalse(validator.isChecksumValid)
    XCTAssertThrowsError(try validator.validate())
  }
}
