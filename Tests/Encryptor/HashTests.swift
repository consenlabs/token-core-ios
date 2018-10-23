//
//  HashTests.swift
//  tokenTests
//
//  Created by James Chen on 2018/03/06.
//  Copyright © 2018 ConsenLabs. All rights reserved.
//

import XCTest
@testable import TokenCore

class HashTests: XCTestCase {
  func testHmacSHA256() {
    let key = "secret".data(using: .utf8)!
    let data = "hello world".data(using: .utf8)!
    let hash = Encryptor.Hash.hmacSHA256(key: key, data: data).tk_toHexString()
    XCTAssertEqual("734cc62f32841568f45715aeb9f4d7891324e6d948e4c6c60c0621cdac48623a", hash)
  }

  func testMerkleRoot() {
    
    let cases = [
      ["1000", "3fa2b684fa9d80f04b70187e6c9ff1c8dd422ce1846beb79cf5e1546c7062d41"],
      ["2000", "4b19aa611413ba9a6b89a2be7833bb835349b9e9e9872c5eacfc82daa2e5f08f"],
      ["3000", "c9ec2ec071ed70d02802decd912a1e8d124420556789384efaab80fcb7ce7ecb"],
      ["4000", "5cfa6745c50787e3d97a1322789713036f8cab7ba534d2a996bea015d811640c"],
      ["5000", "233bc40f24c071507474a9c978f0f0099d0c457f9874326640be55a8a8b96325"],
      ["1024", "5a6c9dcbec66882a3de754eb13e61d8908e6c0b67a23c9d524224ecd93746290"],
      ["2048", "5ee830087937da00520c4ce3793c5c7b951d37771d69a098415ddf7d682a39d9"],
    ]
    cases.forEach { testCase in
      let dataLength = Int(testCase[0])!
      let bytes = (0..<dataLength).map { i in
        UInt8(i / 1024)
      }
      let hash = Encryptor.Hash.merkleRoot(cipherData: Data(bytes: bytes)).tk_toHexString()
      XCTAssertEqual(testCase[1], hash)
    }
  }
}
