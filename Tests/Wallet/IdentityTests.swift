//
//  IdentityTests.swift
//  tokenTests
//
//  Created by xyz on 2017/12/27.
//  Copyright © 2017 ConsenLabs. All rights reserved.
//

import XCTest
@testable import TokenCore

class IdentityTests: TestCase {
  func testCreateIdentity() {
    do {
      var metadata = WalletMeta(source: .newIdentity)
      metadata.network = .testnet
      metadata.passwordHint = TestData.passwordHint
      metadata.name = "xyz"
      let mnemonicAndIdentity = try Identity.createIdentity(password: TestData.password, metadata: metadata)

      let identity = mnemonicAndIdentity.1
      XCTAssertNotNil(identity.keystore.identifier, "Should has identifier")
      XCTAssertNotNil(identity.keystore.ipfsId, "Should has ipfs id")

      XCTAssertEqual(identity.keystore.wallets.count, 2, "Should has two wallets")
      XCTAssertEqual(identity.keystore.wallets[0].imTokenMeta.chain, ChainType.eth, "First wallet should be ethereum")
      XCTAssertEqual(identity.keystore.wallets[1].imTokenMeta.chain, ChainType.btc, "Second wallet should be Bitcoin")
      XCTAssertEqual(identity.keystore.wallets[1].imTokenMeta.network, .testnet, "Bitcoin wallet shoud be in testnet")
    } catch {
      XCTFail("create identity test error: \(error)")
    }
  }

  func testRecoverIdentity() {
    do {
      var metadata = WalletMeta(source: .recoveredIdentity)
      metadata.network = .testnet
      metadata.passwordHint = TestData.passwordHint
      metadata.name = "xyz"
      let identity = try Identity.recoverIdentity(metadata: metadata, mnemonic: TestData.mnemonic, password: TestData.password)
      print("identifier: \(identity.keystore.identifier)")
      print("ipfsId: \(identity.keystore.ipfsId)")
      XCTAssertEqual(identity.keystore.identifier, "im18MDKM8hcTykvMmhLnov9m2BaFqsdjoA7cwNg")
      XCTAssertEqual(identity.keystore.ipfsId, "QmSTTidyfa4np9ak9BZP38atuzkCHy4K59oif23f4dNAGU")

      let ethWallet = identity.keystore.wallets[0]
      XCTAssertEqual(ethWallet.address, "6031564e7b2f5cc33737807b2e58daff870b590b")
      XCTAssertEqual(try ethWallet.privateKey(password: TestData.password), "cce64585e3b15a0e4ee601a467e050c9504a0db69a559d7ec416fa25ad3410c2")
      
      let btcWallet = identity.keystore.wallets[1]

      XCTAssertEqual(btcWallet.keystore.address, "mkeNU5nVnozJiaACDELLCsVUc8Wxoh1rQN")
      XCTAssertEqual(try! btcWallet.calcExternalAddress(at: 1), "mj78AbVtQ9SWnvbU7pcrueyE1krMmZtoUU")
      let expectedXPrv = "tprv8g8UWPRHxaNWXZN3uoaiNpyYyaDr2j5Dvcj1vxLxKcEF653k7xcN9wq9eT73wBM1HzE9hmWJbAPXvDvaMXqGWm81UcVpHnmATfH2JJrfhGg"
      XCTAssertEqual(expectedXPrv, try btcWallet.privateKey(password: TestData.password))
      XCTAssertEqual((btcWallet.keystore as! BTCMnemonicKeystore).getEncryptedXPub(), "z8mGJW10fGNvS5y4u5NJB2InBghTty10hbgM0EzPksr91LUDZqnbX8vINytLWeEqBW7knUNo9+SvDSAFi+gNEEmUUYzvsYYBfieuo6pANe8s/hHnrbqfL/PN9xtvIl57ZO5hMN3AMCX/NzSd8+WIQw==")
    } catch {
      XCTFail("create recover identity \(error)")
    }
  }

  func testExportIdentity() {
    var metadata = WalletMeta(source: .recoveredIdentity)
    metadata.network = .testnet
    metadata.passwordHint = TestData.passwordHint
    metadata.name = "xyz"
    let identity = try! Identity.recoverIdentity(metadata: metadata, mnemonic: TestData.mnemonic, password: TestData.password)
    do {
      _ = try identity.export(password: TestData.wrongPassword)
      XCTFail("Shoud throw invalid password when export identity use wrong password")
    } catch PasswordError.incorrect {
      XCTAssert(1 == 1)
    } catch {
      XCTFail("unknown error")
    }

    let mnemonic = try! identity.export(password: TestData.password)
    XCTAssertEqual(mnemonic, TestData.mnemonic)
  }

