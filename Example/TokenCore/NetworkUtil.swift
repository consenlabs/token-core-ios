//
//  NetworkUtil.swift
//  TokenCore_Example
//
//  Created by xyz on 2019/3/4.
//  Copyright © 2019 CocoaPods. All rights reserved.
//

import Foundation
import Alamofire

class NetworkUtil {
  public static func get(_ url: String) -> String {
    var result: String = ""
    let semaphore = DispatchSemaphore(value: 0)
    AF.request(url).responseJSON { response in
    print("Request: \(String(describing: response.request))")   // original url request
    print("Response: \(String(describing: response.response))") // http url response
    print("Result: \(response.result)")                         // response serialization result
  
  
    if let json = response.result.value {
    print("JSON: \(json)") // serialized json response
    }
  
    if let data = response.data, let utf8Text = String(data: data, encoding: .utf8) {
    print("Data: \(utf8Text)") // original server data as UTF8 string
    result = utf8Text
    }
    semaphore.signal()
    }
    _ = semaphore.wait(timeout: .now() + 10)
    return result
  }
  
  public static func post(_ url: String, body: Parameters) -> String {
    var result: String = ""
    let semaphore = DispatchSemaphore(value: 0)
    AF.request(url, method: .post, parameters: body, encoding: JSONEncoding.default).responseJSON { response in
      print("Request: \(String(describing: response.request))")   // original url request
      print("Response: \(String(describing: response.response))") // http url response
      print("Result: \(response.result)")                         // response serialization result
      
      
      if let json = response.result.value {
        print("JSON: \(json)") // serialized json response
      }
      
      if let data = response.data, let utf8Text = String(data: data, encoding: .utf8) {
        print("Data: \(utf8Text)") // original server data as UTF8 string
        result = utf8Text
      }
      semaphore.signal()
    }
    _ = semaphore.wait(timeout: .now() + 10)
    return result
  }
}
