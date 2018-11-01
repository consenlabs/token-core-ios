//
//  BIP39Tests.swift
//  tokenTests
//
//  Created by Kai Chen on 03/10/2017.
//  Copyright © 2017 ConsenLabs. All rights reserved.
//

import XCTest
@testable import TokenCore

class MnemonicUtilTests: TestCase {
  func testGenerateMnemonic() {
    let mnemonic = MnemonicUtil.generateMnemonic()
    let wordCount = mnemonic.split(separator: " ").count
    XCTAssertEqual(wordCount, 12, "generateMnemonic() should return 12 words")
  }

  func testGenerateSeedFromMnemonic() {
    let seed = MnemonicUtil.btcMnemonicFromEngWords(TestData.mnemonic).seed.tk_toHexString()
    XCTAssertEqual(TestData.seed, seed)
  }
}
