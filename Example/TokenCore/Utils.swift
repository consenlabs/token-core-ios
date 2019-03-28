//
//  Utils.swift
//  TokenCore_Example
//
//  Created by xyz on 2018/11/2.
//  Copyright © 2018 CocoaPods. All rights reserved.
//

import Foundation
import TokenCore

func prettyPrintJSON(_ obj: JSONObject) -> String  {
    // fail fast in demo
    let encoded = try! JSONSerialization.data(withJSONObject: obj, options: .prettyPrinted)
    return String(data: encoded, encoding: .utf8)!
}
