//
//  BTCMnemonicKeystoreTests.swift
//  tokenTests
//
//  Created by James Chen on 2018/02/24.
//  Copyright © 2018 ConsenLabs. All rights reserved.
//

import XCTest
@testable import TokenCore

class BTCMnemonicKeystoreTests: TestCase {
  func testInit() {
    let meta = WalletMeta(chain: .btc, source: .mnemonic)
    let keystore = try? BTCMnemonicKeystore(password: TestData.password, mnemonic: TestData.mnemonic, path: BIP44.btcMainnet, metadata: meta)
    XCTAssertNotNil(keystore)
    XCTAssertEqual(keystore!.address, "12z6UzsA3tjpaeuvA2Zr9jwx19Azz74D6g")
    XCTAssertEqual(keystore!.mnemonicPath, BIP44.btcMainnet)
  }

  func testTestnetInit() {
    let meta = WalletMeta(chain: .btc, source: .mnemonic, network: .testnet)
    let keystore = try? BTCMnemonicKeystore(password: TestData.password, mnemonic: TestData.mnemonic, path: BIP44.btcTestnet, metadata: meta)
    XCTAssertNotNil(keystore)
    XCTAssertEqual(keystore!.address, "mkeNU5nVnozJiaACDELLCsVUc8Wxoh1rQN")
    XCTAssertEqual(keystore!.mnemonicPath, BIP44.btcTestnet)
  }

  func testGetEncryptedXPub() {
    BTCMnemonicKeystore.commonKey = "11111111111111111111111111111111"
    BTCMnemonicKeystore.commonIv = "CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC"
    let meta = WalletMeta(chain: .btc, source: .mnemonic)
    let keystore = try! BTCMnemonicKeystore(password: TestData.password, mnemonic: TestData.mnemonic, path: BIP44.btcMainnet, metadata: meta)
    XCTAssertEqual("KumI81YksYmQgSibrUhoXv3M1GRlON0Ots/HFxHSaIFzbW1g8wZAC/ozIz2M/xgE9B30RfgxlbHAOobt+T0T5iIn14EzeliOk6O5p05F53CZS1bGhNdoAlOogKzN9FMP61CzFyMG29GAIGigUbTY8g==", keystore.getEncryptedXPub())
  }

  func testCalcExternalAddress() {
    let meta = WalletMeta(chain: .btc, source: .mnemonic)
    let keystore = try! BTCMnemonicKeystore(password: TestData.password, mnemonic: TestData.mnemonic, path: BIP44.btcMainnet, metadata: meta)
    XCTAssertEqual("12z6UzsA3tjpaeuvA2Zr9jwx19Azz74D6g", keystore.calcExternalAddress(at: 0))
    XCTAssertEqual("1962gsZ8PoPUYHneFakkCTrukdFMVQ4i4T", keystore.calcExternalAddress(at: 1))
  }

  func testToJSON() {
    let meta = WalletMeta(chain: .btc, source: .mnemonic)
    let keystore = try! BTCMnemonicKeystore(password: TestData.password, mnemonic: TestData.mnemonic, path: BIP44.btcMainnet, metadata: meta)
    let json = keystore.toJSON()
    XCTAssertEqual(json["mnemonicPath"] as? String, BIP44.btcMainnet)
  }
}

// SegWit
extension BTCMnemonicKeystoreTests {
  func testInitSegWit() {
    var meta = WalletMeta(chain: .btc, source: .mnemonic)
    meta.segWit = .p2wpkh
    let keystore = try? BTCMnemonicKeystore(password: TestData.password, mnemonic: TestData.mnemonic, path: BIP44.btcSegwitMainnet, metadata: meta)
    XCTAssertNotNil(keystore)
    XCTAssertEqual(keystore!.address, "3JmreiUEKn8P3SyLYmZ7C1YCd4r2nFy3Dp")
    XCTAssertEqual(keystore!.mnemonicPath, BIP44.btcSegwitMainnet)
  }

  func testTestnetInitSegWit() {
    var meta = WalletMeta(chain: .btc, source: .mnemonic, network: .testnet)
    meta.segWit = .p2wpkh
    let keystore = try? BTCMnemonicKeystore(password: TestData.password, mnemonic: TestData.mnemonic, path: BIP44.btcSegwitTestnet, metadata: meta)
    XCTAssertNotNil(keystore)
    XCTAssertEqual(keystore!.address, "2MwN441dq8qudMvtM5eLVwC3u4zfKuGSQAB")
    XCTAssertEqual(keystore!.mnemonicPath, BIP44.btcSegwitTestnet)
  }

  func testCalcExternalAddressSegWit() {
    var meta = WalletMeta(chain: .btc, source: .mnemonic)
    meta.segWit = .p2wpkh
    let keystore = try! BTCMnemonicKeystore(password: TestData.password, mnemonic: TestData.mnemonic, path: BIP44.btcSegwitMainnet, metadata: meta)
    XCTAssertEqual("3JmreiUEKn8P3SyLYmZ7C1YCd4r2nFy3Dp", keystore.calcExternalAddress(at: 0))
    XCTAssertEqual("33xJxujVGf4qBmPTnGW9P8wrKCmT7Nwt3t", keystore.calcExternalAddress(at: 1))
  }
}
