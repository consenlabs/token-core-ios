//
//  TransactionTests.swift
//  token
//
//  Created by James Chen on 2016/11/03.
//  Copyright © 2016 imToken PTE. LTD. All rights reserved.
//

import XCTest
import BigInt
@testable import TokenCore

typealias Transaction = ETHTransaction

class TransactionTests: TestCase {
  func testSign() {
    let transaction = Transaction(
      raw: [
        "nonce":        "9",
        "gasPrice":     "20000000000",
        "gasLimit":     "21000",
        "to":           "0x3535353535353535353535353535353535353535",
        "value":        "1000000000000000000",
        "data":         ""
      ],
      chainID: 1
    )
    let signature = transaction.sign(with: "4646464646464646464646464646464646464646464646464646464646464646")
    XCTAssertEqual(transaction.v, "37")
    XCTAssertEqual("18515461264373351373200002665853028612451056578545711640558177340181847433846", BigUInt(signature["r"]!, radix: 16)!.description)
    XCTAssertEqual("46948507304638947509940763649030358759909902576025900602547168820602576006531", BigUInt(signature["s"]!, radix: 16)!.description)
  }

  func testSignMore() {
    // https://github.com/consenlabs/token/blob/master/android/app/src/test/java/org/consenlabs/token/test/RLPTest.java#L61
    let transaction = Transaction(raw: [
      "nonce":        "65",
      "gasPrice":     "54633837083",
      "gasLimit":     "21000",
      "to":           "0x632da81d534400f84c52d137d136a6ec89a59d77",
      "value":        "1000000000000000"
      ])
    let rlpedTx = transaction.signingHash
    XCTAssertEqual("0xc4b53b7fbc0a212cf3998c7105af2d50eb18da1bcd373de572f0ec285ba13a5b", rlpedTx)

    _ = transaction.sign(with: "2d743dda0caabdfb9fca0034d33cd0da7fb1ffe78cb80d643d67bf3f2aa12819")

    XCTAssertEqual(transaction.v, "28")
    XCTAssertEqual(transaction.r, "ed296b4495793ade51f50523755dfa68b2415440f044c288e122ebab9fc60269")
    XCTAssertEqual(transaction.s, "3a2967a92f9b54ef3471b11f6548810aa092c96aedeca7df821c06a314da40b5")

    let signedTx = transaction.signedTx
    XCTAssertEqual("f86b41850cb86e321b82520894632da81d534400f84c52d137d136a6ec89a59d7787038d7ea4c68000801ca0ed296b4495793ade51f50523755dfa68b2415440f044c288e122ebab9fc60269a03a2967a92f9b54ef3471b11f6548810aa092c96aedeca7df821c06a314da40b5", signedTx)
  }

  func testSignedTx() {
    let transaction = Transaction(raw: [
      "nonce":        "67",
      "gasPrice":     "32133304176",
      "gasLimit":     "21000",
      "to":           "0x632da81d534400f84c52d137d136a6ec89a59d77",
      "value":        "100000000000000"
    ])

    transaction.v = "1c"
    transaction.r = "914f82ef43d8e4089e22ff96949d5f53ddb18797fba97f43adccf2cbbbbde8d1"
    transaction.s = "32549115990ae59ac8667033c32d4082ba2bdd443e96dda9df6870cca229cd10"
    let signedTx = transaction.signedTx
    XCTAssertEqual("f86a4385077b4b4f7082520894632da81d534400f84c52d137d136a6ec89a59d77865af3107a4000801ca0914f82ef43d8e4089e22ff96949d5f53ddb18797fba97f43adccf2cbbbbde8d1a032549115990ae59ac8667033c32d4082ba2bdd443e96dda9df6870cca229cd10", signedTx)
  }

