//
//  TestHelper.swift
//  token
//
//  Created by James Chen on 2016/09/26.
//  Copyright © 2016 imToken PTE. LTD. All rights reserved.
//

import Foundation

class TestHelper {
  static func loadJSON(filename: String) -> String {
    let jsonPath = Bundle(for: TestHelper.self).path(forResource: filename, ofType: "json")!
    return try! String(contentsOfFile: jsonPath)
  }
}
