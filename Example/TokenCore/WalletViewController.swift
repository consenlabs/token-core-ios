//
//  Wallet.swift
//  TokenCore_Example
//
//  Created by xyz on 2018/11/5.
//  Copyright © 2018 CocoaPods. All rights reserved.
//

import UIKit

class WalletViewController: LayoutViewController {
  
  let getEthBalance: UIButton = LayoutViewController.createButton("Get ETH Balance")
  let transferEthBalance: UIButton = LayoutViewController.createButton("Transfer 0.1 Eth")
  
  let introduceLabel: UITextView = {
    let label =  UITextView.newAutoLayout()
    label.textColor  = UIColor.black
    label.text = "The identity in TokenCore contains an unique id, ipfsId, and some other ids. All those ids are derived from your menmonic, and when you create & recover the Identity, TokenCore will derived the default ETH and BTC Wallet"
    label.isScrollEnabled = false
    label.font = UIFont.systemFont(ofSize: 16.0)
    return label
  }()
  
  let logTextField: UITextView  = {
    let textField  = UITextView.newAutoLayout()
    textField.textColor  = UIColor.black
    textField.text  = "Log will printed here"
    return textField
  }()
  
  required init?(coder aDecoder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  override func fillViews() {
    view.addSubview(introduceLabel)
    view.addSubview(getEthBalance)
    view.addSubview(transferEthBalance)
    view.addSubview(logTextField)
    
  }
  
  override func fillViewConstraints() {
    introduceLabel.autoPinEdge(toSuperviewSafeArea: .top)
    introduceLabel.autoMatch(.width, to: .width, of: self.view)
    
    let views = [getEthBalance, transferEthBalance] as NSArray
    
    getEthBalance.autoPinEdge(.top, to: .bottom, of: introduceLabel, withOffset: 20.0)

    views.autoDistributeViews(along: .horizontal, alignedTo: .top, withFixedSpacing: 8.0)
    views.autoSetViewsDimension(.height, toSize: 24.0)
    
    logTextField.autoPinEdge(.top, to: .bottom, of: getEthBalance)
    logTextField.autoPinEdge(toSuperviewEdge: .bottom)
    logTextField.autoPinEdge(toSuperviewEdge: .left)
    logTextField.autoPinEdge(toSuperviewEdge: .right)
//
//    managerWalletBtn.autoMatch(.width, to: .width, of: self.view)
//    managerWalletBtn.autoSetDimension(.height, toSize: 30.0)
//    managerWalletBtn.autoPinEdge(toSuperviewSafeArea: .bottom)
  }
  
  
}
