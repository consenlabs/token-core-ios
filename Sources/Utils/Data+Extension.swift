//
//  Data+Extension.swift
//  token
//
//  Created by James Chen on 2016/10/05.
//  Copyright © 2016 imToken PTE. LTD. All rights reserved.
//

import Foundation
import CryptoSwift

extension Data {
  public func tk_toHexString() -> String {
    return toHexString() // From CryptoSwift
  }

  func tk_hexToBitArray() -> [UInt] {
    var bits = [UInt]()
    let hex = tk_toHexString()

    for char in hex {
      let bin = Data.tk_hexCharToBinary(char: char)
      for bit in bin {
        //let c = String(format: "%C", String(bit))
        bits.append(UInt(String(bit))!)
      }
    }

    return bits
  }

  public static func tk_random(of length: Int) -> Data {
    var data = Data(count: length)
    data.withUnsafeMutableBytes { (bytes: UnsafeMutablePointer<UInt8>) -> Void in
      _ = SecRandomCopyBytes(kSecRandomDefault, length, bytes)
    }
    return data
  }

  /// Convert hex character to binary, if input is not a valid hex character, return "0000".
  static func tk_hexCharToBinary(char: Character) -> String {
    if let value = Int(String(char), radix: 16) {
      var bin = String(value, radix: 2)
      while bin.count < 4 {
        bin = "0" + bin
      }
      return bin
    } else {
      return "0000"
    }
  }

  func tk_bigEndian() -> Data {
    if CFByteOrderGetCurrent() ==  Int(CFByteOrderBigEndian.rawValue) {
      return self
    }
    return Data(bytes: Array(self.bytes.reversed()))
  }

  func tk_keccak256() -> String {
    return Encryptor.Keccak256().encrypt(data: self)
  }
}
