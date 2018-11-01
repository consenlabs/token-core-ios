//
//  KeyPairTests.swift
//  TokenCoreTests
//
//  Created by James Chen on 2018/06/21.
//  Copyright © 2018 ConsenLabs. All rights reserved.
//

import XCTest
@testable import TokenCore

class KeyPairTests: XCTestCase {
  func testKeyPairEqutable() {
    XCTAssertEqual(KeyPair(privateKey: "private key", publicKey: "public key"), KeyPair(privateKey: "private key", publicKey: "public key"))
    XCTAssertNotEqual(KeyPair(privateKey: "private key 1", publicKey: "public key"), KeyPair(privateKey: "private key", publicKey: "public key"))
    XCTAssertNotEqual(KeyPair(privateKey: "private key", publicKey: "public key 1"), KeyPair(privateKey: "private key", publicKey: "public key"))
  }
}
