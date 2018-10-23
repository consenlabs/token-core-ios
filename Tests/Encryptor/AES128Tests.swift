//
//  AES128Tests.swift
//  tokenTests
//
//  Created by James Chen on 2018/02/09.
//  Copyright © 2018 ConsenLabs. All rights reserved.
//

import XCTest
@testable import TokenCore

class AES128Tests: XCTestCase {
  func testAES128() {
    let commonKey = "4A2B655485ABBAB54BD30298BB0A5B55"
    let commonIv = "73518399CB98DCD114D873E06EBF4BCC"
    let aes = Encryptor.AES128(key: commonKey, iv: commonIv, mode: .cbc, padding: .pkcs5)
    XCTAssertEqual(aes.encrypt(string: "hello world").tk_dataFromHexString()!.base64EncodedString(), "XIlNb4qzyvgxs/asuklWwA==")
  }

  func testEncryptDecrypt() {
    let commonKey = "4A2B655485ABBAB54BD30298BB0A5B55"
    let commonIv = "73518399CB98DCD114D873E06EBF4BCC"
    let aes = Encryptor.AES128(key: commonKey, iv: commonIv, mode: .cbc, padding: .pkcs5)
    let input = "aes message".tk_toHexString()
    XCTAssertEqual(aes.decrypt(hex: aes.encrypt(hex: input)), input)
  }

  func testCTR() {
    measure {
      /// expected, input text, key, iv
      let examples = [
        /// https://github.com/ethereum/wiki/wiki/Web3-Secret-Storage-Definition#test-vectors
        [
          "5318b4d5bcd28de64ee5559e671353e16f075ecae9f99c7a79a38af5f869aa46",
          "7a28b5ba57c53603b0b07b56bba752f7784bf506fa95edc395f5cf6c7514fe9d",
          "f06d69cdc7da0faffb1008270bca38f5",
          "6087dab2f9fdbbfaddc31a909735c1e6"
        ]
      ]

      examples.forEach { example in
        let expected = example.first!
        let input = example[1]
        let key = example[2]
        let iv = example[3]
        let aes = Encryptor.AES128(key: key, iv: iv)

        let encrypted = aes.encrypt(hex: input)
        XCTAssertEqual(expected, encrypted)

        let decrypted = aes.decrypt(hex: encrypted)
        XCTAssertEqual(input, decrypted)
      }
    }
  }

  func testCBC() {
    measure {
      /// expected, input text, key, iv
      let examples = [
        [
          "07533e172414bfa50e99dba4a0ce603f654ebfa1ff46277c3e0c577fdc87f6bb4e4fe16c5a94ce6ce14cfa069821ef9b",
          "cb19dce82bdb902efb5b5b75d0fe4c4c09dee0e99ef222af35dd8da136bde8995f7fd84acfb1679fe2e91de783a5e006",
          "9fc409900f835bb38302e976e16c49e7",
          "16d67ba0ce5a339ff2f07951253e6ba8"
        ]
      ]

      examples.forEach { example in
        let expected = example.first!
        let input = example[1]
        let key = example[2]
        let iv = example[3]

        let aes = Encryptor.AES128(key: key, iv: iv, mode: .cbc)

        let encrypted = aes.encrypt(hex: input)
        XCTAssertEqual(expected, encrypted)

        let decrypted = aes.decrypt(hex: encrypted)
        XCTAssertEqual(input, decrypted)
      }
    }
  }
}
