//
//  BIP44.swift
//  token
//
//  Created by Kai Chen on 17/11/2017.
//  Copyright © 2017 ConsenLabs. All rights reserved.
//

import Foundation

public struct BIP44 {
  public static let eth = "m/44'/60'/0'/0/0"
  public static let ipfs = "m/44'/99'/0'"
  public static let btcMainnet = "m/44'/0'/0'"
  public static let btcTestnet = "m/44'/1'/0'"
  public static let btcSegwitMainnet = "m/49'/0'/0'"
  public static let btcSegwitTestnet = "m/49'/1'/0'"
  public static let eos = "m/44'/194'"
//  public static let slip48 = "m/48'/4'/0'/0'/0',m/48'/4'/1'/0'/0'"
  public static let eosLedger = "m/44'/194'/0'/0/0"

  static func path(for network: Network?, segWit: SegWit) -> String {
    let isMainnet = network?.isMainnet ?? true
    if isMainnet {
      if segWit.isSegWit {
        return BIP44.btcSegwitMainnet
      } else {
        return BIP44.btcMainnet
      }
    } else {
      if segWit.isSegWit {
        return BIP44.btcSegwitTestnet
      } else {
        return BIP44.btcTestnet
      }
    }
  }
}
