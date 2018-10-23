//
//  Secp256k1Tests.swift
//  tokenTests
//
//  Created by James Chen on 2018/02/09.
//  Copyright © 2018 ConsenLabs. All rights reserved.
//

import XCTest
@testable import TokenCore

class Secp256k1Tests: XCTestCase {
  func testSign() {
    let secp256k1 = Encryptor.Secp256k1()
    let signature = "07df15f290ac1433a71e8711936a9c1c481a613c4727d694e8065f26b9128e4a542dbd95801e656bddc992700842a71d73d8d208bb8bedf3a1afee82deba83bf"
    let result = secp256k1.sign(key: "2d743dda0caabdfb9fca0034d33cd0da7fb1ffe78cb80d643d67bf3f2aa12819", message: "2a336702a8fbb5ad1af9243f17ab8a8ea6f4f15386ab84dd1357a6914867948b")
    XCTAssertEqual(signature, result.signature)
    XCTAssertEqual(0, result.recid)
  }

  func testSign49() {
    let secp256k1 = Encryptor.Secp256k1()
    let signature = "282cb1fc266b030ddd000a3afd56396b823e836f635873668f1836d8fe080a2900c4115fd7f8f17e035a53893625a0fe8debfb805ccd5ee209285fb6471809aa"
    let result = secp256k1.sign(key: "3c9229289a6125f7fdf1885a77bb12c37a8d3b4962d936f7e3084dece32a3ca1", message: "49".keccak256())
    XCTAssertEqual(signature, result.signature)
    XCTAssertEqual(1, result.recid)
  }

  func testRecover() {
    let encryptor = Encryptor.Secp256k1()
    let recovered = encryptor.recover(signature: "07df15f290ac1433a71e8711936a9c1c481a613c4727d694e8065f26b9128e4a542dbd95801e656bddc992700842a71d73d8d208bb8bedf3a1afee82deba83bf", message: "2a336702a8fbb5ad1af9243f17ab8a8ea6f4f15386ab84dd1357a6914867948b", recid: 0)
    XCTAssertEqual(recovered, "042eb11b2eeb0db1d3c9ae8cd6cf71478bd415eff91b60869ee4b3a10a2e2f83c60dccab3a45c89fd0eb240e20cf089215c4779f0b35237d06cbced3fbab876e76")
  }

  func testVerify() {
    let encryptor = Encryptor.Secp256k1()
    XCTAssert(encryptor.verify(key: "2d743dda0caabdfb9fca0034d33cd0da7fb1ffe78cb80d643d67bf3f2aa12819"))
  }

  func testVerifyFailure() {
    let encryptor = Encryptor.Secp256k1()

    let invalidLength = "aaa"
    XCTAssertFalse(encryptor.verify(key: invalidLength))

    let invalidFormat = (1...64).map { _ in "i" }.joined()
    XCTAssertFalse(encryptor.verify(key: invalidFormat))

    let invalidKey = "2d743dda0caabdfb9fca0034d33cd0da7fb1ffe78cb80d643d67bf3f2aa12810" // Last digit is wrong
    XCTAssert(encryptor.verify(key: invalidKey))
  }
}
