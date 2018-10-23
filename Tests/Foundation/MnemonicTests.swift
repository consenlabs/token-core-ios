//
//  MnemonicTests.swift
//  token
//
//  Created by James Chen on 2016/10/31.
//  Copyright © 2016 imToken PTE. LTD. All rights reserved.
//

import XCTest
@testable import TokenCore

class MnemonicTests: TestCase {
  let passphrase = "TREZOR"

  func testJSONFixture() {
    let json = TestHelper.loadJSON(filename: "mnemonic") // https://raw.githubusercontent.com/trezor/python-mnemonic/master/vectors.json
    let data = json.data(using: .utf8)!
    let jsonObject = try! JSONSerialization.jsonObject(with: data) as! [String: Any]
    let english = jsonObject["english"] as! [[String]]
    for (index, example) in english.enumerated() {
      let expectedMnemonic = example[1]
      let expectedSeed = example[2]

      let seed = ETHMnemonic(mnemonic: expectedMnemonic, passphrase: passphrase).seed
      XCTAssertEqual(expectedSeed, seed, "Seed from mnemonic #\(index)")
    }
  }

  func testRandom() {
    let random = ETHMnemonic().mnemonic
    XCTAssertEqual(12, random.components(separatedBy: " ").count)
  }

  func testGenerateFromSeed() {
    let seed = try! ETHMnemonic.generateSeed(strength: 128)
    let mnemonic = ETHMnemonic.generate(from: seed)
    XCTAssertEqual(12, mnemonic.components(separatedBy: " ").count)
  }

  func testDeterministicSeed() {
    let mnemonic = "all hour make first leader extend hole alien behind guard gospel lava path output census museum junior mass reopen famous sing advance salt reform"
    let seed = ETHMnemonic.deterministicSeed(from: mnemonic, passphrase: passphrase)
    XCTAssertEqual("26e975ec644423f4a4c4f4215ef09b4bd7ef924e85d1d17c4cf3f136c2863cf6df0a475045652c57eb5fb41513ca2a2d67722b77e954b4b3fc11f7590449191d", seed)
  }

  func testFromSeed() {
    let seed = "f0ca2de86a1d7fec95e256e22d2907f4"
    let mnemnoic = ETHMnemonic(seed: seed)
    XCTAssertEqual(mnemnoic.mnemonic, "valid fabric key stage subject wagon fiscal enlist timber harsh draft trim")
  }

  func testGenerateSeed() {
    let seed = try! ETHMnemonic.generateSeed(strength: 128)
    XCTAssertEqual(32, seed.count)
    XCTAssert(Hex.isHex(seed))
  }

  func testGenerateSeedInvalidLength() {
    XCTAssertThrowsError(try ETHMnemonic.generateSeed(strength: 127))
  }
}
