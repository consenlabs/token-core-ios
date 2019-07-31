//
//  EOSTransaction.swift
//  TokenCore
//
//  Created by James Chen on 2018/06/25.
//  Copyright © 2018 ConsenLabs. All rights reserved.
//

import Foundation
import CoreBitcoin

public final class EOSTransaction {
  private let data: String // Hex tx data
  private let publicKeys: [String]
  private let chainID: String

  public init(data: String, publicKeys: [String], chainID: String) {
    self.data = data
    self.publicKeys = publicKeys
    self.chainID = chainID
  }

  public func sign(password: String, keystore: Keystore) throws -> EOSSignResult {
    let hash = Hex.toBytes(data).sha256().toHexString()

    let toSign = NSMutableData()
    toSign.append(chainID.tk_dataFromHexString()!)
    toSign.append(data.tk_dataFromHexString()!)
    toSign.append(Data(bytes: [UInt8](repeating: 0, count: 32)))
    let hashedTx = BTCSHA256(toSign as Data) as Data

    let signs = try publicKeys.map { publicKey -> String in
      let key: EOSKey
      if let eosKeystore = keystore as? EOSKeystore {
        let privateKey = try eosKeystore.decryptPrivateKey(from: publicKey, password: password)
        key = EOSKey(privateKey: privateKey)
      } else {
        let legacyKeystore = keystore as! EOSLegacyKeystore
        let wif = legacyKeystore.decryptWIF(password)
        key = EOSKey(wif: wif)
      }

      return EOSTransaction.signatureBase58(data: key.sign(data: hashedTx))
    }

    return EOSSignResult(hash: hash, signs: signs)
  }

  static func signatureBase58(data: Data) -> String {
    let toHash = NSMutableData()
    toHash.append(data)
    toHash.append("K1".data(using: .ascii)!)
    let checksum = (BTCRIPEMD160(toHash as Data) as Data).bytes[0..<4]

    let ret = NSMutableData()
    ret.append(data)
    ret.append(Data(bytes: checksum))

    return "SIG_K1_\(BTCBase58StringWithData(ret as Data)!)"
  }
  
  static func deserializeSignature(sig: String) throws -> Data {
    guard sig.starts(with: "SIG_K1_") else {
      throw "Signature must begin with SIG_K1_"
    }
    let base58Str = sig.tk_substring(from: "SIG_K1_".count)
    let decodedData = BTCDataFromBase58(base58Str)! as Data
    let rsvData = Data(bytes: decodedData.bytes[0..<65])
    if EOSTransaction.signatureBase58(data: rsvData) != sig {
      throw "The Checksum of eos signature is invalid"
    }
    return rsvData
  }
}
