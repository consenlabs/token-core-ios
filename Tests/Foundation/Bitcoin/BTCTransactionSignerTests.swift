//
//  BTCTransactionSignerTestsTestsTestsTestsTestsTestsTestsTestsTests.swift
//  tokenTests
//
//  Created by xyz on 2018/1/5.
//  Copyright © 2018 ConsenLabs. All rights reserved.
//

import XCTest
@testable import TokenCore
import CoreBitcoin

class BTCTransactionSignerTests: TestCase {
  // transaction test will on testnet
  func testSignTransacton() {
    let singleUTXOfixture: [String: Any] = [
      "sign": "0100000001a59635c9831e9e7bd3e0d4b716a5f0c786fe394ef4736ce0c5add4c55f59d802010000006b48304502210083952613265936d8eed0b7aab1e8ae84b053edeff6396d9c4d225c65b368349f02205de73e769aeb296fc8cd053871833d8cc836ef7935c7ec9192bc755e2785da0f012102506bc1dc099358e5137292f4efdd57e400f29ba5132aa5d12b18dac1c1f6aabaffffffff0280969800000000001976a914b6fc6ecf55a41b240fd26aaed696624009818d9988ac2d522a01000000001976a914e6cfaab9a59ba187f0a45db0b169c21bb48f09b388ac00000000",
      "privateKey": "a392604efc2fad9c0b3da43b5f698a2e3f270f170d859912be0d54742275c5f6",
      "amount": Int64(10000000),
      "fee": Int64(169115),
      "to": "mxCVgJtD2jSMv2diQVJQAwwq7Cg2wbwpmG",
      "changeIdx": 0,
      "utxos": [
        [
          "txHash": "02d8595fc5d4adc5e06c73f44e39fe86c7f0a516b7d4e0d37b9e1e83c93596a5",
          "vout": 1,
          "amount": "29719880",
          "address": "n2ZNV88uQbede7C5M5jzi6SyG4GVuPpng6",
          "scriptPubKey": "76a914e6cfaab9a59ba187f0a45db0b169c21bb48f09b388ac"
        ],
      ]
    ]
    do {
      let prvKey = BTCKey(privateKey: (singleUTXOfixture["privateKey"] as! String).tk_dataFromHexString())!
      prvKey.isPublicKeyCompressed = true

      let utxos: [UTXO] = (singleUTXOfixture["utxos"] as! [[String: Any]]).map { UTXO(raw: $0)! }
    
      let signer = try BTCTransactionSigner(
        utxos: utxos,
        keys: [prvKey],
        amount: singleUTXOfixture["amount"] as! Int64,
        fee: singleUTXOfixture["fee"] as! Int64,
        toAddress: BTCAddress(string: singleUTXOfixture["to"] as? String)!,
        changeAddress: prvKey.addressTestnet!
      )
      let result = try signer.sign()
      XCTAssertEqual(result.signedTx, singleUTXOfixture["sign"] as! String)
    } catch {
      XCTFail("Create wallet failed \(error)")
    }
  }

