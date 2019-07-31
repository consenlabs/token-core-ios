//
//  EOSKeystore.swift
//  token
//
//  Created by James Chen on 2018/06/20.
//  Copyright © 2018 ConsenLabs. All rights reserved.
//

import Foundation
import CoreBitcoin

struct EOSKeystore: Keystore, EncMnemonicKeystore {
  static let defaultVersion = 10001
  static let chainID = "aca376f206b8fc25a6ed44dbdc66547c36c6c33e3a119ffbeaef943642f0e906"
  let id: String
  let version = EOSKeystore.defaultVersion
  var address = ""
  let crypto: Crypto
  var meta: WalletMeta

  var encMnemonic: EncryptedMessage = EncryptedMessage(encStr: "", nonce: "")
  var mnemonicPath = ""
  var keyPathPrivates = [KeyPathPrivate]()

  /// Init with privaate keys and permissions.
  /// Private keys are WIF keys.
  init(accountName: String = "", password: String, privateKeys: [String], permissions: [EOS.PermissionObject], metadata: WalletMeta, id: String? = nil) throws {
    self.id = id ?? EOSKeystore.generateKeystoreId()
    address = try EOSAccountNameValidator(accountName).validate()
    meta = metadata
    crypto = Crypto(password: password, privateKey: Data.tk_random(of: 128).tk_toHexString(), cacheDerivedKey: true)

    let permissionPublicKeys = Set<String>(permissions.map { $0.publicKey })
    keyPathPrivates = try privateKeys.map({ wif -> KeyPathPrivate in
      let privateKey = EOSKey.privateKey(from: wif)
      let publicKey = EOSKeystore.getPublicKey(privateKey: privateKey)
      guard permissionPublicKeys.contains(publicKey) else {
        throw EOSError.privatePublicNotMatch
      }
      return KeyPathPrivate(
        encrypted: EncryptedMessage.create(crypto: crypto, derivedKey: crypto.cachedDerivedKey(with: password), message: Hex.hex(from: privateKey)),
        publicKey: publicKey,
        derivedMode: "IMPORTED"
      )
    })
    crypto.clearDerivedKey()
  }

  init(accountName: String = "", password: String, mnemonic: Mnemonic, path: String, permissions: [EOS.PermissionObject], metadata: WalletMeta, id: String? = nil) throws {
    self.id = id ?? EOSKeystore.generateKeystoreId()
    address = try EOSAccountNameValidator(accountName).validate()
    mnemonicPath = path
    meta = metadata

    let defaultKeys = try EOSKeystore.calculateDefaultKeys(mnemonic: mnemonic, path: path)
    crypto = Crypto(password: password, privateKey: RandomIV.init().value, cacheDerivedKey: true)
    let derivedKey = crypto.cachedDerivedKey(with: password)
    encMnemonic = EncryptedMessage.create(crypto: crypto, derivedKey: derivedKey, message: mnemonic.tk_toHexString())
    keyPathPrivates = try EOSKeystore.encryptKeyPaths(crypto: crypto, keyPaths: defaultKeys, permissions: permissions, derivedKey: derivedKey)
    crypto.clearDerivedKey()
  }

  // MARK: - JSON
  init(json: JSONObject) throws {
    guard
      let cryptoJson = (json["crypto"] as? JSONObject) ?? (json["Crypto"] as? JSONObject),
      json["version"] as? Int == version
    else {
      throw KeystoreError.invalid
    }

    id = (json["id"] as? String) ?? EOSKeystore.generateKeystoreId()
    address = json["address"] as? String ?? ""
    crypto = try Crypto(json: cryptoJson)

    mnemonicPath = json["mnemonicPath"] as? String ?? ""
    if let encMnemonicJSON = json["encMnemonic"] as? JSONObject, let encMnemonic = EncryptedMessage(json: encMnemonicJSON) {
      self.encMnemonic = encMnemonic
    }

    if let metaJSON = json[WalletMeta.key] as? JSONObject {
      meta = try WalletMeta(json: metaJSON)
    } else {
      meta = WalletMeta(chain: .btc, source: .keystore)
    }

    if let keyPathPrivatesJSON = json["keyPathPrivates"] as? [JSONObject] {
      keyPathPrivates = keyPathPrivatesJSON.compactMap { KeyPathPrivate(json: $0, hasMnemonic: mnemonicPath.isEmpty) }
    }
  }

  func decryptPrivateKey(from publicKey: String, password: String) throws -> [UInt8] {
    
    guard verify(password: password) else {
      throw PasswordError.incorrect
    }
    
    guard let keyPath = keyPathPrivates.first(where: { keyPathPrivate -> Bool in
      return publicKey == keyPathPrivate.publicKey
    }) else {
      throw EOSError.privatePublicNotMatch
    }
    return keyPath.encrypted.decrypt(crypto: crypto, password: password).tk_dataFromHexString()!.bytes
  }

