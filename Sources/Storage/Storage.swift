//
//  Storage.swift
//  token
//
//  Created by James Chen on 2017/01/19.
//  Copyright © 2017 imToken PTE. LTD. All rights reserved.
//

import Foundation

public protocol Storage {
  init()
  func tryLoadIdentity() -> Identity?
  func loadWalletByIDs(_ walletIDs: [String]) -> [BasicWallet]
  func deleteWalletByID(_ walletID: String) -> Bool
  func cleanStorage() -> Bool
  func flushIdentity(_ keystore: IdentityKeystore) -> Bool
  func flushWallet(_ keystore: Keystore) -> Bool
}
