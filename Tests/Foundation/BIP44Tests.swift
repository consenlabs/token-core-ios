//
//  BIP44Tests.swift
//  TokenCoreTests
//
//  Created by James Chen on 2018/05/19.
//  Copyright © 2018 ConsenLabs. All rights reserved.
//

import XCTest
@testable import TokenCore

class BIP44Tests: XCTestCase {
  func testPathForBTC() {
    XCTAssertEqual(BIP44.btcMainnet, BIP44.path(for: .mainnet, segWit: .none))
    XCTAssertEqual(BIP44.btcTestnet, BIP44.path(for: .testnet, segWit: .none))
    XCTAssertEqual(BIP44.btcSegwitMainnet, BIP44.path(for: .mainnet, segWit: .p2wpkh))
    XCTAssertEqual(BIP44.btcSegwitTestnet, BIP44.path(for: .testnet, segWit: .p2wpkh))
    XCTAssertEqual(BIP44.btcMainnet, BIP44.path(for: nil, segWit: .none))
    XCTAssertEqual(BIP44.btcSegwitMainnet, BIP44.path(for: nil, segWit: .p2wpkh))
  }
}
