//
//  KDFPerformanceTests.swift
//  TokenCore
//
//  Created by James Chen on 2018/07/19.
//  Copyright © 2018 imToken PTE. LTD. All rights reserved.
//

import XCTest
@testable import TokenCore

// Note: safely comment out these tests to speed up normal testing.

class KDFPerformanceTests: XCTestCase { // Do NOT inherit from TestCase, which does something that also takes time.
  func testKdfPerformanceScrypt1024() {
    measure {
      Crypto.ScryptKdfparams.defaultN = 1024
      _ = Crypto.ScryptKdfparams(salt: nil).derivedKey(for: TestData.password)
    }
  }

  func testKdfPerformanceScrypt262144() {
    measure {
      // Note: should measure this on a device to see how long it takes.
      Crypto.ScryptKdfparams.defaultN = 262_144
      _ = Crypto.ScryptKdfparams(salt: nil).derivedKey(for: TestData.password)
    }
  }

  func testCreateIdentityKeystore() {
    measure {
      var metadata = WalletMeta(source: .recoveredIdentity)
      metadata.network = .testnet
      Crypto.ScryptKdfparams.defaultN = 262_144

      /// Keystore creation, which calls PDF multiple times.
      /// Test and measure: Ask Crypto instance for derivedKey, then pass it instead of password to reudce KDF call.
      /// Test and measure: Crypto caches derivedKey internally.
      _ = try! IdentityKeystore(metadata: metadata, mnemonic: TestData.mnemonic, password: TestData.password)

      /// Results:
      ///  * Before: 7.88 sec
      ///  * After:  5.41 sec
      ///  * After caching derivedKey: 2.56 sec
    }
  }

  func testDeriveWalletsSerial() {
    Crypto.ScryptKdfparams.defaultN = 1024
    BTCMnemonicKeystore.commonKey = "11111111111111111111111111111111"
    BTCMnemonicKeystore.commonIv = "CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC"
    StorageManager.storageType = InMemoryStorage.self
    var metadata = WalletMeta(source: .newIdentity)
    metadata.name = "kdf tweak"
    metadata.network = .mainnet
    let (mnemonic, identity) = try! Identity.createIdentity(password: TestData.password, metadata: metadata)

    measure {
      Crypto.ScryptKdfparams.defaultN = 262_144

      /// Derive 3 wallets in turn
      /// Test and measure: Test running BTC, ETH and EOS wallet(keystore) derivation in three separate threads.
      _ = try! identity.deriveWallets(for: [.eth], mnemonic: mnemonic, password: TestData.password)
      _ = try! identity.deriveWallets(for: [.btc], mnemonic: mnemonic, password: TestData.password)
      _ = try! identity.deriveWallets(for: [.eos], mnemonic: mnemonic, password: TestData.password)

      /// Results:
      /// * Before: 21 sec
      /// * After caching derivedKey: 8 sec
    }
  }
}
