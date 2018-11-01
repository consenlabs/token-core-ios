//
//  Mnemonic.swift
//  token
//
//  Created by James Chen on 2016/10/31.
//  Copyright © 2016 imToken PTE. LTD. All rights reserved.
//

import Foundation
import CommonCrypto

public typealias Mnemonic = String
public typealias MnemonicSeed = String // Hex encoded seed

// Implimentation of BIP-39 style mnemonic codes for use with generating deterministic keys.
// https://github.com/bitcoin/bips/blob/master/bip-0039.mediawiki
class ETHMnemonic {
  let mnemonic: Mnemonic
  let seed: MnemonicSeed

  // Create a random mnemonic
  convenience init() {
    self.init(seed: try! ETHMnemonic.generateSeed(strength: 128))
  }

  init(mnemonic: Mnemonic, passphrase: String) {
    self.mnemonic = mnemonic
    seed = ETHMnemonic.deterministicSeed(from: mnemonic, passphrase: passphrase)
  }

  init(seed: MnemonicSeed) {
    mnemonic = ETHMnemonic.generate(from: seed)
    self.seed = seed
  }
}

extension ETHMnemonic {
  class func generate(from seed: MnemonicSeed) -> Mnemonic {
    let seedData = seed.tk_dataFromHexString()!
    var hash = Data(count: Int(CC_SHA256_DIGEST_LENGTH))
    hash.withUnsafeMutableBytes { (bytes: UnsafeMutablePointer<UInt8>) -> Void in
      CC_SHA256(seedData.bytes, CC_LONG(seedData.count), bytes)
    }

    let checksumBits = hash.tk_hexToBitArray()
    var seedBits = seedData.tk_hexToBitArray()

    // Append the appropriate checksum bits to the seed
    for i in 0 ..< seedBits.count / 32 {
      seedBits.append(checksumBits[i])
    }

    let dictionary = MnemonicDictionary.dictionary

    // Split into groups of 11, and change to numbers
    var words = [String]()
    for i in 0 ..< seedBits.count / 11 {
      let subBits = (seedBits[i * 11 ..< i * 11 + 11]).map { String($0) }
      let index = strtol(subBits.joined(separator: ""), nil, 2)
      words.append(dictionary[index])
    }

    return words.joined(separator: " ")
  }

  // To create a binary seed from the mnemonic, use the PBKDF2 function with a mnemonic sentence (in UTF-8 NFKD)
  // used as the password and the string "mnemonic" + passphrase (again in UTF-8 NFKD) used as the salt.
  // The iteration count is set to 2048 and HMAC-SHA512 is used as the pseudo-random function. The length
  // of the derived key is 512 bits (= 64 bytes).
  class func deterministicSeed(from mnemonic: Mnemonic, passphrase: String = "") -> MnemonicSeed {
    let data = mnemonic.data(using: .ascii, allowLossyConversion: true)!
    let dataString = String(data: data, encoding: .ascii)!

    let normalizedPassphrase = String(data: passphrase.data(using: .ascii, allowLossyConversion: true)!, encoding: .ascii)!
    let salt = ("mnemonic" + normalizedPassphrase).data(using: .ascii, allowLossyConversion: false)!

    let derivedKeyLen = Int(CC_SHA512_DIGEST_LENGTH)
    var derivedKey = Data(count: derivedKeyLen)
    derivedKey.withUnsafeMutableBytes { (bytes: UnsafeMutablePointer<UInt8>) -> Void in
      CCKeyDerivationPBKDF(
        UInt32(kCCPBKDF2),
        dataString,
        dataString.count,
        salt.bytes,
        salt.count,
        UInt32(kCCPRFHmacAlgSHA512),
        2048,
        bytes,
        derivedKeyLen
      )
    }

    return derivedKey.tk_toHexString()
  }

  // Strength: divisible by 32
  class func generateSeed(strength: Int) throws -> MnemonicSeed {
    guard strength % 32 == 0 else {
      throw MnemonicError.lengthInvalid
    }

    let data = Data.tk_random(of: strength / 8)
    return data.tk_toHexString()
  }
}
