//
//  PasswordValidator.swift
//  token
//
//  Created by James Chen on 2016/12/21.
//  Copyright © 2016 imToken PTE. LTD. All rights reserved.
//

import Foundation

public class PasswordValidator: Validator {
  public typealias Result = String
  private let password: String
  private let formatRegex = "^.{8,}$"

  public init(_ password: String) {
    self.password = password
  }

  public init(_ map: [AnyHashable: Any]) throws {
    guard let password = map["password"] as? String else {
      throw GenericError.paramError
    }
    self.password = password
  }

  private var isEmpty: Bool {
    return password.isEmpty
  }

  var isFormatValid: Bool {
    let predicate = NSPredicate(format: "SELF MATCHES %@", formatRegex)
    return predicate.evaluate(with: password)
  }

  public var isValid: Bool {
    return !isEmpty && isFormatValid
  }

  public func validate() throws -> Result {
    if isEmpty {
      throw PasswordError.blank
    }

    if !isFormatValid {
      throw PasswordError.weak
    }

    return password
  }
}
