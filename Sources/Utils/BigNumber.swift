//
//  BigNumber.swift
//  token
//
//  Created by James Chen on 2016/11/08.
//  Copyright © 2016 imToken PTE. LTD. All rights reserved.
//

import Foundation
import BigInt

// Unsigned big number powoered by BigUInt
public struct BigNumber {
    private let value: BigUInt
    private let padding: Bool
    private let bytesLength: Int

    private init(value: BigUInt, padding: Bool, bytesLength: Int) {
        self.value = value
        self.padding = padding
        self.bytesLength = bytesLength
    }

    func serialize() -> [UInt8] {
        var bytes = value.serialize().bytes
        if padding {
            while bytes.count < bytesLength {
                bytes.insert(0x00, at: 0)
            }
        }
        return bytes
    }
  
    public func hexString() -> String {
      return Hex.hex(from: serialize())
    }

    public var description: String {
        return value.description
    }

    /// - Requires: accepts text with these formats:
    ///     * Big Int string as RLP specifies: e.g. #83729609699884896815286331701780722
    ///     * Hex string prefixed with "0x", e.g. 0x5208
    ///     * Hex string without prefix, e.g. f85f
    ///     * Int string, e.g. 1234
    /// - Returns: The parsed BigNumber instance. If input is invalid, returns 0 (with BigUInt(0) as value).
    /// - Note: if text is a hex string including only digits, parsing may fail.
    ///     For example if 0x5208 is passed in as '5208', it will be wrongly parsed as decimal 5208.
    ///
    /// If padding is true, 0x00 is padded to left to keep bytes length as input prefixed with 0s.
  public static func parse(_ text: String, padding: Bool = false, paddingLen: Int = -1) -> BigNumber {
        var padding = padding
        var value: BigUInt
        var bytesLen: Int = 0

        if text.hasPrefix("#") {
            let t = text.tk_substring(from: 1)
            value = BigUInt(extendedGraphemeClusterLiteral: t)
            bytesLen = bytesLength(of: t)
        } else if Hex.hasPrefix(text) {
            let t = Hex.removePrefix(text)
            value = BigUInt(t, radix: 16)!
            bytesLen = bytesLength(of: t)
        } else {
            if text.tk_isDigits {
                // NOTE: if text is a hex string without alhpabet this won't work.
                // It's just a simple guess. Better to pass in hex always prefixed with "0x".

                value = BigUInt(Hex.removePrefix(text), radix: 10)!
                padding = false
            } else if Hex.isHex(text) {
                let t = Hex.removePrefix(text)
                value = BigUInt(t, radix: 16)!
                bytesLen = bytesLength(of: t)
            } else {
                // Parse fail!
                value = BigUInt(0)
            }
        }
    
        bytesLen = paddingLen != -1 ? paddingLen : bytesLen

        return BigNumber(value: value, padding: padding, bytesLength: bytesLen)
    }

    private static func bytesLength(of string: String) -> Int {
        return (string.count + 1) / 2
    }
}

// MARK: - Converting Ints
extension BigNumber {
    init?(_ v: Any) {
        padding = false
        bytesLength = 0

        if let int = v as? Int64 {
            value = BigUInt(int)
        } else if let int = v as? Int {
            value = BigUInt(int)
        } else if let int = v as? UInt8 {
            value = BigUInt(int)
        } else {
            return nil
        }
    }
}
