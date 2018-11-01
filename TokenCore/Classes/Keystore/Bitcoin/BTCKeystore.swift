//
//  BTCKeystore.swift
//  token
//
//  Created by xyz on 2018/1/3.
//  Copyright © 2018 ConsenLabs. All rights reserved.
//

import Foundation
import CoreBitcoin

struct BTCKeystore: Keystore, WIFCrypto {
  let id: String
  let version = 3
  var address: String
  let crypto: Crypto
  var meta: WalletMeta

  // Import with private key (WIF).
  init(password: String, wif: String, metadata: WalletMeta, id: String? = nil) throws {
    let privateKey = try PrivateKeyValidator(wif, on: .btc, network: metadata.network, requireCompressed: metadata.isSegWit).validate()

    let key = BTCKey(wif: wif)!
    address = key.address(on: metadata.network, segWit: metadata.segWit).string

    crypto = Crypto(password: password, privateKey: privateKey.tk_toHexString())
    self.id = id ?? BTCKeystore.generateKeystoreId()
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

    id = (json["id"] as? String) ?? BTCKeystore.generateKeystoreId()
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
    return meta.isMainnet ? key.wif : key.wifTestnet
  }

  func serializeToMap() -> [String: Any] {
    return [
      "id": id,
      "address": address,
      "createdAt": (Int)(meta.timestamp),
      "source": meta.source.rawValue,
      "chainType": meta.chain!.rawValue,
      "segWit": meta.segWit.rawValue
    ]
  }
}
