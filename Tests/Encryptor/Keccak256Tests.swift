//
//  Keccak256Tests.swift
//  tokenTests
//
//  Created by James Chen on 2018/02/09.
//  Copyright © 2018 ConsenLabs. All rights reserved.
//

import XCTest
@testable import TokenCore

class Keccak256Tests: XCTestCase {
  func testKeccak256() {
    let encrypted = Encryptor.Keccak256().encrypt(hex: "")
    XCTAssertEqual("c5d2460186f7233c927e7db2dcc703c0e500b653ca82273b7bfad8045d85a470", encrypted)
  }

  func testKeccak256HexString() {
    let encrypted = Encryptor.Keccak256().encrypt(hex: "helloworld".tk_toHexString())
    XCTAssertEqual("fa26db7ca85ead399216e7c6316bc50ed24393c3122b582735e7f3b0f91b93f0", encrypted)
  }

  func testKeccak256MoreExamples() {
    let encrypted = Encryptor.Keccak256().encrypt(hex: "3c9229289a6125f7fdf1885a77bb12c37a8d3b4962d936f7e3084dece32a3ca1")
    XCTAssertEqual("82ff40c0a986c6a5cfad4ddf4c3aa6996f1a7837f9c398e17e5de5cbd5a12b28", encrypted)
  }
}
