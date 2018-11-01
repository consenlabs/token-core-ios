//
//  ETHKeystoreTests.swift
//  tokenTests
//
//  Created by James Chen on 2018/02/24.
//  Copyright © 2018 ConsenLabs. All rights reserved.
//

import XCTest
@testable import TokenCore

class ETHKeystoreTests: TestCase {
  func testImportPrivateKey() {
    let meta = WalletMeta(chain: .eth, source: .privateKey)
    let keystore = try? ETHKeystore(password: TestData.password, privateKey: TestData.privateKey, metadata: meta)
    XCTAssertNotNil(keystore)
    XCTAssertEqual("6031564e7b2f5cc33737807b2e58daff870b590b", keystore?.address)
  }

  func testInitWithJSON() {
    let data = TestHelper.loadJSON(filename: "v3-pbkdf2-testpassword").data(using: .utf8)!
    let json = try! JSONSerialization.jsonObject(with: data) as! JSONObject
    let keystore = try? ETHKeystore(json: json)
    XCTAssertNotNil(keystore)
    XCTAssertEqual(keystore!.meta.source, WalletMeta.Source.keystore)
  }
  
  func testValidKeystore() {
    do {
      let invalidKeystoreFiles = Bundle(for: ETHKeystoreTests.self).paths(forResourcesOfType: "json", inDirectory: "invalid_keystores")
      let meta = WalletMeta(chain: .eth, source: .keystore)
      for case let filePath in invalidKeystoreFiles {
        let json = try String(contentsOfFile: filePath).tk_toJSON()
        let err = json["err"] as! String
        do {
          _ = try WalletManager.importFromKeystore(json, encryptedBy: "imToken2018", metadata: meta)
          XCTFail("\(filePath) valid failed")
        } catch let error as AppError  {
          XCTAssertEqual(error.message, err, "\(filePath) valid failed")
        }
      }
    } catch {
      XCTFail(error.localizedDescription)
    }
    
  }
  
  func testImortKeystoreContainsInvalidPK() {
      let invalidKeystore = """
{
    "address": "dcc703c0e500b653ca82273b7bfad8045d85a470",
    "crypto": {
        "cipher": "aes-128-ctr",
        "cipherparams": {
            "iv": "4fd56a178ee2ad36c470fa6e8d972030"
        },
        "ciphertext": "a46adae8498e926eab52ce3cbd2bde64074dcf4927f05c85c528670e3c3b91f8",
        "kdf": "scrypt",
        "kdfparams": {
            "dklen": 32,
            "n": 262144,
            "p": 1,
            "r": 8,
            "salt": "38d1c31c43ef5806733ef2d5a3212810d8f51ff504e41f6ce9c6717e97d16145"
        },
        "mac": "b8724cf79dbecd837ed626620591f4485662692b3555e67967c358a4b7b437d6"
    },
    "id": "df242dcd-f3ee-4b8c-81fc-8cf6c2dd1779",
    "version": 3
}
"""
      let meta = WalletMeta(chain: .eth, source: .keystore)
      let json = try! invalidKeystore.tk_toJSON()
      do {
      _ = try WalletManager.importFromKeystore(json, encryptedBy: "22222222", metadata: meta)
      XCTFail("Shoud throw exception")
      }  catch {
        XCTAssertTrue(error is AppError)
        XCTAssertEqual((error as! AppError).message, KeystoreError.macUnmatch.rawValue)
      }
  
    do {
      _ = try WalletManager.importFromKeystore(json, encryptedBy: "11111111", metadata: meta)
      XCTFail("Shoud throw exception")
    }  catch {
      XCTAssertTrue(error is AppError)
      XCTAssertEqual((error as! AppError).message, KeystoreError.containsInvalidPrivateKey.rawValue)
    }
  }
}