  func exportKeyPairs(_ password: String) -> [KeyPair] {
    return keyPathPrivates.map({ (keyPathPrivate) -> KeyPair in
      let decrypted = keyPathPrivate.encrypted.decrypt(crypto: crypto, password: password)
      let privateKey = EOSKey(privateKey: decrypted.tk_dataFromHexString()!.bytes)
      return KeyPair(privateKey: privateKey.wif, publicKey: keyPathPrivate.publicKey)
    })
  }

  var publicKeys: [String] {
    return keyPathPrivates.map { $0.publicKey }
  }

  mutating func setAccountName(_ name: String) throws {
    let accountName = try EOSAccountNameValidator(name).validate()
    if !address.isEmpty && address != accountName {
      throw EOSError.accountNameAlreadySet
    }
    address = accountName
  }
}

private extension EOSKeystore {
  /// Calculate and return [master, owner, active] keys.
  static func calculateDefaultKeys(mnemonic: Mnemonic, path: String) throws -> [([UInt8], String?)] {
    guard let btcMnemonic = BTCMnemonic(words: mnemonic.split(separator: " "), password: "", wordListType: .english),
      let seedData = btcMnemonic.seed else {
        throw MnemonicError.wordInvalid
    }

    guard let masterKeychain = BTCKeychain(seed: seedData) else {
        throw GenericError.unknownError
    }
    return path.components(separatedBy: ",").map { p in
      let keychain = masterKeychain.derivedKeychain(withPath: p)
      return ([UInt8](keychain!.key.privateKey as Data), p)
    }

  }
  

  static func getPublicKey(privateKey: [UInt8]) -> String {
    let eosKey = EOSKey(privateKey: privateKey)
    return eosKey.publicKey
  }
  
  static func encryptKeyPaths(crypto: Crypto, keyPaths: [([UInt8], String?)], permissions: [EOS.PermissionObject], derivedKey: String) throws -> [KeyPathPrivate] {
    
    let keyPathPrivates = keyPaths.map { (key, path) -> KeyPathPrivate in
      let encryptedKey = EncryptedMessage.create(crypto: crypto, derivedKey: derivedKey, message: Hex.hex(from: key))
      return KeyPathPrivate(encrypted: encryptedKey, publicKey: getPublicKey(privateKey: key), derivedMode: path == nil ? "HD_SHA256" : "PATH_DIRECTLY", path: path)
    }
    try permissions.forEach { permission in
      if [EOS.Permission.owner, EOS.Permission.active].contains(permission.permission) {
        guard keyPathPrivates.first(where: { $0.publicKey == permission.publicKey }) != nil else {
          throw EOSError.privatePublicNotMatch
        }
      }
    }
    return keyPathPrivates
  }
}

extension EOSKeystore {
  struct KeyPathPrivate {
    var encrypted: EncryptedMessage
    var publicKey: String
    var path: String?
    var derivedMode: String

    init(encrypted: EncryptedMessage, publicKey: String, derivedMode:String, path: String? = nil) {
      self.encrypted = encrypted
      self.publicKey = publicKey
      self.derivedMode = derivedMode
      self.path = path
    }

    init?(json: JSONObject, hasMnemonic: Bool) {
      guard
        let encryptedJSON = json["privateKey"] as? JSONObject,
        let encrypted = EncryptedMessage(json: encryptedJSON),
        let publicKey = json["publicKey"] as? String
      else {
          return nil
      }
      let path = json["path"] as? String
      let derivedMode: String
      if let derivedModeFromJSON = json["derivedMode"] as? String {
          derivedMode = derivedModeFromJSON
      } else {
        derivedMode = hasMnemonic ? "IMPORTED" : "HD_SHA256"
      }
      self.init(encrypted: encrypted, publicKey: publicKey, derivedMode: derivedMode, path: path)
    }

    func toJSON() -> JSONObject {
      return [
        "privateKey": encrypted.toJSON(),
        "publicKey": publicKey,
        "path": path ?? "",
        "derivedMode": derivedMode
      ]
    }
  }

  func toJSON() -> JSONObject {
    var json = getStardandJSON()
    json["keyPathPrivates"] = keyPathPrivates.map { $0.toJSON() }
    json["encMnemonic"] = encMnemonic.toJSON()
    json["mnemonicPath"] = mnemonicPath
    json[WalletMeta.key] = meta.toJSON()
    return json
  }

  public func serializeToMap() -> [String: Any] {
    let pubKeyInfos = keyPathPrivates.map { keyPathPrivate -> [String: Any] in
      [
        "publicKey": keyPathPrivate.publicKey,
        "path": keyPathPrivate.path ?? "",
        "derivedMode": keyPathPrivate.derivedMode
      ]
    }
    
    return [
      "id": id,
      "address": address,
      "createdAt": (Int)(meta.timestamp),
      "source": meta.source.rawValue,
      "chainType": meta.chain!.rawValue,
      "publicKeys": pubKeyInfos
    ]
  }
}
