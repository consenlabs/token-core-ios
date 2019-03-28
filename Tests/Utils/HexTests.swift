//
//  HexTests.swift
//  token
//
//  Created by James Chen on 2016/11/03.
//  Copyright © 2016 imToken PTE. LTD. All rights reserved.
//

import XCTest
import CoreBitcoin
@testable import TokenCore

class HexTests: XCTestCase {
  func testHasPrefix() {
    XCTAssert(Hex.hasPrefix("0x0506"))
    XCTAssertFalse(Hex.hasPrefix("0$0506"))
    XCTAssertFalse(Hex.hasPrefix("0506"))
  }

  func testRemovePrefix() {
    XCTAssertEqual("abcd", Hex.removePrefix("0xabcd"))
    XCTAssertEqual("abcd", Hex.removePrefix("abcd"))
  }

  func testAddPrefix() {
    XCTAssertEqual("0xabcd", Hex.addPrefix("0xabcd"))
    XCTAssertEqual("0xabcd", Hex.addPrefix("abcd"))
  }

  func testPad() {
    XCTAssertEqual("0abcde", Hex.pad("abcde"))
    XCTAssertEqual("abcd", Hex.pad("abcd"))
  }

  func testNormalize() {
    XCTAssertEqual("0abcde", Hex.normalize("abcde"))
    XCTAssertEqual("0abcde", Hex.normalize("0xabcde"))
    XCTAssertEqual("abcd", Hex.normalize("0xabcd"))
    XCTAssertEqual("abcd", Hex.normalize("abcd"))
  }

  func testIsHex() {
    XCTAssert(Hex.isHex("736f636b206163726f7373206372616674206475746368206d757368726f6f6d20696d6d656e736520696e697469616c20666f72636520736c696465206c6f74746572792072656d61696e2063756265"))
    XCTAssert(Hex.isHex("3c700055452aa9f5d0e9da0304988f6f"))
    XCTAssertFalse(Hex.isHex("hijk"))
    XCTAssertFalse(Hex.isHex("imToken"))
    XCTAssertFalse("hijk".tk_isHex())
    XCTAssertFalse("imToken".tk_isHex())
    XCTAssertFalse("12345".tk_isHex())
    XCTAssert("123456".tk_isHex())
  }

  func testPrefix() {
    let hex = "0x7468697320697320612074c3a97374" // this is a tést
    let bytes = Hex.toBytes(hex)
    let expected: [UInt8] = [0x74, 0x68, 0x69, 0x73, 0x20, 0x69, 0x73, 0x20, 0x61, 0x20, 0x74, 0xc3, 0xa9, 0x73, 0x74]
    XCTAssertEqual(expected, bytes)
  }

  func testToBytes() {
    let hex = "7468697320697320612074c3a97374" // this is a tést
    let bytes = Hex.toBytes(hex)
    let expected: [UInt8] = [0x74, 0x68, 0x69, 0x73, 0x20, 0x69, 0x73, 0x20, 0x61, 0x20, 0x74, 0xc3, 0xa9, 0x73, 0x74]
    XCTAssertEqual(expected, bytes)
  }

  func testToBytesPaddingZero() {
    let hex = "a7468697320697320612074c3a97374"
    let bytes = Hex.toBytes(hex)
    let expected: [UInt8] = [0x0a, 0x74, 0x68, 0x69, 0x73, 0x20, 0x69, 0x73, 0x20, 0x61, 0x20, 0x74, 0xc3, 0xa9, 0x73, 0x74]
    XCTAssertEqual(expected, bytes)
  }

  func testAddressToBytes() {
    let hex = "632da81d534400f84c52d137d136a6ec89a59d77"
    let bytes = Hex.toBytes(hex)
    let expected: [UInt8] = [99, 45, 168, 29, 83, 68, 0, 248, 76, 82, 209, 55, 209, 54, 166, 236, 137, 165, 157, 119]
    XCTAssertEqual(expected, bytes)
  }

  func testAnotherString() {
    let hex = "this is a tést".tk_toHexString()
    XCTAssertEqual("7468697320697320612074c3a97374", hex)
  }

  func testToHexString() {
    let string = "sock across craft dutch mushroom immense initial force slide lottery remain cube"
    let hex = "736f636b206163726f7373206372616674206475746368206d757368726f6f6d20696d6d656e736520696e697469616c20666f72636520736c696465206c6f74746572792072656d61696e2063756265"
    let result = string.tk_toHexString()
    XCTAssertEqual(result, hex)
  }

  func testFromHexString() {
    let string = "sock across craft dutch mushroom immense initial force slide lottery remain cube"
    let hex = "736f636b206163726f7373206372616674206475746368206d757368726f6f6d20696d6d656e736520696e697469616c20666f72636520736c696465206c6f74746572792072656d61696e2063756265"
    let result = hex.tk_fromHexString()
    XCTAssertEqual(result, string)
  }

  func testFromHexStringWithPrefix() {
    let string = "sock across craft dutch mushroom immense initial force slide lottery remain cube"
    let hex = "0x736f636b206163726f7373206372616674206475746368206d757368726f6f6d20696d6d656e736520696e697469616c20666f72636520736c696465206c6f74746572792072656d61696e2063756265"
    let result = hex.tk_fromHexString()
    XCTAssertEqual(result, string)
  }

  func testDataToHexString() {
    let hex = "3c700055452aa9f5d0e9da0304988f6f"
    let data = hex.tk_dataFromHexString()!
    let btcResult = BTCHexFromData(data)
    let result = data.tk_toHexString()
    XCTAssertEqual(result, btcResult)
  }

  func testDataFromHexString() {
    let hex = "3c700055452aa9f5d0e9da0304988f6f"
    let data = hex.tk_dataFromHexString()!
    let result = BTCDataFromHex(hex)!
    XCTAssertEqual(result, data)

    let examples = [
      "736f636b206163726f7373206372616674206475746368206d757368726f6f6d20696d6d656e736520696e697469616c20666f72636520736c696465206c6f74746572792072656d61696e2063756265",
      "ae3cd4e7013836a3df6bd7241b12db061dbe2c6785853cce422d148a624ce0bd",
      "6087dab2f9fdbbfaddc31a909735c1e6",
    ]
    for example in examples {
      XCTAssertEqual(example.tk_dataFromHexString()!, BTCDataFromHex(example)!)
    }
  }

  func testPaddingDataFromHexString() {
    XCTAssertEqual("123".tk_dataFromHexString()?.tk_toHexString(), "0123")
    XCTAssertEqual("1234".tk_dataFromHexString()?.tk_toHexString(), "1234")
  }

  func testEmptyStringDataFromHexString() {
    XCTAssertEqual("".tk_dataFromHexString()?.tk_toHexString(), "")
    XCTAssertEqual("".tk_dataFromHexString()!, BTCDataFromHex("")!)
  }

  func testInvalidDataFromHexString() {
    XCTAssertNil("gg".tk_dataFromHexString())
    XCTAssertNil("🤣".tk_dataFromHexString())
  }

  func testReverse() {
    let data = "hello".data(using: .utf8)
    let reversed = data?.tk_toHexString().tk_dataFromHexString()
    XCTAssertEqual(data, reversed)
  }
}
