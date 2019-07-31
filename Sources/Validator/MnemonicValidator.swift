//
//  MnemonicValidator.swift
//  token
//
//  Created by James Chen on 2016/10/08.
//  Copyright © 2016 imToken PTE. LTD. All rights reserved.
//

import Foundation
import CoreBitcoin

public class MnemonicValidator: Validator {
  public typealias Result = String
  private let validLengths = [12, 15, 18, 21, 24] // https://dcpos.github.io/bip39/
  private let mnemonic: Mnemonic

  public init(_ mnemonic: Mnemonic) {
    self.mnemonic = mnemonic
  }

  public init(_ map: [AnyHashable: Any]) throws {
    guard let mnemonic = map["mnemonic"] as? String else {
      throw GenericError.paramError
    }
    self.mnemonic = mnemonic.tk_tidyMnemonic()
  }

  private var words: [String] {
    return mnemonic.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
      .trimmingCharacters(in: .whitespaces)
      .components(separatedBy: " ")
  }

  var isLengthValid: Bool {
    return validLengths.contains(words.count)
  }

  var isWordListValid: Bool {
    return !words.contains(where: { word -> Bool in
      !MnemonicDictionary.dictionary.contains(word)
    })
  }

  var isChecksumValid: Bool {
    let btcMnemonic = BTCMnemonic(words: words, password: "", wordListType: BTCMnemonicWordListType.english)
    return btcMnemonic != nil
  }

  public var isValid: Bool {
    return isLengthValid && isWordListValid && isChecksumValid
  }

  public func validate() throws -> Result {
    if !isLengthValid {
      throw MnemonicError.lengthInvalid
    }

    if !isWordListValid {
      throw MnemonicError.wordInvalid
    }

    if !isChecksumValid {
      throw MnemonicError.checksumInvalid
    }

    return mnemonic
  }
}
