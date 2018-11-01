//
//  LocalFileStorageTests.swift
//  tokenTests
//
//  Created by James Chen on 2018/03/12.
//  Copyright © 2018 ConsenLabs. All rights reserved.
//

import XCTest
@testable import TokenCore

class LocalFileStorageTests: TestCase {
  override func setUp() {
    super.setUp()
    _ = LocalFileStorage().cleanStorage()
  }

  func testTryLoadIdentity() {
    let storage: Storage = LocalFileStorage()
    XCTAssertNil(storage.tryLoadIdentity())

    let keystore = try! IdentityKeystore(metadata: WalletMeta(source: .newIdentity), mnemonic: TestData.mnemonic, password: TestData.password)
    _ = storage.flushIdentity(keystore)
    XCTAssertNotNil(storage.tryLoadIdentity())
  }

  func testLoadWalletByIDs() {
    let storage: Storage = LocalFileStorage()
    XCTAssertEqual(0, storage.loadWalletByIDs([]).count)

    let metadata = WalletMeta(chain: .eth, source: .mnemonic)
    let identity = Identity.currentIdentity!
    let wallet = try! identity.importFromMnemonic(TestData.mnemonic, metadata: metadata, encryptBy: TestData.password, at: BIP44.eth)
    _ = storage.flushWallet(wallet.keystore)

    XCTAssertEqual(1, storage.loadWalletByIDs([wallet.walletID]).count)
  }

  func testDeleteWalletByID() {
    let storage: Storage = LocalFileStorage()
    XCTAssertFalse(storage.deleteWalletByID("abcd"))

    let metadata = WalletMeta(chain: .eth, source: .mnemonic)
    let identity = Identity.currentIdentity!
    let wallet = try! identity.importFromMnemonic(TestData.mnemonic, metadata: metadata, encryptBy: TestData.password, at: BIP44.eth)
    _ = storage.flushWallet(wallet.keystore)
    XCTAssert(storage.deleteWalletByID(wallet.walletID))
  }

  func testCleanStorage() {
    let storage: Storage = LocalFileStorage()

    let keystore = try! IdentityKeystore(metadata: WalletMeta(source: .newIdentity), mnemonic: TestData.mnemonic, password: TestData.password)
    _ = storage.flushIdentity(keystore)

    XCTAssert(storage.cleanStorage())
    XCTAssertNil(storage.tryLoadIdentity())
  }

  func testFlushIdentity() {
    let storage: Storage = LocalFileStorage()

    let keystore = try! IdentityKeystore(metadata: WalletMeta(source: .newIdentity), mnemonic: TestData.mnemonic, password: TestData.password)
    XCTAssert(storage.flushIdentity(keystore))
  }

  func testFlushWallet() {
    let storage: Storage = LocalFileStorage()

    let metadata = WalletMeta(chain: .eth, source: .mnemonic)
    let identity = Identity.currentIdentity!
    let wallet = try! identity.importFromMnemonic(TestData.mnemonic, metadata: metadata, encryptBy: TestData.password, at: BIP44.eth)
    XCTAssert(storage.flushWallet(wallet.keystore))
  }
}
