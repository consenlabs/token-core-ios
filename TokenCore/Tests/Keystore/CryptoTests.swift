//
//  CryptoTests.swift
//  tokenTests
//
//  Created by Kai Chen on 22/09/2017.
//  Copyright © 2017 ConsenLabs. All rights reserved.
//

import XCTest
@testable import TokenCore

class CryptoTests: TestCase {
  func testCreate() {
    let crypto = Crypto(password: TestData.password, privateKey: TestData.privateKey)
    XCTAssertEqual(TestData.privateKey, crypto.privateKey(password: TestData.password))
    XCTAssertEqual(crypto.mac, crypto.macFrom(password: TestData.password))
  }

  func testToJSON() {
    let crypto = Crypto(password: TestData.password, privateKey: TestData.privateKey)
    let json = crypto.toJSON()
    XCTAssertEqual(json["cipher"] as! String, "aes-128-ctr")
    XCTAssertEqual(json["kdf"] as! String, "scrypt")
    XCTAssertEqual(json["mac"] as! String, crypto.macFrom(password: TestData.password))
  }

  func testInitWithJSON() {
    let data = TestHelper.loadJSON(filename: "v3-crypto-scrypt-1024").data(using: .utf8)!
    let json = try! JSONSerialization.jsonObject(with: data) as! JSONObject
    let crypto = try! Crypto(json: json)
    XCTAssertEqual(json["mac"] as! String, crypto.macFrom(password: TestData.password))
    XCTAssertEqual(TestData.privateKey, crypto.privateKey(password: TestData.password))
  }

  func testInitWithInvalidJSON() {
    let json = ["bad": "json"]
    XCTAssertThrowsError(try Crypto(json: json))
  }
}

// Cache
extension CryptoTests {
  func testCacheDerivedKey() {
    let crypto = Crypto(password: TestData.password, privateKey: TestData.privateKey, cacheDerivedKey: true)
    let cached = crypto.cachedDerivedKey(with: TestData.password)
    XCTAssertEqual(cached, crypto.cachedDerivedKey(with: TestData.password))
    XCTAssertNotEqual(cached, crypto.cachedDerivedKey(with: TestData.wrongPassword))
  }
}
