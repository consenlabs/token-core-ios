//
//  EncryptedMessageTests.swift
//  tokenTests
//
//  Created by James Chen on 2018/02/22.
//  Copyright © 2018 ConsenLabs. All rights reserved.
//

import XCTest
@testable import TokenCore

class EncryptedMessageTests: TestCase {
  func testInitWithJSON() {
    let json: JSONObject = ["encStr": "aaaa", "nonce": "bbbb"]
    let message = EncryptedMessage(json: json)
    XCTAssert(message != nil)
    XCTAssertEqual(message!.encStr, "aaaa")
    XCTAssertEqual(message!.nonce, "bbbb")
  }

  func testInvalidJSON() {
    XCTAssertNil(EncryptedMessage(json: ["encStr": "aaaa"]))
    XCTAssertNil(EncryptedMessage(json: ["nonce": "bbbb"]))
  }

  func testToJSON() {
    let json: JSONObject = ["encStr": "aaaa", "nonce": "bbbb", "extra": "cccc"]
    let message = EncryptedMessage(json: json)!
    XCTAssertMapEqual(message.toJSON(), ["encStr": "aaaa", "nonce": "bbbb"])
  }

  func testCreate() {
    let password = "testpassword"
    let nonce = "ad5b233114e84ebd04af292d043a75e7"
    let data = TestHelper.loadJSON(filename: "v3-crypto-scrypt-1024").data(using: .utf8)!
    let json = try! JSONSerialization.jsonObject(with: data) as! JSONObject
    let crypto = try! Crypto(json: json)
    // derived key: c759d83c4f0a5f3b4baeee6409bde0bc926069908850554cc24cb956630ead05
    let message = EncryptedMessage.create(crypto: crypto, password: password, message: "hello world".tk_toHexString(), nonce: nonce)
    XCTAssertEqual("3bc0daa30c611807a58d83", message.encStr)
    XCTAssertEqual(nonce, message.nonce)
  }

  func testCreateWithDerivedKey() {
    let nonce = "ad5b233114e84ebd04af292d043a75e7"
    let data = TestHelper.loadJSON(filename: "v3-crypto-scrypt-1024").data(using: .utf8)!
    let json = try! JSONSerialization.jsonObject(with: data) as! JSONObject
    let crypto = try! Crypto(json: json)
    let message = EncryptedMessage.create(crypto: crypto, derivedKey: "c759d83c4f0a5f3b4baeee6409bde0bc926069908850554cc24cb956630ead05", message: "hello world".tk_toHexString(), nonce: nonce)
    XCTAssertEqual("3bc0daa30c611807a58d83", message.encStr)
    XCTAssertEqual(nonce, message.nonce)
  }

  func testDescrypt() {
    let password = "testpassword"
    let nonce = "ad5b233114e84ebd04af292d043a75e7"
    let data = TestHelper.loadJSON(filename: "v3-crypto-scrypt-1024").data(using: .utf8)!
    let json = try! JSONSerialization.jsonObject(with: data) as! JSONObject
    let crypto = try! Crypto(json: json)
    let message = EncryptedMessage.create(crypto: crypto, password: password, message: "hello world".tk_toHexString(), nonce: nonce)
    let decrypted = message.decrypt(crypto: crypto, password: password)
    XCTAssertEqual("hello world".tk_toHexString(), decrypted)
  }
}