  func testSignTransactionMultipleUTXO() {
    do {
      let identity = Identity.currentIdentity!
      let metadata = WalletMeta(chain: .btc, source: .mnemonic, network: .testnet)
      let wallet = try identity.importFromMnemonic(TestData.mnemonic, metadata: metadata, encryptBy: TestData.password, at: BIP44.btcTestnet)

      let outputs: [[String: Any]] = [
        [
          "txHash": "983adf9d813a2b8057454cc6f36c6081948af849966f9b9a33e5b653b02f227a",
          "vout": 0,
          "amount": "200000000",
          "address": "mh7jj2ELSQUvRQELbn9qyA4q5nADhmJmUC",
          "scriptPubKey": "76a914118c3123196e030a8a607c22bafc1577af61497d88ac",
          "derivedPath": "0/22"
        ],
        [
          "txHash": "45ef8ac7f78b3d7d5ce71ae7934aea02f4ece1af458773f12af8ca4d79a9b531",
          "vout": 1,
          "amount": "200000000",
          "address": "mkeNU5nVnozJiaACDELLCsVUc8Wxoh1rQN",
          "scriptPubKey": "76a914383fb81cb0a3fc724b5e08cf8bbd404336d711f688ac",
          "derivedPath": "0/0"
        ],
        [
          "txHash": "14c67e92611dc33df31887bbc468fbbb6df4b77f551071d888a195d1df402ca9",
          "vout": 0,
          "amount": "200000000",
          "address": "mkeNU5nVnozJiaACDELLCsVUc8Wxoh1rQN",
          "scriptPubKey": "76a914383fb81cb0a3fc724b5e08cf8bbd404336d711f688ac",
          "derivedPath": "0/0"
        ],
        [
          "txHash": "117fb6b85ded92e87ee3b599fb0468f13aa0c24b4a442a0d334fb184883e9ab9",
          "vout": 1,
          "amount": "200000000",
          "address": "mkeNU5nVnozJiaACDELLCsVUc8Wxoh1rQN",
          "scriptPubKey": "76a914383fb81cb0a3fc724b5e08cf8bbd404336d711f688ac",
          "derivedPath": "0/0"
        ]
      ]

      let signedResult = try WalletManager.btcSignTransaction(walletID: wallet.walletID, to: "moLK3tBG86ifpDDTqAQzs4a9cUoNjVLRE3", amount: 750000000, fee: 502130, password: TestData.password, outputs: outputs, changeIdx: 53, isTestnet: true, segWit: .none)
      let expected = "01000000047a222fb053b6e5339a9b6f9649f88a9481606cf3c64c4557802b3a819ddf3a98000000006b483045022100c4f39ce7f2448ab8e7154a7b7ce82edd034e3f33e1f917ca43e4aff822ba804c02206dd146d1772a45bb5e51abb081d066114e78bcb504671f61c5a301a647a494ac01210312a0cb31ff52c480c049da26d0aaa600f47e9deee53d02fc2b0e9acf3c20fbdfffffffff31b5a9794dcaf82af1738745afe1ecf402ea4a93e71ae75c7d3d8bf7c78aef45010000006b483045022100d235afda9a56aaa4cbe05df712202e6b1a45aab7a0c83540d3053133f15acc5602201b0e144bec3a02a5c556596040b0be81b0202c19b163bb537b8d965afd61403a0121033d710ab45bb54ac99618ad23b3c1da661631aa25f23bfe9d22b41876f1d46e4effffffffa92c40dfd195a188d87110557fb7f46dbbfb68c4bb8718f33dc31d61927ec614000000006b483045022100dd8f1e20116f96a3400f55e0c637a0ad21ae47ff92d83ffb0c3d324c684a54be0220064b0a6d316154ef07a69bd82de3a052e43c3c6bb0e55e4de4de939b093e1a3a0121033d710ab45bb54ac99618ad23b3c1da661631aa25f23bfe9d22b41876f1d46e4effffffffb99a3e8884b14f330d2a444a4bc2a03af16804fb99b5e37ee892ed5db8b67f11010000006a473044022048d8cb0f1480174b3b9186cc6fe410db765f1f9d3ce036b0d4dee0eb19aa3641022073de4bb2b00a0533e9c8f3e074c655e0695c8b223233ddecf3c99a84351d50a60121033d710ab45bb54ac99618ad23b3c1da661631aa25f23bfe9d22b41876f1d46e4effffffff028017b42c000000001976a91455bdc1b42e3bed851959846ddf600e96125423e088ac0e47f302000000001976a91412967cdd9ceb72bbdbb7e5db85e2dbc6d6c3ab1a88ac00000000";
      XCTAssertEqual(expected, signedResult.signedTx)
    } catch {
      XCTFail()
    }
  }

  func testInsufficientFunds() {
    do {
      let identity = Identity.currentIdentity!
      let metadata = WalletMeta(chain: .btc, source: .mnemonic, network: .testnet)
      let wallet = try identity.importFromMnemonic(TestData.mnemonic, metadata: metadata, encryptBy: TestData.password, at: BIP44.btcTestnet)

      let outputs: [[String: Any]] = [
        [
          "txHash": "983adf9d813a2b8057454cc6f36c6081948af849966f9b9a33e5b653b02f227a",
          "vout": 0,
          "amount": "200000000",
          "address": "mh7jj2ELSQUvRQELbn9qyA4q5nADhmJmUC",
          "scriptPubKey": "76a914118c3123196e030a8a607c22bafc1577af61497d88ac",
          "derivedPath": "0/22"
        ],
        [
          "txHash": "45ef8ac7f78b3d7d5ce71ae7934aea02f4ece1af458773f12af8ca4d79a9b531",
          "vout": 1,
          "amount": "200000000",
          "address": "mkeNU5nVnozJiaACDELLCsVUc8Wxoh1rQN",
          "scriptPubKey": "76a914383fb81cb0a3fc724b5e08cf8bbd404336d711f688ac",
          "derivedPath": "0/0"
        ]
      ]

      XCTAssertThrowsError(try WalletManager.btcSignTransaction(walletID: wallet.walletID, to: "moLK3tBG86ifpDDTqAQzs4a9cUoNjVLRE3", amount: 410000000, fee: 502130, password: TestData.password, outputs: outputs, changeIdx: 53, isTestnet: true, segWit: .none))
    } catch {
      XCTFail()
    }
  }

