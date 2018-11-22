//
//  EOSKey.swift
//  TokenCore
//
//  Created by James Chen on 2018/06/21.
//  Copyright © 2018 ConsenLabs. All rights reserved.
//

import Foundation
import CoreBitcoin

class EOSKey {
  private let btcKey: BTCKey

  var publicKey: String {
    let publicKey = btcKey.compressedPublicKey as Data
    let checksum = (BTCRIPEMD160(publicKey) as Data).bytes[0..<4]
    let base58 = BTCBase58StringWithData(publicKey + checksum)!
    return "EOS" + base58
  }

  var wif: String {
    return btcKey.wif
  }

  init(privateKey: [UInt8]) {
    btcKey = BTCKey(privateKey: Data(bytes: privateKey))!
  }
  
  init(key: BTCKey) {
    btcKey = key
  }

  convenience init(wif: String) {
    self.init(privateKey: EOSKey.privateKey(from: wif))
  }

  func sign(data: Data) -> Data {
    return btcKey.eosCompactSignature(forHash: data)
  }
  
  
  public static func ecRecover(data: Data, signature: Data) throws -> String {
    guard let key = BTCKey.eosEcRecover(signature, forHash: data) else {
      throw "Not found a workable private key"
    }
    return EOSKey(key: key).publicKey
  }

  static func privateKey(from wif: String) -> [UInt8] {
    let wifBytes = (BTCDataFromBase58(wif) as Data).bytes
    return [UInt8].init(wifBytes[1..<wifBytes.count - 4])
  }
}
