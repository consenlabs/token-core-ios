//
//  BitcoinWalletTests.swift
//  tokenTests
//
//  Created by xyz on 2017/10/10.
//  Copyright © 2017 ConsenLabs. All rights reserved.
//

import XCTest
@testable import TokenCore

class BitcoinWalletTests: TestCase {
  func testWIF() {
    /* CoreBitcoin is not exposed for use here
    let compressedWIF = "cNcBUemoNGVRN9fRtxrmtteAPQeWZ399d2REmX1TBjvWpRfNMy91"
    let compressedBTCKey = BTCKey(wif: compressedWIF)!
    XCTAssertTrue(compressedBTCKey.isPublicKeyCompressed)
    XCTAssertEqual("1J7mdg5rbQyUHENYdx39WVWK7fsLpEoXZy", compressedBTCKey.address!.string)
    let uncompressedWIF = "91pPmKypfMGxN73N3iCjLuwBjgo7F4CpGQtFuE9FziSieVTY4jn"
    let uncompressedBTCKey = BTCKey(wif: uncompressedWIF)!
    XCTAssertTrue(!uncompressedBTCKey.isPublicKeyCompressed)
    let compressedPrvKey = (compressedBTCKey.privateKey as Data?)!.tk_toHexString()
    let uncompressedPrvKey = (uncompressedBTCKey.privateKey as Data?)!.tk_toHexString()
    XCTAssertEqual(compressedPrvKey, uncompressedPrvKey)
    uncompressedBTCKey.isPublicKeyCompressed = true
    XCTAssertEqual("1J7mdg5rbQyUHENYdx39WVWK7fsLpEoXZy", uncompressedBTCKey.address!.string)
    */
  }

  func testImportWalletFromWIF() {
    let expectedResult: [String: Any] = [
      "address": "1N3RC53vbaDNrziTdWmctBEeQ4fo4quNpq",
      "source": "WIF",
      "chainType": "BITCOIN"
    ]
    do {
      let identity = Identity.currentIdentity!
      let metadata = WalletMeta(chain: .btc, source: .wif)
      let wallet = try identity.importFromPrivateKey(TestData.wif, encryptedBy: TestData.password, metadata: metadata)
      XCTAssertMapEqual(expectedResult, wallet.serializeToMap())
      XCTAssertEqual(TestData.wif, try wallet.privateKey(password: TestData.password))

      do {
        XCTAssertNotNil(try wallet.privateKey(password: TestData.password))
      }
    } catch {
      XCTFail("testImportWalletFromWIF")
    }
  }

  func testImportWalletFromMnemonic() {
    let expectedResult: [String: Any] = [
      "address": "12z6UzsA3tjpaeuvA2Zr9jwx19Azz74D6g",
      "source": "MNEMONIC",
      "chainType": "BITCOIN",
      "externalAddress":
        [
          "address": "1962gsZ8PoPUYHneFakkCTrukdFMVQ4i4T",
          "derivedPath": "0/1",
          "type": "EXTERNAL"
          ]
      ]

    do {
      let metadata = WalletMeta(chain: .btc, source: .mnemonic)
      let identity = Identity.currentIdentity!
      let wallet = try identity.importFromMnemonic(TestData.mnemonic, metadata: metadata, encryptBy: TestData.password, at: BIP44.btcMainnet)
      XCTAssertMapEqual(expectedResult, wallet.serializeToMap())
      XCTAssertEqual(TestData.mnemonic, try wallet.exportMnemonic(password: TestData.password), "Mnemonic should be equal")
      XCTAssertEqual(TestData.xprv, try wallet.privateKey(password: TestData.password), "XPrv should be euqal")
    } catch {
      XCTFail("Create wallet failed \(error)")
    }
  }
}
