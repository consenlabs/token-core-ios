//
//  WalletMeta.swift
//  token
//
//  Created by James Chen on 2017/01/03.
//  Copyright © 2017 imToken PTE. LTD. All rights reserved.
//

import Foundation

public struct WalletMeta {
  static let key = "imTokenMeta"

  public enum Source: String {
    case newIdentity = "NEW_IDENTITY"
    case recoveredIdentity = "RECOVERED_IDENTITY"
    case privateKey = "PRIVATE"
    case wif = "WIF"
    case keystore = "KEYSTORE"
    case mnemonic = "MNEMONIC"
  }

  public enum Mode: String {
    case normal
    case offlineSigning
    case hardware
  }


  var mode: Mode = .normal

  public var name: String = ""
  public var passwordHint: String = ""
  public var network: Network?
  public var chain: ChainType?
  public let source: Source
  

  public var segWit = SegWit.none

  let timestamp: Double
  let version: String
  var backup: [String] = []

  public init(source: Source) {
    self.source = source
    timestamp = WalletMeta.currentTime
    version = WalletMeta.currentVersion
  }

  public init(chain: ChainType, source: Source, network: Network? = .mainnet) {
    self.source = source
    self.chain = chain
    self.network = network
    timestamp = WalletMeta.currentTime
    version = WalletMeta.currentVersion
  }

  public init(_ map: [AnyHashable: Any], source: Source? = nil) {
    if let name = map["name"] as? String {
      self.name = name
    }
    if let passwordHint = map["passwordHint"] as? String {
      self.passwordHint = passwordHint
    }
    if let chainStr = map["chainType"] as? String, let chainType = ChainType(rawValue: chainStr) {
      chain = chainType
    }
    if let networkStr = map["network"] as? String, let network = Network(rawValue: networkStr) {
      self.network = network
    }
    if source != nil {
      self.source = source!
    } else if let sourceStr = map["source"] as? String, let source = Source(rawValue: sourceStr) {
      self.source = source
    } else {
      self.source = .newIdentity
    }

    if let segWitStr = map["segWit"] as? String, let segWit = SegWit(rawValue: segWitStr) {
      self.segWit = segWit
    }

    timestamp = WalletMeta.currentTime
    version = WalletMeta.currentVersion
  }

  public init(json: JSONObject) throws {
    if let source = Source(rawValue: (json["source"] as? String) ?? "") {
      self.source = source
    } else {
      self.source = .newIdentity
    }

    if let timestampString = json["timestamp"] as? String, let timestamp = Double(timestampString) {
      self.timestamp = timestamp
    } else {
      timestamp = WalletMeta.currentTime
    }

    if let version = json["version"] as? String {
      self.version = version
    } else {
      version = WalletMeta.currentVersion
    }

    if let chainStr = json["chain"] as? String,
      let chain = ChainType(rawValue: chainStr) {
      self.chain = chain
    }

    if let networkStr = json["network"] as? String,
      let network = Network(rawValue: networkStr) {
      self.network = network
    }

    if let mode = Mode(rawValue: (json["mode"] as? String) ?? "") {
      self.mode = mode
    }

    if let name = json["name"] as? String {
      self.name = name
    }

    if let passwordHint = json["passwordHint"] as? String {
      self.passwordHint = passwordHint
    }

    if let segWitStr = json["segWit"] as? String, let segWit = SegWit(rawValue: segWitStr) {
      self.segWit = segWit
    }

    if let backup = json["backup"] as? [String] {
      self.backup = backup
    }
  }

  func mergeMeta(_ name: String, chainType: ChainType) -> WalletMeta {
    var metadata = self
    metadata.name = name
    metadata.chain = chainType
    return metadata
  }

  func toJSON() -> JSONObject {
    var json: JSONObject = [
      "source": source.rawValue,
      "timestamp": "\(timestamp)",
      "version": version,
      "mode": mode.rawValue,
      "name": name,
      "passwordHint": passwordHint,
      "backup": backup
    ]
    if chain != nil {
      json["chain"] = chain!.rawValue
    }

    if network != nil {
      json["network"] = network!.rawValue
    }

    json["segWit"] = segWit.rawValue
    
    return json
  }

  var isSegWit: Bool {
    return segWit.isSegWit
  }

  var isMainnet: Bool {
    if let network = network {
      return network.isMainnet
    }
    return true
  }

  // swiftlint:disable force_cast
  private static var currentVersion: String {
    if let versionString = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String {
      return
        "iOS-"
          + versionString
          + "."
          + (Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as! String)
    }

    return "none-loaded-bundle"
  }

  private static var currentTime: Double {
    return Double(Date().timeIntervalSince1970)
  }
}
