//
//  BTCMnemonicKeystore.swift
//  token
//
//  Created by James Chen on 2016/09/20.
//  Copyright © 2016 imToken PTE. LTD. All rights reserved.
//

import Foundation
import CoreBitcoin

public struct BTCMnemonicKeystore: Keystore, EncMnemonicKeystore, XPrvCrypto {
  static let defaultVersion = 44
  static let defaultSalt = "imToken" // Compatible with old version

  /// Generate app specific key and IV!
  public static var commonKey = "00000000000000000000000000000000"
  public static var commonIv = "00000000000000000000000000000000"

  public let id: String
  public let version: Int
  public let crypto: Crypto
  public var meta: WalletMeta
  public let address: String
  let mnemonicPath: String
  let encMnemonic: EncryptedMessage
  let xpub: String

  init(password: String, mnemonic: Mnemonic, path: String, metadata: WalletMeta, id: String? = nil) throws {
    version = BTCMnemonicKeystore.defaultVersion
    self.id = id ?? BTCMnemonicKeystore.generateKeystoreId()

    var realMnemonic = mnemonic
    if mnemonic.isEmpty {
      realMnemonic = ETHMnemonic().mnemonic
    }

    mnemonicPath = path

    guard let btcMnemonic = BTCMnemonic(words: realMnemonic.split(separator: " "), password: "", wordListType: .english),
      let seedData = btcMnemonic.seed else {
      throw MnemonicError.wordInvalid
    }

    let btcNetwork = metadata.isMainnet ? BTCNetwork.mainnet() : BTCNetwork.testnet()
    guard let masterKeychain = BTCKeychain(seed: seedData, network: btcNetwork),
          let accountKeychain = masterKeychain.derivedKeychain(withPath: mnemonicPath) else {
      throw GenericError.unknownError
    }
    accountKeychain.network = btcNetwork
    guard let rootPrivateKey = accountKeychain.extendedPrivateKey else {
      throw GenericError.unknownError
    }

    crypto = Crypto(password: password, privateKey: rootPrivateKey.tk_toHexString(), cacheDerivedKey: true)
    encMnemonic = EncryptedMessage.create(crypto: crypto, derivedKey: crypto.cachedDerivedKey(with: password), message: realMnemonic.tk_toHexString())
    crypto.clearDerivedKey()
    let indexKey = accountKeychain.derivedKeychain(withPath: "/0/0").key!
    address = indexKey.address(on: metadata.network, segWit: metadata.segWit).string
    xpub = accountKeychain.extendedPublicKey

    meta = metadata
  }

  private func derivedKey(for password: String) -> String {
    let key = crypto.derivedKey(with: password)
    return key.tk_substring(to: 32)
  }

  func getEncryptedXPub() -> String {
    let aes = Encryptor.AES128(key: BTCMnemonicKeystore.commonKey, iv: BTCMnemonicKeystore.commonIv, mode: .cbc, padding: .pkcs5)
    return BTCDataFromHex(aes.encrypt(string: xpub)).base64EncodedString()
  }
  
  public func getDecryptXPub() -> String {
    return xpub
  }

  func calcExternalAddress(at index: Int) -> String {
    let indexKey = BTCKeychain(extendedKey: xpub).derivedKeychain(withPath: "/0/\(index)").key!
    return indexKey.address(on: meta.network, segWit: meta.segWit).string
  }

  init(json: JSONObject) throws {
    version = (json["version"] as? Int) ?? BTCMnemonicKeystore.defaultVersion

    guard let cryptoJSON = json["crypto"] as? JSONObject else {
      throw KeystoreError.invalid
    }
    crypto = try Crypto(json: cryptoJSON)

    guard
      let id = json["id"] as? String,
      let mnemonicPath = json["mnemonicPath"] as? String,
      let encMnemonicJSON = json["encMnemonic"] as? JSONObject,
      let encMnemonic = EncryptedMessage(json: encMnemonicJSON),
      let address = json["address"] as? String,
      let xpub = json["xpub"] as? String else {
      throw KeystoreError.invalid
    }
    self.id = id
    self.mnemonicPath = mnemonicPath
    self.encMnemonic = encMnemonic
    self.address = address
    self.xpub = xpub

    if let metaJSON = json[WalletMeta.key] as? JSONObject {
      meta = try WalletMeta(json: metaJSON)
    } else {
      meta = WalletMeta(chain: .btc, source: .newIdentity)
    }
  }

