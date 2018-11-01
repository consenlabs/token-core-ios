//
//  EOSSignResult.swift
//  TokenCore
//
//  Created by James Chen on 2018/06/25.
//  Copyright © 2018 ConsenLabs. All rights reserved.
//

import Foundation

public struct EOSSignResult: Equatable {
  public let hash: String
  public let signs: [String]

  public init(hash: String, signs: [String]) {
    self.hash = hash
    self.signs = signs
  }

  public static func == (lhs: EOSSignResult, rhs: EOSSignResult) -> Bool {
    return lhs.hash == rhs.hash && lhs.signs == rhs.signs
  }
}
