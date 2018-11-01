//
//  SigUtilTests.swift
//  tokenTests
//
//  Created by Kai Chen on 16/11/2017.
//  Copyright © 2017 ConsenLabs. All rights reserved.
//

import XCTest
@testable import TokenCore

class SigUtilTests: XCTestCase {
  let signatureFixtures: [[String: String]] = [
    [
      "testLabel": "personalSign - kumavis fml manual test I",
      "message": "0x68656c6c6f20776f726c64", // "hello world"
      "signature": "ce909e8ea6851bc36c007a0072d0524b07a3ff8d4e623aca4c71ca8e57250c4d0a3fc38fa8fbaaa81ead4b9f6bd03356b6f8bf18bccad167d78891636e1d69561b",
      "addressHex": "0xbe93f9bacbcffc8ee6663f2647917ed7a20a57bb",
      "privateKey": "6969696969696969696969696969696969696969696969696969696969696969"
    ]
  ]

  func testHashPersonalMessage() {
    XCTAssertEqual(SigUtil.hashPersonalMessage("hello world"), "d9eba16ed0ecae432b71fe008c98cc872bb4cc214d3220a36f365326cf807d68")
  }

  func testPersonalSign() {
    for fixture in signatureFixtures {
      guard let privKey = fixture["privateKey"],
        let msg = fixture["message"],
        let sign = fixture["signature"] else {
        XCTFail("fixture data invalid")
        return
      }
      let plaintext = String(data: msg.tk_dataFromHexString()!, encoding: .utf8)
      debugPrint(privKey, msg, plaintext!, sign)
      let result = SigUtil.personalSign(privateKey: privKey, msgParams: ["data": plaintext!])
      XCTAssertEqual(SigUtil.concatSig(v: result["v"] as! Int32, r: result["r"] as! String, s: result["s"] as! String), sign)
    }
  }

  func testUnpackSig() {
    let result = try! SigUtil.unpackSig(sig: "ce909e8ea6851bc36c007a0072d0524b07a3ff8d4e623aca4c71ca8e57250c4d0a3fc38fa8fbaaa81ead4b9f6bd03356b6f8bf18bccad167d78891636e1d69561b")
    XCTAssertEqual(result.0, "ce909e8ea6851bc36c007a0072d0524b07a3ff8d4e623aca4c71ca8e57250c4d0a3fc38fa8fbaaa81ead4b9f6bd03356b6f8bf18bccad167d78891636e1d6956")
    XCTAssertEqual(result.1, 0)
  }

  func testUnpackSigInvalidParam() {
    // Wrong length
    XCTAssertThrowsError(try SigUtil.unpackSig(sig: "abcd"))
    // Not hex
    let notHex = (0..<130).map { _ in "i" }.joined()
    XCTAssertThrowsError(try SigUtil.unpackSig(sig: notHex))
  }

  func testEcsign() {
    let result = SigUtil.ecsign(with: "3c9229289a6125f7fdf1885a77bb12c37a8d3b4962d936f7e3084dece32a3ca1", data: "49".keccak256())
    XCTAssertEqual(result["r"] as? String, "282cb1fc266b030ddd000a3afd56396b823e836f635873668f1836d8fe080a29")
    XCTAssertEqual(result["v"] as? Int32, 28)
    XCTAssertEqual(result["s"] as? String, "00c4115fd7f8f17e035a53893625a0fe8debfb805ccd5ee209285fb6471809aa")
  }

  func testEcsignRecover() {
    let ecsign = SigUtil.ecsign(with: "3c9229289a6125f7fdf1885a77bb12c37a8d3b4962d936f7e3084dece32a3ca1", data: "49".keccak256())
    let sign = SigUtil.concatSig(v: ecsign["v"] as! Int32, r: ecsign["r"] as! String, s: ecsign["s"] as! String).add0xIfNeeded()
    let (sig, recId) = try! SigUtil.unpackSig(sig: sign.removePrefix0xIfNeeded())
    let pub = SigUtil.ecrecover(signature: sig, recid: recId, forHash: "49".keccak256())!.tk_dataFromHexString()!
    XCTAssertEqual(ETHKey.pubToAddress(pub), ETHKey(privateKey: "3c9229289a6125f7fdf1885a77bb12c37a8d3b4962d936f7e3084dece32a3ca1").address)
  }
}
