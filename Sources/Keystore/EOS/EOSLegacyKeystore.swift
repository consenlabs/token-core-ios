//
//  EOSLegacyKeystore.swift
//  TokenCore
//
//  Created by James Chen on 2018/06/20.
//  Copyright © 2018 ConsenLabs. All rights reserved.
//

import Foundation
import CoreBitcoin

// Legacy keystore format pre-mainnet launch.
struct EOSLegacyKeystore: Keystore, WIFCrypto {
  let id: String
  let version = 3
  var address: String
  let crypto: Crypto
  var meta: WalletMeta

  // Import with private key (WIF).
  init(password: String, wif: String, metadata: WalletMeta, accountName: String, id: String? = nil) throws {
    address = accountName
    crypto = Crypto(password: password, privateKey: wif.tk_toHexString())
    self.id = id ?? EOSKeystore.generateKeystoreId()
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

    id = (json["id"] as? String) ?? EOSKeystore.generateKeystoreId()
    address = json["address"] as? String ?? ""
    crypto = try Crypto(json: cryptoJson)

    if let metaJSON = json[WalletMeta.key] as? JSONObject {
      meta = try WalletMeta(json: metaJSON)
    } else {
      meta = WalletMeta(chain: .btc, source: .keystore)
    }
  }

  func decryptWIF(_ password: String) -> String {
    let wif = crypto.privateKey(password: password).tk_fromHexString()
    let key = BTCKey(wif: wif)!
    return key.wif
  }
  
  func exportPrivateKeys(_ password: String) -> [KeyPair] {
    let wif = crypto.privateKey(password: password).tk_fromHexString()
    let key = BTCKey(wif: wif)!
    let eosKey = EOSKey(wif: key.wif)
    let keyPair = KeyPair(privateKey: key.wif, publicKey: eosKey.publicKey)
    return [keyPair]
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
