//
//  RandomIV.swift
//  token
//
//  Created by James Chen on 2018/03/19.
//  Copyright © 2018 ConsenLabs. All rights reserved.
//

import Foundation

class RandomIV {
  let data: Data
  var value: String {
    return data.tk_toHexString()
  }

  init() {
    data = Data.tk_random(of: 16)
  }
}
