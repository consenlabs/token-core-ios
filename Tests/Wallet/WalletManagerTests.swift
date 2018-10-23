//
//  WalletManagerTests.swift
//  token
//
//  Created by Kai Chen on 07/09/2017.
//  Copyright © 2017 ConsenLabs. All rights reserved.
//

import XCTest
@testable import TokenCore

class WalletManagerTests: TestCase {
  func testImportPrivateKey() {
    do {
      let privateKey = "ee61c0a3c5801584eaa527dd4bf87837b540e74175e127985732b2e4ed6108a4"

      var meta = WalletMeta(source: .privateKey)
      meta.chain = .eth
      let wallet = try WalletManager.importFromPrivateKey(privateKey, encryptedBy: TestData.password, metadata: meta)

      XCTAssertNotNil(try WalletManager.findWalletByAddress(wallet.address, on: .eth), "Should exist after imported")
      XCTAssert(wallet.verifyPassword(TestData.password))

      XCTAssertNotNil(try WalletManager.findWalletByPrivateKey(privateKey, on: .eth), "Should exist after imported")
    } catch {
      XCTFail("fail caused by \(error)")
    }
  }

  func testImportMnemonic() {
    let mnemonic = "stock canoe swift boat level behave devote lemon heavy snow garage company"
    do {
      let meta = WalletMeta(chain: .eth, source: .mnemonic)
      let wallet = try WalletManager.importFromMnemonic(mnemonic, metadata: meta, encryptBy: TestData.password, at: BIP44.eth)

      XCTAssertNotNil(try WalletManager.findWalletByAddress(wallet.address, on: .eth), "Should exist after imported")
      XCTAssert(wallet.verifyPassword(TestData.password))

      XCTAssertNotNil(try WalletManager.findWalletByMnemonic(mnemonic, on: .eth, path: BIP44.eth), "Should exist after imported")
    } catch {
      XCTFail("fail caused by \(error)")
    }
  }

  func testImportKeystore() {
    let json = TestHelper.loadJSON(filename: "v3-scrypt-testpassword")
    let password = "testpassword"

    do {
      let keystore = try json.tk_toJSON()
      let meta = WalletMeta(chain: .eth, source: .keystore)
      let wallet = try WalletManager.importFromKeystore(keystore, encryptedBy: password, metadata: meta)

      XCTAssert(wallet.verifyPassword(password))

      XCTAssertNotNil(try WalletManager.findWalletByKeystore(keystore, on: .eth, password: password), "Should exist after keystore imported")
    } catch {
      XCTFail("fail caused by \(error)")
    }
  }

  func testSwitchBTCWalletMode() {
    let mnemonic = "stock canoe swift boat level behave devote lemon heavy snow garage company"
    do {
      var meta = WalletMeta(chain: .btc, source: .mnemonic)
      meta.segWit = .p2wpkh
      let wallet = try WalletManager.importFromMnemonic(mnemonic, metadata: meta, encryptBy: TestData.password, at: BIP44.btcMainnet)
      XCTAssert((wallet.keystore as! BTCMnemonicKeystore).meta.isSegWit)
      _ = try WalletManager.switchBTCWalletMode(walletID: wallet.walletID, password: TestData.password, segWit: .none)
      let loadedWallet = try! WalletManager.findWalletByAddress(wallet.address, on: .btc)
      XCTAssertFalse((loadedWallet.keystore as! BTCMnemonicKeystore).meta.isSegWit)
    } catch {
      XCTFail("fail caused by \(error)")
    }
  }
  
  func testSameMnemonicSwitchOverrideIdentity() {
    let mnemonic = "stock canoe swift boat level behave devote lemon heavy snow garage company"
    do {
      var meta = WalletMeta(chain: .btc, source: .mnemonic)
      meta.segWit = .p2wpkh
      meta.network = Network.mainnet
      _ = try Identity.recoverIdentity(metadata: meta, mnemonic: mnemonic, password: TestData.password)
      meta.segWit = .none
      let wallet = try WalletManager.importFromMnemonic(mnemonic, metadata: meta, encryptBy: TestData.password, at: BIP44.btcMainnet)
      XCTAssertNotNil(wallet)
      _ = try WalletManager.switchBTCWalletMode(walletID: wallet.walletID, password: TestData.password, segWit: .p2wpkh)
      XCTFail("Should throw an exception")
    } catch {
      XCTAssertEqual(AddressError.alreadyExist.localizedDescription, error.localizedDescription)
    }
  }

  func testFindByWalletID() {
    let mnemonic = "stock canoe swift boat level behave devote lemon heavy snow garage company"
    do {
      let meta = WalletMeta(chain: .eth, source: .mnemonic)
      let wallet = try WalletManager.importFromMnemonic(mnemonic, metadata: meta, encryptBy: TestData.password, at: BIP44.eth)

      XCTAssertNotNil(try WalletManager.findWalletByWalletID(wallet.walletID), "Should exist after imported")
    } catch {
      XCTFail("fail caused by \(error)")
    }
  }

