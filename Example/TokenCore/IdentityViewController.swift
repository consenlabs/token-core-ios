//
//  ViewController.swift
//  TokenCore
//
//  Created by Neal Xu on 11/01/2018.
//  Copyright (c) 2018 Neal Xu. All rights reserved.
//

import UIKit
import PureLayout
import MBProgressHUD
import TokenCore

class IdentityViewController: UIViewController {
  
  let createIdentityBtn: UIButton = {
    let btn = UIButton.init(type: .system)
    btn.configureForAutoLayout()
    btn.setTitle("Create Identity", for: .normal)
    return btn
  }()
  
  let recoverIdentityBtn: UIButton = {
    let btn = UIButton.init(type: .system)
    btn.configureForAutoLayout()
    btn.setTitle("Recover Identity", for: .normal)
    return btn
  }()
  
  let logTextField: UITextView  = {
    let textField  = UITextView.newAutoLayout()
    textField.textColor  = UIColor.black
    textField.text  = "Log will printed here"
    return textField
  }()
  
  let managerWalletBtn: UIButton = {
    let btn = UIButton(type: .system)
    btn.setTitle("Manage the wallets", for: .normal)
    btn.isHidden = true
    return btn
  }()
  
  let introduceLabel: UITextView = {
    let label =  UITextView.newAutoLayout()
    label.textColor  = UIColor.black
    label.text = "The identity in TokenCore contains an unique id, ipfsId, and some other ids. All those ids are derived from your menmonic, and when you create & recover the Identity, TokenCore will derived the default ETH and BTC Wallet"
    label.isScrollEnabled = false
    label.font = UIFont.systemFont(ofSize: 16.0)
    return label
  }()
  
  var didSetupConstraints = false
  
  override func loadView() {
    view = UIView()
    view.backgroundColor = UIColor.white
    view.addSubview(createIdentityBtn)
    view.addSubview(recoverIdentityBtn)
    view.addSubview(logTextField)
    view.addSubview(managerWalletBtn)
    view.addSubview(introduceLabel)
    
    view.setNeedsUpdateConstraints()
  }
  
  override func updateViewConstraints() {
    if !didSetupConstraints {
      introduceLabel.autoPinEdge(toSuperviewSafeArea: .top)
      introduceLabel.autoMatch(.width, to: .width, of: self.view)
      
      let views = [createIdentityBtn, recoverIdentityBtn] as NSArray
      
      createIdentityBtn.autoPinEdge(.top, to: .bottom, of: introduceLabel, withOffset: 20.0)
      
      
      views.autoDistributeViews(along: .horizontal, alignedTo: .top, withFixedSpacing: 8.0)
      views.autoSetViewsDimension(.height, toSize: 24.0)
      
      logTextField.autoPinEdge(.top, to: .bottom, of: createIdentityBtn)
      logTextField.autoPinEdge(toSuperviewEdge: .bottom)
      logTextField.autoPinEdge(toSuperviewEdge: .left)
      logTextField.autoPinEdge(toSuperviewEdge: .right)
      
      managerWalletBtn.autoMatch(.width, to: .width, of: self.view)
      managerWalletBtn.autoSetDimension(.height, toSize: 30.0)
      managerWalletBtn.autoPinEdge(toSuperviewSafeArea: .bottom)
      
      didSetupConstraints = true
    }
    super.updateViewConstraints()
  }

  override func viewDidLoad() {
    super.viewDidLoad()
    // Do any additional setup after loading the view, typically from a nib.
    self.title = "Identity Management"
    createIdentityBtn.addTarget(self, action: #selector(handleCreateIdentityBtn(_:)), for: .touchUpInside)
    recoverIdentityBtn.addTarget(self, action: #selector(handleRecoverIdentityClick(_:)), for: .touchUpInside)
  }

  override func didReceiveMemoryWarning() {
    super.didReceiveMemoryWarning()
    // Dispose of any resources that can be recreated.
  }
  
  @objc
  func handleCreateIdentityBtn(_ sender: Any) {
    self.generateIdentity()
  }
  
  @objc
  func handleRecoverIdentityClick(_ sender: UIButton) {
    
    let alert = UIAlertController(title: "Pls input your mnemonic", message: nil, preferredStyle: .alert)
    alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
    
    alert.addTextField(configurationHandler: { textField in
      // The test mnemonic
      textField.text = Constants.testMnemonic
      textField.placeholder = "Input your mnemonic here..."
    })
    
    alert.addAction(UIAlertAction(title: "OK", style: .default, handler: { action in
      
      if let mnemonic = alert.textFields?.first?.text {
        AppState.shared.mnemonic = mnemonic
        self.generateIdentity(mnemonic: mnemonic)
      }
    }))
    
    self.present(alert, animated: true)
  }
  
  @objc
  func handleNextItemClick(_ sender: UIBarButtonItem) {
    
  }
  
  func generateIdentity(mnemonic: String? = nil) {
    self.managerWalletBtn.isHidden = true
    let hud = MBProgressHUD.showAdded(to: self.view, animated: true)
    let isCreate = mnemonic == nil
    hud.label.text = isCreate ? "Create Identity..." : "Recover Identity"
    var mnemonicStr: String = ""
    DispatchQueue.global().async {
      do {
        let source = isCreate ? WalletMeta.Source.newIdentity : WalletMeta.Source.recoveredIdentity
        var metadata = WalletMeta(source: source)
        metadata.network = Network.mainnet
        metadata.segWit = .p2wpkh
        metadata.name = isCreate ? "MyFirstIdentity" : "MyRecoveredIdentity"
        let identity: Identity
        if let mnemonic = mnemonic {
          mnemonicStr = mnemonic
          identity = try Identity.recoverIdentity(metadata: metadata, mnemonic: mnemonic, password: Constants.password)
        } else {
          (mnemonicStr, identity) = try Identity.createIdentity(password: Constants.password, metadata: metadata)
        }
        
        DispatchQueue.main.async {
          var logText = self.logTextField.text ?? ""
          logText.append("\n")
          logText.append("The mnemonic:\n")
          logText.append(mnemonicStr)
          logText.append("\n")
          
          identity.wallets.forEach { wallet in
            logText.append(prettyPrintJSON(wallet.serializeToMap()))
            logText.append("\n")
          }
          
          self.logTextField.text = logText
          MBProgressHUD.hide(for: self.view, animated: true)
          self.managerWalletBtn.isHidden = false
        }
      } catch {
        print("createIdentity failed, error:\(error)")
      }
    }
  }

}

