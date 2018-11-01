//
//  EOSPermission.swift
//  TokenCore
//
//  Created by James Chen on 2018/06/20.
//  Copyright © 2018 ConsenLabs. All rights reserved.
//

import Foundation

public struct EOS {
  struct Permission {
    static let owner = "owner"
    static let active = "active"
  }

  public struct PermissionObject {
    public var permission: String
    public var publicKey: String
    public var parent: String

    public init(permission: String, publicKey: String, parent: String) {
      self.permission = permission
      self.publicKey = publicKey
      self.parent = parent
    }
  }
}
