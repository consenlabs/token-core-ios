//
//  SegWit.swift
//  TokenCore
//
//  Created by James Chen on 2018/05/16.
//  Copyright © 2018 ConsenLabs. All rights reserved.
//

import Foundation

public enum SegWit: String {
  case none = "NONE"
  case p2wpkh = "P2WPKH"

  public var isSegWit: Bool {
    return self == .p2wpkh
  }
}
