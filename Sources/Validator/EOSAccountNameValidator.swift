//
//  EOSAccountNameValidator.swift
//  TokenCore
//
//  Created by James Chen on 2018/07/04.
//  Copyright © 2018 ConsenLabs. All rights reserved.
//

import Foundation

struct EOSAccountNameValidator: Validator {
  typealias Result = String
  private let formatRegex = "^[1-5a-z.]{1,12}$"

  private let accountName: String

  init(_ accountName: String) {
    self.accountName = accountName
  }

  var isValid: Bool {
    if accountName.isEmpty {
      return true
    }

    let predicate = NSPredicate(format: "SELF MATCHES %@", formatRegex)
    return predicate.evaluate(with: accountName)
  }

  func validate() throws -> Result {
    if isValid {
      return accountName
    }

    throw EOSError.accountNameInvalid
  }
}
