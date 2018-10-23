//
//  BTCKeystoreTests.swift
//  tokenTests
//
//  Created by James Chen on 2018/02/24.
//  Copyright © 2018 ConsenLabs. All rights reserved.
//

import XCTest
import CoreBitcoin
@testable import TokenCore

class EOSKeystoreTests: TestCase {
  private var meta: WalletMeta {
    let m = WalletMeta(chain: .eos, source: .mnemonic)
    return m
  }

  private var privateKeyMeta: WalletMeta {
    let m = WalletMeta(chain: .eos, source: .wif)
    return m
  }

  func testImportPrivateKeys() {
    let privateKeys = [
      "5Jnx4Tv6iu5fyq9g3aKmKsEQrhe7rJZkJ4g3LTK5i7tBDitakvP",
      "5JK2n2ujYXsooaqbfMQqxxd8P7xwVNDaajTuqRagJNGPi88yPGw",
      "5J25CphXSMh2SUdjspX7M4sLT5QATkTXJhiGSMn4nwg1HbhHLRe"
    ]
    let permissions = [
      EOS.PermissionObject(permission: "owner", publicKey: "EOS621QecaYWvdKdCvHJRo76fvJwTo1Y4qegPnKxsf3FJ5zm2pPru", parent: ""),
      EOS.PermissionObject(permission: "active", publicKey: "EOS6qTGVvgoT39AAJp1ykty8XVDFv1GfW4QoS4VyjfQQPv5ziMNzF", parent: ""),
      EOS.PermissionObject(permission: "sns", publicKey: "EOS877B3gaJytVzFizhWPD26SefS9QV1qYTZT2QCcXueQfV4PAN8h", parent: "")
    ]
    let keystore = try? EOSKeystore(accountName: "test", password: TestData.password, privateKeys: privateKeys, permissions: permissions, metadata: privateKeyMeta)
    XCTAssertNotNil(keystore)
    XCTAssertEqual(keystore!.meta.chain, .eos)
    XCTAssertEqual(keystore!.meta.source, .wif)
    XCTAssertEqual("test", keystore!.address)

    XCTAssertEqual(
      ["EOS621QecaYWvdKdCvHJRo76fvJwTo1Y4qegPnKxsf3FJ5zm2pPru", "EOS6qTGVvgoT39AAJp1ykty8XVDFv1GfW4QoS4VyjfQQPv5ziMNzF", "EOS877B3gaJytVzFizhWPD26SefS9QV1qYTZT2QCcXueQfV4PAN8h"],
      keystore!.publicKeys
    )
  }

  func testImportPrivateKeyUnmatchPublicKey() {
    let privateKeys = [
      "5Jnx4Tv6iu5fyq9g3aKmKsEQrhe7rJZkJ4g3LTK5i7tBDitakvP",
      "5JK2n2ujYXsooaqbfMQqxxd8P7xwVNDaajTuqRagJNGPi88yPGw"
    ]
    let permissions = [
      EOS.PermissionObject(permission: "owner", publicKey: "EOS621QecaYWvdKdCvHJRo76fvJwTo1Y4qegPnKxsf3FJ5zm2pPrU", parent: ""),
      EOS.PermissionObject(permission: "active", publicKey: "EOS6qTGVvgoT39AAJp1ykty8XVDFv1GfW4QoS4VyjfQQPv5ziMNzF", parent: "")
    ]
    do {
      _ = try EOSKeystore(password: TestData.password, privateKeys: privateKeys, permissions: permissions, metadata: privateKeyMeta)
      XCTFail("Should throw")
    } catch let err {
      XCTAssertEqual(err.localizedDescription, EOSError.privatePublicNotMatch.localizedDescription)
    }
  }

  func testImportMnemonic() {
    let keystore = try? EOSKeystore(password: TestData.password, mnemonic: TestData.mnemonic, path: BIP44.eosLedger, permissions: [], metadata: meta)
    XCTAssertNotNil(keystore)
    XCTAssertEqual(keystore!.meta.chain, .eos)
    XCTAssertEqual(keystore!.meta.source, .mnemonic)
    XCTAssert(keystore!.address.isEmpty)

    XCTAssertEqual(
      [ "EOS88XhiiP7Cu5TmAUJqHbyuhyYgd6sei68AU266PyetDDAtjmYWF"],
      keystore!.publicKeys
    )

    XCTAssertEqual(keystore!.decryptMnemonic(TestData.password), TestData.mnemonic)
    XCTAssertEqual(keystore!.mnemonicPath, BIP44.eosLedger)
  }

