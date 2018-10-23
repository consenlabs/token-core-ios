//
//  ETHKeyTests.swift
//  token
//
//  Created by James Chen on 2016/09/26.
//  Copyright © 2016 imToken PTE. LTD. All rights reserved.
//

import XCTest
@testable import TokenCore

class ETHKeyTests: TestCase {
  func testAddressFromMnemonic() {
    let ethKey = ETHKey(mnemonic: "course left dad either tribe curious edit refuse tongue whisper axis volume", path: BIP44.eth)
    XCTAssertEqual(ethKey.address, "08c1c4735f4103b4e6f6629d4efb12b5869b0de8")
  }

  func testAddressFromPrivateKey() {
    let ethKey1 = ETHKey(mnemonic: "course left dad either tribe curious edit refuse tongue whisper axis volume", path: BIP44.eth)
    let ethKey2 = ETHKey(privateKey: ethKey1.privateKey)
    XCTAssertEqual(ethKey2.address, "08c1c4735f4103b4e6f6629d4efb12b5869b0de8")
  }

  func testAddressFromMnemonicWithIndex() {
    let ethKey1 = ETHKey(mnemonic: "course left dad either tribe curious edit refuse tongue whisper axis volume", path: "m/44'/60'/0'/0/3")
    let ethKey2 = ETHKey(privateKey: ethKey1.privateKey)
    XCTAssertEqual(ethKey2.address, "c49da23670b4d0908626c36aa5d82f3acb4af8ce")
  }

  func testAddressFromSeed() {
    let seed = ETHMnemonic.deterministicSeed(from: "course left dad either tribe curious edit refuse tongue whisper axis volume")
    let ethKey = ETHKey(seed: seed.tk_dataFromHexString()!, path: BIP44.eth)
    XCTAssertEqual(ethKey.address, "08c1c4735f4103b4e6f6629d4efb12b5869b0de8")
  }

  func testMnemonicToAddress() {
    XCTAssertEqual(
      "08c1c4735f4103b4e6f6629d4efb12b5869b0de8",
      ETHKey.mnemonicToAddress("course left dad either tribe curious edit refuse tongue whisper axis volume", path: BIP44.eth)
    )
  }

  func testPubToAddress() {
    // Private key: 3a1076bf45ab87712ad64ccb3b10217737f7faacbf2872e88fdd9a537d8fe266
    let publicKey = "04efb99d9860f4dec4cb548a5722c27e9ef58e37fbab9719c5b33d55c216db49311221a01f638ce5f255875b194e0acaa58b19a89d2e56a864427298f826a7f887"
    XCTAssertEqual(
      "c2d7cf95645d33006175b78989035c7c9061d3f9",
      ETHKey.pubToAddress(Data(bytes: Hex.toBytes(publicKey)))
    )
  }
}
