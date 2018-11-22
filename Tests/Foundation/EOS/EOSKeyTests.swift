//
//  EOSKeyTests.swift
//  TokenCoreTests
//
//  Created by James Chen on 2018/06/21.
//  Copyright © 2018 ConsenLabs. All rights reserved.
//

import XCTest
import CoreBitcoin
@testable import TokenCore

class EOSKeyTests: TestCase {
  func testWif() {
    let eosKey = EOSKey(wif: TestData.eosPrivateKey)
    XCTAssertEqual(TestData.eosPublicKey, eosKey.publicKey)
  }

  func testPrivateKey() {
    let privateKeyBytes = (BTCDataFromBase58(TestData.eosPrivateKey) as Data).bytes
    let privateKey = [UInt8].init(privateKeyBytes[1..<privateKeyBytes.count - 4])
    let eosKey = EOSKey(privateKey: privateKey)
    XCTAssertEqual(TestData.eosPublicKey, eosKey.publicKey)
  }
  
  func testEcSignTest() {
    do {
      let meta = WalletMeta(chain: .eos, source: .wif)
      let eosWallet = try WalletManager.importFromPrivateKey(TestData.eosPrivateKey, encryptedBy: TestData.password, metadata: meta, accountName: "imtoken1")
      let signedData = try WalletManager.eosEcSign(walletID: eosWallet.walletID, data: "imToken2017", publicKey: TestData.eosPublicKey, password: TestData.password)
      XCTAssertEqual("SIG_K1_JuVsfsNmB3JgvsnxUcmuw5m27gH9xTGuU4yN9BMoRLeLVYhA4Bfypdm8DDg5cUTXSLArDLc3gtRFkFHMm3rmZyZxD5FE7k", signedData)
      let rightPubKey = try WalletManager.eosEcRecover(data: "imToken2017", signature: signedData)
      XCTAssertEqual(TestData.eosPublicKey, rightPubKey)
      
      let wrongPubKey = try WalletManager.eosEcRecover(data: "imToken2016", signature: signedData)
      XCTAssertNotEqual(TestData.eosPublicKey, wrongPubKey)
    } catch {
      XCTFail(error.localizedDescription)
    }

  }

}
