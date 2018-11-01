//
//  ChainTypeTests.swift
//  TokenCoreTests
//
//  Created by James Chen on 2018/05/25.
//  Copyright © 2018 ConsenLabs. All rights reserved.
//

import XCTest
@testable import TokenCore

class ChainTypeTests: XCTestCase {
  func testPrivateKeySource() {
    XCTAssertEqual(ChainType.eth.privateKeySource, WalletMeta.Source.privateKey)
    XCTAssertEqual(ChainType.btc.privateKeySource, WalletMeta.Source.wif)
    XCTAssertEqual(ChainType.eos.privateKeySource, WalletMeta.Source.wif)
  }
}
