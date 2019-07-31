//
//  Identity.swift
//  token
//
//  Created by xyz on 2017/12/13.
//  Copyright © 2017 ConsenLabs. All rights reserved.
//

import Foundation
import CoreBitcoin

public final class Identity {
  private static var _currentIdentity: Identity?
  static let storage = StorageManager.storage

  public static var currentIdentity: Identity? {
    set(newIdentity) {
      _currentIdentity = newIdentity
    }
    get {
      if _currentIdentity == nil {
        _currentIdentity = storage.tryLoadIdentity()
      }
      return _currentIdentity
    }
  }

  public var keystore: IdentityKeystore
  public var identifier: String {
    return keystore.identifier
  }
  public var wallets: [BasicWallet] {
    return keystore.wallets
  }

  init(metadata: WalletMeta, mnemonic: String, password: String) throws {
    keystore = try IdentityKeystore(metadata: metadata, mnemonic: mnemonic, password: password)

    _ = try deriveWallets(for: [.eth, .btc], mnemonic: mnemonic, password: password)

    _ = Identity.storage.flushIdentity(keystore)
  }

  public init?(json: JSONObject) {
    guard let keystore = try? IdentityKeystore(json: json) else {
      return nil
    }
    self.keystore = keystore
    self.keystore.wallets = Identity.storage.loadWalletByIDs(self.keystore.walletIds)
  }

  public func export(password: String) throws -> String {
    guard keystore.verify(password: password) else {
      throw PasswordError.incorrect
    }
    return try keystore.mnemonic(from: password)
  }

  public func delete(password: String) throws -> Bool {
    guard keystore.verify(password: password) else {
      throw PasswordError.incorrect
    }

    if Identity.storage.cleanStorage() {
      Identity.currentIdentity = nil
      return true
    }
    return false
  }

  public func deriveWallets(for chainTypes: [ChainType], password: String) throws -> [BasicWallet] {
    let mnemonic = try export(password: password)
    return try deriveWallets(for: chainTypes, mnemonic: mnemonic, password: password)
  }
}

// MARK: Factory And Storage
public extension Identity {
  static func createIdentity(password: String, metadata: WalletMeta) throws -> (String, Identity) {
    let mnemonic = MnemonicUtil.generateMnemonic()

    let identity = try Identity(metadata: metadata, mnemonic: mnemonic, password: password)
    currentIdentity = identity
    return (mnemonic, identity)
  }

  static func recoverIdentity(metadata: WalletMeta, mnemonic: String, password: String) throws -> Identity {
    let identity = try Identity(metadata: metadata, mnemonic: mnemonic, password: password)
    currentIdentity = identity
    return identity
  }
}

// MARK: Wallet
extension Identity {
  func append(_ newKeystore: Keystore) throws -> BasicWallet {
    let wallet = BasicWallet(newKeystore)
    
    if findWalletByAddress(wallet.address.removePrefix0xIfNeeded(), on: newKeystore.meta.chain!) != nil {
      throw AddressError.alreadyExist
    }
    
    keystore.wallets.append(wallet)
    keystore.walletIds.append(wallet.walletID)
    if Identity.storage.flushWallet(wallet.keystore) && Identity.storage.flushIdentity(keystore) {
      return wallet
    }

    throw GenericError.importFailed
  }

  func removeWallet(_ wallet: BasicWallet) -> Bool {
    if let index = keystore.walletIds.index(where: { return $0 == wallet.walletID }) {
      keystore.wallets.remove(at: index)
      keystore.walletIds.remove(at: index)
      return Identity.storage.flushIdentity(keystore)
    }
    return false
  }

  func importFromMnemonic(_ mnemonic: String, metadata: WalletMeta, encryptBy password: String, at path: String) throws -> BasicWallet {
    if path.isEmpty {
      throw MnemonicError.pathInvalid
    }

    let keystore: Keystore

    switch metadata.chain! {
    case .btc:
      keystore = try BTCMnemonicKeystore(password: password, mnemonic: mnemonic, path: path, metadata: metadata)
    case .eth:
      keystore = try ETHMnemonicKeystore(password: password, mnemonic: mnemonic, path: path, metadata: metadata)
    case .eos:
      throw GenericError.operationUnsupported
    }

    return try append(keystore)
  }

  func importEOS(
    from mnemonic: String,
    accountName: String,
    permissions: [EOS.PermissionObject],
    metadata: WalletMeta,
    encryptBy password: String,
    at path: String
  ) throws -> BasicWallet {
    if path.isEmpty {
      throw MnemonicError.pathInvalid
    }

    if metadata.chain != .eos {
      throw GenericError.operationUnsupported
    }

    let keystore = try EOSKeystore(accountName: accountName, password: password, mnemonic: mnemonic, path: path, permissions: permissions, metadata: metadata)
    return try append(keystore)
  }

  func importEOS(
    from privateKeys: [String],
    accountName: String,
    permissions: [EOS.PermissionObject],
    encryptedBy password: String,
    metadata: WalletMeta
  ) throws -> BasicWallet {
    if metadata.chain != .eos {
      throw GenericError.operationUnsupported
    }

    let keystore = try EOSKeystore(accountName: accountName, password: password, privateKeys: privateKeys, permissions: permissions, metadata: metadata)
    return try append(keystore)
  }