  func testDeleteIdentity() {
    var metadata = WalletMeta(source: .recoveredIdentity)
    metadata.network = .testnet
    metadata.passwordHint = TestData.passwordHint
    metadata.name = "xyz"
    let identity = try! Identity.recoverIdentity(metadata: metadata, mnemonic: TestData.mnemonic, password: TestData.password)
    do {
      _ = try identity.delete(password: TestData.wrongPassword)
      XCTFail("Shoud throw invalid password when delete identity use wrong password")
    } catch PasswordError.incorrect {
        XCTAssert(1 == 1)
    } catch {
      XCTFail("unknown error")
    }
  }

  func testRemoveWallet() {
    var metadata = WalletMeta(source: .recoveredIdentity)
    metadata.network = .testnet
    let identity = try! Identity.recoverIdentity(metadata: metadata, mnemonic: TestData.mnemonic, password: TestData.password)
    let wallet = try! identity.findWalletByMnemonic(TestData.mnemonic, on: .eth, path: BIP44.eth, network: .testnet)!
    XCTAssertNotNil(wallet)
    XCTAssertTrue(identity.removeWallet(wallet))
    XCTAssertFalse(identity.removeWallet(wallet))
  }

  func testIPFSDecrypt() {
    var metadata = WalletMeta(source: .recoveredIdentity)
    metadata.network = .testnet
    metadata.passwordHint = TestData.passwordHint
    metadata.name = "xyz"
    let identity = try! Identity.recoverIdentity(metadata: metadata, mnemonic: TestData.mnemonic, password: TestData.password)
    
    let fixture: [[String: String]] = [
      ["content": "imToken", "iv": "11111111111111111111111111111111", "result": "0340b2495a1111111111111111111111111111111110b6602c68084bdd08dae796657aa6854ad13312fedc88f5b6f16c56b3e755dde125a1c4775db536ac0442ac942f9634c777f3ae5ca39f6abcae4bd6c87e54ab29ae0062b04d917b32e8d7c88eeb6261301b"],
      ["content": "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa", "iv": "11111111111111111111111111111111", "result": "0340b2495a11111111111111111111111111111111708b7e9486a339f6c482ec9d3786dd9f99222fa64753bc2e7d246b0fed9c2153b8a5dcc59ea3e320aa153ceefdd909e8484d215121a9b8416d395de38313ef65b9e27d2ba0cc17bf29c5b26fa5aa5be1a2500b017f06cdd001e8cd908c5a48f10962880a61b4704754fd6bbe3b5a1a8332376651c28205a02574ed95a70363e0d1031d133c8d2376808b74ffd78b831ec659b44e9f3d3734d26abd44dda88fac86d1a5f0128f77d0558fb1ef6d2cc8f9541c"],
      ["content": "a", "iv": "11111111111111111111111111111111", "result": "0340b2495a111111111111111111111111111111111084e741e2b83ec644e844985088fd58d8449cb690cd7389d74e3be1ccdca755b0235c90431b7635a441944d880bd52c860b109b7a05a960192719eb3f294ec1b72f5dfd1b8f4c6e992b9c3add7c7c1b871b"],
      ["content": "A", "iv": "11111111111111111111111111111111", "result": "0340b2495a1111111111111111111111111111111110de32f176b67269ddfe24b2162eae14968d2eafcb53ec5741a07a1d65dc10189e0f6b4c199e98b02fcb9ec744b134cecc4ae8bfbf79e7703781c259eab9ee2fa31f887b24d04b37b7c5aa49a3ff2a8d5e1b"],
      ["content": "a", "iv": "11111111111111111111111111111111", "result": "0340b2495a111111111111111111111111111111111084e741e2b83ec644e844985088fd58d8449cb690cd7389d74e3be1ccdca755b0235c90431b7635a441944d880bd52c860b109b7a05a960192719eb3f294ec1b72f5dfd1b8f4c6e992b9c3add7c7c1b871b"],
      ["content": "a", "iv": "22222222222222222222222222222222", "result": "0340b2495a22222222222222222222222222222222102906146aa78fadd4abac01d9aa34dbd66463220fa0a98b9212594e7624a34bb20ba50df75cb04362f8dcfe7a8c44b2b5740a2d66de015d867e609463482686959ebba6047600562fa82e94ee905f1d291c"]
    ]
    let timestamp: TimeInterval = 1514779200.0
    for aCase in fixture {
      let encrypted = identity.encryptDataToIpfs(content: aCase["content"]!, iv: (aCase["iv"]?.tk_dataFromHexString()!)!, timestamp:timestamp)!
      XCTAssertEqual(aCase["result"], encrypted)
      XCTAssertEqual(aCase["content"], try? identity.decryptDataFromIpfs(payload: encrypted))
    }
  }
}
