//
//  BTCTransactionTests.swift
//  TokenCoreTests
//
//  Created by James Chen on 2018/05/17.
//  Copyright © 2018 ConsenLabs. All rights reserved.
//

import XCTest
import CoreBitcoin
@testable import TokenCore

class BTCTransactionTests: XCTestCase {
  func testAddInputs() {
    let tx = BTCTransaction()
    let utxos = [
      [
        "txHash": "02d8595fc5d4adc5e06c73f44e39fe86c7f0a516b7d4e0d37b9e1e83c93596a5",
        "vout": 1,
        "amount": "29719880",
        "address": "n2ZNV88uQbede7C5M5jzi6SyG4GVuPpng6",
        "scriptPubKey": "76a914e6cfaab9a59ba187f0a45db0b169c21bb48f09b388ac"
      ]
    ].map { UTXO(raw: $0)! }
    tx.addInputs(from: utxos)
    XCTAssertEqual(tx.inputs.count, 1)
  }

  func testCalculateTotalSpend() {
    let tx = BTCTransaction()
    let utxos = [
      [
        "txHash": "02d8595fc5d4adc5e06c73f44e39fe86c7f0a516b7d4e0d37b9e1e83c93596a5",
        "vout": 1,
        "amount": "29719880",
        "address": "n2ZNV88uQbede7C5M5jzi6SyG4GVuPpng6",
        "scriptPubKey": "76a914e6cfaab9a59ba187f0a45db0b169c21bb48f09b388ac"
      ],
      [
        "txHash": "02d8595fc5d4adc5e06c73f44e39fe86c7f0a516b7d4e0d37b9e1e83c93596a5",
        "vout": 2,
        "amount": "1",
        "address": "n2ZNV88uQbede7C5M5jzi6SyG4GVuPpng6",
        "scriptPubKey": "76a914e6cfaab9a59ba187f0a45db0b169c21bb48f09b388ac"
      ]
    ].map { UTXO(raw: $0)! }
    XCTAssertEqual(tx.calculateTotalSpend(utxos: utxos), 29719881)
  }
}
