//
//  BTCKeyTests.swift
//  TokenCoreTests
//
//  Created by James Chen on 2018/05/16.
//  Copyright © 2018 ConsenLabs. All rights reserved.
//

import XCTest
@testable import TokenCore
@testable import CoreBitcoin

class BTCKeyTests: TestCase {
  func testAddress() {
    let key = BTCKey(wif: TestData.wifTestnet)!
    XCTAssertEqual(key.address(on: .testnet, segWit: .none).string, "mgpHw67hvPxe8qQbtVZ8a7kHzn8U2v3ihF")

    let keyMainnet = BTCKey(wif: TestData.wif)!
    XCTAssertEqual(keyMainnet.address(on: .mainnet, segWit: .none).string, "1N3RC53vbaDNrziTdWmctBEeQ4fo4quNpq")
  }

  func testAddressSegWit() {
    let key = BTCKey(wif: TestData.wifTestnet)!
    XCTAssertEqual(key.address(on: .testnet, segWit: .p2wpkh).string, "2NB53xvb7eociGEYThz5WZWvr4qZexH8LG7")

    let keyMainnet = BTCKey(wif: TestData.wif)!
    XCTAssertEqual(keyMainnet.address(on: .mainnet, segWit: .p2wpkh).string, "3Js9bGaZSQCNLudeGRHL4NExVinc25RbuG")
  }
}
