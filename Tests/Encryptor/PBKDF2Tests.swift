//
//  PBKDF2Tests.swift
//  tokenTests
//
//  Created by James Chen on 2018/02/09.
//  Copyright © 2018 ConsenLabs. All rights reserved.
//

import XCTest
@testable import TokenCore

class PBKDF2Tests: XCTestCase {
  func testPBKDF2() {
    let examples = [
      /// salt, iterations, key len, password, expected
      ["salt".tk_toHexString(), 4096, 32, "password", "c5e478d59288c841aa530db6845c4c8d962893a001ce4e11a4963873aa98134a"],
      ["saltSALTsaltSALTsaltSALTsaltSALTsalt".tk_toHexString(), 4096, 40, "passwordPASSWORDpassword", "348c89dbcbd32b2f32d814b8116e84cf2b17347ebc1800181c4e2a1fb8dd53e1c635518c7dac47e9"]
    ]

    examples.forEach { example in
      let salt = example[0] as! String
      let iterations = example[1] as! Int
      let keyLength = example[2] as! Int
      let password = example[3] as! String
      let expected = example[4] as! String

      let pbkdf2 = Encryptor.PBKDF2(password: password, salt: salt, iterations: iterations, keyLength: keyLength)
      XCTAssertEqual(expected, pbkdf2.encrypt())
    }
  }
}
