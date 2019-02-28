# TokenCore
TokenCore is a blockchain library. TokenCore provides the relatively consistent API that allows you to manage your wallets and sign transactions in BTC, ETH and EOS chains simultaneously.
In addition, TokenCore introduces the concept of 'identity', you can use the same mnemonic to manage wallets on the three chains.

## Installation
To install TokenCore, use CocoaPods and add this to your Podfile:

```
pod "TokenCore", git: "https://github.com/consenlabs/token-core-ios.git", branch: "master"
```

## Run the Example   
The example show how to manager the wallet and sign transaction, the eos sign will coming soon.    
```
$ cd Example
$ pod install
```

## Try the API
### Create new Identity and derive the eth, btc wallets
```swift
// You should create or recover Identity first before you create other wallets
do {
  var metadata = WalletMeta(source: .newIdentity)
  metadata.network = Network.mainnet
  metadata.segWit = .p2wpkh // .p2wpkh means that the derived btc wallet is a SegWit wallet
  metadata.name = "MyFirstIdentity"
  let (mnemonic, identity) = try Identity.createIdentity(password: TestData.password, metadata: metadata)
  let ethereumWallet = identity.wallets[0]
  let bitcoinWalelt = identity.wallets[1]
} catch {
  print("createIdentity failed, error:\(error)")
}
```
### Export Wallet
```swift

let prvKey = try WalletManager.exportPrivateKey(walletID: ethereumWallet.walletID, password: TestData.password)
print("PrivateKey: \(prvKey)")
let mnemonics = try WalletManager.exportMnemonic(walletID: ethereumWallet.walletID, password: TestData.password)
print("Mnemonic: \(mnemonics)")
let keystore = try WalletManager.exportKeystore(walletID: ethereumWallet.walletID, password: TestData.password)
print("Keystore: \(keystore)")

// output:
// PrivateKey: f653be3f639f45ea1ed3eb152829b6d881ce62257aa873891e06fa9569a8d9aa
// Mnemonic: tide inmate cloud around wise bargain celery cement jungle melody galaxy grocery
// Keystore: {"id":"c7575eba-3ae3-4cc3-86ba-2eb9c6839cad","version":3,"crypto":{"ciphertext":"7083ba3dd5470ba4be4237604625e05fa6b668954d270beb848365cbf6933ec5","mac":"f4f9ea8d42ff348b11fc146c396da446cc975309b3538e08a58c0b218bddd15d","cipher":"aes-128-ctr","cipherparams":{"iv":"db3f523faf4da4f1c6edcd7bc1386879"},"kdf":"pbkdf2","kdfparams":{"dklen":32,"c":10240,"prf":"hmac-sha256","salt":"0ce830e9f888dfe33c31e6cfc444d6f588161c9d4128d4066ee5dfdcbc5d0079"}},"address":"4a1c2072ac67b616e5c578fd9e2a4d30e0158471"}
```

### SignTransaction
```swift
let signResult = WalletManager.ethSignTransaction(
        walletID: String,
        nonce: String,
        gasPrice: String,
        gasLimit: String,
        to: String,
        value: String,
        data: String,
        password: String,
        chainID: Int
      )
let signedTx = signResult.signedTx // This is the signature result which you need to broadcast.
let txHahs = signResult.txHash // This is txHash which you can use for locating your transaction record
```


## Troubleshooting
For macOS 10.14 Mojave and Xcode 10, install `/Library/Developer/CommandLineTools/Packages/macOS_SDK_headers_for_macOS_10.14.pkg` since Xcode command line tools don't install to `/usr/include` anymore.

## TODO
- [ ] Test on Objective-C   
- [ ] upgrade the `BigInt` from 3.0 to 3.1  


## Copyright and License

```
  Copyright 2018 imToken PTE. LTD.

  Licensed under the Apache License, Version 2.0 (the "License");
  you may not use this file except in compliance with the License.
  You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

  Unless required by applicable law or agreed to in writing, software
  distributed under the License is distributed on an "AS IS" BASIS,
  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
  See the License for the specific language governing permissions and
  limitations under the License.
```

## Thanks and more info
Thanks bitcoinj, CoreBitcoin and others library.
