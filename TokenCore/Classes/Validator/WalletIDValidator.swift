//
//  WalletIDValidator.swift
//  TokenCoreTests
//
//  Created by James Chen on 2018/05/24.
//  Copyright © 2018 ConsenLabs. All rights reserved.
//

import Foundation

public class WalletIDValidator: Validator {
  typealias Result = WalletID
  private let walletID: WalletID
  private let formatRegex = "^[a-f0-9]{8}-[a-f0-9]{4}-4[a-f0-9]{3}-[89ab][a-f0-9]{3}-[a-f0-9]{12}$"

  public init(walletID: WalletID) {
    self.walletID = walletID
  }

  /// A valid ID is lower case UUID.
  public var isValid: Bool {
    let predicate = NSPredicate(format: "SELF MATCHES %@", formatRegex)
    return predicate.evaluate(with: walletID)
  }

  func validate() throws -> WalletID {
    if !isValid {
      throw GenericError.paramError
    }
    return walletID
  }
}
