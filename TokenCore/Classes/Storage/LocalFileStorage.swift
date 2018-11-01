//
//  LocalFileStorage.swift
//  token
//
//  Created by James Chen on 2016/09/16.
//  Copyright © 2016 imToken PTE. LTD. All rights reserved.
//

import Foundation

public final class LocalFileStorage: Storage {
  private let identityFileName = "identity.json"
  public init() {}

  public func tryLoadIdentity() -> Identity? {
    guard let jsonObject = tryLoadJSON(identityFileName) else {
      return nil
    }

    return Identity(json: jsonObject)
  }

  public func loadWalletByIDs(_ walletIDs: [String]) -> [BasicWallet] {
    var wallets = [BasicWallet]()

    for walletID in walletIDs {
      guard let id = try? WalletIDValidator(walletID: walletID).validate() else {
        continue
      }
      let json = tryLoadJSON(id)
      if json == nil {
        continue
      }

      if let wallet = try? BasicWallet(json: json!) {
        wallets.append(wallet)
      }
    }
    return wallets
  }

  public func deleteWalletByID(_ walletID: String) -> Bool {
    do {
      let id = try WalletIDValidator(walletID: walletID).validate()
      return deleteFile(id)
    } catch {
      return false
    }
  }

  public func cleanStorage() -> Bool {
    do {
      try FileManager.default.removeItem(at: walletsDirectory)
    } catch {
      return false
    }
    return true
  }

  public func flushIdentity(_ keystore: IdentityKeystore) -> Bool {
    return writeContent(keystore.dump(), to: identityFileName)
  }

  public func flushWallet(_ keystore: Keystore) -> Bool {
    do {
      let id = try WalletIDValidator(walletID: keystore.id).validate()
      return writeContent(keystore.dump(), to: id)
    } catch {
      return false
    }
  }
}

private extension LocalFileStorage {
 func tryLoadJSON(_ filename: String) -> JSONObject? {
    do {
      guard let fileContent = readFrom(filename) else {
        return nil
      }
      return try? fileContent.tk_toJSON()
    }
  }

  func readFrom(_ filename: String) -> String? {
    do {
      let filePath = walletsDirectory.appendingPathComponent(filename).path
      return try String(contentsOfFile: filePath, encoding: .utf8)
    } catch {
      return nil
    }
  }

  func writeContent(_ content: String, to filename: String) -> Bool {
    do {
      let filePath = walletsDirectory.appendingPathComponent(filename).path
      try content.write(toFile: filePath, atomically: true, encoding: .utf8)
      return true
    } catch {
      debugPrint("Error: \(error)")
      return false
    }
  }

  func deleteFile(_ filename: String) -> Bool {
    do {
      let filePath = walletsDirectory.appendingPathComponent(filename).path
      try FileManager.default.removeItem(atPath: filePath)
      return true
    } catch {
      return false
    }
  }

  var walletsDirectory: URL {
    let walletsPath = "\(NSHomeDirectory())/Documents/wallets"
    var walletsDirectory = URL(fileURLWithPath: walletsPath)

    do {
      if !FileManager.default.fileExists(atPath: walletsPath) {
        try FileManager.default.createDirectory(atPath: walletsDirectory.path, withIntermediateDirectories: true, attributes: nil)
        var resourceValues = URLResourceValues()
        resourceValues.isExcludedFromBackup = true
        try walletsDirectory.setResourceValues(resourceValues)
      }
    } catch let err {
      debugPrint(err)
    }

    return walletsDirectory
  }
}
