//
//  ETHKey.swift
//  token
//
//  Created by James Chen on 2016/10/24.
//  Copyright © 2016 imToken PTE. LTD. All rights reserved.
//

import Foundation
import CoreBitcoin

public class ETHKey {
  private let rootPrivateKey: String
  let privateKey: String // For user daily use, adress/privateKey, via path "m/44'/60'/0'/0/index"
  var address: String {
    let btcKey = BTCKey(privateKey: privateKey.tk_dataFromHexString())!
    return ETHKey.pubToAddress(btcKey.uncompressedPublicKey as Data)
  }

  init(privateKey: String) {
    rootPrivateKey = ""
    self.privateKey = privateKey
  }

  init(seed: Data, path: String) {
    let rootKeychain = BTCKeychain(seed: seed)!
    rootPrivateKey = rootKeychain.extendedPrivateKey.tk_toHexString()
    let components = path.components(separatedBy: "/")
    let index = UInt32(components.last!)!
    let account = rootKeychain.derivedKeychain(withPath: components.dropLast().joined(separator: "/"))!
    privateKey = (account.key(at: index).privateKey as Data).tk_toHexString()
  }

  convenience init(mnemonic: Mnemonic, path: String) {
    let seed = ETHMnemonic.deterministicSeed(from: mnemonic)
    self.init(seed: seed.tk_dataFromHexString()!, path: path)
  }

  public static func mnemonicToAddress(_ mnemonic: Mnemonic, path: String) -> String {
    return ETHKey(mnemonic: mnemonic, path: path).address
  }

  public static func pubToAddress(_ publicKey: Data) -> String {
    let stringToEncrypt = publicKey.tk_toHexString().tk_substring(from: 2)
    let sha3Keccak = Encryptor.Keccak256().encrypt(hex: stringToEncrypt)
    return sha3Keccak.tk_substring(from: 24)
  }
}
