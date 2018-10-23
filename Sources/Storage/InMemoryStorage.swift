//
//  InMemoryStorage.swift
//  token
//
//  Created by James Chen on 2017/01/19.
//  Copyright © 2017 imToken PTE. LTD. All rights reserved.
//

import Foundation

/// InMemoryStorage for keystores.
/// - Note: In Memory Storage doesn't persist keystores thus
///             should not be used in production.
///             Expect to use it only for test purpose.
public final class InMemoryStorage: Storage {
  public init() {}

  public func tryLoadIdentity() -> Identity? {
    guard
      let content = InMemoryStorage.db["identity.json"],
      let json = try? content.tk_toJSON(),
      let identity = Identity(json: json)
    else {
      return nil
    }
    return identity
  }

  public func loadWalletByIDs(_ walletIDs: [String]) -> [BasicWallet] {
    var wallets = [BasicWallet]()
    walletIDs.forEach { walletID in
      if let content = InMemoryStorage.db[walletID],
        let json = try? content.tk_toJSON(),
        let wallet = try? BasicWallet(json: json) {
        wallets.append(wallet)
      }
    }
    return wallets
  }

  public func deleteWalletByID(_ walletID: String) -> Bool {
    return InMemoryStorage.db.removeValue(forKey: walletID) != nil
  }

  public func cleanStorage() -> Bool {
    InMemoryStorage.db.removeAll()
    return true
  }

  public func flushIdentity(_ keystore: IdentityKeystore) -> Bool {
    let content = keystore.dump()
    InMemoryStorage.db["identity.json"] = content
    return true
  }

  public func flushWallet(_ keystore: Keystore) -> Bool {
    let content = keystore.dump()
    InMemoryStorage.db[keystore.id] = content
    return true
  }

  private static var db = [String: String]()
  static var enabled = true
}
