//
//  BTCKey.swift
//  TokenCore
//
//  Created by James Chen on 2018/05/16.
//  Copyright © 2018 ConsenLabs. All rights reserved.
//

import Foundation
import CoreBitcoin

public extension BTCKey {
  public func address(on network: Network?, segWit: SegWit) -> BTCAddress {
    if segWit.isSegWit {
      if isMainnet(network) {
        return witnessAddress
      } else {
        return witnessAddressTestnet
      }
    } else {
      if isMainnet(network) {
        return address
      } else {
        return addressTestnet
      }
    }
  }

  private func isMainnet(_ network: Network?) -> Bool {
    if let network = network {
      return network.isMainnet
    }
    return true
  }
}
