//
//  AppState.swift
//  TokenCore_Example
//
//  Created by xyz on 2018/11/2.
//  Copyright © 2018 CocoaPods. All rights reserved.
//

import Foundation


class AppState {
  
  public static let shared = AppState()
  
  var mnemonic: String?
  var walletIds: [String]?
  let defaultPassword: String = "88888888"
  
}
