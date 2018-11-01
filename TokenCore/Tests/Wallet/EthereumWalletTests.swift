//
//  WalletTests.swift
//  token
//
//  Created by Kai Chen on 08/09/2017.
//  Copyright © 2017 ConsenLabs. All rights reserved.
//

import XCTest
@testable import TokenCore

class EthereumWalletTests: TestCase {
  func testImportWalletFromPrivateKey() {
    let expectedResult: [String: Any] = [
      "address": "6031564e7b2f5cc33737807b2e58daff870b590b",
      "source": "PRIVATE",
      "chainType": "ETHEREUM"
    ]
    
    do {
      let identity = Identity.currentIdentity!
      let metadata = WalletMeta(chain: .eth, source: .privateKey)
      let wallet = try identity.importFromPrivateKey(TestData.privateKey, encryptedBy: TestData.password, metadata: metadata)
      XCTAssertMapEqual(expectedResult, wallet.keystore.serializeToMap())
      XCTAssertEqual(TestData.privateKey, try wallet.privateKey(password: TestData.password), "private decrypted from keystore should be right")
    } catch {
      XCTFail("import wallet from private key failed: \(error)")
    }
  }
  
  func testImportWalletFromMnemonic() {
    let expectedResult: [String: Any] = [
      "address": "6031564e7b2f5cc33737807b2e58daff870b590b",
      "source": "MNEMONIC",
      "chainType": "ETHEREUM"
    ]
    do {
      let metadata = WalletMeta(chain: .eth, source: .mnemonic)
      let identity = Identity.currentIdentity!

      let wallet = try identity.importFromMnemonic(TestData.mnemonic, metadata: metadata, encryptBy: TestData.password, at: BIP44.eth)
      XCTAssertMapEqual(expectedResult, wallet.keystore.serializeToMap())
      XCTAssertEqual(TestData.mnemonic, try wallet.exportMnemonic(password: TestData.password), "mnemonic decrypted from keystore should be right")
      XCTAssertEqual(TestData.privateKey, try wallet.privateKey(password: TestData.password), "private decrypted from keystore should be right")
    } catch {
      XCTFail("import wallet from mnemonic failed: \(error)")
    }
  }

  func testImportWalletFromKeystore () {
    let json = TestHelper.loadJSON(filename: "v3-pbkdf2-testpassword")
    let data = json.data(using: .utf8)!
    let keystore = try! JSONSerialization.jsonObject(with: data) as! JSONObject
    let expectedResult: [String: Any] = [
      "address": "008aeeda4d805471df9b2a5b0f38a0c3bcba786b",
      "source": "KEYSTORE",
      "chainType": "ETHEREUM"
    ]
    let metadata = WalletMeta(chain: .eth, source: .keystore)
    let identity =  Identity.currentIdentity!
    let wallet = try! identity.importFromKeystore(keystore, encryptedBy: "testpassword", metadata: metadata)
    XCTAssertMapEqual(expectedResult, wallet.keystore.serializeToMap())
  }
}