  func testSignSegWetTransaction() {
    do {
      let identity = Identity.currentIdentity!
      let metadata = WalletMeta(chain: .btc, source: .mnemonic, network: .testnet)
      let wallet = try identity.importFromMnemonic(TestData.mnemonic, metadata: metadata, encryptBy: TestData.password, at: BIP44.btcSegwitTestnet)

      let outputs: [[String: Any]] = [
        [
          "txHash": "c2ceb5088cf39b677705526065667a3992c68cc18593a9af12607e057672717f",
          "vout": 0,
          "amount": "50000",
          "address": "2MwN441dq8qudMvtM5eLVwC3u4zfKuGSQAB",
          "scriptPubKey": "a9142d2b1ef5ee4cf6c3ebc8cf66a602783798f7875987",
          "derivedPath": "0/0"
        ],
        [
          "txHash": "9ad628d450952a575af59f7d416c9bc337d184024608f1d2e13383c44bd5cd74",
          "vout": 0,
          "amount": "50000",
          "address": "mkeNU5nVnozJiaACDELLCsVUc8Wxoh1rQN",
          "scriptPubKey": "a91481af6d803fdc6dca1f3a1d03f5ffe8124cd1b44787",
          "derivedPath": "0/1"
        ]
      ]

      let signedResult = try WalletManager.btcSignTransaction(walletID: wallet.walletID, to: "2N9wBy6f1KTUF5h2UUeqRdKnBT6oSMh4Whp", amount: 80000, fee: 10000, password: TestData.password, outputs: outputs, changeIdx: 0, isTestnet: true, segWit: .p2wpkh)
      let expected = "020000000001027f717276057e6012afa99385c18cc692397a666560520577679bf38c08b5cec20000000017160014654fbb08267f3d50d715a8f1abb55979b160dd5bffffffff74cdd54bc48333e1d2f108460284d137c39b6c417d9ff55a572a9550d428d69a00000000171600149d66aa6399de69d5c5ae19f9098047760251a854ffffffff02803801000000000017a914b710f6e5049eaf0404c2f02f091dd5bb79fa135e87102700000000000017a914755fba51b5c443b9f16b1f86665dec10dd7a25c58702483045022100f0c66cd322e50f992ad34448fb3bf823066e5ffaa8e840a901058a863a4d950c02206cdafb1ad1ef4d938122b106069d8b435387e4d55711f50a46a8d91d9f674c550121031aee5e20399d68cf0035d1a21564868f22bc448ab205292b4279136b15ecaebc02483045022100cfe92e4ad4fbfc13be20afc6f37429e26426257d015b409d28c260544e581b2c022028412816d1fef11093b474c2c662a25a4062f4e37d06ce66207863de98814a07012103a241c8d13dd5c92475652c43bf56580fbf9f1e8bc0aa0132ddc8443c03062bb900000000";
      XCTAssertEqual(expected, signedResult.signedTx)
    } catch {
      XCTFail()
    }
  }
  
