//
//  StringExtensionTests.swift
//  token
//
//  Created by James Chen on 2016/10/25.
//  Copyright © 2016 imToken PTE. LTD. All rights reserved.
//

import XCTest
@testable import TokenCore

class StringExtensionTests: XCTestCase {
  func testIsDigits() {
    XCTAssert("156".tk_isDigits)
    XCTAssertFalse("0x156".tk_isDigits)
  }

  func testSutstring() {
    let str = "Hello, string"
    XCTAssertEqual(str.tk_substring(to: 5), "Hello")
    XCTAssertEqual(str.tk_substring(from: 7), "string")
  }

  func testAdd0xIfNeeded() {
    XCTAssertEqual("1234".add0xIfNeeded(), "0x1234")
  }

  func testRemovePrefix0xIfNeeded() {
    XCTAssertEqual("0x1234".removePrefix0xIfNeeded(), "1234")
  }
}
