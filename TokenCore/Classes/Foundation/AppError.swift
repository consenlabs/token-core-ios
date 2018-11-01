//
//  AppError.swift
//  token
//
//  Created by James Chen on 2016/09/20.
//  Copyright © 2016 imToken PTE. LTD. All rights reserved.
//

import Foundation

// Base protocol of errors that could be thrown from imToken.
public protocol AppError: Error {
  var message: String { get }
}

public extension AppError where Self: RawRepresentable, Self.RawValue == String {
  var message: String {
    return rawValue
  }
}

public enum PasswordError: String, AppError {
  case blank = "password_blank"
  case weak = "password_weak"
  case incorrect = "password_incorrect"
}

public enum MnemonicError: String, AppError {
  case lengthInvalid = "mnemonic_length_invalid"
  case wordInvalid = "mnemonic_word_invalid"
  case checksumInvalid = "mnemonic_checksum_invalid"
  case pathInvalid = "mnemonic_path_invalid"
}

public enum PrivateKeyError: String, AppError {
  case invalid = "privatekey_invalid"
  case wifInvalid = "wif_invalid"
  case publicKeyNotCompressed = "segwit_needs_compress_public_key"
}

public enum KeystoreError: String, AppError {
  case invalid = "keystore_invalid"
  case cipherUnsupported = "cipher_unsupported"
  case kdfUnsupported = "kdf_unsupported"
  case prfUnsupported = "prf_unsupported"
  case kdfParamsInvalid = "kdf_params_invalid"
  case macUnmatch = "mac_unmatch"
  case privateKeyAddressUnmatch = "private_key_address_not_match"
  case containsInvalidPrivateKey = "keystore_contains_invalid_private_key"
}

public enum AddressError: String, AppError {
  case invalid = "address_invalid"
  case alreadyExist = "address_already_exist"
}

public enum GenericError: String, AppError {
  case importFailed = "import_failed"
  case generateFailed = "generate_failed"
  case deleteWalletFailed = "delete_wallet_failed"
  case walletNotFound = "wallet_not_found"
  case operationUnsupported = "operation_unsupported"
  case unknownError = "unknown_error"
  case unsupportedChain = "unsupported_chain"
  case storeWalletFailed = "store_wallet_failed"
  case paramError = "param_error"
  case wifWrongNetwork = "wif_wrong_network"
  case insufficientFunds = "insufficient_funds"
  case amountLessThanMinimum = "amount_less_than_minimum"
}

public enum EOSError: String, AppError {
  case accountNameAlreadySet = "Only can set accountName once in eos wallet"
  case privatePublicNotMatch = "eos_private_public_not_match"
  case publicKeyNotFound = "eos_public_key_not_found"
  case accountNameInvalid = "eos_account_name_invalid"
  case requiredEOSWallet = "required_eos_wallet"
}

public enum IdentityError: String, AppError {
  case invalidIdentity = "invalid_identity"
  case unsupportEncryptionDataVersion = "unsupport_encryption_data_version"
  case invalidEncryptionDataSignature = "invalid_encryption_data_signature"
}
