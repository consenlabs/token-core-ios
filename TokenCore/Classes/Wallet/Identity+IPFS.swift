//
//  Identity+IPFS.swift
//  TokenCore
//
//  Created by James Chen on 2018/07/06.
//  Copyright © 2018 ConsenLabs. All rights reserved.
//

import Foundation
import CoreBitcoin

// Encrypt data
public extension Identity {
  func encryptDataToIpfs(content: String) -> String? {
    let contentBytes = content.data(using: .utf8)!
    let iv = Encryptor.Hash.hmacSHA256(key: keystore.encKey.tk_dataFromHexString()!, data: contentBytes).subdata(in: 0..<16)

    return encryptDataToIpfs(content: content, iv: iv, timestamp: Date().timeIntervalSince1970)
  }

  func encryptDataToIpfs(content: String, iv: Data, timestamp: TimeInterval) -> String? {
    // BackupPayload = VersionByte || Timestamp || IV || CiphertextLength || Ciphertext || SignatureLength || Signature
    var toSign = Data() // VersionByte || Timestamp || IV || MerkleRoot

    var version: UInt8 = 3
    toSign.append(Data(bytes: &version, count: MemoryLayout<UInt8>.size))

    let timestampInt = UInt32(timestamp)
    var timestampData = CFSwapInt32HostToLittle(timestampInt)
    toSign.append(Data(bytes: &timestampData, count: MemoryLayout<UInt32>.size))

    let contentBytes = content.data(using: .utf8)!
    toSign.append(iv)

    let cipherText = Encryptor.AES128(key: keystore.encKey.tk_substring(to: 32), iv: iv.tk_toHexString(), mode: .cbc, padding: .pkcs5).encrypt(hex: contentBytes.toHexString())
    let cipherData = cipherText.tk_dataFromHexString()!
    toSign.append(Encryptor.Hash.merkleRoot(cipherData: cipherData))

    let signature = signIPFSHeader(toSign)

    var result = Data()
    result.append(Data(bytes: &version, count: MemoryLayout<UInt8>.size))
    result.append(Data(bytes: &timestampData, count: MemoryLayout<UInt32>.size))
    result.append(iv)

    result.append(BTCProtocolSerialization.data(forVarString: cipherData))
    result.append(signature)

    return result.tk_toHexString()
  }

  func decryptDataFromIpfs(payload: String) throws -> String {
    let encryptedData =  payload.tk_dataFromHexString()!
    var pos = 0
    guard encryptedData[0] == 3 else {
      throw IdentityError.unsupportEncryptionDataVersion
    }
    pos += 1

    let timestampData = encryptedData[1..<pos+MemoryLayout<UInt32>.size]
    _ = timestampData.withUnsafeBytes { (ptr: UnsafePointer<UInt32>) -> UInt32 in
      return ptr.pointee
    }

    pos += 4

    let iv = encryptedData[pos..<pos+16]
    pos += 16

    var toSign = encryptedData[0..<pos]

    var ciphertextLength = 0
    let ciphertext = BTCProtocolSerialization.readVarString(from: encryptedData[pos..<encryptedData.count], readBytes: &ciphertextLength)!
    pos += ciphertextLength
    let signature = encryptedData[pos..<encryptedData.count]

    toSign.append(Encryptor.Hash.merkleRoot(cipherData: ciphertext))

    let ipfsId = try recoverIPFSID(signature: signature.tk_toHexString(), data: toSign)

    if keystore.ipfsId != ipfsId {
      throw IdentityError.invalidEncryptionDataSignature
    }

    guard
      let decryptedData = Encryptor.AES128(key: keystore.encKey.tk_substring(to: 32), iv: iv.tk_toHexString(), mode: .cbc, padding: .pkcs5)
        .decrypt(hex: ciphertext.toHexString()).tk_dataFromHexString(),
      let message = String(data: decryptedData, encoding: .utf8)
      else {
        return ""
    }

    return message
  }

  private func recoverIPFSID(signature: String, data: Data)throws -> String {
    let (sig, recId) = try SigUtil.unpackSig(sig: signature.removePrefix0xIfNeeded())

    let pubkey = SigUtil.ecrecover(signature: sig, recid: recId, forHash: data.tk_keccak256())
    return SigUtil.calcIPFSIDFromKey(BTCKey(publicKey: pubkey?.tk_dataFromHexString()))
  }

  func signAuthenticationMessage(accessTime: Int, deviceToken: String, encryptedBy password: String) throws -> String {
    guard keystore.verify(password: password) else {
      throw PasswordError.incorrect
    }
    let prvKeyHex = keystore.encAuthKey.decrypt(crypto: keystore.crypto, password: password)

    let message = "\(accessTime).\(identifier).\(deviceToken)"
    let ecsignature = SigUtil.ecsign(with: prvKeyHex, data: message.keccak256())
    let v = ecsignature["v"] as! Int32
    let r = ecsignature["r"] as! String
    let s = ecsignature["s"] as! String
    let hex = SigUtil.concatSig(v: v, r: r, s: s)

    return hex
  }

  private func signIPFSHeader(_ data: Data) -> Data {
    let ecsignature = SigUtil.ecsign(with: keystore.encKey, data: data.tk_keccak256())
    let v = ecsignature["v"] as! Int32
    let r = ecsignature["r"] as! String
    let s = ecsignature["s"] as! String
    let hex = SigUtil.concatSig(v: v, r: r, s: s)
    return hex.tk_dataFromHexString()!
  }
}
