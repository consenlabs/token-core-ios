//
//  ETHKeystore.swift
//  token
//
//  Created by xyz on 2018/1/3.
//  Copyright © 2018 ConsenLabs. All rights reserved.
//

import Foundation

struct ETHKeystore: ExportableKeystore, PrivateKeyCrypto {
  let id: String
  let version = 3
  var address: String
  let crypto: Crypto
  var meta: WalletMeta

  // Import from private key
  init(password: String, privateKey: String, metadata: WalletMeta, id: String? = nil) throws {
    address = ETHKey(privateKey: privateKey).address
    crypto = Crypto(password: password, privateKey: privateKey)
    self.id = id ?? ETHKeystore.generateKeystoreId()
    meta = metadata
  }

  // MARK: - JSON
  init(json: JSONObject) throws {
    guard
      let cryptoJson = (json["crypto"] as? JSONObject) ?? (json["Crypto"] as? JSONObject),
      json["version"] as? Int == version
      else {
        throw KeystoreError.invalid
    }

    id = (json["id"] as? String) ?? ETHKeystore.generateKeystoreId()
    address = json["address"] as? String ?? ""
    crypto = try Crypto(json: cryptoJson)

    if let metaJSON = json[WalletMeta.key] as? JSONObject {
      meta = try WalletMeta(json: metaJSON)
    } else {
      meta = WalletMeta(chain: .eth, source: .keystore)
    }
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
