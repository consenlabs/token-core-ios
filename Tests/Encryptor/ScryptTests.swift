//
//  ScryptTests.swift
//  tokenTests
//
//  Created by James Chen on 2018/02/09.
//  Copyright © 2018 ConsenLabs. All rights reserved.
//

import XCTest
@testable import TokenCore

class ScryptTests: XCTestCase {
  func testEncrypt() {
    /// salt, r, n, p, password, expected
    let examples = [
      ["ab0c7876052600dd703518d6fc3fe8984592145b591fc8fb5c6d43190334ba19", 1, 262144, 8, "testpassword", "fac192ceb5fd772906bea3e118a69e8bbb5cc24229e20d8766fd298291bba6bd"]
    ]

    examples.forEach { example in
      let salt = example[0] as! String
      let r = example[1] as! Int
      let n = example[2] as! Int
      let p = example[3] as! Int
      let password = example[4] as! String
      let expected = example[5] as! String

      let scrypt = Encryptor.Scrypt(password: password, salt: salt, n: n, r: r, p: p)
      XCTAssertEqual(expected, scrypt.encrypt())
    }
  }
}
