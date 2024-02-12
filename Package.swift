// swift-tools-version: 5.9

import PackageDescription

let package = Package(
  name: "SocialLogin",
  platforms: [
    .iOS(.v13)
  ],
  products: [
    .library(name: "SocialLogin", targets: ["SocialLogin"])
  ],
  dependencies: [
    .package(url: "https://github.com/facebook/facebook-ios-sdk", from: "16.3.1"),
    .package(url: "https://github.com/google/GoogleSignIn-iOS", from: "7.0.0")
  ],
  targets: [
    .target(name: "SocialLogin", dependencies: [
      .product(name: "FacebookLogin", package: "facebook-ios-sdk"),
      .product(name: "GoogleSignIn", package: "GoogleSignIn-iOS")
    ])
  ]
)
