//
//  StorageManager.swift
//  token
//
//  Created by xyz on 2018/1/8.
//  Copyright © 2018 ConsenLabs. All rights reserved.
//

import Foundation

public struct StorageManager {
  public static var storageType: Storage.Type = LocalFileStorage.self {
    didSet {
      storage = storageType.init()
    }
  }
  public static var storage: Storage = StorageManager.storageType.init()
}
