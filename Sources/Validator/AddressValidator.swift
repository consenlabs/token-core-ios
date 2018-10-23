//
//  AddressValidator.swift
//  token
//
//  Created by James Chen on 2016/12/28.
//  Copyright © 2016 imToken PTE. LTD. All rights reserved.
//

import Foundation

public class AddressValidator: Validator {
  public typealias Result = String
  private let address: String
  private let formatRegex = "^(0x)?[0-9a-f]{40}$"

  public init(address: String) {
    self.address = address
  }

  var isFormatValid: Bool {
    let predicate = NSPredicate(format: "SELF MATCHES[c] %@", formatRegex)
    return predicate.evaluate(with: address)
  }

  var isChecksumValid: Bool {
    let address = Hex.removePrefix(self.address.lowercased())
    let hash = Encryptor.Keccak256().encrypt(hex: address.tk_toHexString())

    let checksumed = address.enumerated().map { (index, char) in
      let hashedValue = hash.tk_substring(from: index).tk_substring(to: 1)
      if Int(hashedValue, radix: 16)! >= 8 {
        return String(char).uppercased()
      } else {
        return String(char)
      }
    }.joined()

    return Hex.addPrefix(checksumed) == self.address
  }

  public var isValid: Bool {
    if !isFormatValid {
      return false
    }

    return sameCase || isChecksumValid
  }

  public func validate() throws -> Result {
    if !isValid {
      throw AddressError.invalid
    }
    return address
  }

  private var sameCase: Bool {
    let val = Hex.removePrefix(address)
    return val == val.lowercased() || val == val.uppercased()
  }
}
