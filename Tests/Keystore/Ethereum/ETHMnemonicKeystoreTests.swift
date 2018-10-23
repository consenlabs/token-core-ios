//
//  ETHMnemonicKeystoreTests.swift
//  tokenTests
//
//  Created by James Chen on 2018/02/24.
//  Copyright © 2018 ConsenLabs. All rights reserved.
//

import XCTest
@testable import TokenCore

class ETHMnemonicKeystoreTests: TestCase {
  func testInit() {
    let meta = WalletMeta(chain: .eth, source: .mnemonic)
    let keystore = try? ETHMnemonicKeystore(password: TestData.password, mnemonic: TestData.mnemonic, path: BIP44.eth, metadata: meta)
    XCTAssertNotNil(keystore)
    XCTAssertEqual(keystore!.address, "6031564e7b2f5cc33737807b2e58daff870b590b")
    XCTAssertEqual(keystore!.mnemonicPath, BIP44.eth)
  }

  func testInitWithJSON() {
    let meta = WalletMeta(chain: .eth, source: .mnemonic)
    let keystore = try! ETHMnemonicKeystore(password: TestData.password, mnemonic: TestData.mnemonic, path: BIP44.eth, metadata: meta)
    let new = try? ETHMnemonicKeystore(json: keystore.toJSON())
    XCTAssertNotNil(new)
    XCTAssertEqual(new!.address, "6031564e7b2f5cc33737807b2e58daff870b590b")
  }
}
