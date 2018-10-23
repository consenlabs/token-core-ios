//
//  StorageManagerTests.swift
//  tokenTests
//
//  Created by James Chen on 2018/03/12.
//  Copyright © 2018 ConsenLabs. All rights reserved.
//

import XCTest
@testable import TokenCore

class StorageManagerTests: XCTestCase {
  func testInMemoryStorage() {
    StorageManager.storageType = InMemoryStorage.self
    XCTAssert(StorageManager.storage is InMemoryStorage)
  }

  func testLocalFileStorage() {
    StorageManager.storageType = LocalFileStorage.self
    XCTAssert(StorageManager.storage is LocalFileStorage)
  }
}
