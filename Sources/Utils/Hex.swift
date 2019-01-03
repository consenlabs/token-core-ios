//
//  Hex.swift
//  token
//
//  Created by James Chen on 2016/11/03.
//  Copyright © 2016 imToken PTE. LTD. All rights reserved.
//

import Foundation

public final class Hex {
  private static let prefix = "0x"

  // The values refer to individual bytes, so the legal value range is between 0x00 and 0xFF (hex) or 0 and 255 (decimal).
  static func toBytes(_ hex: String) -> [UInt8] {
    let normalized = normalize(hex)

    var bytes = [UInt8]()
    let length = normalized.count

    for i in stride(from: 0, to: length, by: 2) {
      let num = normalized.tk_substring(from: i).tk_substring(to: 2)
      bytes.append(UInt8(num, radix: 16) ?? 0)
    }

    return bytes
  }

  static func hex(from bytes: [UInt8]) -> String {
    return Data(bytes: bytes).tk_toHexString()
  }

  static func removePrefix(_ hex: String) -> String {
    if hasPrefix(hex) {
      return hex.tk_substring(from: 2)
    } else {
      return hex
    }
  }

  static func addPrefix(_ hex: String) -> String {
    if hasPrefix(hex) {
      return hex
    } else {
      return prefix + hex
    }
  }

  static func hasPrefix(_ string: String) -> Bool {
    return string.hasPrefix(prefix)
  }

  static func isHex(_ string: String) -> Bool {
    if hasPrefix(string) {
      return isHex(string.tk_substring(from: 2))
    }

    if string.count % 2 != 0 {
      return false
    }
    
    let regex = "^[A-Fa-f0-9]+$"
    let predicate = NSPredicate(format: "SELF MATCHES %@", regex)
    return predicate.evaluate(with: string)
  }

  // Add '0' to left if length is not even
  static func pad(_ hex: String) -> String {
    if hex.count % 2 == 1 {
      return "0" + hex
    } else {
      return hex
    }
  }

  static func normalize(_ hex: String) -> String {
    return pad(removePrefix(hex))
  }
}

public extension String {
  public func tk_toHexString() -> String {
    return data(using: .utf8)!.tk_toHexString()
  }

  func tk_fromHexString() -> String {
    if Hex.hasPrefix(self) {
      return tk_substring(from: 2).tk_fromHexString()
    }

    let bytes = [UInt8](hex: self)
    return String(bytes: bytes, encoding: .ascii)!
  }

  func tk_dataFromHexString() -> Data? {
    if Hex.hasPrefix(self) {
      return tk_substring(from: 2).tk_dataFromHexString()
    }

    let length = count

    if length % 2 == 1 {
      return ("0" + self).tk_dataFromHexString()
    }

    if isEmpty {
      return Data()
    }

    if !Hex.isHex(self) {
      return nil
    }

    guard let chars = cString(using: .utf8) else { return nil}

    guard let data = NSMutableData(capacity: length / 2) else { return nil }
    var byteChars: [CChar] = [0, 0, 0]
    var wholeByte: CUnsignedLong = 0

    for i in stride(from: 0, to: length, by: 2) {
      byteChars[0] = chars[i]
      byteChars[1] = chars[i + 1]
      wholeByte = strtoul(byteChars, nil, 16)
      data.append(&wholeByte, length: 1)
    }

    return data as Data
  }

  func tk_isHex() -> Bool {
    return Hex.isHex(self)
  }
  
  func tk_data() -> Data? {
    var dataBytes: Data?
    if self.tk_isHex() {
      dataBytes = self.tk_dataFromHexString()
    } else {
      dataBytes = self.data(using: .utf8)
    }
    return dataBytes
  }
}
