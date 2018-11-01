//
//  Scrypt.swift
//  token
//
//  Created by James Chen on 2016/10/25.
//  Copyright © 2016 imToken PTE. LTD. All rights reserved.
//

import Foundation
import libscrypt

extension Encryptor {
  class Scrypt {
    private let password: String
    private let salt: String
    private let n: Int
    private let r: Int
    private let p: Int
    private let dklen = 32

    // Param: password and salt should be in hex format.
    init(password: String, salt: String, n: Int, r: Int, p: Int) {
      self.password = password
      self.salt = salt
      self.n = n
      self.r = r
      self.p = p
    }

    func encrypt() -> String {
      let passwordBytes = password.data(using: .utf8)!.bytes
      let saltBytes = salt.tk_dataFromHexString()!.bytes

      var data = Data(count: dklen)
      data.withUnsafeMutableBytes { (bytes: UnsafeMutablePointer<UInt8>) -> Void in
        libscrypt_scrypt(
          passwordBytes,
          passwordBytes.count,
          saltBytes,
          saltBytes.count,
          UInt64(n),
          UInt32(r),
          UInt32(p),
          bytes,
          dklen
        )
      }
      return data.tk_toHexString()
    }
  }
}
