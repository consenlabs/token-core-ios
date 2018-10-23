//
//  Validator.swift
//  token
//
//  Created by James Chen on 2016/12/21.
//  Copyright © 2016 imToken PTE. LTD. All rights reserved.
//

import Foundation

protocol Validator {
  associatedtype Result

  var isValid: Bool { get }
  func validate() throws -> Result
}
