//
//  String+Extension.swift
//  token
//
//  Created by James Chen on 2016/10/05.
//  Copyright © 2016 imToken PTE. LTD. All rights reserved.
//

import Foundation

public extension String {
  var tk_isDigits: Bool {
    let regex = "^[0-9]+$"
    let predicate = NSPredicate(format: "SELF MATCHES %@", regex)
    return predicate.evaluate(with: self)
  }

  func tk_substring(from: Int) -> String {
    return String(dropFirst(from))
  }

  func tk_substring(to: Int) -> String {
    return String(dropLast(count - to))
  }

  func lpad(width: Int, with: String) -> String {
    let len = lengthOfBytes(using: .utf8)

    if len >= width {
      return self
    } else {
      return "".padding(toLength: (width - len), withPad: with, startingAt: 0) + self
    }
  }

  func keccak256() -> String {
    return Encryptor.Keccak256().encrypt(data: data(using: .utf8)!)
  }

  func add0xIfNeeded() -> String {
    return Hex.addPrefix(self)
  }

  func removePrefix0xIfNeeded() -> String {
    return Hex.removePrefix(self)
  }

  public func tk_tidyMnemonic() -> String {
    return self.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
      .trimmingCharacters(in: .whitespaces)
  }

  func tk_toJSON() throws -> JSONObject {
    let jsonObject: JSONObject
    do {
      let data = self.data(using: .utf8)!
      jsonObject = try JSONSerialization.jsonObject(with: data) as! JSONObject
    } catch {
      throw KeystoreError.invalid
    }
    return jsonObject
  }
}
