Pod::Spec.new do |s|
  s.name          = "TokenCore"
  s.version       = "0.1"
  s.summary       = "Blockchain Library for imToken"
  
  s.description   = <<-DESC
  Token Core Library powering imToken iOS app.
  DESC
  
  s.homepage      = "https://token.im"
  s.license       = {
    type: "Apache License, Version 2.0",
    file: "LICENSE"
  }

  s.author        = { "James Chen" => "james@ashchan.com" }
  s.platform      = :ios, "9.0"

  s.source        = { :git => "https://github.com/consenlabs/ios-token-core.git", :tag => "#{s.version}" }
  s.source_files  = "Sources/**/*.{h,m,swift}"
  s.swift_version = "4.0"
  s.dependency "CryptoSwift", "0.9.0"
  s.dependency "BigInt", "3.0.0"
  s.dependency "GRKOpenSSLFramework"
  s.dependency "CoreBitcoin"
  s.dependency "secp256k1.swift"
end
