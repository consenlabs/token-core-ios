//
//  Network.swift
//  TokenCore
//
//  Created by James Chen on 2018/03/28.
//  Copyright © 2018 ConsenLabs. All rights reserved.
//

import Foundation

public enum Network: String {
  case mainnet = "MAINNET"
  case testnet = "TESTNET"

  var isMainnet: Bool {
    return self == .mainnet
  }
}
