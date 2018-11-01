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
  
  s.source        = { :git => "https://github.com/consenlabs/token-core-ios.git", :tag => "#{s.version}" }
  s.source_files  = 'TokenCore/Classes/**/*', 'TokenCore/Vendor/**/*'
  s.swift_version = "4.0"
  
  s.preserve_paths = "TokenCore/Modules"
  s.pod_target_xcconfig = {
    "SWIFT_INCLUDE_PATHS" => "${PODS_ROOT}/../../TokenCore/Modules",
    "OTHER_LDFLAGS" => "-lObjC",
    "SWIFT_OPTIMIZATION_LEVEL" => "-Owholemodule"
  }
  
  s.dependency "CryptoSwift", "0.9.0"
  s.dependency "BigInt", "3.0.0"
  s.dependency "GRKOpenSSLFramework"
  s.dependency "secp256k1.swift"
end
