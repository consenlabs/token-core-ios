//
//  BTCTransaction.swift
//  token
//
//  Created by xyz on 2018/1/4.
//  Copyright © 2018 ConsenLabs. All rights reserved.
//

import Foundation
import CoreBitcoin

struct UTXO {
  let txHash: String
  let vout: Int
  let amount: Int64
  let address: String
  let scriptPubKey: String
  let derivedPath: String?
  let sequence: UInt32

  init(txHash: String, vout: Int, amount: Int64, address: String, scriptPubKey: String, derivedPath: String?, sequence: UInt32 = 4294967295) {
    self.txHash = txHash
    self.vout = vout
    self.amount = amount
    self.address = address
    self.scriptPubKey = scriptPubKey
    self.derivedPath = derivedPath
    self.sequence = sequence
  }

  init?(raw: [String: Any]) {
    guard let txHash = raw["txHash"] as? String,
      let vout = raw["vout"] as? Int,
      let amount = Int64(raw["amount"] as? String ?? "badamount"),
      let address = raw["address"] as? String,
      let scriptPubKey = raw["scriptPubKey"] as? String else {
      return nil
    }
    let derivedPath = raw["derivedPath"] as? String

    self.init(
      txHash: txHash,
      vout: vout,
      amount: amount,
      address: address,
      scriptPubKey: scriptPubKey,
      derivedPath: derivedPath
    )
  }
  

  static func parseFormBlockchain(_ raw: [String: Any], isTestNet: Bool, isSegWit: Bool) -> UTXO? {
    guard let txHash = raw["tx_hash_big_endian"] as? String,
    let vout = raw["tx_output_n"] as? Int,
    let amount = raw["value"] as? Int64,
      let scriptPubKey = raw["script"] as? String else {
        return nil
    }
//    let address = WalletManager.scriptToAddress(scriptPubKey, isTestNet: isTestNet, isSegWit: isSegWit)
    return self.init(
      txHash: txHash,
      vout: vout,
      amount: amount,
      address: "",
      scriptPubKey: scriptPubKey,
      derivedPath: nil
    )
  }
  
  
}

class BTCTransactionSigner {
  let utxos: [UTXO]
  let keys: [BTCKey]
  let amount: Int64
  let fee: Int64
  let toAddress: BTCAddress
  let changeAddress: BTCAddress
  let dustThreshold: Int64 = 2730

  init(utxos: [UTXO], keys: [BTCKey], amount: Int64, fee: Int64, toAddress: BTCAddress, changeAddress: BTCAddress) throws {
    guard amount >= dustThreshold else {
      throw GenericError.amountLessThanMinimum
    }

    self.utxos = utxos
    self.keys = keys
    self.amount = amount
    self.fee = fee
    self.toAddress = toAddress
    self.changeAddress = changeAddress
  }

  func sign() throws -> TransactionSignedResult {
    let rawTx = BTCTransaction()

    let totalAmount = rawTx.calculateTotalSpend(utxos: utxos)
    if totalAmount < amount {
      throw GenericError.insufficientFunds
    }

    rawTx.addInputs(from: utxos)

    rawTx.addOutput(BTCTransactionOutput(value: amount, address: toAddress))

    let changeAmount = totalAmount - amount - fee
    if changeAmount >= dustThreshold {
        rawTx.addOutput(BTCTransactionOutput(value: changeAmount, address: changeAddress))
    }

    try rawTx.sign(with: keys, isSegWit: false)

    let signedTx = rawTx.hex!
    let txHash = rawTx.transactionID!
    return TransactionSignedResult(signedTx: signedTx, txHash: txHash)
  }

  func signSegWit() throws -> TransactionSignedResult {
    let rawTx = BTCTransaction()
    rawTx.version = 2

    let totalAmount = rawTx.calculateTotalSpend(utxos: utxos)
    if totalAmount < amount {
      throw GenericError.insufficientFunds
    }

    rawTx.addInputs(from: utxos, isSegWit: true)

    rawTx.addOutput(BTCTransactionOutput(value: amount, address: toAddress))

    let changeAmount = rawTx.calculateTotalSpend(utxos: utxos) - amount - fee
    if changeAmount >= dustThreshold {
      rawTx.addOutput(BTCTransactionOutput(value: changeAmount, address: changeAddress))
    }

    try rawTx.sign(with: keys, isSegWit: true)

    let signedTx = rawTx.hexWithWitness!
    let txHash = rawTx.transactionID!
    let wtxID = rawTx.witnessTransactionID!
    return TransactionSignedResult(signedTx: signedTx, txHash: txHash, wtxID: wtxID)
  }

}
