//
//  MnemonicUtil.swift
//  token
//
//  Created by xyz on 2018/1/5.
//  Copyright © 2018 ConsenLabs. All rights reserved.
//

import Foundation
import CoreBitcoin

struct MnemonicUtil {
  static func btcMnemonicFromEngWords(_ words: String) -> BTCMnemonic {
    return BTCMnemonic(words: words.split(separator: " "), password: "", wordListType: BTCMnemonicWordListType.english)!
  }

  static func generateMnemonic() -> String {
    let entropy = Data.tk_random(of: 16)
    let words = BTCMnemonic(entropy: entropy, password: "", wordListType: .english).words as! [String]
    return words.joined(separator: " ")
  }
}