  func testImportWithPermissions() {
    let permissions = [
      EOS.PermissionObject(permission: "owner", publicKey: "EOS88XhiiP7Cu5TmAUJqHbyuhyYgd6sei68AU266PyetDDAtjmYWF", parent: "")
    ]
    let keystore = try? EOSKeystore(password: TestData.password, mnemonic: TestData.mnemonic, path: BIP44.eosLedger, permissions: permissions, metadata: meta)
    XCTAssertNotNil(keystore)
    
    XCTAssertEqual(
      "EOS88XhiiP7Cu5TmAUJqHbyuhyYgd6sei68AU266PyetDDAtjmYWF",
      keystore!.publicKeys[0]
    )
  }

  func testImportUnmatchPublicKey() {
    func testImportEOSWalletFailedWhenDerivedPubKeyNotSame() {
      let permissions = [
        EOS.PermissionObject(permission: "owner", publicKey: "EOS7tpXQ1thFJ69ZXDqqEan7GMmuWdcptKmwgbs7n1cnx3hWPw3jW", parent: ""),
        EOS.PermissionObject(permission: "active", publicKey: "EOS5SxZMjhKiXsmjxac8HBx56wWdZV1sCLZESh3ys1rzbMn4FUumU", parent: "")
      ]
      do {
        _ = try EOSKeystore(password: TestData.password, mnemonic: TestData.mnemonic, path: BIP44.eos, permissions: permissions, metadata: meta)
        XCTFail("Should throw")
      } catch let err {
        XCTAssertEqual(err.localizedDescription, EOSError.privatePublicNotMatch.localizedDescription)
      }
    }
  }

  func testExportPrivateKeys() {
    let keystore = try! EOSKeystore(password: TestData.password, mnemonic: TestData.mnemonic, path: BIP44.eosLedger, permissions: [], metadata: meta)
    XCTAssertEqual(
      [
        KeyPair(privateKey: "5KAigHMamRhN7uwHFnk3yz7vUTyQT1nmXoAA899XpZKJpkqsPFp", publicKey: "EOS88XhiiP7Cu5TmAUJqHbyuhyYgd6sei68AU266PyetDDAtjmYWF")
      ],
      keystore.exportKeyPairs(TestData.password)
    )
  }
  
  func testInitFromJSON() {
    do {
      let keystoreJson = TestHelper.loadJSON(filename: "42c275c6-957a-49e8-9eb3-43c21cbf583f")
      let wallet = try BasicWallet(json: (try keystoreJson.tk_toJSON()))
      XCTAssertNotNil(wallet.keystore as? EOSLegacyKeystore)
    } catch {
      XCTFail("Some error happen \(error)")
    }
  }

  func testInvalidAccountName() {
    do {
      let _ = try EOSKeystore(accountName: "Oops", password: TestData.password, mnemonic: TestData.mnemonic, path: BIP44.eos, permissions: [], metadata: meta)
      XCTFail()
    } catch let err {
      XCTAssertEqual(err.localizedDescription, EOSError.accountNameInvalid.localizedDescription)
    }
  }

  func testInitWithInvalidJSON() {
    let data = "{}".data(using: .utf8)!
    let json = try! JSONSerialization.jsonObject(with: data) as! JSONObject
    do {
      _ = try EOSKeystore(json: json)
      XCTFail()
    } catch let err {
      XCTAssertEqual(err.localizedDescription, KeystoreError.invalid.localizedDescription)
    }
  }

  func testSerializeToMap() {
    let keystore = try! EOSKeystore(password: TestData.password, mnemonic: TestData.mnemonic, path: BIP44.eos, permissions: [], metadata: meta)
    let map = keystore.serializeToMap()
    XCTAssertEqual(map["id"] as! String, keystore.id)
  }

  func testToJSON() {
    let keystore = try! EOSKeystore(password: TestData.password, mnemonic: TestData.mnemonic, path: BIP44.eos, permissions: [], metadata: meta)
    let json = keystore.toJSON()
    XCTAssertEqual(json["mnemonicPath"] as! String, BIP44.eos)
  }
  
 
}
