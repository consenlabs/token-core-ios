//
//  TransactionSignedResult.swift
//  token
//
//  Created by xyz on 2018/1/22.
//  Copyright © 2018 ConsenLabs. All rights reserved.
//

import Foundation

public struct TransactionSignedResult {
  public let signedTx: String
  public let txHash: String
  public let wtxID: String

  init(signedTx: String, txHash: String, wtxID: String) {
    self.signedTx = signedTx
    self.txHash = txHash
    self.wtxID = wtxID
  }

  init(signedTx: String, txHash: String) {
    self.init(signedTx: signedTx, txHash: txHash, wtxID: "")
  }
}
