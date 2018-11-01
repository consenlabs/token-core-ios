//
//  TestCases.swift
//  tokenTests
//
//  Created by xyz on 2018/1/5.
//  Copyright © 2018 ConsenLabs. All rights reserved.
//

import XCTest
@testable import TokenCore

func XCTAssertMapEqual(_ expectedMap: [AnyHashable: Any], _ actual: [AnyHashable: Any], file: StaticString = #file, line: UInt = #line) {
  for (key, value) in expectedMap {
    if let nestedMap = value as? [AnyHashable: Any] {
      XCTAssertMapEqual(nestedMap, actual[key] as! [AnyHashable: Any], file: file, line: line)
    }
    if let value = value as? String {
      XCTAssertEqual(value, actual[key] as! String, file: file, line: line)
    }
    if let value = value as? Int {
      XCTAssertEqual(value, actual[key] as! Int, file: file, line: line)
    }
  }
}

struct TestData {
  static let password = "Insecure Pa55w0rd"
  static let passwordHint = "password hint"
  static let wrongPassword = "Wrong Password"

  static let mnemonic = "inject kidney empty canal shadow pact comfort wife crush horse wife sketch"
  static let otherMnemonic = "spy excess school tiger quick link olympic timber final learn rebuild dragon"
  static let seed = "ee3fce3ccf05a2b58c851e321077a63ee2113235112a16fc783dc16279ff818a549ff735ac4406c624235db2d37108e34c6cbe853cbe09eb9e2369e6dd1c5aaa"
  static let eosPrivateKey = "5KQwrPbwdL6PhXujxW37FSSQZ1JiwsST4cqQzDeyXtP79zkvFD3"
  static let eosPublicKey = "EOS6MRyAjQq8ud7hVNYcfnVPJqcVpscN5So8BhtHuGYqET5GDW5CV"
  static let eosChainID = "aca376f206b8fc25a6ed44dbdc66547c36c6c33e3a119ffbeaef943642f0e906"
  static let privateKey = "cce64585e3b15a0e4ee601a467e050c9504a0db69a559d7ec416fa25ad3410c2"
  static let wif = "L2hfzPyVC1jWH7n2QLTe7tVTb6btg9smp5UVzhEBxLYaSFF7sCZB"
  static let wifTestnet = "cUieW64P5NYWe2JrxiHRMeE3xWZTdtTCh5DNWF1VVYBAmLJkBRWs" // compressed
  static let xprv = "xprv9yrdwPSRnvomqFK4u1y5uW2SaXS2Vnr3pAYTjJjbyRZR8p9BwoadRsCxtgUFdAKeRPbwvGRcCSYMV69nNK4N2kadevJ6L5iQVy1SwGKDTHQ"
}

class TestCase: XCTestCase {
  private var storage: Storage!

  override func setUp() {
    super.setUp()

    continueAfterFailure = false
    Crypto.ScryptKdfparams.defaultN = 1024
    BTCMnemonicKeystore.commonKey = "11111111111111111111111111111111"
    BTCMnemonicKeystore.commonIv = "CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC"
    StorageManager.storageType = InMemoryStorage.self
    storage = StorageManager.storageType.init()
    var metadata = WalletMeta(source: .newIdentity)
    metadata.name = "xyz"
    metadata.passwordHint = TestData.passwordHint
    metadata.network = .mainnet
    _ = try! Identity.createIdentity(password: TestData.password, metadata: metadata)
  }

  override func tearDown() {
    _ = storage.cleanStorage()
    StorageManager.storageType = LocalFileStorage.self
    _ = try! Identity.currentIdentity?.delete(password: TestData.password)

    super.tearDown()
  }
}
