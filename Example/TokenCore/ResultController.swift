//
//  ResultController.swift
//  TokenCore_Example
//
//  Created by xyz on 2019/2/28.
//  Copyright © 2019 CocoaPods. All rights reserved.
//

import UIKit

class ResultController: UIViewController {

  var info: String!
  
  @IBOutlet weak var textView: UITextView!
  
  override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
    self.navigationItem.title = "Result"
    textView.text = info
    print("Result:\n\(info)")
    }
    

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
    }
    */

}
