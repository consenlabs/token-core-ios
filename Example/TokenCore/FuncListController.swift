//
//  FuncListController.swift
//  TokenCore_Example
//
//  Created by xyz on 2019/2/28.
//  Copyright © 2019 CocoaPods. All rights reserved.
//

import UIKit
import MBProgressHUD
import TokenCore
import Alamofire


class FuncListController: UITableViewController {
  var requestResult = ""
  let sections = ["Manage Identity", "Manage Wallets", "Transactions"]
  let rows = [
    [
      "Create Identity",
      "Recover Identity",
      "Export Identity"
    ],
    [
      "Derive EOS Wallet",
      "Import ETH Keystore",
      "Import ETH Private Key",
      "Import ETH Mnemonic",
      "Import BTC Mnemonic",
      "Import BTC WIF"
    ],
    [
      "Transfer 0.1 ETH on Kovan",
      "Transfer 0.1 SNT on Kovan",
      "Transfer 0.01 BTC on TestNet"
    ]
  ]
  
  var nonce:Int = 1000
  
  override func viewDidLoad() {
    super.viewDidLoad()
    
  }

  override func numberOfSections(in tableView: UITableView) -> Int {
    return sections.count
  }
  
  override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    return rows[section].count
  }
  
  
  override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    let cell = tableView.dequeueReusableCell(withIdentifier: "func_cell", for: indexPath)
    cell.textLabel?.text = rows[indexPath.section][indexPath.row]
    return cell
  }
  
  override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
    return sections[section]
  }
  
  
  override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
    switch indexPath.section {
    case 0:
      switch indexPath.row {
      case 0:
        doWorkBackground("Create Identity...") {
          self.generateIdentity()
        }
        break
      case 1:
        recoverIdentity()
        break
      case 2:
        exportIdentity()
        break
      default:
        // do nothing
        break
      }
    case 1:
      switch indexPath.row {
      case 0:
        doWorkBackground("Deriving EOS Wallet") {
          self.deriveEosWallet()
        }
        break
      case 1:
        doWorkBackground("Import ETH Keystore") {
          self.importEthKeystore()
        }
        break
      case 2:
        doWorkBackground("Import ETH PrivateKey") {
          self.importEthPrivateKey()
        }
        break
      case 3:
        doWorkBackground("Import ETH Mnemonic") {
          self.importEthMnemonic()
        }
        break
      case 4:
        doWorkBackground("Import BTC Mnemonic") {
          self.importBtcMnemonic()
        }
        break
      case 5:
        doWorkBackground("Import BTC WIF") {
          self.importBtcPrivateKey()
        }
        break
      default:
        break
      }
      break
    case 2:
      switch indexPath.row {
      case 0:
        doWorkBackground("Transfer ETH") {
          self.transferEth()
          }
        break
      case 1:
        doWorkBackground("Transfer ETH Token") {
          self.transferEthToken()
        }
        break
      case 2:
        doWorkBackground("Transfer BTC") {
         self.transferBTC()
        }
        break
      default:
        break
      }
    default:
      break
    }
  }

  func generateIdentity(mnemonic: String? = nil) {
    do {
      var mnemonicStr: String = ""
      let isCreate = mnemonic == nil
      let source = isCreate ? WalletMeta.Source.newIdentity : WalletMeta.Source.recoveredIdentity
      var metadata = WalletMeta(source: source)
      metadata.network = Network.testnet
      metadata.segWit = .p2wpkh
      
      metadata.name = isCreate ? "MyFirstIdentity" : "MyRecoveredIdentity"
      let identity: Identity
      if let mnemonic = mnemonic {
        mnemonicStr = mnemonic
        identity = try Identity.recoverIdentity(metadata: metadata, mnemonic: mnemonic, password: Constants.password)
      } else {
        (mnemonicStr, identity) = try Identity.createIdentity(password: Constants.password, metadata: metadata)
      }
      
      var result = ""
      result.append("\n")
      result.append("The mnemonic:\n")
      result.append(mnemonicStr)
      result.append("\n")
      
      identity.wallets.forEach { wallet in
        result.append(prettyPrintJSON(wallet.serializeToMap()))
        result.append("\n")
      }
      requestResult = result
      return
    } catch {
      print("createIdentity failed, error:\(error)")
    }
    requestResult = "unknown error"
  }
 
  
  func recoverIdentity() {
    let alert = UIAlertController(title: "Pls input your mnemonic", message: nil, preferredStyle: .alert)
    alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
    
    alert.addTextField(configurationHandler: { textField in
      textField.text = Constants.testMnemonic
      textField.placeholder = "Input your mnemonic here..."
    })
    
    alert.addAction(UIAlertAction(title: "OK", style: .default, handler: { action in
      
      if let mnemonic = alert.textFields?.first?.text {
        self.doWorkBackground("Recover Identity...") {
          AppState.shared.mnemonic = mnemonic
          self.generateIdentity(mnemonic: mnemonic)
        }
      }
    }))
    
    self.present(alert, animated: true)
  }
  
  func exportIdentity() {
    let mnemonic = try! Identity.currentIdentity?.export(password: Constants.password)
    presentResult(mnemonic!)
  }
  
  func transferEth() {
    do {
      let ethWallet = try WalletManager.findWalletByAddress("6031564e7b2f5cc33737807b2e58daff870b590b", on: .eth)
      // chainID 41:kovan 0 testnet, 1 mainnet
      nonce += 1
      let signedResult = try WalletManager.ethSignTransaction(walletID: ethWallet.walletID, nonce: String(nonce), gasPrice: "20", gasLimit: "21000", to: "0xEAC1a91E4E847c92161bF6DFFba23e8499d46A3e", value: "1000000000000000", data: "", password: Constants.password, chainID: 41)
      // https://faucet.kovan.network/
      let requestUrl = "https://api-kovan.etherscan.io/api?module=proxy&action=eth_sendRawTransaction&hex=\(signedResult.signedTx)&apikey=SJMGV3C6S3CSUQQXC7CTQ72UCM966KD2XZ"
      requestResult = NetworkUtil.get(requestUrl)
    } catch  {
     print(error)
    }
  }
  
  func transferBTC()  {
    do {
      let btcWallet = try WalletManager.findWalletByAddress("2MwN441dq8qudMvtM5eLVwC3u4zfKuGSQAB", on: .btc)
      let utxoReq = "https://testnet.blockchain.info/unspent?active=2MwN441dq8qudMvtM5eLVwC3u4zfKuGSQAB"
      let unspentsStr = NetworkUtil.get(utxoReq)
      let json = try unspentsStr.tk_toJSON()
      let unspentsJson = json["unspent_outputs"] as! [JSONObject]
      let signed = try WalletManager.btcSignTransaction(walletID: btcWallet.walletID, to: "mv4rnyY3Su5gjcDNzbMLKBQkBicCtHUtFB", amount: Int64(1e5), fee: 10000, password: Constants.password, outputs: unspentsJson, changeIdx: 0, isTestnet: true, segWit: .p2wpkh)
      
      let signedResult = signed.signedTx
      let pushTxReq = "https://api.blockcypher.com/v1/btc/test3/txs/push?token=b41082066c8344de82c04fbca16b3883"
      let reqBody: Parameters = [
        "tx": signedResult
      ]
      requestResult = NetworkUtil.post(pushTxReq, body: reqBody)
    } catch {
      print(error)
    }
  }

  
  func transferEthToken() {
    do {
      let ethWallet = try WalletManager.findWalletByAddress("6031564e7b2f5cc33737807b2e58daff870b590b", on: .eth)
      // chainID 41:kovan 0 testnet, 1 mainnet
      nonce += 1
      
      let data = "0xa9059cbb\(Constants.password.removePrefix0xIfNeeded())\(BigNumber.parse("1000000000000000", padding: true, paddingLen: 16).hexString())"
      let tokenID = "0xf26085682797370769bbb4391a0ed05510d9029d"
      let signedResult = try WalletManager.ethSignTransaction(walletID: ethWallet.walletID, nonce: String(nonce), gasPrice: "20", gasLimit: "21000", to: tokenID, value: "0", data: data, password: Constants.password, chainID: 41)
      // https://faucet.kovan.network/
      let requestUrl = "https://api-kovan.etherscan.io/api?module=proxy&action=eth_sendRawTransaction&hex=\(signedResult.signedTx)&apikey=SJMGV3C6S3CSUQQXC7CTQ72UCM966KD2XZ"
      requestResult = NetworkUtil.get(requestUrl)
    } catch  {
      print(error)
    }
  }
  
  func importEthKeystore() {
    do {
      if let existWallet = try? WalletManager.findWalletByAddress("41983f2e3af196c1df429a3ff5cdecc45c82c600", on: .eth) {
        _ = existWallet.delete()
      }
      
      
      let meta = WalletMeta(chain: .eth, source: .keystore)
      
      let keystoreStr = """
          {
          "crypto": {
            "cipher": "aes-128-ctr",
            "cipherparams": {
              "iv": "a322450a5d78b355d3f10d32424bdeb7"
              },
            "ciphertext": "7323633304b6e10fce17725b2f6ff8190b8e2f1c4fdb29904802e8eb9cb1ac6b",
            "kdf": "pbkdf2",
            "kdfparams": {
              "c": 65535,
              "dklen": 32,
              "prf": "hmac-sha256",
              "salt": "51bcbf8d464d96fca108a6bd7779381076a3f5a6ca5242eb12c8c219f1015767"
            },
            "mac": "cf81fa8f858554a21d00a376923138e727567f686f30f77fe3bba31b40a91c56"
          },
          "id": "045861fe-0e9b-4069-92aa-0ac03cad55e0",
          "version": 3,
          "address": "41983f2e3af196c1df429a3ff5cdecc45c82c600",
          "imTokenMeta": {
            "backup": [],
            "chainType": "ETHEREUM",
            "mode": "NORMAL",
            "name": "ETH-Wallet-2",
            "passwordHint": "",
            "source": "KEYSTORE",
            "timestamp": 1519611469,
            "walletType": "V3"
            }
          }
"""
      let keystore = try! keystoreStr.tk_toJSON()
      let ethWallet = try! WalletManager.importFromKeystore(keystore, encryptedBy: Constants.password, metadata: meta)
      requestResult = "Import ETH Wallet by keystore success:\n"
      requestResult = requestResult + prettyPrintJSON(ethWallet.serializeToMap())
      requestResult = try! ethWallet.privateKey(password: Constants.password)
    }
  }
  
  func importEthPrivateKey() {
    do {
      if let existWallet = try? WalletManager.findWalletByAddress("41983f2e3af196c1df429a3ff5cdecc45c82c600", on: .eth) {
        _ = existWallet.delete()
      }

      let meta = WalletMeta(chain: .eth, source: .privateKey)
      let ethWallet = try! WalletManager.importFromPrivateKey(Constants.testPrivateKey, encryptedBy: Constants.password, metadata: meta)
      requestResult = "Import ETH Wallet by PrivateKey success:\n"
      requestResult = requestResult + prettyPrintJSON(ethWallet.serializeToMap())
      
    }
  }
  
  func importEthMnemonic() {
    do {
      if let existWallet = try? WalletManager.findWalletByAddress("41983f2e3af196c1df429a3ff5cdecc45c82c600", on: .eth) {
        _ = existWallet.delete()
      }
      
      let meta = WalletMeta(chain: .eth, source: .mnemonic)
      let ethWallet = try! WalletManager.importFromMnemonic(Constants.testMnemonic, metadata: meta, encryptBy: Constants.password, at: BIP44.eth)
      requestResult = "Import ETH Wallet by Mnemonic success:\n"
      requestResult = requestResult + prettyPrintJSON(ethWallet.serializeToMap())
    }
  }
  
  func importBtcMnemonic() {
    do {
      if let existWallet = try? WalletManager.findWalletByAddress("mpke4CzhBTV2dFZpnABT9EN1kPc4vDWZxw", on: .btc) {
        _ = existWallet.delete()
      }
      
      let meta = WalletMeta(chain: .btc, source: .mnemonic, network: .testnet)
      
      let btcWallet = try! WalletManager.importFromMnemonic(Constants.testMnemonic, metadata: meta, encryptBy: Constants.password, at: BIP44.btcSegwitTestnet)
      requestResult = "Import BTC SegWit Wallet by Mnemonic success:\n"
      requestResult = requestResult + prettyPrintJSON(btcWallet.serializeToMap())
    }
  }
  
  func importBtcPrivateKey() {
    do {
      if let existWallet = try? WalletManager.findWalletByAddress("n2ZNV88uQbede7C5M5jzi6SyG4GVuPpng6", on: .btc) {
        _ = existWallet.delete()
      }
      
      let meta = WalletMeta(chain: .btc, source: .wif, network: .testnet)
      
      let btcWallet = try! WalletManager.importFromPrivateKey(Constants.testWif, encryptedBy: Constants.password, metadata: meta)
      requestResult = "Import BTC SegWit Wallet by WIF success:\n"
      requestResult = requestResult + prettyPrintJSON(btcWallet.serializeToMap())
    }
  }
  
  func deriveEosWallet() {
    do {
      if let existWallet = try? WalletManager.findWalletByAddress("n2ZNV88uQbede7C5M5jzi6SyG4GVuPpng6", on: .btc) {
        _ = existWallet.delete()
      }
      
      guard let identity = Identity.currentIdentity else {
        requestResult = "Pls create or recover an identity first"
        return
      }
      let wallets = try! identity.deriveWallets(for: [.eos], password: Constants.password)
      let eosWallet = wallets.first!
      requestResult = "Derived EOS Wallet by identity mnemonic success:\n"
      requestResult = requestResult + prettyPrintJSON(eosWallet.serializeToMap())
    }
  }
  
  private func presentResult(_ result: String) {
    let vc = self.storyboard!.instantiateViewController(withIdentifier: "ResultController") as! ResultController
    vc.info = result
    self.navigationController?.pushViewController(vc, animated: true)
  }

  func doWorkBackground(_ workTip: String, hardWork: @escaping () -> Void) {
    let hud = MBProgressHUD.showAdded(to: self.view, animated: true)
    hud.label.text = workTip
    DispatchQueue.global().async {
      hardWork()
      
      DispatchQueue.main.async {
        MBProgressHUD.hide(for: self.view, animated: true)
        self.presentResult(self.requestResult)
      }
    }
  }
  
}
