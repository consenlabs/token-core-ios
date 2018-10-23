//
//  ETHRlpTests.swift
//  token
//
//  Created by James Chen on 2016/10/27.
//  Copyright © 2016 imToken PTE. LTD. All rights reserved.
//

import XCTest
@testable import TokenCore

class RLPTests: XCTestCase {
  func testZero() {
    XCTAssertEqual("80", RLP.encode(0))
  }

  func testString() {
    XCTAssertEqual(
      "b839303030303030303030303030303030303030303030303030303030303030303030303030303030303030303030303030303030303030303030",
      RLP.encode("000000000000000000000000000000000000000000000000000000000")
    )
  }

  func testBinary() {
    XCTAssertEqual(
      "9d0000000000000000000000000001000000000000000000000000000000",
      RLP.encode(String(bytes: Hex.toBytes("0000000000000000000000000001000000000000000000000000000000"), encoding: .ascii)!)
    )
  }

  func testJSONFixture() {
    let json = TestHelper.loadJSON(filename: "rlp") // https://github.com/ethereumjs/tests/blob/58cd17e70b2a7da28dd77cf56a9f5e6cd672ec99/RLPTests/rlptest.json
    let data = json.data(using: .utf8)!
    let jsonObject = try! JSONSerialization.jsonObject(with: data) as! [String: Any]
    for (_, testPair) in jsonObject {
      let inOut = testPair as! [String: Any]
      let input = inOut["in"]!
      let output = (inOut["out"] as! String).uppercased()
      let encoded: String = RLP.encode(input).uppercased()
      XCTAssertEqual(output, encoded, "Encoding \(input)")
    }
  }
}