  func testSignedTx2() {
    let transaction = Transaction(raw: [
      "nonce":        "0x03",
      "gasPrice":     "0x01",
      "gasLimit":     "0x5208",
      "to":           "0xb94f5374fce5edbc8e2a8697c15331677e6ebf0b",
      "value":        "0x0a",
      "data":         "0x",
      "v":            "0x1c",
      "r":            "0x98ff921201554726367d2be8c804a7ff89ccf285ebc57dff8ae4c44b9c19ac4a",
      "s":            "0x8887321be575c8095f789dd4c743dfe42c1820f9231f98a962b210e3ac2452a3"
      ])
    let signedTx = transaction.signedTx
    XCTAssertEqual("f85f030182520894b94f5374fce5edbc8e2a8697c15331677e6ebf0b0a801ca098ff921201554726367d2be8c804a7ff89ccf285ebc57dff8ae4c44b9c19ac4aa08887321be575c8095f789dd4c743dfe42c1820f9231f98a962b210e3ac2452a3", signedTx)
  }

  func testRlpWithZeroPrefixData() {
    let transaction = Transaction(raw: [
      "nonce":        "0x00",
      "gasPrice":     "0x01",
      "gasLimit":     "0x61a8",
      "to":           "095e7baea6a6c7c4c2dfeb977efac326af552d87",
      "value":        "0x0a",
      "data":         "0x000000000000000000000000000000000000000000000000000000000",
      "v":            "0x1b",
      "r":            "0x48b55bfa915ac795c431978d8a6a992b628d557da5ff759b307d495a36649353",
      "s":            "0xefffd310ac743f371de3b9f7f9cb56c0b28ad43601b4ab949f53faa07bd2c804"
      ])
    XCTAssertEqual(
      "f87c80018261a894095e7baea6a6c7c4c2dfeb977efac326af552d870a9d00000000000000000000000000000000000000000000000000000000001ba048b55bfa915ac795c431978d8a6a992b628d557da5ff759b307d495a36649353a0efffd310ac743f371de3b9f7f9cb56c0b28ad43601b4ab949f53faa07bd2c804",
      transaction.signedTx
    )
  }

  func testSignWithZeroAddress() {
    let tx = Transaction(raw: [
      "nonce":        "0",
      "gasPrice":     "1",
      "gasLimit":     "31415",
      "to":           "0x0000000000000000000000000000000000000000",
      "value":        "0",
      "data":         ""
      ])
    let signature = tx.sign(with: "0101010101010101010101010101010101010101010101010101010101010101")
    XCTAssertEqual("27", signature["v"])
    XCTAssertEqual("70011721239254335992234962732673807139656098521717117805596934149023384508204", BigUInt(signature["r"]!, radix: 16)!.description)
    XCTAssertEqual("17624540777746785479194051974711071979083475571118607927022572721095387941", BigUInt(signature["s"]!, radix: 16)!.description)
  }

  // MARK: - Failing tests from ttTransactonTest

  func testAddressLessThan20Prefixed0() {
    let transaction = Transaction(raw: [
      "nonce":        "0x00",
      "gasPrice":     "0x01",
      "gasLimit":     "0x5208",
      "to":           "0x000000000000000000000000000b9331677e6ebf",
      "value":        "0x0a",
      "data":         "",
      "v":            "0x1c",
      "r":            "0x98ff921201554726367d2be8c804a7ff89ccf285ebc57dff8ae4c44b9c19ac4a",
      "s":            "0x8887321be575c8095f789dd4c743dfe42c1820f9231f98a962b210e3ac2452a3"
      ])
    let expected = "f85f800182520894000000000000000000000000000b9331677e6ebf0a801ca098ff921201554726367d2be8c804a7ff89ccf285ebc57dff8ae4c44b9c19ac4aa08887321be575c8095f789dd4c743dfe42c1820f9231f98a962b210e3ac2452a3"
    XCTAssertEqual(expected, transaction.signedTx)
  }