  func testExportPrivateKey() {
    do {
      let privateKey = "ee61c0a3c5801584eaa527dd4bf87837b540e74175e127985732b2e4ed6108a4"

      var meta = WalletMeta(source: .privateKey)
      meta.chain = .eth
      let wallet = try WalletManager.importFromPrivateKey(privateKey, encryptedBy: TestData.password, metadata: meta)

      XCTAssertEqual(privateKey, try WalletManager.exportPrivateKey(walletID: wallet.walletID, password: TestData.password))
    } catch {
      XCTFail("fail caused by \(error)")
    }
  }
}

// EOS
extension WalletManagerTests {
  func testImportFromMnemonic() {
    let wallet = try! WalletManager.importEOS(from: TestData.mnemonic, accountName: "", permissions: [], metadata: WalletMeta(chain: .eos, source: .mnemonic), encryptBy: TestData.password, at: BIP44.eos)
    XCTAssertTrue(wallet.address.isEmpty)
  }

  func testImportFromMnemonicEmptyPath() {
    do {
      _ = try WalletManager.importEOS(from: TestData.mnemonic, accountName: "", permissions: [], metadata: WalletMeta(chain: .eos, source: .mnemonic), encryptBy: TestData.password, at: "")
      XCTFail()
    } catch let err {
      XCTAssertEqual(err.localizedDescription, MnemonicError.pathInvalid.localizedDescription)
    }
  }

  func testImportFromMnemonicInvalidChain() {
    do {
      _ = try WalletManager.importEOS(from: TestData.mnemonic, accountName: "", permissions: [], metadata: WalletMeta(chain: .eth, source: .mnemonic), encryptBy: TestData.password, at: BIP44.eos)
      XCTFail()
    } catch let err {
      XCTAssertEqual(err.localizedDescription, GenericError.operationUnsupported.localizedDescription)
    }
  }

  func testImportFromPrivateKeys() {
    let privateKeys = [
      "5Jnx4Tv6iu5fyq9g3aKmKsEQrhe7rJZkJ4g3LTK5i7tBDitakvP",
      "5JK2n2ujYXsooaqbfMQqxxd8P7xwVNDaajTuqRagJNGPi88yPGw"
    ]
    let permissions = [
      EOS.PermissionObject(permission: "owner", publicKey: "EOS621QecaYWvdKdCvHJRo76fvJwTo1Y4qegPnKxsf3FJ5zm2pPru", parent: ""),
      EOS.PermissionObject(permission: "active", publicKey: "EOS6qTGVvgoT39AAJp1ykty8XVDFv1GfW4QoS4VyjfQQPv5ziMNzF", parent: "")
    ]
    let wallet = try? WalletManager.importEOS(from: privateKeys, accountName: "", permissions: permissions, encryptedBy: TestData.password, metadata: WalletMeta(chain: .eos, source: .privateKey))
    XCTAssertNotNil(wallet)
  }

  func testImprtFromPrivateKeysPublickKeyNotMatch() {
    do {
     _  = try WalletManager.importEOS(from: [TestData.eosPrivateKey], accountName: "", permissions: [], encryptedBy: TestData.password, metadata: WalletMeta(chain: .eos, source: .privateKey))
      XCTFail()
    } catch let err {
      XCTAssertEqual(EOSError.privatePublicNotMatch.localizedDescription, err.localizedDescription)
    }
  }

  func testImportFromPrivateKeysInvalidChain() {
    do {
      _ = try WalletManager.importEOS(from: [""], accountName: "", permissions: [], encryptedBy: TestData.password, metadata: WalletMeta(chain: .eth, source: .privateKey))
      XCTFail()
    } catch let err {
      XCTAssertEqual(err.localizedDescription, GenericError.operationUnsupported.localizedDescription)
    }
  }

  func testSetAccountName() {
    let wallet = try! WalletManager.importEOS(from: TestData.mnemonic, accountName: "", permissions: [], metadata: WalletMeta(chain: .eos, source: .mnemonic), encryptBy: TestData.password, at: BIP44.eos)
    let updatedWallet = try! WalletManager.setEOSAccountName(walletID: wallet.walletID, accountName: "newname")
    XCTAssertEqual("newname", updatedWallet.address)
  }

  func testSetAccountNameWrongWalletType() {
    let mnemonic = "stock canoe swift boat level behave devote lemon heavy snow garage company"
    do {
      let meta = WalletMeta(chain: .eth, source: .mnemonic)
      let identity = Identity.currentIdentity!
      let wallet = try identity.importFromMnemonic(mnemonic, metadata: meta, encryptBy: TestData.password, at: BIP44.eth)
      _ = try WalletManager.setEOSAccountName(walletID: wallet.walletID, accountName: "newname")
      XCTFail()
    } catch let err {
      XCTAssertEqual(GenericError.operationUnsupported.localizedDescription, err.localizedDescription)
    }
  }