  public func toJSON() -> JSONObject {
    var json = getStardandJSON()
    json["mnemonicPath"] = mnemonicPath
    json["encMnemonic"] = encMnemonic.toJSON()
    json["xpub"] = self.xpub
    json[WalletMeta.key] = meta.toJSON()

    return json
  }

  public func serializeToMap() -> [String: Any] {
    let externalMap: [String: Any] = [
      "address": self.calcExternalAddress(at: 1),
      "derivedPath": "0/1",
      "type": "EXTERNAL"
    ]
    return [
      "id": id,
      "address": address,
      "externalAddress": externalMap,
      "encXPub": getEncryptedXPub(),
      "createdAt": (Int)(meta.timestamp),
      "source": meta.source.rawValue,
      "chainType": meta.chain!.rawValue,
      "segWit": meta.segWit.rawValue
    ]
  }
}

// MARK: - Nested JSON objects
extension BTCMnemonicKeystore {
  struct Info {
    let curve: String
    let purpose: String

    init?(json: JSONObject) {
      guard let curve = json["curve"] as? String, let purpose = json["purpose"] as? String else {
        return nil
      }

      self.curve = curve
      self.purpose = purpose
    }

    init() {
      curve = "secp256k1"
      purpose = "sign"
    }

    func toJSON() -> JSONObject {
      return [
        "curve": curve,
        "purpose": purpose
      ]
    }
  }
}

extension BTCMnemonicKeystore {
  
  public static var scriptDerivedPathCache: [String: String] = [String: String]()
  
  public static func findUtxoKeyByScript(_ script: String, at keychain: BTCKeychain, isSegWit: Bool) -> BTCKey? {
    
    if let derivedPath = scriptDerivedPathCache[script] {
      return keychain.key(withPath: "/\(derivedPath)")
    } else {
      let scriptBytes = Hex.toBytes(script)
      let targetHash160: Data
      if isSegWit {
        // p2pkh script = HASH160(1byte) (1byte dataLength) ab68025513c3dbd2f7b92a94e0581f5d50f654e7(20byte reedmScript hash160) EQUALVERIFY CHECKSIG
        targetHash160 = Data(bytes: scriptBytes[2...21])
      } else {
        // p2sh-p2wpkh script = DUP(1byte) HASH160(1byte) (1byte dataLength) ab68025513c3dbd2f7b92a94e0581f5d50f654e7(20byte pk hash160) EQUALVERIFY CHECKSIG
        targetHash160 = Data(bytes: scriptBytes[3...22])
      }
      
      var foundKey: BTCKey?
      for i in 0...65535 {
        let receiveKey = keychain.key(withPath: "/0/\(i)")!
        let receiveKeyHash160 = hashPubKey(receiveKey.publicKey! as Data, isSegWit: isSegWit)
        if (receiveKeyHash160 as Data) == targetHash160 {
          foundKey = receiveKey
          scriptDerivedPathCache[script] = "0/\(i)"
          break
        }
        
        let changeKey = keychain.key(withPath: "/1/\(i)")!
        let changeKeyHash160 = hashPubKey(changeKey.publicKey! as Data, isSegWit: isSegWit)
        if (changeKeyHash160 as Data) == targetHash160 {
          scriptDerivedPathCache[script] = "1/\(i)"
          foundKey = changeKey
          break
        }
      }
      return foundKey
    }
  }
  
  public static func hashPubKey(_ data: Data, isSegWit: Bool) -> Data {
    let hash160 = BTCHash160(data)!
    if isSegWit {
      var redeemScript = "0x0014".tk_dataFromHexString()!
      redeemScript.append(hash160 as Data)
      return BTCHash160(redeemScript as Data) as Data
    } else {
      return hash160 as Data
    }
  }

}
