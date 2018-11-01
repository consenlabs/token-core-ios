//
//  Keccak256.swift
//  token
//
//  Created by James Chen on 2016/10/26.
//  Copyright © 2016 imToken PTE. LTD. All rights reserved.
//

import Foundation
import CryptoSwift

public extension Encryptor {
  public class Keccak256 {
    public init() {}

    // Encrypt and return as hex
    public func encrypt(hex: String) -> String {
      return encrypt(data: hex.tk_dataFromHexString()!)
    }

    public func encrypt(data: Data) -> String {
      return SHA3(variant: .keccak256).calculate(for: data.bytes).toHexString()
    }
  }
}
