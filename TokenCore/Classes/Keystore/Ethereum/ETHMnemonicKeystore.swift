//
//  ETHMnemonicKeystore.swift
//  token
//
//  Created by James Chen on 2016/09/20.
//  Copyright © 2016 imToken PTE. LTD. All rights reserved.
//

import Foundation

struct ETHMnemonicKeystore: ExportableKeystore, EncMnemonicKeystore, PrivateKeyCrypto {
  let id: String
  let version = 3
  let address: String
  let crypto: Crypto
  let meta: WalletMeta
  let encMnemonic: EncryptedMessage
  let mnemonicPath: String

  init(password: String, mnemonic: String, path: String, metadata: WalletMeta, id: String? = nil) throws {
    self.id = id ?? ETHMnemonicKeystore.generateKeystoreId()
    meta = metadata

    let ethKey = ETHKey(mnemonic: mnemonic, path: path)
    crypto = Crypto(password: password, privateKey: ethKey.privateKey, cacheDerivedKey: true)
    encMnemonic = EncryptedMessage.create(crypto: crypto, derivedKey: crypto.cachedDerivedKey(with: password), message: mnemonic.tk_toHexString())
    crypto.clearDerivedKey()
    mnemonicPath = path
    address = ethKey.address
  }

  init(json: JSONObject) throws {
    guard
      let cryptoJson = (json["crypto"] as? JSONObject) ?? (json["Crypto"] as? JSONObject),
      json["version"] as? Int == version,
      let encMnemonicNode = json["encMnemonic"] as? JSONObject,
      let mnemonicPath = json["mnemonicPath"] as? String
      else {
      throw KeystoreError.invalid
    }

    id = (json["id"] as? String) ?? ETHMnemonicKeystore.generateKeystoreId()

    address = json["address"] as? String ?? ""
    crypto = try Crypto(json: cryptoJson)

    encMnemonic = EncryptedMessage(json: encMnemonicNode)!
    self.mnemonicPath = mnemonicPath
    if let metaJSON = json[WalletMeta.key] as? JSONObject {
      meta = try WalletMeta(json: metaJSON)
    } else {
      meta = WalletMeta(chain: .eth, source: .keystore)
    }
  }

  func toJSON() -> JSONObject {
    var json = getStardandJSON()
    json["mnemonicPath"] = mnemonicPath
    json["encMnemonic"] = encMnemonic.toJSON()
    json[WalletMeta.key] = meta.toJSON()
    return json
  }

  func serializeToMap() -> [String: Any] {
    return [
      "id": id,
      "address": address,
      "createdAt": (Int)(meta.timestamp),
      "source": meta.source.rawValue,
      "chainType": meta.chain!.rawValue
    ]
  }
}