  func testSignDustOutput() {
    let singleUTXOfixture: [String: Any] = [
      "sign": "0100000001a59635c9831e9e7bd3e0d4b716a5f0c786fe394ef4736ce0c5add4c55f59d802010000006a47304402202a45e3da0432b54363557dc3b61a8002f82b7f25519029fe941dc2c5d8de40d6022058fe0410b52d927d5a3642fed2ed9e6e41a4bd50d96208d3d8b8cd2151e10b18012102506bc1dc099358e5137292f4efdd57e400f29ba5132aa5d12b18dac1c1f6aabaffffffff01684ec501000000001976a914b6fc6ecf55a41b240fd26aaed696624009818d9988ac00000000",
      "privateKey": "a392604efc2fad9c0b3da43b5f698a2e3f270f170d859912be0d54742275c5f6",
      "amount": Int64(10000000),
      "fee": Int64(169115),
      "to": "mxCVgJtD2jSMv2diQVJQAwwq7Cg2wbwpmG",
      "changeIdx": 0,
      "utxos": [
        [
          "txHash": "02d8595fc5d4adc5e06c73f44e39fe86c7f0a516b7d4e0d37b9e1e83c93596a5",
          "vout": 1,
          "amount": "29719880",
          "address": "n2ZNV88uQbede7C5M5jzi6SyG4GVuPpng6",
          "scriptPubKey": "76a914e6cfaab9a59ba187f0a45db0b169c21bb48f09b388ac"
        ],
      ]
    ]
    
    do {
      let prvKey = BTCKey(privateKey: (singleUTXOfixture["privateKey"] as! String).tk_dataFromHexString())!
      prvKey.isPublicKeyCompressed = true
      
      let utxos: [UTXO] = (singleUTXOfixture["utxos"] as! [[String: Any]]).map { UTXO(raw: $0)! }
      
      _ = try BTCTransactionSigner(
        utxos: utxos,
        keys: [prvKey],
        amount: 2000,
        fee: singleUTXOfixture["fee"] as! Int64,
        toAddress: BTCAddress(string: singleUTXOfixture["to"] as? String)!,
        changeAddress: prvKey.addressTestnet!
      )
      
      XCTFail("Should throw amount_less_than_minimum")
    } catch {
      XCTAssertEqual(GenericError.amountLessThanMinimum.localizedDescription, error.localizedDescription)
    }
    
    do {
      let prvKey = BTCKey(privateKey: (singleUTXOfixture["privateKey"] as! String).tk_dataFromHexString())!
      prvKey.isPublicKeyCompressed = true
      
      let utxos: [UTXO] = (singleUTXOfixture["utxos"] as! [[String: Any]]).map { UTXO(raw: $0)! }
      
      let signer = try BTCTransactionSigner(
        utxos: utxos,
        keys: [prvKey],
        amount: (29719880 - 12000),
        fee: 10000,
        toAddress: BTCAddress(string: singleUTXOfixture["to"] as? String)!,
        changeAddress: prvKey.addressTestnet!
      )
      let result = try signer.sign()
      // sign result doesn't contain change output, you can check this on : https://live.blockcypher.com/btc/decodetx/
      XCTAssertEqual(result.signedTx, singleUTXOfixture["sign"] as! String)
    } catch {
      XCTFail("Create wallet failed \(error)")
    }
  }
  
  func testSegWitSignDustOutput() {
    do {
      let identity = Identity.currentIdentity!
      let metadata = WalletMeta(chain: .btc, source: .mnemonic, network: .testnet)
      let wallet = try identity.importFromMnemonic(TestData.mnemonic, metadata: metadata, encryptBy: TestData.password, at: BIP44.btcSegwitTestnet)
      
      let outputs: [[String: Any]] = [
        [
          "txHash": "c2ceb5088cf39b677705526065667a3992c68cc18593a9af12607e057672717f",
          "vout": 0,
          "amount": "50000",
          "address": "2MwN441dq8qudMvtM5eLVwC3u4zfKuGSQAB",
          "scriptPubKey": "a9142d2b1ef5ee4cf6c3ebc8cf66a602783798f7875987",
          "derivedPath": "0/0"
        ],
        [
          "txHash": "9ad628d450952a575af59f7d416c9bc337d184024608f1d2e13383c44bd5cd74",
          "vout": 0,
          "amount": "50000",
          "address": "mkeNU5nVnozJiaACDELLCsVUc8Wxoh1rQN",
          "scriptPubKey": "a91481af6d803fdc6dca1f3a1d03f5ffe8124cd1b44787",
          "derivedPath": "0/1"
        ]
      ]
      do {
        _ = try WalletManager.btcSignTransaction(walletID: wallet.walletID, to: "2N9wBy6f1KTUF5h2UUeqRdKnBT6oSMh4Whp", amount: 2000, fee: 10000, password: TestData.password, outputs: outputs, changeIdx: 0, isTestnet: true, segWit: .p2wpkh)
        XCTFail("Should throw amount_less_than_minimum")
      } catch {
        XCTAssertEqual(GenericError.amountLessThanMinimum.localizedDescription, error.localizedDescription)
      }
      
      let signedResult = try WalletManager.btcSignTransaction(walletID: wallet.walletID, to: "2N9wBy6f1KTUF5h2UUeqRdKnBT6oSMh4Whp", amount: (50000 + 50000 - 12000), fee: 10000, password: TestData.password, outputs: outputs, changeIdx: 0, isTestnet: true, segWit: .p2wpkh)
      let expected = "020000000001027f717276057e6012afa99385c18cc692397a666560520577679bf38c08b5cec20000000017160014654fbb08267f3d50d715a8f1abb55979b160dd5bffffffff74cdd54bc48333e1d2f108460284d137c39b6c417d9ff55a572a9550d428d69a00000000171600149d66aa6399de69d5c5ae19f9098047760251a854ffffffff01c05701000000000017a914b710f6e5049eaf0404c2f02f091dd5bb79fa135e870247304402205fd9dea5df0db5cc7b1d4b969f63b4526fb00fd5563ab91012cb511744a53d570220784abfe099a2b063b1cfc1f145fef2ffcb100b0891514fa164d357f0ef7ca6bb0121031aee5e20399d68cf0035d1a21564868f22bc448ab205292b4279136b15ecaebc02483045022100b0246c12428dbf863fcc9060ab6fc46dc2135adaa6cf8117de49f9acecaccf6c022059377d05c9cab24b7dec14242ea3206cc1f464d5ff9904dca515fc71766507cd012103a241c8d13dd5c92475652c43bf56580fbf9f1e8bc0aa0132ddc8443c03062bb900000000";
      // sign result doesn't contain change output, you can check this on : https://live.blockcypher.com/btc/decodetx/
      XCTAssertEqual(expected, signedResult.signedTx)
    } catch {
      XCTFail()
    }
  }
  
