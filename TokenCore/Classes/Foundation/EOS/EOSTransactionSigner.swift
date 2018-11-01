//
//  EOSTransactionSigner.swift
//  TokenCore
//
//  Created by xyz on 2018/5/26.
//  Copyright © 2018 ConsenLabs. All rights reserved.
//

import Foundation
import CoreBitcoin

class EOSTransactionSigner {
  private let txs: [EOSTransaction]
  private let keystore: Keystore
  private let password: String

  init(txs: [EOSTransaction], keystore: Keystore, password: String) {
    self.txs = txs
    self.keystore = keystore
    self.password = password
  }

  public func sign() throws -> [EOSSignResult] {
    guard keystore.verify(password: password) else {
      throw PasswordError.incorrect
    }

    return try txs.map { tx -> EOSSignResult in
      return try tx.sign(password: password, keystore: keystore)
    }
  }
}
