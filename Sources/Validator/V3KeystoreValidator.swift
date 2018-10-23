//
//  KeystoreValidator.swift
//  token
//
//  Created by xyz on 2017/12/30.
//  Copyright © 2017 ConsenLabs. All rights reserved.
//

import Foundation

public struct V3KeystoreValidator: Validator {
  public typealias Result = JSONObject
  private let keystore: JSONObject
  public init(_ keystore: JSONObject) {
    self.keystore = keystore
  }

  public var isValid: Bool {
    guard
      (keystore["crypto"] as? JSONObject) != nil || (keystore["Crypto"] as? JSONObject) != nil,
      (keystore["version"] as? Int) == 3,
      let address = keystore["address"] as? String, address != ""
      else {
        return false
    }
    return true
  }

  public func validate() throws -> Result {
    if !isValid {
      throw KeystoreError.invalid
    }
    return keystore
  }
}
