<a href="https://github.com/Boilertalk/secp256k1.swift">
  <img src="https://storage.googleapis.com/boilertalk/logo.svg" width="100%" height="256">
</a>

<p align="center">
  <a href="https://travis-ci.org/Boilertalk/secp256k1.swift">
    <img src="http://img.shields.io/travis/Boilertalk/secp256k1.swift.svg?style=flat" alt="CI Status">
  </a>
  <a href="http://cocoapods.org/pods/secp256k1.swift">
    <img src="https://img.shields.io/cocoapods/v/secp256k1.swift.svg?style=flat" alt="Version">
  </a>
  <a href="http://cocoapods.org/pods/secp256k1.swift">
    <img src="https://img.shields.io/cocoapods/l/secp256k1.swift.svg?style=flat" alt="License">
  </a>
  <a href="http://cocoapods.org/pods/secp256k1.swift">
    <img src="https://img.shields.io/cocoapods/p/secp256k1.swift.svg?style=flat" alt="Platform">
  </a>
  <a href="https://github.com/Carthage/Carthage">
    <img src="https://img.shields.io/badge/Carthage-compatible-4BC51D.svg?style=flat" alt="Carthage compatible">
  </a>
</p>

# :alembic: secp256k1

This library provides [secp256k1](https://github.com/bitcoin-core/secp256k1) bindings for Swift with Cocoapods, Carthage and Swift Package Manager on macOS and Linux.    
The Cocoapods version supports iOS 8.0, macOS 10.10, tvOS 9.0 and watchOS 2.0. The Swift Package Manager version supports macOS and Linux.

We try to merge bug fix commits ASAP and only change the import and config structure of the original repository in order to create a compilable version for the package managers.

All credits for the original source code goes to [bitcoin-core](https://github.com/bitcoin-core).

> Note: This library only binds the original C code into a Swift package. If you want an Ethereum Web3 package which manages signatures and verifications, check out [Web3.swift](https://github.com/Boilertalk/Web3.swift)

## Example

To run the example project, run `pod try secp256k1.swift`. Or clone the repo, and run pod install from the Example directory.

## Installation

### CocoaPods

secp256k1 is available through [CocoaPods](http://cocoapods.org). To install
it, simply add the following line to your `Podfile`:

```ruby
pod 'secp256k1.swift'
```

### Carthage

secp256k1 is compatible with [Carthage](https://github.com/Carthage/Carthage), a decentralized dependency manager that builds your dependencies and provides you with binary frameworks. To install it, simply add the following line to your `Cartfile`:

```
github "Boilertalk/secp256k1.swift"
```

### Swift Package Manager

secp256k1 is compatible with Swift Package Manager v4 (Swift 4 and above). Simply add it to the dependencies in your `Package.swift`.

```Swift
dependencies: [
    .package(url: "https://github.com/Boilertalk/secp256k1.swift.git", from: "0.1.0")
]
```

## Usage

To use secp256k1 functions you need to import it first.

```Swift
import secp256k1
```

After that you can use all secp256k1 functions as described [in the official headers](https://github.com/bitcoin-core/secp256k1/tree/master/include).

## Author

Koray Koska, koray@koska.at

## License

secp256k1 is available under the MIT license. See the LICENSE file for more info.
