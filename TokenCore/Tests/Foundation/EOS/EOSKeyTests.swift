//
//  EOSKeyTests.swift
//  TokenCoreTests
//
//  Created by James Chen on 2018/06/21.
//  Copyright © 2018 ConsenLabs. All rights reserved.
//

import XCTest
import CoreBitcoin
@testable import TokenCore

class EOSKeyTests: TestCase {
  func testWif() {
    let eosKey = EOSKey(wif: TestData.eosPrivateKey)
    XCTAssertEqual(TestData.eosPublicKey, eosKey.publicKey)
  }

  func testPrivateKey() {
    let privateKeyBytes = (BTCDataFromBase58(TestData.eosPrivateKey) as Data).bytes
    let privateKey = [UInt8].init(privateKeyBytes[1..<privateKeyBytes.count - 4])
    let eosKey = EOSKey(privateKey: privateKey)
    XCTAssertEqual(TestData.eosPublicKey, eosKey.publicKey)
  }
}
