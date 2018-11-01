//
//  Crypto.swift
//  token
//
//  Created by Kai Chen on 22/09/2017.
//  Copyright © 2017 ConsenLabs. All rights reserved.
//

import Foundation

protocol Kdfparams {
  init(json: JSONObject) throws
  func toJSON() -> JSONObject
  func derivedKey(for password: String) -> String
}

// Version 3 of the Web3 Secret Storage Definition
// https://github.com/ethereum/wiki/wiki/Web3-Secret-Storage-Definition
public class Crypto {
  enum Cipher: String {
    case aes128Ctr = "aes-128-ctr" // AES-128-CTR is the minimal requirement
    case aes128Cbc = "aes-128-cbc" // Version 1 fixed algorithm
  }

  enum Kdf: String {
    case scrypt, pbkdf2
  }

  let cipher: Cipher
  let ciphertext: String
  let cipherparams: Cipherparams
  let kdf: Kdf
  let kdfparams: Kdfparams // KDF-dependent static and dynamic parameters to the KDF function
  let mac: String // SHA3 (keccak-256) of the concatenation of the last 16 bytes of the derived key together with the full ciphertext

  private var cachedDerivedKey = CachedDerivedKey(hashedPassword: "", derivedKey: "")

  /**
   Create an Crypto instance.
   - Parameters:
     - password: Password to encrypt private key.
     - privateKey: Private key.
     - cacheDerivedKey: Specify whether the crypto should cache derived key to avoid calling KDF function multiple times.
         If true, the caller can fetch derived key with `cachedDerivedKey(with password:)`,
         and should explictly call `clearDerivedKey()` afterwards.
   */
  init(password: String, privateKey: String, cacheDerivedKey: Bool = false) {
    cipher = .aes128Ctr
    cipherparams = Cipherparams()
    kdf = .scrypt
    kdfparams = ScryptKdfparams(salt: nil)

    let derivedKey = kdfparams.derivedKey(for: password)
    if cacheDerivedKey {
      cachedDerivedKey.cache(password: password, derivedKey: derivedKey)
    }
    ciphertext = Encryptor.AES128(key: derivedKey.tk_substring(to: 32), iv: cipherparams.iv, mode: Crypto.aesMode(cipher: cipher)).encrypt(hex: privateKey)
    let macHex = derivedKey.tk_substring(from: 32) + ciphertext
    mac = Encryptor.Keccak256().encrypt(hex: macHex)
  }

  init(json: JSONObject) throws {
    guard let ciphertext = json["ciphertext"] as? String,
      let cipherparamsJson = json["cipherparams"] as? JSONObject,
      let kdfparamsJson = json["kdfparams"] as? JSONObject,
      let mac = json["mac"] as? String,
      let cipherStr = json["cipher"] as? String,
      let kdfStr = json["kdf"] as? String
    else {
      throw KeystoreError.invalid
    }

    guard let cipher = Cipher(rawValue: cipherStr.lowercased()) else {
      throw KeystoreError.cipherUnsupported
    }

    guard let kdf = Kdf(rawValue: kdfStr.lowercased()) else {
      throw KeystoreError.kdfUnsupported
    }

    let kdfparamsClass: Kdfparams.Type = kdf == .scrypt ? ScryptKdfparams.self : PBKDF2Kdfparams.self

    self.cipher = cipher
    self.ciphertext = ciphertext
    cipherparams = try Cipherparams(json: cipherparamsJson)
    self.kdf = kdf
    kdfparams = try kdfparamsClass.init(json: kdfparamsJson)
    self.mac = mac
  }

  func toJSON() -> JSONObject {
    return [
      "cipher": cipher.rawValue,
      "ciphertext": ciphertext,
      "cipherparams": cipherparams.toJSON(),
      "kdf": kdf.rawValue,
      "kdfparams": kdfparams.toJSON(),
      "mac": mac
    ]
  }
}

// MARK: Cache derivedKey
private extension Crypto {
  struct CachedDerivedKey {
    var hashedPassword: String
    var derivedKey: String

    mutating func cache(password: String, derivedKey: String) {
      hashedPassword = hash(password: password)
      self.derivedKey = derivedKey
    }

    mutating func clear() {
      hashedPassword = ""
      derivedKey = ""
    }

    func fetch(password: String) -> String? {
      if hash(password: password) == hashedPassword {
        return derivedKey
      }
      return nil
    }

    private func hash(password: String) -> String {
      return password.sha256().sha256()
    }
  }
}

// MARK: Public API
extension Crypto {
  // Derive key with password
  func derivedKey(with password: String) -> String {
    return kdfparams.derivedKey(for: password)
  }

  func cachedDerivedKey(with password: String) -> String {
    if let cached = cachedDerivedKey.fetch(password: password) {
      return cached
    } else {
      let key = derivedKey(with: password)
      cachedDerivedKey.cache(password: password, derivedKey: key)
      return key
    }
  }

