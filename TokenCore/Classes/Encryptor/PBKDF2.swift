//
//  PBKDF2.swift
//  token
//
//  Created by James Chen on 2016/10/25.
//  Copyright © 2016 imToken PTE. LTD. All rights reserved.
//

import Foundation
import CryptoSwift

extension Encryptor {
    class PBKDF2 {
      private let password: String
      private let salt: String
      private let iterations: Int
      private let keyLength: Int

      // Param password and salt salt should be in hex format.
      init(password: String, salt: String, iterations: Int, keyLength: Int = 32) {
        self.password = password
        self.salt = salt
        self.iterations = iterations
        self.keyLength = keyLength
      }

      // Encrypt input string and return encrypted string in hex format.
      func encrypt() -> String {
        let saltBytes = [UInt8](hex: salt)
        let passwordBytes = password.data(using: .utf8)!.bytes
        if let pbkdf2 = try? PKCS5.PBKDF2(password: passwordBytes, salt: saltBytes, iterations: iterations, keyLength: keyLength) {
          if let encrypted = try? pbkdf2.calculate() {
            return Data(bytes: encrypted).tk_toHexString()
          }
        }

        return ""
      }
  }
}