  func testSignMultiUXTOBySegWit() {
    do {
      let identity = Identity.currentIdentity!
      let metadata = WalletMeta(chain: .btc, source: .wif, network: .testnet)
      let wallet = try identity.importFromPrivateKey("cT4fTJyLd5RmSZFHnkGmVCzXDKuJLbyTt7cy77ghTTCagzNdPH1j", encryptedBy: TestData.password, metadata: metadata)
    
      let outputs: [[String: Any]] = [
        [
          "txHash": "ea2cdabdb11f2afdbe9e9d51744d5924bb3917ae4b383b3ef7c9c3dbb691653a",
          "vout": 1,
          "amount": "100000000",
          "address": "2NARMf1Wb3rhiYhGBwYuCgKEDi4zmojTsvk",
          "scriptPubKey": "a914bc64b2d79807cd3d72101c3298b89117d32097fb87",
          "derivedPath": ""
        ],
        [
          "txHash": "ad3b68e534f6deb12e1b8c1e1098b76e4b29c0e60416daae90487a91a982e366",
          "vout": 0,
          "amount": "100000000",
          "address": "2NARMf1Wb3rhiYhGBwYuCgKEDi4zmojTsvk",
          "scriptPubKey": "a914bc64b2d79807cd3d72101c3298b89117d32097fb87",
          "derivedPath": ""
        ]
      ]
    
      let signedResult  = try WalletManager.btcSignTransaction(walletID: wallet.walletID, to: "mvqN876ymCo7HbRbmYoaoMfwigBdEKx4J1", amount: 195000000, fee: 210090, password: TestData.password, outputs: outputs, changeIdx: 0, isTestnet: true, segWit: .p2wpkh)
      let expected = "020000000001023a6591b6dbc3c9f73e3b384bae1739bb24594d74519d9ebefd2a1fb1bdda2cea0100000017160014e6cfaab9a59ba187f0a45db0b169c21bb48f09b3ffffffff66e382a9917a4890aeda1604e6c0294b6eb798101e8c1b2eb1def634e5683bad0000000017160014e6cfaab9a59ba187f0a45db0b169c21bb48f09b3ffffffff02c0769f0b000000001976a914a80543dc9a417df6cccd36d1c1d85b04a8a4f49f88ac961649000000000017a914bc64b2d79807cd3d72101c3298b89117d32097fb870247304402204dfe8a3b8d22d7ebf762067ea4696b660c6550c92121ee11d582887b4c66e84302200d2945733954ff9f5edc259181f25206fcda79b04f5d453f7f536755dd6bb39d012102506bc1dc099358e5137292f4efdd57e400f29ba5132aa5d12b18dac1c1f6aaba02483045022100d6d1d9fa05f40d215554a0ca15642aca73e4f3edf47f7fc8edc52f80289d9dd40220162a53822d0a6913c22b27ffe60543d7b8ec2ff7943ce6f15a56f874daa33c89012102506bc1dc099358e5137292f4efdd57e400f29ba5132aa5d12b18dac1c1f6aaba00000000";
      
      XCTAssertEqual(expected, signedResult.signedTx)
      XCTAssertEqual("cb875cbaabe98e37f179b813a567350dae47cbd4770c5f499cf32869ca6d070d", signedResult.wtxID)
      XCTAssertEqual("d25fa6a70404e9ad051a2ef12128e02736668736dbab9d427d132e61c551f5a9", signedResult.txHash)
    } catch {
      XCTFail("\(error)")
    }
  }
  
  
}
