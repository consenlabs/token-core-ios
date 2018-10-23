//
//  SigUtil.swift
//  token
//
//  Created by Kai Chen on 16/11/2017.
//  Copyright © 2017 ConsenLabs. All rights reserved.
//

import Foundation
import CoreBitcoin

public typealias ECSignature = [String: Any] // -> { v: integer, r: string, s: string }

public struct SigUtil {
  static func personalSign(privateKey: String, msgParams: [String: String]) -> ECSignature {
    guard let data = msgParams["data"] else {
      return [String: AnyHashable]()
    }
    return ecsign(with: privateKey, data: hashPersonalMessage(data))
  }

  public static func batchEcsign(with privateKey: String, data: [String]) -> [ECSignature] {
    return data.map { ecsign(with: privateKey, data: $0) }
  }

  public static func ecsign(with privateKey: String, data: String) -> ECSignature {
    let result = Encryptor.Secp256k1().sign(key: privateKey, message: data)
    let v = result.recid + 27
    let r = result.signature.tk_substring(to: 64)
    let s = result.signature.tk_substring(from: 64)
    return ["v": v, "r": r, "s": s]
  }

  public static func ecrecover(signature: String, recid: Int32, forHash msgHash: String) -> String? {
    return Encryptor.Secp256k1().recover(signature: signature, message: msgHash, recid: recid)
  }

  public static func hashPersonalMessage(_ msg: String) -> String {
    let prefix = "\u{0019}Ethereum Signed Message:\n\(String(msg.lengthOfBytes(using: .utf8)))"
    return Encryptor.Keccak256().encrypt(hex: (prefix + msg).tk_toHexString())
  }

  public static func concatSig(v: Int32, r: String, s: String) -> String {
    var buf = ""
    buf += r.lpad(width: 64, with: "0")
    buf += s.lpad(width: 64, with: "0")
    buf += String(format: "%2x", v)
    return buf
  }

  public static func concatSig(v: Int32, rs: String) -> String {
    var buf = ""
    buf += rs.lpad(width: 128, with: "0")
    buf += String(format: "%2x", v)
    return buf
  }

  public static func unpackSig(sig: String) throws -> (String, Int32) {
    guard sig.count == 130 else {
      throw GenericError.paramError
    }
    let signature = sig.tk_substring(to: 128)
    let recIdStr = sig.tk_substring(from: 128)

    guard let recId = Int32(recIdStr, radix: 16) else {
      throw GenericError.paramError
    }
    return (signature, recId - 27)
  }

  public static func calcIPFSIDFromKey(_ key: BTCKey) -> String {
    let pubKeyHash = key.publicKey.sha256()!
    var multiHashIndex: UInt8 = 0x12
    var length: UInt8 = UInt8(pubKeyHash.count)
    var ipfsIdData = Data(bytes: &multiHashIndex, count: MemoryLayout<UInt8>.size)
    ipfsIdData.append(Data(bytes: &length, count: MemoryLayout<UInt8>.size))
    ipfsIdData.append(pubKeyHash)
    return BTCBase58StringWithData(ipfsIdData)
  }
}
