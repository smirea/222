// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "222",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [.executable(name: "222", targets: ["App"])],
    targets: [.executableTarget(name: "App", resources: [.process("Assets.xcassets")])]
)
