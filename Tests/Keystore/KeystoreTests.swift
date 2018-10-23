//
//  KeystoreTests.swift
//  TokenCoreTests
//
//  Created by James Chen on 2018/05/21.
//  Copyright © 2018 ConsenLabs. All rights reserved.
//

import XCTest
@testable import TokenCore

class KeystoreTests: TestCase {
  func testEthSerializeToMap() {
    let meta = WalletMeta(chain: .eth, source: .privateKey)
    let keystore = try! ETHKeystore(password: TestData.password, privateKey: TestData.privateKey, metadata: meta)
    XCTAssertNotNil(keystore)
  }

  func testBtcSerializeToMap() {
    var meta = WalletMeta(chain: .btc, source: .wif)
    meta.segWit = .p2wpkh
    let keystore = try! BTCKeystore(password: TestData.password, wif: TestData.wif, metadata: meta)
    XCTAssertNotNil(keystore)
    XCTAssertEqual(SegWit.p2wpkh.rawValue, keystore.serializeToMap()["segWit"] as! String)
  }

  func testGenerateKeystoreId() {
    XCTAssertNotNil(BTCMnemonicKeystore.generateKeystoreId())
    XCTAssertNotEqual(BTCMnemonicKeystore.generateKeystoreId(), BTCMnemonicKeystore.generateKeystoreId())
  }
}
