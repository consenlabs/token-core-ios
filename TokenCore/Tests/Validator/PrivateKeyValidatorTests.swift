//
//  PrivateKeyValidatorTests.swift
//  tokenTests
//
//  Created by James Chen on 2018/02/16.
//  Copyright © 2018 ConsenLabs. All rights reserved.
//

import XCTest
@testable import TokenCore

class PrivateKeyValidatorTests: TestCase {
  func testValidateBTC() {
    let validator = PrivateKeyValidator(TestData.wif, on: .btc, network: .mainnet)
    XCTAssert(validator.isValid)
    XCTAssertNoThrow(try validator.validate())
  }

  func testValidateBTCNetwork() {
    let validator = PrivateKeyValidator(TestData.wif, on: .btc, network: .testnet)
    XCTAssertFalse(validator.isValid)
    XCTAssertThrowsError(try validator.validate())
  }

  func testValidateETH() {
    let validator = PrivateKeyValidator(TestData.privateKey, on: .eth)
    XCTAssert(validator.isValid)
    XCTAssertNoThrow(try validator.validate())
  }

  func testValidateBTCReturn() {
    let validator = PrivateKeyValidator(TestData.wif, on: .btc, network: .mainnet)
    do {
      let result = try validator.validate()
      XCTAssertEqual(TestData.wif, result)
    } catch {
      XCTFail("No throw!")
    }
  }

  func testValidateETHReturn() {
    let validator = PrivateKeyValidator(TestData.privateKey, on: .eth)
    do {
      let result = try validator.validate()
      XCTAssertEqual(TestData.privateKey, result)
    } catch {
      XCTFail("No throw!")
    }
  }

  func testInvalidBTC() {
    let validator = PrivateKeyValidator("abc", on: .btc)
    XCTAssertFalse(validator.isValid)
    XCTAssertThrowsError(try validator.validate())
  }

  func testInvalidBTCSegWitUncompressed() {
    // SegWit must have compressed key
    let validator = PrivateKeyValidator("5J1jV2CspMgKnS4N7zJJz8Xcej3Lngcu89WP53jXW4CXEGF9M3A", on: .btc, requireCompressed: true)
    XCTAssertFalse(validator.isValid)
    XCTAssertThrowsError(try validator.validate())
  }

  func testInvalidETH() {
    let validator = PrivateKeyValidator("abc", on: .eth)
    XCTAssertFalse(validator.isValid)
    XCTAssertThrowsError(try validator.validate())
  }

  func testInvalidETHPubKey() {
    let validator = PrivateKeyValidator("0000000000000000000000000000000000000000000000000000000000000000", on: .eth)
    XCTAssertFalse(validator.isValid)
    XCTAssertThrowsError(try validator.validate())
  }
  
  func testValidateEOS() {
    let validator = PrivateKeyValidator(TestData.eosPrivateKey, on: .eos)
    XCTAssert(validator.isValid)
    XCTAssertNoThrow(try validator.validate())
  }

  func testInvalidEOS() {
    let validator = PrivateKeyValidator("abc", on: .eos)
    XCTAssertFalse(validator.isValid)
    XCTAssertThrowsError(try validator.validate())
  }

  func testValidateEOSReturn() {
    let validator = PrivateKeyValidator(TestData.eosPrivateKey, on: .eos)
    do {
      let result = try validator.validate()
      XCTAssertEqual(TestData.eosPrivateKey, result)
    } catch {
      XCTFail("No throw!")
    }
  }
}