  func testDataTestEnoughGAS() {
    let transaction = Transaction(raw: [
      "nonce":        "0x00",
      "gasPrice":     "0x01",
      "gasLimit":     "0x59d8",
      "to":           "095e7baea6a6c7c4c2dfeb977efac326af552d87",
      "value":        "0x0a",
      "data":         "0x0358ac39584bc98a7c979f984b03",
      "v":            "0x1b",
      "r":            "0x48b55bfa915ac795c431978d8a6a992b628d557da5ff759b307d495a36649353",
      "s":            "0xefffd310ac743f371de3b9f7f9cb56c0b28ad43601b4ab949f53faa07bd2c804"
      ])
    let expected = "f86d80018259d894095e7baea6a6c7c4c2dfeb977efac326af552d870a8e0358ac39584bc98a7c979f984b031ba048b55bfa915ac795c431978d8a6a992b628d557da5ff759b307d495a36649353a0efffd310ac743f371de3b9f7f9cb56c0b28ad43601b4ab949f53faa07bd2c804"
    XCTAssertEqual(expected, transaction.signedTx)
  }

  func testDataTx_bcValidBlockTest() {
    let transaction = Transaction(raw: [
      "nonce":        "0x00",
      "gasPrice":     "0x32",
      "gasLimit":     "0xc350",
      "to":           "",
      "value":        "0x00",
      "data":         "0x60056013565b6101918061001d6000396000f35b3360008190555056006001600060e060020a6000350480630a874df61461003a57806341c0e1b514610058578063a02b161e14610066578063dbbdf0831461007757005b610045600435610149565b80600160a060020a031660005260206000f35b610060610161565b60006000f35b6100716004356100d4565b60006000f35b61008560043560243561008b565b60006000f35b600054600160a060020a031632600160a060020a031614156100ac576100b1565b6100d0565b8060018360005260205260406000208190555081600060005260206000a15b5050565b600054600160a060020a031633600160a060020a031614158015610118575033600160a060020a0316600182600052602052604060002054600160a060020a031614155b61012157610126565b610146565b600060018260005260205260406000208190555080600060005260206000a15b50565b60006001826000526020526040600020549050919050565b600054600160a060020a031633600160a060020a0316146101815761018f565b600054600160a060020a0316ff5b56",
      "v":            "0x1c",
      "r":            "0xc5689ed1ad124753d54576dfb4b571465a41900a1dff4058d8adf16f752013d0",
      "s":            "0xe221cbd70ec28c94a3b55ec771bcbc70778d6ee0b51ca7ea9514594c861b1884"
      ])
    let expected = "f901fb803282c3508080b901ae60056013565b6101918061001d6000396000f35b3360008190555056006001600060e060020a6000350480630a874df61461003a57806341c0e1b514610058578063a02b161e14610066578063dbbdf0831461007757005b610045600435610149565b80600160a060020a031660005260206000f35b610060610161565b60006000f35b6100716004356100d4565b60006000f35b61008560043560243561008b565b60006000f35b600054600160a060020a031632600160a060020a031614156100ac576100b1565b6100d0565b8060018360005260205260406000208190555081600060005260206000a15b5050565b600054600160a060020a031633600160a060020a031614158015610118575033600160a060020a0316600182600052602052604060002054600160a060020a031614155b61012157610126565b610146565b600060018260005260205260406000208190555080600060005260206000a15b50565b60006001826000526020526040600020549050919050565b600054600160a060020a031633600160a060020a0316146101815761018f565b600054600160a060020a0316ff5b561ca0c5689ed1ad124753d54576dfb4b571465a41900a1dff4058d8adf16f752013d0a0e221cbd70ec28c94a3b55ec771bcbc70778d6ee0b51ca7ea9514594c861b1884"
    XCTAssertEqual(expected, transaction.signedTx)
  }

  func testLibsecp256k1test() {
    let transaction = Transaction(raw: [
      "nonce":        "0x00",
      "gasPrice":     "0x09184e72a000",
      "gasLimit":     "0xf388",
      "to":           "",
      "value":        "0x00",
      "data":         "0x",
      "v":            "0x1b",
      "r":            "0x2c",
      "s":            "0x04"
      ])
    let expected = "d1808609184e72a00082f3888080801b2c04"
    XCTAssertEqual(expected, transaction.signedTx)
  }

