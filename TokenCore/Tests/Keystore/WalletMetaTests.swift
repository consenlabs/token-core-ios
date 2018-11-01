//
//  WalletMetaTests.swift
//  tokenTests
//
//  Created by James Chen on 2018/02/24.
//  Copyright © 2018 ConsenLabs. All rights reserved.
//

import XCTest
@testable import TokenCore

class WalletMetaTests: XCTestCase {
  func testCreate() {
    let meta = WalletMeta(chain: .btc, source: .privateKey)
    XCTAssertEqual(meta.chain, ChainType.btc)
    XCTAssertEqual(meta.source, WalletMeta.Source.privateKey)
    XCTAssertEqual(meta.network, Network.mainnet)
  }

  func testIsMainnet() {
    XCTAssert(WalletMeta(source: .privateKey).isMainnet)
    XCTAssertFalse(WalletMeta(chain: .btc, source: .privateKey, network: .testnet).isMainnet)
  }

  func testMerge() {
    var meta = WalletMeta(chain: .btc, source: .privateKey)
    meta.name = "First wallet"
    let new = meta.mergeMeta("Second wallet", chainType: .eth)
    XCTAssertEqual(new.name, "Second wallet")
    XCTAssertEqual(new.chain, ChainType.eth)
  }
}
