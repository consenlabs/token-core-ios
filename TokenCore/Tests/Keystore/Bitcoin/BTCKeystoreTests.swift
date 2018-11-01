//
//  BTCKeystoreTests.swift
//  tokenTests
//
//  Created by James Chen on 2018/02/24.
//  Copyright © 2018 ConsenLabs. All rights reserved.
//

import XCTest
@testable import TokenCore

class BTCKeystoreTests: TestCase {
  func testImportWithPrivateKey() {
    let meta = WalletMeta(chain: .btc, source: .wif, network: .mainnet)
    let keystore = try? BTCKeystore(password: TestData.password, wif: TestData.wif, metadata: meta)
    XCTAssertNotNil(keystore)
    XCTAssertEqual("1N3RC53vbaDNrziTdWmctBEeQ4fo4quNpq", keystore?.address)
  }

  func testImportWithPrivateKeyTestnet() {
    let meta = WalletMeta(chain: .btc, source: .wif, network: .testnet)
    let keystore = try? BTCKeystore(password: TestData.password, wif: TestData.wifTestnet, metadata: meta)
    XCTAssertNotNil(keystore)
    XCTAssertEqual("mgpHw67hvPxe8qQbtVZ8a7kHzn8U2v3ihF", keystore?.address)
  }

  func testImportFailureWithInvaidPrivateKey() {
    let meta = WalletMeta(chain: .btc, source: .wif)
    XCTAssertThrowsError(try BTCKeystore(password: TestData.password, wif: TestData.privateKey, metadata: meta))
  }

  func testInitWithJSON() {
    let data = TestHelper.loadJSON(filename: "v3-wif").data(using: .utf8)!
    let json = try! JSONSerialization.jsonObject(with: data) as! JSONObject
    let keystore = try? BTCKeystore(json: json)
    XCTAssertNotNil(keystore)
    XCTAssertEqual(keystore!.meta.source, WalletMeta.Source.wif)
  }
}

// SegWit
extension BTCKeystoreTests {
  func testImportWithPrivateKeySegWit() {
    var meta = WalletMeta(chain: .btc, source: .wif, network: .testnet)
    meta.segWit = .p2wpkh
    let keystore = try? BTCKeystore(password: TestData.password, wif: TestData.wifTestnet, metadata: meta)
    XCTAssertNotNil(keystore)
    XCTAssertEqual("2NB53xvb7eociGEYThz5WZWvr4qZexH8LG7", keystore?.address)
  }
}
