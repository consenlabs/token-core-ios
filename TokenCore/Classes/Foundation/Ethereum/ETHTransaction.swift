//
//  Transaction.swift
//  token
//
//  Created by James Chen on 2016/11/03.
//  Copyright © 2016 imToken PTE. LTD. All rights reserved.
//

import Foundation

public final class ETHTransaction: NSObject {
  private var raw: [String: String]
  private var chainID: Int
  let nonce, gasPrice, gasLimit, to, value, data: String
  var v, r, s: String

  /**
   Construct a transaction with raw data
   - Parameters:
   - raw: Raw data
   - chainID: Chain ID, 1 by default after [EIP 155](https://github.com/ethereum/EIPs/issues/155) fork.
   */
  public init(raw: [String: String], chainID: Int) {
    self.raw = raw
    self.chainID = chainID

    // Make sure every property at least has empty string value
    nonce       = ETHTransaction.parse(raw, "nonce")
    gasPrice    = ETHTransaction.parse(raw, "gasPrice")
    gasLimit    = ETHTransaction.parse(raw, "gasLimit")
    to          = ETHTransaction.parse(raw, "to")
    value       = ETHTransaction.parse(raw, "value")
    data        = ETHTransaction.parse(raw, "data")
    v           = ETHTransaction.parse(raw, "v")
    r           = ETHTransaction.parse(raw, "r")
    s           = ETHTransaction.parse(raw, "s")

    if v.isEmpty && chainID > 0 {
      v = String(chainID)
      r = "0"
      s = "0"
    }

    super.init()
  }

  convenience init(raw: [String: String]) {
    self.init(raw: raw, chainID: -4) // -4 is to support old ecoding without chain id.
  }

  /// - Returns: Signed TX, always prefixed with 0x
  public var signedTx: String {
    return RLP.encode(serialize())
  }

  /// Should only called after signing
  public var signedResult: TransactionSignedResult {
    return TransactionSignedResult(signedTx: signedTx, txHash: signingHash)
  }

  private var signingData: String {
    return RLP.encode(serialize())
  }

  var signingHash: String {
    return Encryptor.Keccak256().encrypt(hex: signingData).add0xIfNeeded()
  }

  /// Sign transaction with private key
  /// - Parameters:
  ///     - privateKey: The private key from the keystore to sign the transaction.
  /// - Returns: dictionary [v, r, s] (all as String)
  public func sign(with privateKey: String) -> [String: String] {
    let result = Encryptor.Secp256k1().sign(key: privateKey, message: signingHash)

    v = encodeV(result.recid)
    r = result.signature.tk_substring(to: 64)
    s = result.signature.tk_substring(from: 64)

    return ["v": v, "r": r, "s": s]
  }

  private func encodeV(_ v: Int32) -> String {
    let intValue: Int32 = v + Int32(chainID) * 2 + 35
    return String(intValue)
  }

  private var isSigned: Bool {
    return !(v.isEmpty || r.isEmpty || s.isEmpty)
  }
}

// Parse and construct values
private extension ETHTransaction {
  func serialize() -> [BigNumber] {
    let base: [BigNumber] = [
      BigNumber.parse(nonce),
      BigNumber.parse(gasPrice),
      BigNumber.parse(gasLimit),
      BigNumber.parse(to, padding: true),  // Address
      BigNumber.parse(value),
      BigNumber.parse(data, padding: true) // Binary
    ]

    if isSigned {
      return base + [BigNumber.parse(v), BigNumber.parse(r), BigNumber.parse(s)]
    } else {
      return base
    }
  }

  static func parse(_ data: [String: String], _ key: String) -> String {
    return data[key] ?? ""
  }
}
