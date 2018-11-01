//
//  WalletIDValidatorTests.swift
//  TokenCoreTests
//
//  Created by James Chen on 2018/05/24.
//  Copyright © 2018 ConsenLabs. All rights reserved.
//

import XCTest
@testable import TokenCore

class WalletIDValidatorTests: TestCase {
  func testValidate() {
    let id = BTCMnemonicKeystore.generateKeystoreId()
    let validator = WalletIDValidator(walletID: id)
    XCTAssert(validator.isValid)
    XCTAssertNoThrow(try validator.validate())
  }

  func testInvalid() {
    let invalidIDs = [
      "abc",
      "5CBF03DF-FC01-4B87-A1EE-D65978F80441", // Require lower case
      "../Library/3198bc9c-6672-5ab3-d995-4942343ae5b6"
    ]
    for id in invalidIDs {
      let validator = WalletIDValidator(walletID: id)
      XCTAssertFalse(validator.isValid)
    }
  }

  func testValidateReturn() {
    let id = BTCMnemonicKeystore.generateKeystoreId()
    let validator = WalletIDValidator(walletID: id)
    do {
      let result = try validator.validate()
      XCTAssertEqual(id, result)
    } catch {
      XCTFail("No throw!")
    }
  }
}
