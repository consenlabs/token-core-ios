//
//  Hash.swift
//  token
//
//  Created by James Chen on 2018/03/06.
//  Copyright © 2018 ConsenLabs. All rights reserved.
//

import Foundation
import CryptoSwift
import CoreBitcoin

extension Encryptor {
  class Hash {
    static func hmacSHA256(key: Data, data: Data) -> Data {
      if let hmac = try? HMAC(key: Array(key), variant: .sha256).authenticate(Array(data)) {
        return Data(bytes: hmac)
      } else {
        return Data()
      }
    }

    /// Only for calculating merkle root hash for Identity backup.
    static func  merkleRoot(cipherData: Data) -> Data {
      let length = cipherData.count
      var items = [Data]()
      var i = 0
      while i < length {
        items.append(cipherData.subdata(in: i..<(i + min(length - i, 1024))))
        i += 1024
      }

      return BTCMerkleTree(dataItems: items).merkleRoot
    }
  }
}
