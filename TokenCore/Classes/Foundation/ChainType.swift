//
//  ChainType.swift
//  token
//
//  Created by Kai Chen on 08/09/2017.
//  Copyright © 2017 ConsenLabs. All rights reserved.
//

import Foundation

public enum ChainType: String {
  case eth = "ETHEREUM"
  case btc = "BITCOIN"
  case eos = "EOS"

  public var privateKeySource: WalletMeta.Source {
    if self == .eth {
      return .privateKey
    }
    return .wif
  }
}
