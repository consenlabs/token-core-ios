//
//  Keystore.swift
//  token
//
//  Created by James Chen on 2016/09/20.
//  Copyright © 2016 imToken PTE. LTD. All rights reserved.
//

import Foundation

public protocol Keystore {
  var id: String { get }
  var version: Int { get }
  var address: String { get }
  var crypto: Crypto { get }

  var meta: WalletMeta { get }

  func dump() -> String
  func toJSON() -> JSONObject
  func serializeToMap() -> [String: Any]
  func verify(password: String) -> Bool
}

protocol ExportableKeystore: Keystore {
  func export() -> String
}

extension ExportableKeystore {
  func export() -> String {
    let json = getStardandJSON()
    return prettyJSON(json)
  }
}

protocol PrivateKeyCrypto {
  var crypto: Crypto { get }
  func decryptPrivateKey(_ password: String) -> String
}

protocol WIFCrypto {
  var crypto: Crypto { get }
  func decryptWIF(_ password: String) -> String
}

protocol XPrvCrypto {
  var crypto: Crypto { get }
  func decryptXPrv(_ password: String) -> String
}

protocol EncMnemonicKeystore {
  var encMnemonic: EncryptedMessage { get }
  var crypto: Crypto { get }
  var mnemonicPath: String { get }
  func decryptMnemonic(_ password: String) -> String
}

public extension Keystore {
  static func generateKeystoreId() -> String {
    return NSUUID().uuidString.lowercased()
  }

  func verify(password: String) -> Bool {
    let decryptedMac = crypto.macFrom(password: password)
    let mac = crypto.mac
    return decryptedMac.lowercased() == mac.lowercased()
  }

  func dump() -> String {
    let json = toJSON()
    return prettyJSON(json)
  }

  func toJSON() -> JSONObject {
    var json = getStardandJSON()
    json[WalletMeta.key] = meta.toJSON()
    return json
  }

  func getStardandJSON() -> JSONObject {
    return [
      "id": id,
      "address": address,
      "version": version,
      "crypto": crypto.toJSON()
    ]
  }

  fileprivate func prettyJSON(_ json: JSONObject) -> String {
    let data = try! JSONSerialization.data(withJSONObject: json, options: [])
    return String(data: data, encoding: .utf8)!
  }
}

extension PrivateKeyCrypto {
  func decryptPrivateKey(_ password: String) -> String {
    return crypto.privateKey(password: password)
  }
}

extension EncMnemonicKeystore {
  func decryptMnemonic(_ password: String) -> String {
    let mnemonicHexStr = encMnemonic.decrypt(crypto: crypto, password: password)
    return mnemonicHexStr.tk_fromHexString()
  }
}

extension XPrvCrypto {
  func decryptXPrv(_ password: String) -> String {
    return crypto.privateKey(password: password).tk_fromHexString()
  }
}