  func testExportPrivateKeys() {
    let privateKeys = [
      "5Jnx4Tv6iu5fyq9g3aKmKsEQrhe7rJZkJ4g3LTK5i7tBDitakvP",
      "5JK2n2ujYXsooaqbfMQqxxd8P7xwVNDaajTuqRagJNGPi88yPGw"
    ]
    let permissions = [
      EOS.PermissionObject(permission: "owner", publicKey: "EOS621QecaYWvdKdCvHJRo76fvJwTo1Y4qegPnKxsf3FJ5zm2pPru", parent: ""),
      EOS.PermissionObject(permission: "active", publicKey: "EOS6qTGVvgoT39AAJp1ykty8XVDFv1GfW4QoS4VyjfQQPv5ziMNzF", parent: "")
    ]
    let wallet = try! WalletManager.importEOS(from: privateKeys, accountName: "", permissions: permissions, encryptedBy: TestData.password, metadata: WalletMeta(chain: .eos, source: .privateKey))
    let exportedKeys = try! WalletManager.exportPrivateKeys(walletID: wallet.walletID, password: TestData.password).map { $0.privateKey }
    XCTAssertEqual(privateKeys, exportedKeys)
  }

  func testSignTransaction() {
    let wallet = try! WalletManager.importEOS(from: TestData.mnemonic, accountName: "", permissions: [], metadata: WalletMeta(chain: .eos, source: .mnemonic), encryptBy: TestData.password, at: BIP44.eosLedger)
    let txs = [
      EOSTransaction(
        data: "c578065b93aec6a7c811000000000100a6823403ea3055000000572d3ccdcd01000000602a48b37400000000a8ed323225000000602a48b374208410425c95b1ca80969800000000000453595300000000046d656d6f00",
        publicKeys: ["EOS88XhiiP7Cu5TmAUJqHbyuhyYgd6sei68AU266PyetDDAtjmYWF"],
        chainID: TestData.eosChainID
      )
    ]
    let result = try! WalletManager.eosSignTransaction(walletID: wallet.walletID, txs: txs, password: TestData.password)
    XCTAssertEqual(1, result.count)
    XCTAssertEqual(
      result[0],
      EOSSignResult(hash: "6af5b3ae9871c25e2de195168ed7423f455a68330955701e327f02276bb34088", signs: ["SIG_K1_KjZXm86HMVyUd59E15pCkrpn5uUPAAsjTxjEVRRueEvGciinxRS3sATmEEWdkb8hRNHhf6SXofsz4qzPdD6mfZ67FoqLxh"])
    )
  }

  func testSignTransactionWrongPassword() {
    let wallet = try! WalletManager.importEOS(from: TestData.mnemonic, accountName: "", permissions: [], metadata: WalletMeta(chain: .eos, source: .mnemonic), encryptBy: TestData.password, at: BIP44.eos)
    let txs = [
      EOSTransaction(
        data: "c578065b93aec6a7c811000000000100a6823403ea3055000000572d3ccdcd01000000602a48b37400000000a8ed323225000000602a48b374208410425c95b1ca80969800000000000453595300000000046d656d6f00",
        publicKeys: ["EOS5SxZMjhKiXsmjxac8HBx56wWdZV1sCLZESh3ys1rzbMn4FUumU"],
        chainID: TestData.eosChainID
      )
    ]
    do {
      _ = try WalletManager.eosSignTransaction(walletID: wallet.walletID, txs: txs, password: TestData.wrongPassword)
      XCTFail()
    } catch let err {
      XCTAssertEqual(PasswordError.incorrect.localizedDescription, err.localizedDescription)
    }
  }

  func testSignTransactionWalletNotFound() {
    do {
      _ = try WalletManager.eosSignTransaction(walletID: "oops", txs: [], password: "")
      XCTFail()
    } catch let err {
      XCTAssertEqual(GenericError.walletNotFound.localizedDescription, err.localizedDescription)
    }
  }
  
  func testImportingInvalidPkKeystore() {
    do {
      let invalidPkKeystore = """
        {"address":"dcc703c0e500b653ca82273b7bfad8045d85a470","crypto":{"cipher":"aes-128-ctr","cipherparams":{"iv":"4fd56a178ee2ad36c470fa6e8d972030"},"ciphertext":"a46adae8498e926eab52ce3cbd2bde64074dcf4927f05c85c528670e3c3b91f8","kdf":"scrypt","kdfparams":{"dklen":32,"n":262144,"p":1,"r":8,"salt":"38d1c31c43ef5806733ef2d5a3212810d8f51ff504e41f6ce9c6717e97d16145"},"mac":"b8724cf79dbecd837ed626620591f4485662692b3555e67967c358a4b7b437d6"},"id":"df242dcd-f3ee-4b8c-81fc-8cf6c2dd1779","version":3}
"""
      let meta = WalletMeta(chain: .eth, source: .keystore)
      _ = try WalletManager.importFromKeystore(invalidPkKeystore.tk_toJSON(), encryptedBy: "11111111", metadata: meta)
      XCTFail("Should throw exception")
    } catch let err as AppError {
      XCTAssertEqual(KeystoreError.containsInvalidPrivateKey.rawValue, err.message)
    } catch {
      XCTFail(error.localizedDescription)
    }
  }
}
