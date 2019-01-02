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
      let signedData = try WalletManager.eosEcSign(walletID: eosWallet.walletID, data: "imToken2017", isHex: false, publicKey: TestData.eosPublicKey, password: TestData.password)
      XCTAssertEqual("SIG_K1_JuVsfsNmB3JgvsnxUcmuw5m27gH9xTGuU4yN9BMoRLeLVYhA4Bfypdm8DDg5cUTXSLArDLc3gtRFkFHMm3rmZyZxD5FE7k", signedData)
      let rightPubKey = try WalletManager.eosEcRecover(data: "imToken2017", isHex: false, signature: signedData)
      XCTAssertEqual(TestData.eosPublicKey, rightPubKey)
      
      let wrongPubKey = try WalletManager.eosEcRecover(data: "imToken2016", isHex: false, signature: signedData)
      XCTAssertNotEqual(TestData.eosPublicKey, wrongPubKey)
    } catch {
      XCTFail(error.localizedDescription)
    }

  }
  
  func testEcSignHexTest() {
    do {
      let meta = WalletMeta(chain: .eos, source: .mnemonic)
      let eosWallet = try WalletManager.importEOS(from: TestData.mnemonic, accountName: "blobblobblob", permissions: [], metadata: meta, encryptBy: TestData.password, at: BIP44.eosLedger)
      let signedData = try WalletManager.eosEcSign(walletID: eosWallet.walletID, data: "1546396453811", isHex: false, publicKey: "EOS88XhiiP7Cu5TmAUJqHbyuhyYgd6sei68AU266PyetDDAtjmYWF", password: TestData.password)
      XCTAssertEqual("SIG_K1_KYKWN3wf2jVsd2MP279ds6YvoPCKx4YHHisfenaEZWwwZEq2bodf8LRBepMm33PEBjYp3STceR5AeD94V6DEWEkEZWA5sq", signedData)

    } catch {
      XCTFail(error.localizedDescription)
    }
    
  }

}
