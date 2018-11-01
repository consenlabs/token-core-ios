//
//  BTCKeystoreTests.swift
//  tokenTests
//
//  Created by James Chen on 2018/02/24.
//  Copyright © 2018 ConsenLabs. All rights reserved.
//

import XCTest
@testable import TokenCore

class EOSLegacyKeystoreTests: TestCase {
  func testImportEOSPrivateKey() {
    let meta = WalletMeta(chain: .eos, source: .privateKey)
    let keystore = try? EOSLegacyKeystore(password: TestData.password, wif: TestData.eosPrivateKey, metadata: meta, accountName: "eos-name")
    XCTAssertNotNil(keystore)
    XCTAssertEqual("eos-name", keystore?.address)
    XCTAssertNotNil(keystore?.id)
  }

  func testImportEOSPrivateKeySpecifyingId() {
    let meta = WalletMeta(chain: .eos, source: .privateKey)
    let keystore = try? EOSLegacyKeystore(password: TestData.password, wif: TestData.eosPrivateKey, metadata: meta, accountName: "eos-name", id: "keystore-id")
    XCTAssertNotNil(keystore)
    XCTAssertEqual("keystore-id", keystore?.id)
  }

  func testInitWithJSON() {
    let data = TestHelper.loadJSON(filename: "v3-wif").data(using: .utf8)!
    let json = try! JSONSerialization.jsonObject(with: data) as! JSONObject
    let keystore = try? EOSLegacyKeystore(json: json)
    XCTAssertNotNil(keystore)
    XCTAssertEqual(keystore!.meta.source, WalletMeta.Source.wif)
  }

  func testInitWithInvalidJSON() {
    let data = "{}".data(using: .utf8)!
    let json = try! JSONSerialization.jsonObject(with: data) as! JSONObject
    do {
      _ = try EOSLegacyKeystore(json: json)
      XCTFail()
    } catch let err {
      XCTAssertEqual(err.localizedDescription, KeystoreError.invalid.localizedDescription)
    }
  }

  func testDecryptWIF() {
    let meta = WalletMeta(chain: .eos, source: .privateKey)
    let keystore = try! EOSLegacyKeystore(password: TestData.password, wif: TestData.eosPrivateKey, metadata: meta, accountName: "eos-name")
    XCTAssertEqual(TestData.eosPrivateKey, keystore.decryptWIF(TestData.password))
  }

  func testSerializeToMap() {
    let meta = WalletMeta(chain: .eos, source: .privateKey)
    let keystore = try! EOSLegacyKeystore(password: TestData.password, wif: TestData.eosPrivateKey, metadata: meta, accountName: "eos-name")
    let map = keystore.serializeToMap()
    XCTAssertEqual(map["id"] as! String, keystore.id)
    XCTAssertEqual(map["address"] as! String, "eos-name")
  }
  
  func testExportPrivateKeys() {
    let meta = WalletMeta(chain: .eos, source: .privateKey)
    let keystore = try! EOSLegacyKeystore(password: TestData.password, wif: TestData.eosPrivateKey, metadata: meta, accountName: "eos-name")
    let keyPairs = keystore.exportPrivateKeys(TestData.password)
    XCTAssertEqual(1, keyPairs.count)
    XCTAssertEqual("EOS6MRyAjQq8ud7hVNYcfnVPJqcVpscN5So8BhtHuGYqET5GDW5CV", keyPairs[0].publicKey)
    XCTAssertEqual("5KQwrPbwdL6PhXujxW37FSSQZ1JiwsST4cqQzDeyXtP79zkvFD3", keyPairs[0].privateKey)
  }
}
