//
//  BTCTransaction.swift
//  TokenCore
//
//  Created by James Chen on 2018/05/17.
//  Copyright © 2018 ConsenLabs. All rights reserved.
//

import Foundation
import CoreBitcoin

extension BTCTransaction {
  func addInputs(from utxos: [UTXO], isSegWit: Bool = false) {
    for utxo in utxos {
      let input: BTCTransactionInput
      if isSegWit {
        input = SegWitInput()
      } else {
        input = BTCTransactionInput()
      }

      input.previousHash = BTCReversedData(BTCDataFromHex(utxo.txHash))
      input.previousIndex = UInt32(utxo.vout)
      input.signatureScript = BTCScript(hex: utxo.scriptPubKey)
      input.sequence = utxo.sequence
      input.value = utxo.amount

      addInput(input)
    }
  }

  func sign(with privateKeys: [BTCKey], isSegWit: Bool) throws {
    for (index, ele) in inputs.enumerated() {
      let input = ele as! BTCTransactionInput
      let key = privateKeys[index]
      if isSegWit {
        let scriptCode = BTCScript(hex: "1976a914\((BTCHash160(key.publicKey as Data) as Data).toHexString())88ac")
        let sigHash = try signatureHash(for: scriptCode, forSegWit: isSegWit, inputIndex: UInt32(index), hashType: .BTCSignatureHashTypeAll)
        let signature = key.signature(forHash: sigHash, hashType: .BTCSignatureHashTypeAll)
        input.witnessData = BTCScript()!.appendData(signature).appendData(key.publicKey as Data)
        input.signatureScript = BTCScript()!.append(key.witnessRedeemScript)
      } else {
        let sigHash = try signatureHash(for: input.signatureScript, forSegWit: isSegWit, inputIndex: UInt32(index), hashType: .BTCSignatureHashTypeAll)
        let signature = key.signature(forHash: sigHash, hashType: .BTCSignatureHashTypeAll)
        input.signatureScript = BTCScript()!.appendData(signature).appendData(key.publicKey as Data)
      }
    }
  }

  func calculateTotalSpend(utxos: [UTXO]) -> Int64 {
    return utxos.map { $0.amount }.reduce(0, +)
  }
}

class SegWitInput: BTCTransactionInput {
  override var data: Data! {
    let payload = NSMutableData()

    payload.append(previousHash)
    payload.append(&previousIndex, length: 4)

    if isCoinbase {
      payload.append(BTCProtocolSerialization.data(forVarInt: UInt64(coinbaseData.count)))
      payload.append(coinbaseData)
    } else {
      payload.append(BTCProtocolSerialization.data(forVarInt: 23))
      payload.append(BTCProtocolSerialization.data(forVarInt: 22))
      payload.append(signatureScript.data)
    }

    payload.append(&sequence, length: 4)

    return payload as Data
  }
}
