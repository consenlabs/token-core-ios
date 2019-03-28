//
//  LayoutViewController.swift
//  TokenCore_Example
//
//  Created by xyz on 2018/11/5.
//  Copyright © 2018 CocoaPods. All rights reserved.
//

import UIKit
import PureLayout

class LayoutViewController: UIViewController {
  
  var didSetupConstraints = false
  
  override func loadView() {
    view = UIView()
    self.fillViews()
    view.setNeedsUpdateConstraints()
  }
  
  func fillViews() {
    assertionFailure("This shoud be implemented in subclass")
  }
  
  override func updateViewConstraints() {
    if !didSetupConstraints {
      self.fillViewConstraints()
      didSetupConstraints = true
    }
    super.updateViewConstraints()
  }
  
  func fillViewConstraints() {
    assertionFailure("This shoud be implemented in subclass")
  }
  
  static func createButton(_ text: String) -> UIButton {
    let btn = UIButton.init(type: .system)
    btn.configureForAutoLayout()
    btn.setTitle(text, for: .normal)
    return btn
  }
  
  
  
  override func viewDidLoad() {
    super.viewDidLoad()
    
    // Do any additional setup after loading the view.
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
