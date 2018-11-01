//
//  BigNumberTests.swift
//  token
//
//  Created by James Chen on 2016/11/08.
//  Copyright © 2016 imToken PTE. LTD. All rights reserved.
//

import XCTest
@testable import TokenCore

class BigNumberTests: XCTestCase {

  // MARK: - Parsing strings

  func testParseRLPBigIntger() {
    let num = BigNumber.parse("#83729609699884896815286331701780722")
    XCTAssertEqual("83729609699884896815286331701780722", num.description)
  }

  func testParseHex() {
    let num = BigNumber.parse("0x5208")
    XCTAssertEqual("21000", num.description)
  }

  func testParsePureDigitsAsInt() {
    let num = BigNumber.parse("5208")
    XCTAssertEqual("5208", num.description)
  }

  func testParseHexWithoutPrefix() {
    let num = BigNumber.parse("f85f")
    XCTAssertEqual("63583", num.description)
  }

  func testParseInt() {
    let num = BigNumber.parse("1234")
    XCTAssertEqual("1234", num.description)
  }

  func testParseNoneIntHex() {
    let num = BigNumber.parse("gg")
    XCTAssertEqual("0", num.description)
  }

  // MARK: - Init with integers

  func testInitWithImpliedInt() {
    let int: Int64 = 123_056_546_413_051
    let num = BigNumber(int)
    XCTAssertNotNil(num)
    XCTAssertEqual("123056546413051", num!.description)
  }

  func testInitWithInt64() {
    let int: Int64 = 3_825_123_056_546_413_051
    let num = BigNumber(int)
    XCTAssertNotNil(num)
    XCTAssertEqual("3825123056546413051", num!.description)
  }

  func testInitWithInt() {
    let int: Int = 99999
    let num = BigNumber(int)
    XCTAssertNotNil(num)
    XCTAssertEqual("99999", num!.description)
  }

  func testInitWithUInt8() {
    let byte: UInt8 = 127
    let num = BigNumber(byte)
    XCTAssertNotNil(num)
    XCTAssertEqual("127", num!.description)
  }

  func testInitWithInvalidType() {
    XCTAssertNil(BigNumber("oops"))
  }

  // MARK: - Serialization

  func testZeroSerialize() {
    let zero = BigNumber(0)!
    XCTAssertEqual([], zero.serialize())
  }

  func testOneSerialize() {
    let one = BigNumber(1)!
    XCTAssertEqual([0x01], one.serialize())
  }

  func testHexSerialize() {
    let hex = "0x5208"
    let num = BigNumber.parse(hex)
    XCTAssertEqual([82, 8], num.serialize())
  }
}
