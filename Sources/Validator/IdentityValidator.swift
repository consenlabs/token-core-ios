//
//  IdentityValidator.swift
//  token
//
//  Created by xyz on 2018/1/6.
//  Copyright © 2018 ConsenLabs. All rights reserved.
//

import Foundation

public struct IdentityValidator: Validator {
  public typealias Result = Identity
  // some wallet api doesn't have identifier
  private let identifier: String?

  public init(_ identifier: String? = nil) {
    self.identifier = identifier
  }

  public var isValid: Bool {
    guard let identity = Identity.currentIdentity else {
      return false
    }
    if identifier != nil {
      return identity.identifier == identifier
    }
    return true
  }

  public func validate() throws -> Result {
    guard let identity = Identity.currentIdentity else {
      throw IdentityError.invalidIdentity
    }
    if identifier != nil && identity.identifier != identifier {
      throw IdentityError.invalidIdentity
    }
    return identity
  }
}
