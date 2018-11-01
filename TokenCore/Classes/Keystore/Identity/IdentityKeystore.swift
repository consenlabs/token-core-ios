//
//  IdentityKeystore.swift
//  token
//
//  Created by xyz on 2017/12/14.
//  Copyright © 2017 ConsenLabs. All rights reserved.
//

import Foundation
import CoreBitcoin

public struct IdentityKeystore {
  static let defaultVersion = 10000

  var id: String
  public let identifier: String
  let version: Int
  let crypto: Crypto
  var meta: WalletMeta
  let encAuthKey: EncryptedMessage
  let encMnemonic: EncryptedMessage

  let encKey: String
  let ipfsId: String
  var walletIds: [String]
  var wallets: [BasicWallet]

  public func dump(_ includingExtra: Bool = true) -> String {
    return toJSONString()
  }

  func verify(password: String) -> Bool {
    let decryptedMac = crypto.macFrom(password: password)
    let mac = crypto.mac
    return decryptedMac.lowercased() == mac.lowercased()
  }

  func mnemonic(from password: String) throws -> String {
    return String(data: encMnemonic.decrypt(crypto: crypto, password: password).tk_dataFromHexString()!, encoding: .utf8)!
  }
}

extension IdentityKeystore {
  init(metadata: WalletMeta, mnemonic: Mnemonic, password: String) throws {
    version = IdentityKeystore.defaultVersion
    id = ETHKeystore.generateKeystoreId()

    guard let btcMnemonic = BTCMnemonic(words: mnemonic.split(separator: " "), password: "", wordListType: .english),
      let seedData = btcMnemonic.seed else {
        throw MnemonicError.wordInvalid
    }

    guard let masterKeychain = BTCKeychain(seed: seedData) else {
        throw GenericError.unknownError
    }

    let network = metadata.isMainnet ? BTCNetwork.mainnet() : BTCNetwork.testnet()
    masterKeychain.network = network

    let masterKey = (masterKeychain.key.privateKey as Data).tk_toHexString()

    let backupKey = BTCEncryptedBackup.backupKey(for: network, masterKey: masterKey.tk_dataFromHexString())
    let authenticationKey = BTCEncryptedBackup.authenticationKey(withBackupKey: backupKey)!

    encKey = Encryptor.Hash.hmacSHA256(key: backupKey!, data: "Encryption Key".data(using: .utf8)!).tk_toHexString()

    var identifierData = Data()
    // this magic hex will start with 'im' after base58check
    let magicHex = "0fdc0c"
    identifierData.append(magicHex.tk_dataFromHexString()!)
    // todo: hardcode the network header
    var networkHeader: UInt8 = network!.isMainnet ? 0 : 111
    let networkHeaderData = Data(bytes: &networkHeader, count: MemoryLayout<UInt8>.size)
    identifierData.append(networkHeaderData)
    var identifierVersion: UInt8 = 2
    let identifierVersionData = Data(bytes: &identifierVersion, count: MemoryLayout<UInt8>.size)
    identifierData.append(identifierVersionData)
    let hash160 = BTCHash160((authenticationKey.publicKey) as Data) as Data
    identifierData.append(hash160)

    identifier = BTCBase58CheckStringWithData(identifierData)!

    let ipfsIDKey = BTCKey(privateKey: encKey.tk_dataFromHexString())!

    ipfsId = SigUtil.calcIPFSIDFromKey(ipfsIDKey)

    crypto = Crypto(password: password, privateKey: masterKeychain.extendedPrivateKey.tk_toHexString(), cacheDerivedKey: true)
    let derivedKey = crypto.cachedDerivedKey(with: password)

    let mnemonicHex = mnemonic.tk_toHexString()
    encMnemonic = EncryptedMessage.create(crypto: crypto, derivedKey: derivedKey, message: mnemonicHex)

    let authKeyHex = (authenticationKey.privateKey! as Data).tk_toHexString()
    encAuthKey = EncryptedMessage.create(crypto: crypto, derivedKey: derivedKey, message: authKeyHex)

    crypto.clearDerivedKey()

    meta = metadata
    walletIds = []
    wallets = []

  }
}

// MARK: - Parsing JSON
public extension IdentityKeystore {
  init(json: JSONObject) throws {
    id = ETHKeystore.generateKeystoreId()
    version = (json["version"] as? Int) ?? IdentityKeystore.defaultVersion

    guard let cryptoJSON = json["crypto"] as? JSONObject else {
      throw KeystoreError.invalid
    }
    crypto = try Crypto(json: cryptoJSON)

    guard
      let encMnemonicJSON = json["encMnemonic"] as? JSONObject,
      let encMnemonic = EncryptedMessage(json: encMnemonicJSON),
      let identifier = json["identifier"] as? String,
      let ipfsId = json["ipfsId"] as? String,
      let encAuthKeyJSON = json["encAuthKey"] as? JSONObject,
      let encAuthKey = EncryptedMessage(json: encAuthKeyJSON),
      let encKey = json["encKey"] as? String,
      let walletIds = json["walletIds"] as? [String],
      let metaJSON = json[WalletMeta.key] as? JSONObject
    else {
      throw KeystoreError.invalid
    }
    self.encMnemonic = encMnemonic
    self.encAuthKey = encAuthKey
    self.identifier = identifier
    self.ipfsId = ipfsId
    self.encKey = encKey
    self.walletIds = walletIds
    self.wallets = []
    self.meta = try WalletMeta(json: metaJSON)
  }

  func toJSON() -> JSONObject {
    return [
      "id": id,
      "identifier": identifier,
      "ipfsId": ipfsId,
      "encKey": encKey,
      "version": version,
      "encMnemonic": encMnemonic.toJSON(),
      "encAuthKey": encAuthKey.toJSON(),
      "crypto": crypto.toJSON(),
      "walletIds": walletIds,
      WalletMeta.key: meta.toJSON()
    ]
  }

  private func toJSONString() -> String {
    let data = try! JSONSerialization.data(withJSONObject: toJSON())
    return String(data: data, encoding: .utf8)!
  }

  func serializeToMap() -> [String: Any] {
    let walletsJSON: [[String: Any]] = wallets.map { wallet in
      return wallet.keystore.serializeToMap()
    }

    return [
      "identifier": identifier,
      "ipfsId": ipfsId,
      "wallets": walletsJSON
    ]
  }
}
