//
//  EOSTransactionSignerTests.swift
//  TokenCoreTests
//
//  Created by James Chen on 2018/06/26.
//  Copyright © 2018 ConsenLabs. All rights reserved.
//

import Foundation

import XCTest
@testable import TokenCore
import CoreBitcoin

class EOSTransactionSignerTests: TestCase {
//  func testSignTransacton() {
//    let wallet = try! WalletManager.importEOS(from: TestData.mnemonic, accountName: "", permissions: [], metadata: WalletMeta(chain: .eos, source: .mnemonic), encryptBy: TestData.password, at: BIP44.eos)
//    let txs = [
//      EOSTransaction(
//        data: "c578065b93aec6a7c811000000000100a6823403ea3055000000572d3ccdcd01000000602a48b37400000000a8ed323225000000602a48b374208410425c95b1ca80969800000000000453595300000000046d656d6f00",
//        publicKeys: ["EOS5SxZMjhKiXsmjxac8HBx56wWdZV1sCLZESh3ys1rzbMn4FUumU"],
//        chainID: TestData.eosChainID
//      )
//    ]
//    let result = try! EOSTransactionSigner(txs: txs, keystore: wallet.keystore, password: TestData.password).sign()
//    XCTAssertEqual(1, result.count)
//    XCTAssertEqual(
//      result[0],
//      EOSSignResult(hash: "6af5b3ae9871c25e2de195168ed7423f455a68330955701e327f02276bb34088", signs: ["SIG_K1_KkCTdqnTztAPnYeB2TWhrqcDhnnLvFJJdXnFCE3g8jRyz2heCggDQt5bMABu4LawHaDy4taHwJR3XMKV2ZXnBWqyiBnQ9J"])
//    )
//  }

  func testSignWithWrongPassword() {
    let wallet = try! WalletManager.importEOS(from: TestData.mnemonic, accountName: "", permissions: [], metadata: WalletMeta(chain: .eos, source: .mnemonic), encryptBy: TestData.password, at: BIP44.eos)
    let txs = [
      EOSTransaction(
        data: "c578065b93aec6a7c811000000000100a6823403ea3055000000572d3ccdcd01000000602a48b37400000000a8ed323225000000602a48b374208410425c95b1ca80969800000000000453595300000000046d656d6f00",
        publicKeys: ["EOS5SxZMjhKiXsmjxac8HBx56wWdZV1sCLZESh3ys1rzbMn4FUumU"],
        chainID: TestData.eosChainID
      )
    ]
    do {
      _ = try EOSTransactionSigner(txs: txs, keystore: wallet.keystore, password: TestData.wrongPassword).sign()
      XCTFail()
    } catch let err {
      XCTAssertEqual(PasswordError.incorrect.localizedDescription, err.localizedDescription)
    }
  }
  
  func testSignHash() {
    let key = EOSKey(wif: "5KQwrPbwdL6PhXujxW37FSSQZ1JiwsST4cqQzDeyXtP79zkvFD3")
    
    guard let testcaseFile = Bundle(for: EOSTransactionSignerTests.self).path(forResource: "EOSSignTestcase", ofType: "txt") else {
      XCTFail("Testcase file not found!")
      return
    }
    
    do {
      let content = try String(contentsOfFile:testcaseFile, encoding: String.Encoding.utf8)
      let testcase = content.split(separator: "\n")
      for line in testcase {
        let aCase = line.split(separator: ",")
        
        let actual = EOSTransaction.signatureBase58(data: key.sign(data: (aCase[0].data(using: .utf8)?.sha256())!))
        XCTAssertEqual(String(aCase[1]) as String, actual)
        
      }
    } catch {
      XCTFail(error.localizedDescription)
    }
    
  }
}
