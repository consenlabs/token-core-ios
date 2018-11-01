//
//  BasicWallet.swift
//  token
//
//  Created by Kai Chen on 24/10/2017.
//  Copyright © 2017 ConsenLabs. All rights reserved.
//

import Foundation

public typealias WalletID = String

public class BasicWallet {
  public var walletID: WalletID
  public var keystore: Keystore
  public let chainType: ChainType?

  public init(json: JSONObject) throws {
    do {
      guard
        let version = json["version"] as? Int,
        let meta = json[WalletMeta.key] as? JSONObject,
        let chainTypeStr = meta["chain"] as? String,
        let chainType = ChainType(rawValue: chainTypeStr),
        let sourceStr = meta["source"] as? String,
        let source = WalletMeta.Source(rawValue: sourceStr)
      else {
        throw KeystoreError.invalid
      }

      let mnemonicKeystoreSource: [WalletMeta.Source] = [
        .mnemonic,
        .newIdentity,
        .recoveredIdentity
      ]

      switch version {
      case 3:
        switch chainType {
        case .eth:
          if mnemonicKeystoreSource.contains(source) {
            self.keystore = try ETHMnemonicKeystore(json: json)
          } else {
            self.keystore = try ETHKeystore(json: json)
          }
        case .btc:
          self.keystore = try BTCKeystore(json: json)
        case .eos:
          self.keystore = try EOSLegacyKeystore(json: json)
        }
      case BTCMnemonicKeystore.defaultVersion:
        self.keystore = try BTCMnemonicKeystore(json: json)
      case EOSKeystore.defaultVersion:
        self.keystore = try EOSKeystore(json: json)
      default:
        throw KeystoreError.invalid
      }
      self.chainType = chainType
    } catch {
      throw KeystoreError.invalid
    }
    self.walletID = self.keystore.id
  }

  public init(_ keystore: Keystore) {
    self.walletID = keystore.id
    self.keystore = keystore
    chainType = keystore.meta.chain
  }

  public var address: String {
    return keystore.address
  }

  public var imTokenMeta: WalletMeta {
    return keystore.meta
  }
}

public extension BasicWallet {
  func exportMnemonic(password: String) throws -> String {
    guard let mnemonicKeystore = self.keystore as? EncMnemonicKeystore else {
      throw GenericError.operationUnsupported
    }

    guard keystore.verify(password: password) else {
      throw PasswordError.incorrect
    }

    return mnemonicKeystore.decryptMnemonic(password)
  }

  func export() -> String {
    if let exportableKeystore = keystore as? ExportableKeystore {
      return exportableKeystore.export()
    }
    return ""
  }

  public func privateKey(password: String) throws -> String {
    guard keystore.verify(password: password) else {
      throw PasswordError.incorrect
    }

    if let pkKestore = keystore as? PrivateKeyCrypto {
      return pkKestore.decryptPrivateKey(password)
    } else if let wifKeystore = keystore as? WIFCrypto {
      return wifKeystore.decryptWIF(password)
    } else if let xprvKeystore = keystore as? XPrvCrypto {
      return xprvKeystore.decryptXPrv(password)
    } else {
      throw GenericError.operationUnsupported
    }
  }

  func privateKeys(password: String) throws -> [KeyPair] {
    guard keystore.verify(password: password) else {
      throw PasswordError.incorrect
    }

    if let eosKeystore = keystore as? EOSKeystore {
      return eosKeystore.exportKeyPairs(password)
    } else if let legacyEOSKeystore = keystore as? EOSLegacyKeystore {
      return legacyEOSKeystore.exportPrivateKeys(password)
    } else {
      throw GenericError.operationUnsupported
    }
  }

  func delete() -> Bool {
    guard let identity = Identity.currentIdentity else {
      return false
    }
    return identity.removeWallet(self)
  }

  func verifyPassword(_ password: String) -> Bool {
    return keystore.verify(password: password)
  }

  func serializeToMap() -> JSONObject {
    return keystore.serializeToMap()
  }

  func calcExternalAddress(at externalIdx: Int) throws -> String {
    guard let hdkeystore = self.keystore as? BTCMnemonicKeystore else {
      throw GenericError.operationUnsupported
    }

    return hdkeystore.calcExternalAddress(at: externalIdx)
  }
}
