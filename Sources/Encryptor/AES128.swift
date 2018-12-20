//
//  AES128.swift
//  token
//
//  Created by James Chen on 2016/10/25.
//  Copyright © 2016 imToken PTE. LTD. All rights reserved.
//

import Foundation
import CryptoSwift

extension Encryptor {
  class AES128 {
    // swiftlint:disable nesting
    enum Mode {
      case ctr
      case cbc
    }

    private let key: String
    private let iv: String
    private let mode: Mode
    private let padding: Padding

    // Key and iv both should be in hex format
    init(key: String, iv: String, mode: Mode = .ctr, padding: Padding = .noPadding) {
      self.key = key
      self.iv = iv
      self.mode = mode
      self.padding = padding
    }

    func encrypt(string: String) -> String {
      return encrypt(hex: string.tk_toHexString())
    }

    // Encrypt input hex string and return encrypted string in hex format
    func encrypt(hex: String) -> String {
      if let aes = aes {
        let inputBytes = [UInt8].init(hex: hex)
        let encrypted = try! aes.encrypt(inputBytes)
        return Data(bytes: encrypted).tk_toHexString()
      } else {
        return ""
      }
    }

    // Decrypt input hex string and return decrypted string in hex format
    func decrypt(hex: String) -> String {
      if let aes = aes {
        let inputBytes = [UInt8].init(hex: hex)
        let decrypted = try! aes.decrypt(inputBytes)
        return Data(bytes: decrypted).tk_toHexString()
      } else {
        return ""
      }
    }

    private var aes: AES? {
      let keyBytes = [UInt8].init(hex: key)
      let ivBytes = [UInt8].init(hex: iv)

      return try? AES(key: keyBytes, blockMode: blockMode(iv: ivBytes), padding: self.padding)
    }

    private func blockMode(iv: [UInt8]) -> BlockMode {
      switch mode {
      case .cbc:
        return CBC(iv: iv)
      default:
        return CTR(iv: iv)
      }
    }
  }
}
