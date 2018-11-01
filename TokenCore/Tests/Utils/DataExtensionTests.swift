//
//  DataExtensionTests.swift
//  token
//
//  Created by James Chen on 2016/10/31.
//  Copyright © 2016 imToken PTE. LTD. All rights reserved.
//

import XCTest
@testable import TokenCore

class DataExtensionTests: XCTestCase {
  func testHexCharToBinary() {
    let mapping: [Character: String] = [
      "0": "0000",
      "1": "0001",
      "2": "0010",
      "3": "0011",
      "4": "0100",
      "5": "0101",
      "6": "0110",
      "7": "0111",
      "8": "1000",
      "9": "1001",
      "a": "1010",
      "A": "1010",
      "b": "1011",
      "B": "1011",
      "c": "1100",
      "C": "1100",
      "d": "1101",
      "D": "1101",
      "e": "1110",
      "E": "1110",
      "f": "1111",
      "F": "1111",
      "g": "0000"
    ]
    for (hex, bin) in mapping {
      XCTAssertEqual(bin, Data.tk_hexCharToBinary(char: hex))
    }
  }
}