  /**
   Import ETH keystore json to generate wallet
   
   - parameter keystore: JSON text
   - parameter password: Password of keystore
   - parameter metadata: Wallet metadata
   */
  func importFromKeystore(_ keystore: JSONObject, encryptedBy password: String, metadata: WalletMeta) throws -> BasicWallet {
    var keystore = try ETHKeystore(json: keystore)
    keystore.meta = metadata
    guard keystore.verify(password: password) else {
      throw KeystoreError.macUnmatch
    }

    let privateKey = keystore.decryptPrivateKey(password)
    do {
    _ = try PrivateKeyValidator(privateKey, on: .eth).validate()
    } catch let err as AppError {
      if err.message == PrivateKeyError.invalid.rawValue {
        throw KeystoreError.containsInvalidPrivateKey
      } else {
        throw err
      }
    }
    guard ETHKey(privateKey: keystore.decryptPrivateKey(password)).address == keystore.address else {
      throw KeystoreError.privateKeyAddressUnmatch
    }

    return try append(keystore)
  }

  /**
   Import private key to generate wallet
   */
  func importFromPrivateKey(_ privateKey: String, encryptedBy password: String, metadata: WalletMeta, accountName: String? = nil) throws -> BasicWallet {
    let keystore: Keystore
    switch metadata.chain! {
    case .btc:
      keystore = try BTCKeystore(password: password, wif: privateKey, metadata: metadata)
    case .eth:
      keystore = try ETHKeystore(password: password, privateKey: privateKey, metadata: metadata)
    case .eos:
      guard let accountName = accountName, !accountName.isEmpty else {
        throw GenericError.paramError
      }
      keystore = try EOSLegacyKeystore(password: password, wif: privateKey, metadata: metadata, accountName: accountName)
    }
    return try append(keystore)
  }

  func findWalletByPrivateKey(_ privateKey: String, on chainType: ChainType, network: Network? = nil, segWit: SegWit = .none) throws -> BasicWallet? {
    if chainType == .eth {
      let address = ETHKey(privateKey: privateKey).address
      return findWalletByAddress(address, on: chainType)
    } else {
      guard let key = BTCKey(wif: privateKey) else {
        throw PrivateKeyError.invalid
      }

      let address = key.address(on: network, segWit: segWit).string
      return findWalletByAddress(address, on: chainType)
    }
  }

  // ETH: generate address from mnemonic and path
  // BTC: generate $PATH/0/0 address from mnemonic and path
  func findWalletByMnemonic(_ mnemonic: String, on chainType: ChainType, path: String, network: Network? = nil, segWit: SegWit = .none) throws -> BasicWallet? {
    if path.isEmpty {
      throw MnemonicError.pathInvalid
    }

    if chainType == .eth {
      let addr = ETHKey.mnemonicToAddress(mnemonic, path: path)
      return findWalletByAddress(addr, on: chainType)
    } else if chainType == .btc {
      guard let btcMnemonic = BTCMnemonic(words: mnemonic.split(separator: " "), password: "", wordListType: .english),
        let seedData = btcMnemonic.seed else {
          throw MnemonicError.wordInvalid
      }

      let isMainnet = network?.isMainnet ?? true
      guard let masterKeychain = BTCKeychain(seed: seedData, network: isMainnet ? BTCNetwork.mainnet() : BTCNetwork.testnet()),
        let account = masterKeychain.derivedKeychain(withPath: path),
        let key = account.externalKey(at: 0) else {
          throw GenericError.unknownError
      }
      return findWalletByAddress(key.address(on: network, segWit: segWit).string, on: chainType)
    }

    throw GenericError.unsupportedChain
  }

  func findWalletByKeystore(_ keystore: [String: Any], on chainType: ChainType, password: String) throws -> BasicWallet? {
    guard chainType == .eth else {
      throw GenericError.unsupportedChain
    }

    let ks = try ETHKeystore(json: keystore)
    guard ks.verify(password: password) else {
      throw KeystoreError.macUnmatch
    }
    return findWalletByAddress(ks.address, on: .eth)
  }

  func findWalletByWalletID(_ walletID: String) -> BasicWallet? {
    return keystore.wallets.first(where: { return $0.walletID == walletID })
  }

  func findWalletByAddress(_ address: String, on chainType: ChainType) -> BasicWallet? {
    return keystore.wallets.first { (wallet) -> Bool in
      return wallet.address.removePrefix0xIfNeeded() == address.removePrefix0xIfNeeded() && wallet.imTokenMeta.chain == chainType
    }
  }

  func deriveWallets(for chainTypes: [ChainType], mnemonic: String, password: String) throws -> [BasicWallet] {
    return try chainTypes.map { chainType in
      var meta = WalletMeta(chain: chainType, source: keystore.meta.source)
      meta.passwordHint = keystore.meta.passwordHint

      switch chainType {
      case .eth:
        meta.name = "ETH"
        return try importFromMnemonic(mnemonic, metadata: meta, encryptBy: password, at: BIP44.eth)
      case .btc:
        meta.name = "BTC"
        meta.network = keystore.meta.network
        meta.segWit = keystore.meta.segWit
        return try importFromMnemonic(mnemonic, metadata: meta, encryptBy: password, at: BIP44.path(for: meta.network, segWit: meta.segWit))
      case .eos:
        meta.name = "EOS"
        return try importEOS(from: mnemonic, accountName: "", permissions: [], metadata: meta, encryptBy: password, at: BIP44.eosLedger)
      }
    }
  }
}