  func testTransactionWithHihghValue() {
    let transaction = Transaction(raw: [
      "nonce":        "0x00",
      "gasPrice":     "0x01",
      "gasLimit":     "0x5208",
      "to":           "095e7baea6a6c7c4c2dfeb977efac326af552d87",
      "value":        "0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff",
      "data":         "",
      "v":            "0x1b",
      "r":            "0x48b55bfa915ac795c431978d8a6a992b628d557da5ff759b307d495a36649353",
      "s":            "0xefffd310ac743f371de3b9f7f9cb56c0b28ad43601b4ab949f53faa07bd2c804"
      ])
    let expected = "f87f800182520894095e7baea6a6c7c4c2dfeb977efac326af552d87a0ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff801ba048b55bfa915ac795c431978d8a6a992b628d557da5ff759b307d495a36649353a0efffd310ac743f371de3b9f7f9cb56c0b28ad43601b4ab949f53faa07bd2c804"
    XCTAssertEqual(expected, transaction.signedTx)
  }

  func testUnpadedRValue() {
    let transaction = Transaction(raw: [
      "nonce":        "0x0d",
      "gasPrice":     "0x09184e72a000",
      "gasLimit":     "0xf710",
      "to":           "7c47ef93268a311f4cad0c750724299e9b72c268",
      "value":        "0x00",
      "data":         "0x379607f50000000000000000000000000000000000000000000000000000000000000005",
      "v":            "0x1c",
      "r":            "0x006ab6dda9f4df56ea45583af36660329147f1753f3724ea5eb9ed83e812ca77",
      "s":            "0x495701e230667832c8999e884e366a61028633ecf951e8cd66d119f381ae5718"
      ])
    let expected = "f8880d8609184e72a00082f710947c47ef93268a311f4cad0c750724299e9b72c26880a4379607f500000000000000000000000000000000000000000000000000000000000000051c9f6ab6dda9f4df56ea45583af36660329147f1753f3724ea5eb9ed83e812ca77a0495701e230667832c8999e884e366a61028633ecf951e8cd66d119f381ae5718"
    XCTAssertEqual(expected, transaction.signedTx)
  }

  func testJSONFixture() {
    /// https://github.com/ethereum/tests/blob/862b4e3d4a9a7141af1b4aaf7dfe228a6a294614/TransactionTests/ttTransactionTest.json
    let json = TestHelper.loadJSON(filename: "ttTransactionTest")
    let data = json.data(using: .utf8)!
    let jsonRoot = try! JSONSerialization.jsonObject(with: data) as! [String: Any]
    for (key, value) in jsonRoot {
      if let jsonObject = value as? [String: Any], let transactionObject = jsonObject["transaction"] as? [String: String], let rlp = jsonObject["rlp"] as? String {
        let tx = Transaction(raw: [
          "nonce":        transactionObject["nonce"]!,
          "gasPrice":     transactionObject["gasPrice"]!,
          "gasLimit":     transactionObject["gasLimit"]!,
          "to":           transactionObject["to"]!,
          "value":        transactionObject["value"]!,
          "data":         transactionObject["data"]!,
          "v":            transactionObject["v"]!,
          "r":            transactionObject["r"]!,
          "s":            transactionObject["s"]!
          ])
        XCTAssertEqual(Hex.removePrefix(rlp), tx.signedTx, "fixture #\(key)")
      }
    }
  }

  func testEIP155() {
    let transaction = Transaction(raw: [
      "nonce":        "0x07",
      "gasPrice":     "0x04a817c807",
      "gasLimit":     "0x029040",
      "to":           "0x3535353535353535353535353535353535353535",
      "value":        "0x0157",
      "data":         "",
      "v":            "0x25",
      "r":            "0x52f1a9b320cab38e5da8a8f97989383aab0a49165fc91c737310e4f7e9821021",
      "s":            "0x52f1a9b320cab38e5da8a8f97989383aab0a49165fc91c737310e4f7e9821021"
      ])
    let expected = "f867078504a817c807830290409435353535353535353535353535353535353535358201578025a052f1a9b320cab38e5da8a8f97989383aab0a49165fc91c737310e4f7e9821021a052f1a9b320cab38e5da8a8f97989383aab0a49165fc91c737310e4f7e9821021"
    XCTAssertEqual(expected, transaction.signedTx)
  }
}
