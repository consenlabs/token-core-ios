//
//  KeyPair.swift
//  TokenCore
//
//  Created by James Chen on 2018/06/21.
//  Copyright © 2018 ConsenLabs. All rights reserved.
//

import Foundation

public struct KeyPair: Equatable {
  public let privateKey: String
  public let publicKey: String

  public static func == (lhs: KeyPair, rhs: KeyPair) -> Bool {
    return lhs.privateKey == rhs.privateKey && lhs.publicKey == rhs.publicKey
  }
}
