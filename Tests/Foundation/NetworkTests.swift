//
//  NetworkTests.swift
//  TokenCoreTests
//
//  Created by James Chen on 2018/03/28.
//  Copyright © 2018 ConsenLabs. All rights reserved.
//

import XCTest
@testable import TokenCore

class NetworkTests: XCTestCase {
  func testIsMainnet() {
    XCTAssert(Network.mainnet.isMainnet)
    XCTAssertFalse(Network.testnet.isMainnet)
  }
}
