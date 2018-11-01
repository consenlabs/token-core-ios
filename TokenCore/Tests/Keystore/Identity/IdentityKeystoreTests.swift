//
//  IdentityKeystoreTests.swift
//  tokenTests
//
//  Created by James Chen on 2018/02/24.
//  Copyright © 2018 ConsenLabs. All rights reserved.
//

import XCTest
@testable import TokenCore

class IdentityKeystoreTests: TestCase {
  func testInit() {
    let meta = WalletMeta(source: .newIdentity)
    let keystore = try? IdentityKeystore(metadata: meta, mnemonic: TestData.mnemonic, password: TestData.password)
    XCTAssertNotNil(keystore)
  }

  func testInitFailureWithInvalidMnemomic() {
    let meta = WalletMeta(source: .newIdentity)
    XCTAssertThrowsError(try IdentityKeystore(metadata: meta, mnemonic: "a bad phrase", password: TestData.password))
  }

  func testVerify() {
    let meta = WalletMeta(source: .newIdentity)
    let keystore = try! IdentityKeystore(metadata: meta, mnemonic: TestData.mnemonic, password: TestData.password)
    XCTAssert(keystore.verify(password: TestData.password))
    XCTAssertFalse(keystore.verify(password: "bad" + TestData.password))
  }

  func testMnemonicFromPassword() {
    let meta = WalletMeta(source: .newIdentity)
    let keystore = try! IdentityKeystore(metadata: meta, mnemonic: TestData.mnemonic, password: TestData.password)
    let mnemomic = try? keystore.mnemonic(from: TestData.password)
    XCTAssertEqual(mnemomic, TestData.mnemonic)
  }

  func testSerializeToMap() {
    let meta = WalletMeta(source: .newIdentity)
    var keystore = try! IdentityKeystore(metadata: meta, mnemonic: TestData.mnemonic, password: TestData.password)

    let data = TestHelper.loadJSON(filename: "v3-pbkdf2-testpassword").data(using: .utf8)!
    let json = try! JSONSerialization.jsonObject(with: data) as! JSONObject
    let ethKeystore = try! ETHKeystore(json: json)
    let wallet = BasicWallet(ethKeystore)
    keystore.wallets.append(wallet)

    let map = keystore.serializeToMap()
    XCTAssertEqual((map["wallets"] as! [[String: Any]]).first!["address"] as! String, "008aeeda4d805471df9b2a5b0f38a0c3bcba786b")
  }
}