  func clearDerivedKey() {
    cachedDerivedKey.clear()
  }

  // Create encryptor with key and nonce
  func encryptor(from key: String, nonce: String, AESMode: Encryptor.AES128.Mode? = nil) -> Encryptor.AES128 {
    let mode = AESMode ?? Crypto.aesMode(cipher: .aes128Ctr)
    return Encryptor.AES128(key: key, iv: nonce, mode: mode)
  }
}

// MARK: Functional API
extension Crypto {
  // ciphertext -> private key
  func privateKey(password: String) -> String {
    let cipherKey = derivedKey(with: password).tk_substring(to: 32)
    return Encryptor.AES128(key: cipherKey, iv: cipherparams.iv, mode: aesMode()).decrypt(hex: ciphertext)
  }

  func macFrom(password: String) -> String {
    return macForDerivedKey(key: derivedKey(with: password))
  }

  func macForDerivedKey(key: String) -> String {
    let cipherKey = key.tk_substring(from: 32)
    let macHex = cipherKey + ciphertext
    return Encryptor.Keccak256().encrypt(hex: macHex)
  }

  static func aesMode(cipher: Cipher) -> Encryptor.AES128.Mode {
    switch cipher {
    case .aes128Cbc:
      return .cbc
    default:
      return .ctr
    }
  }

  func aesMode() -> Encryptor.AES128.Mode {
    return Crypto.aesMode(cipher: cipher)
  }
}

// MARK: KDF
extension Crypto {
  struct Cipherparams {
    let iv: String // 128-bit initialisation vector for the cipher.

    init() {
      iv = Data.tk_random(of: 16).tk_toHexString()
    }

    init(json: JSONObject) throws {
      iv = (json["iv"] as? String) ?? ""
    }

    func toJSON() -> JSONObject {
      return ["iv": iv]
    }
  }

  // https://en.wikipedia.org/wiki/PBKDF2
  struct PBKDF2Kdfparams: Kdfparams {
    let c: Int // number of iterations
    let dklen: Int // length for the derived key. Must be >= 32
    let prf: String // a pseudorandom function of two parameters with output length hLen (e.g. a keyed HMAC)
    let salt: String // salt passed to PBKDF

    init(json: JSONObject) throws {
      guard let c = json["c"] as? Int,
        let dklen = json["dklen"] as? Int,
        let prf = json["prf"] as? String,
        let salt = json["salt"] as? String
      else {
        throw KeystoreError.kdfParamsInvalid
      }

      if c <= 0 {
        throw KeystoreError.kdfParamsInvalid
      }
      self.c = c

      if dklen < 32 {
        throw KeystoreError.kdfParamsInvalid
      }
      self.dklen = dklen

      if prf.lowercased() != "hmac-sha256" {
        throw KeystoreError.prfUnsupported
      }
      self.prf = prf.lowercased()

      if salt.isEmpty {
        throw KeystoreError.kdfParamsInvalid
      }
      self.salt = salt
    }

    func toJSON() -> JSONObject {
      return [
        "c": c,
        "dklen": dklen,
        "prf": prf,
        "salt": salt
      ]
    }

    func derivedKey(for password: String) -> String {
      return Encryptor.PBKDF2(password: password, salt: salt, iterations: c, keyLength: dklen).encrypt()
    }
  }

  // https://en.wikipedia.org/wiki/Scrypt
  public struct ScryptKdfparams: Kdfparams {
    let dklen: Int // Intended output length in octets of the derived key; a positive integer satisfying dkLen ≤ (232− 1) * hLen.
    let n: Int // CPU/memory cost parameter.
    let r: Int // RAM cost
    let p: Int // CPU cost
    let salt: String

    public static var defaultN = 262144

    init(salt: String?) {
      dklen = 32
      n = ScryptKdfparams.defaultN
      r = 8
      p = 1
      self.salt = salt ?? Data.tk_random(of: 32).tk_toHexString()
    }

    init(json: JSONObject) throws {
      guard let dklen = json["dklen"] as? Int,
        let n = json["n"] as? Int,
        let r = json["r"] as? Int,
        let p = json["p"] as? Int,
        let salt = json["salt"] as? String
      else {
        throw KeystoreError.kdfParamsInvalid
      }

      if dklen != 32 || n <= 0 || r <= 0 || p <= 0 || salt.isEmpty {
        throw KeystoreError.kdfParamsInvalid
      }

      self.dklen = dklen
      self.n = n
      self.r = r
      self.p = p
      self.salt = salt
    }

    func toJSON() -> JSONObject {
      return [
        "dklen": dklen,
        "n": n,
        "r": r,
        "p": p,
        "salt": salt
      ]
    }

    func derivedKey(for password: String) -> String {
      return Encryptor.Scrypt(password: password, salt: salt, n: n, r: r, p: p).encrypt()
    }
  }
}
