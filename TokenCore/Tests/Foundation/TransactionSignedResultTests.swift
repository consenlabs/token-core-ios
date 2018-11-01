//
//  TransactionSignedResultTests.swift
//  tokenTests
//
//  Created by James Chen on 2018/02/22.
//  Copyright © 2018 ConsenLabs. All rights reserved.
//

import XCTest
@testable import TokenCore

class TransactionSignedResultTests: XCTestCase {
  func testEthSignedResult() {
    let transaction = Transaction(raw: [
      "nonce":        "65",
      "gasPrice":     "54633837083",
      "gasLimit":     "21000",
      "to":           "0x632da81d534400f84c52d137d136a6ec89a59d77",
      "value":        "1000000000000000"
      ])
    _ = transaction.sign(with: "2d743dda0caabdfb9fca0034d33cd0da7fb1ffe78cb80d643d67bf3f2aa12819")
    let signedResult = transaction.signedResult
    XCTAssertEqual(signedResult.signedTx, "f86b41850cb86e321b82520894632da81d534400f84c52d137d136a6ec89a59d7787038d7ea4c68000801ca0ed296b4495793ade51f50523755dfa68b2415440f044c288e122ebab9fc60269a03a2967a92f9b54ef3471b11f6548810aa092c96aedeca7df821c06a314da40b5")
    XCTAssertEqual(signedResult.txHash, transaction.signingHash)
  }

  func testEthSignedResultWithoutSigningFirst() {
    let transaction = Transaction(raw: [
      "nonce":        "65",
      "gasPrice":     "54633837083",
      "gasLimit":     "21000",
      "to":           "0x632da81d534400f84c52d137d136a6ec89a59d77",
      "value":        "1000000000000000"
      ])
    let signedResult = transaction.signedResult
    XCTAssertNotEqual(signedResult.signedTx, "f86b41850cb86e321b82520894632da81d534400f84c52d137d136a6ec89a59d7787038d7ea4c68000801ca0ed296b4495793ade51f50523755dfa68b2415440f044c288e122ebab9fc60269a03a2967a92f9b54ef3471b11f6548810aa092c96aedeca7df821c06a314da40b5")
  }
}
